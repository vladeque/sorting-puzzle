#!/usr/bin/env node
// GAME-012 batch 4: server-side account-deletion checks against a disposable local backend
// (docs/ACCOUNT_DELETION_PLAN.md). Driven by scripts/tools/run_local_backend_account_deletion_check.ps1,
// which owns the database, secrets, API process, and worker run.
//
//   --phase before-worker  registers guest A with a real P-256 key, deletes it through
//                          DELETE /v1/player/account (protocol 1.3), and checks immediate revocation,
//                          exact replay of the stored 202, key reuse, a new-key status read, that A's
//                          old installation key is refused before the worker runs, and that a fresh
//                          key bootstraps a new guest. Writes the state the next phase needs.
//   --phase after-worker   reads the database through `docker compose exec postgres psql` to check
//                          that the worker anonymized A, then that A's old key now bootstraps an
//                          unrelated new player.
//
// Never prints tokens, signatures, or private keys. The state file holds the throwaway
// installation key for the disposable database only.

import { createHash, createPrivateKey, createPublicKey, generateKeyPairSync, randomUUID, sign as cryptoSign } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";

function parseArgs(argv) {
  const parsed = {
    baseUrl: "http://127.0.0.1:8080",
    phase: "",
    stateFile: "",
    backendRoot: "",
    database: "sorting_puzzle_game010",
    databaseUser: "sorting_puzzle",
  };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index + 1];
    switch (argv[index]) {
      case "--base-url": parsed.baseUrl = value; index += 1; break;
      case "--phase": parsed.phase = value; index += 1; break;
      case "--state-file": parsed.stateFile = value; index += 1; break;
      case "--backend-root": parsed.backendRoot = value; index += 1; break;
      case "--database": parsed.database = value; index += 1; break;
      case "--database-user": parsed.databaseUser = value; index += 1; break;
      default: break;
    }
  }
  if (!["before-worker", "after-worker"].includes(parsed.phase) || !parsed.stateFile) {
    throw new Error("Usage: --phase <before-worker|after-worker> --state-file <path> [--backend-root <path>]");
  }
  return parsed;
}

const args = parseArgs(process.argv.slice(2));
const BASE_URL = args.baseUrl.replace(/\/$/, "");
let failures = 0;

function check(condition, description, detail = "") {
  if (condition) {
    console.log(`  ok   ${description}`);
  } else {
    failures += 1;
    console.log(`  FAIL ${description}${detail ? ` (${detail})` : ""}`);
  }
}

function section(title) {
  console.log(`\n== ${title}`);
}

function sha256Hex(value) {
  return createHash("sha256").update(value).digest("hex");
}

function isoTimestamp() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, ".000Z");
}

function errorCode(response) {
  return response.json?.error?.code ?? `http_${response.status}`;
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
  return { status: response.status, json };
}

// An installation identity: device id plus P-256 key, as the Android Keystore client holds it.
function createInstallation(privateKeyPem = "", deviceId = "") {
  const privateKey = privateKeyPem
    ? createPrivateKey(privateKeyPem)
    : generateKeyPairSync("ec", { namedCurve: "prime256v1" }).privateKey;
  const publicKeyDer = createPublicKey(privateKey).export({ type: "spki", format: "der" });
  return {
    deviceId: deviceId || randomUUID(),
    privateKey,
    privateKeyPem: privateKey.export({ type: "pkcs8", format: "pem" }),
    publicKeyBase64: publicKeyDer.toString("base64"),
    publicKeySha256: sha256Hex(publicKeyDer),
  };
}

function requestMeta(installation, protocolVersion, sessionId = "") {
  return {
    protocol_version: protocolVersion,
    request_id: randomUUID(),
    device_id: installation.deviceId,
    ...(sessionId ? { session_id: sessionId } : {}),
    app: { platform: "android", version: "1.0.0", build: 1 },
    locale: "en-US",
    client_time: isoTimestamp(),
  };
}

async function registerGuest(installation) {
  const descriptor = {
    installation_key: { algorithm: "ecdsa_p256_sha256", public_key: installation.publicKeyBase64 },
    device_model: "sorting-puzzle-account-deletion-check",
    os_version: `node-${process.versions.node}`,
  };
  const challenge = await callApi("POST", "/v1/sessions/guest/challenge", {
    body: { meta: requestMeta(installation, "1.1"), data: descriptor },
  });
  if (challenge.status !== 200) return challenge;
  const { challenge_id: challengeId, nonce } = challenge.json.data;
  const meta = requestMeta(installation, "1.1");
  const idempotencyKey = randomUUID();
  const proof = Buffer.from(JSON.stringify([
    "guest-registration-proof/1",
    challengeId,
    nonce,
    meta.request_id,
    idempotencyKey,
    installation.deviceId,
    installation.publicKeySha256,
  ]), "utf8");
  return callApi("POST", "/v1/sessions/guest", {
    headers: { "Idempotency-Key": idempotencyKey },
    body: {
      meta,
      data: {
        ...descriptor,
        challenge_id: challengeId,
        nonce,
        signature: cryptoSign("sha256", proof, installation.privateKey).toString("base64"),
      },
    },
  });
}

function deletionRequest(installation, sessionId, expectedStateVersion, requestId) {
  const meta = requestMeta(installation, "1.3", sessionId);
  meta.request_id = requestId;
  meta.expected_state_version = expectedStateVersion;
  return { meta, data: { confirmed: true } };
}

function sql(query) {
  if (!args.backendRoot) throw new Error("--backend-root is required for database checks");
  return execFileSync(
    "docker",
    ["compose", "exec", "-T", "postgres", "psql", "-U", args.databaseUser, "-d", args.database, "-tA", "-c", query],
    { cwd: args.backendRoot, encoding: "utf8" },
  ).trim();
}

function isUuid(value) {
  return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value);
}

async function beforeWorker() {
  section("Health");
  const ready = await callApi("GET", "/health/ready");
  check(ready.status === 200 && ready.json?.status === "ready", "the API is ready");

  section("Register guest A");
  const installationA = createInstallation();
  const bootstrapA = await registerGuest(installationA);
  check(bootstrapA.status === 200, "guest A bootstraps with a real P-256 proof", errorCode(bootstrapA));
  if (bootstrapA.status !== 200) return;
  const playerA = bootstrapA.json.data.player_id;
  const sessionA = bootstrapA.json.data.session_id;
  const { access_token: accessA, refresh_token: refreshA } = bootstrapA.json.data.tokens;
  const authA = { Authorization: `Bearer ${accessA}` };
  console.log(`  player A: ${playerA}`);

  const stateA = await callApi("GET", "/v1/player/state", { headers: authA });
  const stateVersion = stateA.json?.meta?.state_version;
  check(stateA.status === 200 && Number.isInteger(stateVersion), "GET /v1/player/state returns a state version");

  section("DELETE /v1/player/account");
  const requestId = randomUUID();
  const idempotencyKey = randomUUID();
  const firstBody = deletionRequest(installationA, sessionA, stateVersion, requestId);
  const accepted = await callApi("DELETE", "/v1/player/account", {
    headers: { ...authA, "Idempotency-Key": idempotencyKey },
    body: firstBody,
  });
  const receipt = accepted.json?.data ?? {};
  check(accepted.status === 202, "the deletion is accepted with 202", errorCode(accepted));
  check(accepted.json?.meta?.protocol_version === "1.3", "the response uses protocol 1.3");
  check(accepted.json?.meta?.request_id === requestId, "the response echoes the request id");
  check(accepted.json?.meta?.state_version === stateVersion + 1, "the authoritative state version advances by one");
  check(receipt.kind === "deletion" && isUuid(receipt.request_id), "the receipt is a deletion request");
  check(["pending", "processing"].includes(receipt.status), "the receipt status is pending", receipt.status);
  const windowDays = (Date.parse(receipt.complete_by) - Date.parse(receipt.created_at)) / 86_400_000;
  check(Math.abs(windowDays - 30) < 0.01, "complete_by is 30 days after the request", `${windowDays} days`);

  section("Immediate revocation");
  const stateAfter = await callApi("GET", "/v1/player/state", { headers: authA });
  check(stateAfter.status === 401, "the deleted player's access token is rejected", errorCode(stateAfter));
  const refreshed = await callApi("POST", "/v1/sessions/refresh", {
    body: { meta: requestMeta(installationA, "1.1", sessionA), data: { refresh_token: refreshA } },
  });
  check(refreshed.status === 401, "the deleted player's refresh token is rejected", errorCode(refreshed));

  section("Replay and key reuse");
  const replay = await callApi("DELETE", "/v1/player/account", {
    headers: { ...authA, "Idempotency-Key": idempotencyKey },
    body: deletionRequest(installationA, sessionA, stateVersion, requestId),
  });
  check(replay.status === 202, "an exact replay with the original token returns the stored 202", errorCode(replay));
  check(replay.json?.data?.request_id === receipt.request_id, "the replay returns the same deletion request");
  const reused = await callApi("DELETE", "/v1/player/account", {
    headers: { ...authA, "Idempotency-Key": idempotencyKey },
    body: deletionRequest(installationA, sessionA, stateVersion + 5, randomUUID()),
  });
  check(reused.status === 409 && errorCode(reused) === "idempotency.key_reused", "a different body under the same key is key_reused", errorCode(reused));
  const statusRead = await callApi("DELETE", "/v1/player/account", {
    headers: { ...authA, "Idempotency-Key": randomUUID() },
    body: deletionRequest(installationA, sessionA, stateVersion, randomUUID()),
  });
  check(
    statusRead.status === 202 && statusRead.json?.data?.request_id === receipt.request_id,
    "a new key under the original token reads the existing request without a version conflict",
    errorCode(statusRead),
  );

  section("Installation keys before the worker runs");
  const oldKey = await registerGuest(createInstallation(installationA.privateKeyPem, installationA.deviceId));
  check(oldKey.status !== 200, "the deleted installation cannot bootstrap again", errorCode(oldKey));
  console.log(`  old installation response: ${oldKey.status} ${errorCode(oldKey)}`);
  const oldKeyNewDevice = await registerGuest(createInstallation(installationA.privateKeyPem));
  check(
    oldKeyNewDevice.status !== 200,
    "the deleted installation's key cannot bootstrap under a new device id",
    errorCode(oldKeyNewDevice),
  );
  console.log(`  old key, new device response: ${oldKeyNewDevice.status} ${errorCode(oldKeyNewDevice)}`);
  const installationB = createInstallation();
  const bootstrapB = await registerGuest(installationB);
  check(bootstrapB.status === 200, "a fresh installation key bootstraps a new guest", errorCode(bootstrapB));
  const playerB = bootstrapB.json?.data?.player_id ?? "";
  check(isUuid(playerB) && playerB !== playerA, "the fresh guest is a different player");

  writeFileSync(args.stateFile, JSON.stringify({
    playerA,
    deletionRequestId: receipt.request_id,
    installationA: { deviceId: installationA.deviceId, privateKeyPem: installationA.privateKeyPem },
    playerB,
  }));
}

async function afterWorker() {
  const state = JSON.parse(readFileSync(args.stateFile, "utf8"));
  section("Worker anonymization");
  check(
    sql(`SELECT status FROM deletion_requests WHERE deletion_request_id = '${state.deletionRequestId}'`) === "completed",
    "the deletion request is completed",
  );
  check(
    sql(`SELECT status || '|' || (deleted_at IS NOT NULL) FROM players WHERE player_id = '${state.playerA}'`) === "anonymized|true",
    "player A is an anonymized tombstone",
  );
  check(
    sql(`SELECT display_name FROM player_profiles WHERE player_id = '${state.playerA}'`) === "Deleted Player",
    "player A's profile is replaced with the anonymous profile",
  );
  check(
    sql(`SELECT count(*) FROM devices WHERE player_id = '${state.playerA}' AND anonymized_at IS NULL`) === "0",
    "player A's devices are anonymized",
  );
  check(
    sql(`SELECT status FROM players WHERE player_id = '${state.playerB}'`) === "active",
    "the fresh guest is untouched",
  );

  // The server allows one new player per installation key per 24 hours, so the old key cannot start
  // another player here at all. A real client discards the key and generates a fresh one for a new
  // game (checked before the worker). What matters is that the key never resumes the deleted player.
  section("Old installation key after the worker runs");
  const installationA = createInstallation(state.installationA.privateKeyPem);
  const rebootstrap = await registerGuest(installationA);
  console.log(`  old-key response: ${rebootstrap.status} ${errorCode(rebootstrap)}`);
  check(
    rebootstrap.json?.data?.player_id !== state.playerA,
    "the old key never resumes the deleted player",
    errorCode(rebootstrap),
  );
}

try {
  if (args.phase === "before-worker") {
    await beforeWorker();
  } else {
    await afterWorker();
  }
} catch (error) {
  failures += 1;
  console.log(`  FAIL unexpected error: ${error.message}`);
}
console.log(failures === 0 ? `\nGAME-012 ${args.phase} checks passed.` : `\nGAME-012 ${args.phase} checks failed: ${failures}`);
// exitCode rather than process.exit(): exiting with fetch's keep-alive sockets still open can crash
// Node 24 on Windows (0xC0000409) instead of reporting the result.
process.exitCode = failures === 0 ? 0 : 1;
