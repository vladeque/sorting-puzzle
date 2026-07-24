#!/usr/bin/env node
// GAME-005: proves protocol-v2 save synchronization against the real local backend API and
// PostgreSQL. This performs genuine HTTP calls with a real P-256 installation key -- no mocking --
// exercising the exact wire contract that scripts/save/save_sync_service.gd and
// scripts/save/local_save_store.gd implement (guest challenge/bootstrap, signed operation journal
// entries, cursor/checkpoint reconciliation, multi-batch continuation).
//
// Requires a locally running backend (see ../../../sorting-puzzle-backend/docs/LOCAL_DEVELOPMENT.md):
//   pnpm db:up && pnpm bootstrap:local && pnpm generate:local-secrets && pnpm dev:api
//
// Usage: node scripts/tools/local_backend_save_sync_integration_check.mjs
//   [--base-url http://127.0.0.1:8080] [--provenance ../../configs/backend/content_provenance.json]

import { createHash, generateKeyPairSync, randomUUID, sign as cryptoSign } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const args = { baseUrl: "http://127.0.0.1:8080", provenance: null, dumpFixtures: null };
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] === "--base-url") args.baseUrl = argv[++index];
    else if (argv[index] === "--provenance") args.provenance = argv[++index];
    else if (argv[index] === "--dump-fixtures") args.dumpFixtures = argv[++index];
  }
  return args;
}

const args = parseArgs(process.argv.slice(2));
const BASE_URL = args.baseUrl.replace(/\/$/, "");
const PROVENANCE_PATH =
  args.provenance ?? path.resolve(SCRIPT_DIR, "../../configs/backend/content_provenance.json");
const fixtures = {};

function captureFixture(name, value) {
  fixtures[name] = value;
}

let failures = 0;
let checks = 0;

function check(condition, description) {
  checks += 1;
  if (condition) {
    console.log(`  ok  - ${description}`);
  } else {
    failures += 1;
    console.error(`FAIL  - ${description}`);
  }
}

function section(title) {
  console.log(`\n=== ${title} ===`);
}

// --- Canonicalization + hashing, matching packages/protocol/src/mutation-fingerprint.ts and
// scripts/save/local_save_codec.gd exactly (recursively key-sorted JSON, UTF-8 SHA-256). ---

function canonicalize(value) {
  if (value === null || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map(canonicalize);
  const out = {};
  for (const key of Object.keys(value).sort()) out[key] = canonicalize(value[key]);
  return out;
}

function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function sha256Hex(bufferOrString) {
  return createHash("sha256").update(bufferOrString).digest("hex");
}

function isoTimestamp(offsetMilliseconds = 0) {
  return new Date(Date.now() + offsetMilliseconds).toISOString();
}

// --- Real P-256 installation identity (mirrors the Android Keystore-backed client identity). ---

const { publicKey, privateKey } = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const installationPublicKeyDer = publicKey.export({ type: "spki", format: "der" });
const installationPublicKeyBase64 = installationPublicKeyDer.toString("base64");
const installationKeySha256 = sha256Hex(installationPublicKeyDer);
const deviceId = randomUUID();

function signDer(payloadBytes) {
  return cryptoSign("sha256", payloadBytes, privateKey).toString("base64");
}

function guestProofPayload({ challengeId, nonce, requestId, idempotencyKey }) {
  const fields = [
    "guest-registration-proof/1",
    challengeId,
    nonce,
    requestId,
    idempotencyKey,
    deviceId,
    installationKeySha256,
  ];
  return Buffer.from(JSON.stringify(fields), "utf8");
}

function saveOperationSignaturePayload(operationHash) {
  const domain = Buffer.from("sorting-puzzle:save-operation:2\0", "utf8");
  return Buffer.concat([domain, Buffer.from(operationHash, "ascii")]);
}

function saveOperationHash(operation) {
  const hashable = {
    format: operation.format,
    operation_id: operation.operation_id,
    device_id: operation.device_id,
    device_sequence: operation.device_sequence,
    operation_type: operation.operation_type,
    occurred_at: operation.occurred_at,
    previous_operation_hash: operation.previous_operation_hash,
    payload: operation.payload,
  };
  return sha256Hex(canonicalJson(hashable));
}

function buildOperation(operationType, payload, sequence, previousHash) {
  const operation = {
    format: "save-operation/2",
    operation_id: randomUUID(),
    device_id: deviceId,
    device_sequence: sequence,
    operation_type: operationType,
    occurred_at: isoTimestamp(),
    previous_operation_hash: previousHash,
    payload,
  };
  const operationHash = saveOperationHash(operation);
  const signature = signDer(saveOperationSignaturePayload(operationHash));
  return { ...operation, operation_hash: operationHash, signature };
}

// --- HTTP helpers. ---

function requestMeta({ protocolVersion, sessionId }) {
  return {
    protocol_version: protocolVersion,
    request_id: randomUUID(),
    device_id: deviceId,
    ...(sessionId ? { session_id: sessionId } : {}),
    app: { platform: "android", version: "1.0.0", build: 1 },
    locale: "en-US",
    client_time: isoTimestamp(),
  };
}

async function callApi(method, requestPath, { body, headers = {} } = {}) {
  const response = await fetch(`${BASE_URL}${requestPath}`, {
    method,
    headers: { "Content-Type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let json = null;
  try {
    json = text.length > 0 ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  return { status: response.status, json, text };
}

function fail(message, response) {
  console.error(`\nFATAL: ${message}`);
  if (response) console.error(JSON.stringify(response, null, 2));
  process.exit(1);
}

// --- Main scenario. ---

async function main() {
  console.log(`Target backend: ${BASE_URL}`);
  console.log(`Installation device_id: ${deviceId}`);
  console.log(`Installation public key sha256: ${installationKeySha256}`);

  const provenance = JSON.parse(readFileSync(PROVENANCE_PATH, "utf8"));
  const levelProvenance = new Map(
    provenance.levels.map((level) => [level.campaign_level, level]),
  );
  const level1 = levelProvenance.get(1);
  const level2 = levelProvenance.get(2);
  if (!level1 || !level2) fail("content_provenance.json is missing levels 1-2.");

  section("Health");
  const live = await callApi("GET", "/health/live");
  check(live.status === 200 && live.json?.status === "ok", "GET /health/live returns ok");
  const ready = await callApi("GET", "/health/ready");
  check(ready.status === 200 && ready.json?.status === "ready", "GET /health/ready returns ready");

  section("Guest challenge (POST /v1/sessions/guest/challenge)");
  const challengeRequest = await callApi("POST", "/v1/sessions/guest/challenge", {
    body: {
      meta: requestMeta({ protocolVersion: "1.1" }),
      data: {
        installation_key: { algorithm: "ecdsa_p256_sha256", public_key: installationPublicKeyBase64 },
        device_model: "sorting-puzzle-integration-check",
        os_version: "node-" + process.versions.node,
      },
    },
  });
  check(challengeRequest.status === 200, "challenge request accepted");
  if (challengeRequest.status !== 200) fail("Guest challenge failed.", challengeRequest.json);
  const challenge = challengeRequest.json.data;
  check(
    challenge.signature_payload_version === "guest-registration-proof/1",
    "challenge advertises the expected signature payload version",
  );

  section("Guest bootstrap (POST /v1/sessions/guest)");
  const bootstrapRequestId = randomUUID();
  const bootstrapIdempotencyKey = randomUUID();
  const guestSignature = signDer(
    guestProofPayload({
      challengeId: challenge.challenge_id,
      nonce: challenge.nonce,
      requestId: bootstrapRequestId,
      idempotencyKey: bootstrapIdempotencyKey,
    }),
  );
  const bootstrapMeta = requestMeta({ protocolVersion: "1.1" });
  bootstrapMeta.request_id = bootstrapRequestId;
  const bootstrapRequest = await callApi("POST", "/v1/sessions/guest", {
    headers: { "Idempotency-Key": bootstrapIdempotencyKey },
    body: {
      meta: bootstrapMeta,
      data: {
        installation_key: { algorithm: "ecdsa_p256_sha256", public_key: installationPublicKeyBase64 },
        device_model: "sorting-puzzle-integration-check",
        os_version: "node-" + process.versions.node,
        challenge_id: challenge.challenge_id,
        nonce: challenge.nonce,
        signature: guestSignature,
      },
    },
  });
  check(bootstrapRequest.status === 200, "bootstrap request accepted with a real P-256 signature");
  if (bootstrapRequest.status !== 200) fail("Guest bootstrap failed.", bootstrapRequest.json);
  captureFixture("guest_bootstrap_response", bootstrapRequest.json);
  const bootstrap = bootstrapRequest.json.data;
  check(bootstrap.device_id === deviceId, "bootstrap confirms the requesting device_id");
  check(bootstrap.authentication_level === "guest", "bootstrap issues a guest-level session");
  const playerId = bootstrap.player_id;
  let sessionId = bootstrap.session_id;
  let accessToken = bootstrap.tokens.access_token;
  console.log(`Registered player_id: ${playerId}`);
  console.log(`Session_id: ${sessionId}`);

  function authHeaders(idempotencyKey) {
    const headers = { Authorization: `Bearer ${accessToken}` };
    if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;
    return headers;
  }

  section("Initial save state (GET /v2/saves/state)");
  const initialState = await callApi("GET", "/v2/saves/state", { headers: authHeaders() });
  check(initialState.status === 200, "initial save state is readable immediately after bootstrap");
  check(
    initialState.json?.data?.checkpoint?.format === "save-checkpoint/2",
    "initial checkpoint uses the save-checkpoint/2 format",
  );
  check(
    Boolean(initialState.json?.data?.capabilities?.unrestricted_offline_play),
    "server advertises unrestricted_offline_play capability",
  );
  check(
    initialState.json?.data?.capabilities?.maximum_operations_per_request === 500,
    "server advertises the 500-operation batch limit",
  );
  const initialAvailableLives = initialState.json.data.checkpoint.lives.available_lives;

  section("Empty sync (POST /v2/saves/sync with zero operations)");
  const emptySyncRequest = {
    meta: { ...requestMeta({ protocolVersion: "2.0", sessionId }) },
    data: {
      source_namespace: { kind: "player", player_id: playerId },
      cursor: { device_id: deviceId, acknowledged_sequence: 0, acknowledged_hash: null },
      journal_head_sequence: 0,
      operations: [],
    },
  };
  const emptySync = await callApi("POST", "/v2/saves/sync", {
    headers: authHeaders(randomUUID()),
    body: emptySyncRequest,
  });
  check(emptySync.status === 200, "an empty operations batch is accepted");
  captureFixture("empty_sync_request", emptySyncRequest);
  captureFixture("empty_sync_response", emptySync.json);
  check(
    emptySync.json?.data?.acknowledged_cursor?.acknowledged_sequence === 0,
    "an empty sync leaves the acknowledged cursor unchanged",
  );
  check(
    emptySync.json?.data?.continuation?.has_more === false,
    "an empty sync reports no further continuation",
  );

  section("Signed multi-type operation batch (POST /v2/saves/sync)");
  const operations = [];
  let previousHash = null;
  let sequence = 1;
  const completion = buildOperation(
    "campaign_completion",
    {
      campaign_level: 1,
      stars: 3,
      configuration_version: level1.configuration_version,
      level_version: level1.level_version,
      rules_version: level1.rules_version,
    },
    sequence++,
    previousHash,
  );
  operations.push(completion);
  previousHash = completion.operation_hash;

  const attempt = buildOperation(
    "campaign_attempt",
    {
      campaign_level: 2,
      outcome: "failed",
      configuration_version: level2.configuration_version,
      level_version: level2.level_version,
      rules_version: level2.rules_version,
    },
    sequence++,
    previousHash,
  );
  operations.push(attempt);
  previousHash = attempt.operation_hash;

  const spend = buildOperation(
    "resource_spend",
    { asset: "coins", amount: 50, reason: "shop" },
    sequence++,
    previousHash,
  );
  operations.push(spend);
  previousHash = spend.operation_hash;

  const life = buildOperation(
    "life_state",
    {
      available_lives: 4,
      maximum_lives: 5,
      restore_interval_seconds: 3600,
      next_restore_at: null,
      observed_at: isoTimestamp(),
    },
    sequence++,
    previousHash,
  );
  operations.push(life);
  previousHash = life.operation_hash;

  const profileEdit = buildOperation(
    "profile_edit",
    { display_name: "Integration Tester", avatar_id: "avatar_cat" },
    sequence++,
    previousHash,
  );
  operations.push(profileEdit);
  previousHash = profileEdit.operation_hash;

  const batchRequest = {
    meta: requestMeta({ protocolVersion: "2.0", sessionId }),
    data: {
      source_namespace: { kind: "player", player_id: playerId },
      cursor: { device_id: deviceId, acknowledged_sequence: 0, acknowledged_hash: null },
      journal_head_sequence: operations.length,
      operations,
    },
  };
  const batchIdempotencyKey = randomUUID();
  const batchSync = await callApi("POST", "/v2/saves/sync", {
    headers: authHeaders(batchIdempotencyKey),
    body: batchRequest,
  });
  check(batchSync.status === 200, "campaign_completion/attempt/resource_spend/life_state/profile_edit are all accepted");
  if (batchSync.status !== 200) fail("Signed operation batch was rejected.", batchSync.json);
  captureFixture("batch_sync_request", batchRequest);
  captureFixture("batch_sync_response", batchSync.json);
  const batchData = batchSync.json.data;
  check(
    batchData.acknowledged_cursor.acknowledged_sequence === operations.length,
    "the acknowledged cursor advances to the submitted sequence",
  );
  check(
    batchData.acknowledged_cursor.acknowledged_hash === previousHash,
    "the acknowledged cursor hash matches the last submitted operation hash",
  );
  check(
    batchData.checkpoint.campaign.highest_completed_level === 1
      && batchData.checkpoint.campaign.current_level === 2,
    "the checkpoint reflects the selected campaign completion",
  );
  check(batchData.checkpoint.balances.coins === 250, "the checkpoint reflects the resource spend (300 - 50)");
  // mergeLives (packages/domain/src/local-first-save.ts) trusts the highest reported
  // available_lives among the base checkpoint and every submitted life_state operation --
  // an offline client can never sync itself DOWN to fewer lives than the server already
  // credits it, only up (e.g. after legitimate restoration time has passed).
  check(
    batchData.checkpoint.lives.available_lives === Math.max(initialAvailableLives, 4),
    "the checkpoint takes the maximum of the base and reported life state (life state cannot be synced downward)",
  );
  check(
    batchData.checkpoint.profile.display_name === "Integration Tester",
    "the checkpoint reflects the profile edit",
  );
  check(batchData.continuation.has_more === false, "the batch reaches the journal head");

  section("Idempotent replay (identical Idempotency-Key + body)");
  const replaySync = await callApi("POST", "/v2/saves/sync", {
    headers: authHeaders(batchIdempotencyKey),
    body: batchRequest,
  });
  check(replaySync.status === 200, "a replayed identical request/idempotency tuple is accepted");
  check(
    JSON.stringify(replaySync.json.data) === JSON.stringify(batchData),
    "a replayed request returns the identical stored response instead of double-applying operations",
  );

  section("Multi-batch continuation (POST /v2/saves/sync across two requests)");
  const continuationOperations = [];
  let continuationPreviousHash = previousHash;
  let continuationSequence = operations.length + 1;
  const totalContinuationOperations = 520;
  for (let index = 0; index < totalContinuationOperations; index += 1) {
    const operation = buildOperation(
      "life_state",
      {
        available_lives: 4,
        maximum_lives: 5,
        restore_interval_seconds: 3600,
        next_restore_at: null,
        observed_at: isoTimestamp(index),
      },
      continuationSequence++,
      continuationPreviousHash,
    );
    continuationOperations.push(operation);
    continuationPreviousHash = operation.operation_hash;
  }
  const journalHeadSequence = continuationSequence - 1;
  const firstBatch = continuationOperations.slice(0, 500);
  const secondBatch = continuationOperations.slice(500);
  check(firstBatch.length === 500, "the first continuation batch is capped at the 500-operation limit");
  check(secondBatch.length === totalContinuationOperations - 500, "the remainder is queued for a second batch");

  const firstContinuationSync = await callApi("POST", "/v2/saves/sync", {
    headers: authHeaders(randomUUID()),
    body: {
      meta: requestMeta({ protocolVersion: "2.0", sessionId }),
      data: {
        source_namespace: { kind: "player", player_id: playerId },
        cursor: {
          device_id: deviceId,
          acknowledged_sequence: batchData.acknowledged_cursor.acknowledged_sequence,
          acknowledged_hash: batchData.acknowledged_cursor.acknowledged_hash,
        },
        journal_head_sequence: journalHeadSequence,
        operations: firstBatch,
      },
    },
  });
  check(firstContinuationSync.status === 200, "the first 500-operation continuation batch is accepted");
  if (firstContinuationSync.status !== 200) fail("First continuation batch rejected.", firstContinuationSync.json);
  captureFixture("first_continuation_response", firstContinuationSync.json);
  const firstContinuationData = firstContinuationSync.json.data;
  check(
    firstContinuationData.acknowledged_cursor.acknowledged_sequence === firstBatch.at(-1).device_sequence,
    "the first batch acknowledges through its own last operation, not the full journal head",
  );
  check(
    firstContinuationData.continuation.has_more === true,
    "the server reports has_more=true while the acknowledged cursor trails the journal head",
  );
  check(
    firstContinuationData.continuation.next_device_sequence === firstBatch.at(-1).device_sequence + 1,
    "continuation.next_device_sequence points at the next unacknowledged operation",
  );

  const secondContinuationSync = await callApi("POST", "/v2/saves/sync", {
    headers: authHeaders(randomUUID()),
    body: {
      meta: requestMeta({ protocolVersion: "2.0", sessionId }),
      data: {
        source_namespace: { kind: "player", player_id: playerId },
        cursor: {
          device_id: deviceId,
          acknowledged_sequence: firstContinuationData.acknowledged_cursor.acknowledged_sequence,
          acknowledged_hash: firstContinuationData.acknowledged_cursor.acknowledged_hash,
        },
        journal_head_sequence: journalHeadSequence,
        operations: secondBatch,
      },
    },
  });
  check(secondContinuationSync.status === 200, "the second continuation batch is accepted");
  if (secondContinuationSync.status !== 200) fail("Second continuation batch rejected.", secondContinuationSync.json);
  captureFixture("second_continuation_response", secondContinuationSync.json);
  const secondContinuationData = secondContinuationSync.json.data;
  check(
    secondContinuationData.acknowledged_cursor.acknowledged_sequence === journalHeadSequence,
    "the second batch reaches the journal head",
  );
  check(
    secondContinuationData.continuation.has_more === false,
    "continuation stops reporting has_more once the journal head is reached",
  );

  section("Cursor mismatch conflict (stale cursor is rejected, not silently applied)");
  const staleCursorSync = await callApi("POST", "/v2/saves/sync", {
    headers: authHeaders(randomUUID()),
    body: {
      meta: requestMeta({ protocolVersion: "2.0", sessionId }),
      data: {
        source_namespace: { kind: "player", player_id: playerId },
        cursor: { device_id: deviceId, acknowledged_sequence: 0, acknowledged_hash: null },
        journal_head_sequence: 0,
        operations: [],
      },
    },
  });
  check(staleCursorSync.status === 409, "a stale acknowledged cursor is rejected with 409");
  check(
    staleCursorSync.json?.error?.code === "save_sync.cursor_mismatch",
    "the stale-cursor rejection uses the documented save_sync.cursor_mismatch code",
  );
  captureFixture("stale_cursor_response", { status: staleCursorSync.status, body: staleCursorSync.json });

  section("Final save state readback (GET /v2/saves/state)");
  const finalState = await callApi("GET", "/v2/saves/state", { headers: authHeaders() });
  check(finalState.status === 200, "final save state is readable");
  check(
    finalState.json?.data?.checkpoint?.generation === secondContinuationData.checkpoint.generation,
    "the readback checkpoint generation matches the last synchronize response",
  );
  const finalDeviceCursor = (finalState.json?.data?.device_cursors ?? []).find(
    (cursor) => cursor.device_id === deviceId,
  );
  check(
    finalDeviceCursor?.acknowledged_sequence === journalHeadSequence,
    "the device stream cursor persisted in PostgreSQL matches the journal head",
  );

  captureFixture("final_state_response", finalState.json);
  captureFixture("identity", { player_id: playerId, device_id: deviceId, session_id: sessionId });

  console.log(`\nPlayer id for Postgres inspection: ${playerId}`);
  console.log(`Device id for Postgres inspection: ${deviceId}`);
  console.log(`\n${checks - failures}/${checks} checks passed.`);

  if (args.dumpFixtures) {
    const { mkdirSync, writeFileSync } = await import("node:fs");
    mkdirSync(args.dumpFixtures, { recursive: true });
    for (const [name, value] of Object.entries(fixtures)) {
      writeFileSync(path.join(args.dumpFixtures, `${name}.json`), JSON.stringify(value, null, 2));
    }
    console.log(`Captured ${Object.keys(fixtures).length} real backend response fixtures to ${args.dumpFixtures}`);
  }

  if (failures > 0) {
    console.error(`${failures} check(s) FAILED.`);
    process.exit(1);
  }
  console.log("GAME-005 live backend integration check passed.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
