extends RefCounted
class_name AccountDeletionOperations

## GAME-012 closed protocol adapter for BE-607's `DELETE /v1/player/account` (protocol 1.3; see
## docs/ACCOUNT_DELETION_PLAN.md). Builds the persisted operation identity that
## `BackendTransport.delete_json()` replays, and turns its result into one final outcome with a
## validated receipt. The receipt reads only the `PrivacyRequestStatus` keys it exposes, so
## additive response fields are ignored, and unrecognized status values map to `"unknown"`. An
## accepted response with an unknown status still means access was revoked.

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")

const PROTOCOL_VERSION := "1.3"
const PATH := "/v1/player/account"
const KIND := "deletion"
const STATUSES := ["pending", "processing", "completed"]
const UNKNOWN := "unknown"

const OUTCOME_ACCEPTED := "accepted"
const OUTCOME_VERSION_CONFLICT := "version_conflict"
const OUTCOME_REJECTED := "rejected"
const OUTCOME_NOT_APPLIED := "not_applied"
const OUTCOME_UNCONFIRMED := "unconfirmed"

const REASON_OFFLINE := "offline"
const REASON_RATE_LIMITED := "rate_limited"
const REASON_UNAVAILABLE := "temporarily_unavailable"
const REASON_AUTHENTICATION := "authentication"
const REASON_UNSUPPORTED_CLIENT := "unsupported_client"
const REASON_NOT_CONFIGURED := "not_configured"
const REASON_FAILED := "failed"


static func request_data() -> Dictionary:
	return {"confirmed": true}


## A new operation bound to the session that will send it. `expected_state_version` comes from a
## fresh authoritative player-state read, never from a local save generation.
static func create_operation(
	player_id: String,
	device_id: String,
	session_id: String,
	expected_state_version: int
) -> Dictionary:
	return {
		"request_id": LocalSaveCodecScript.create_uuid(),
		"idempotency_key": LocalSaveCodecScript.create_uuid(),
		"expected_state_version": expected_state_version,
		"player_id": player_id,
		"device_id": device_id,
		"session_id": session_id,
		"possibly_applied": false,
	}


## The rebuilt operation after a settled `409 state.version_conflict`. The expected state version is
## part of the backend fingerprint and the conflict is stored against the old key, so the retry needs
## a new key as well as the new version. The conflict settled the old key as not applied, so the
## rebuilt operation starts unsent.
static func rebuild_after_version_conflict(operation: Dictionary, current_state_version: int) -> Dictionary:
	return create_operation(
		str(operation.get("player_id", "")),
		str(operation.get("device_id", "")),
		str(operation.get("session_id", "")),
		current_state_version
	)


## Maps a `BackendTransport.delete_json()` result to `{outcome, possibly_applied, ...}`:
## - "accepted" adds `receipt` (`request_id`, `status`, `created_at`, `updated_at`, `complete_by`,
##   `state_version`).
## - "version_conflict" adds `current_state_version` (-1 when the response omitted it).
## - "rejected", "not_applied", and "unconfirmed" add `error` and a UI `reason`.
## An accepted envelope whose data fails validation is "unconfirmed": the server accepted something,
## and malformed data does not show that this deletion was not applied.
static func interpret_result(result: Dictionary) -> Dictionary:
	var possibly_applied := bool(result.get("possibly_applied", false))
	var transport_outcome := str(result.get("outcome", ""))
	var error := (result.get("error", {}) as Dictionary).duplicate(true)
	match transport_outcome:
		OUTCOME_ACCEPTED:
			var receipt := parse_receipt(result.get("data"), result.get("meta"))
			if bool(receipt.get("ok", false)):
				receipt.erase("ok")
				receipt.erase("error")
				return {
					"outcome": OUTCOME_ACCEPTED,
					"possibly_applied": true,
					"receipt": receipt,
				}
			return _failure(
				OUTCOME_UNCONFIRMED,
				true,
				{"code": "transport.malformed_response", "category": "internal", "http_status": 202}
			)
		OUTCOME_REJECTED:
			var code := str(error.get("code", ""))
			if code == "state.version_conflict":
				var recovery := error.get("recovery", {}) as Dictionary
				var current = recovery.get("current_state_version")
				return {
					"outcome": OUTCOME_VERSION_CONFLICT,
					"possibly_applied": possibly_applied,
					"current_state_version": (
						int(current) if _is_nonnegative_integer(current) else -1
					),
					"error": error,
				}
			return _failure(OUTCOME_REJECTED, possibly_applied, error)
		OUTCOME_NOT_APPLIED:
			return _failure(OUTCOME_NOT_APPLIED, false, error)
	return _failure(OUTCOME_UNCONFIRMED, true, error)


static func parse_receipt(data: Variant, meta: Variant) -> Dictionary:
	if not (data is Dictionary) or not (meta is Dictionary):
		return _error("Account deletion response is not an object.")
	var document := data as Dictionary
	var state_version = (meta as Dictionary).get("state_version")
	if not _is_nonnegative_integer(state_version):
		return _error("Account deletion response has no state_version.")
	if not LocalSaveCodecScript.is_uuid(document.get("request_id")):
		return _error("Account deletion response has an invalid request_id.")
	if str(document.get("kind", "")) != KIND:
		return _error("Account deletion response is not a deletion request.")
	if not (document.get("status") is String):
		return _error("Account deletion response has an invalid status.")
	for key in ["created_at", "updated_at", "complete_by"]:
		if not LocalSaveCodecScript.is_timestamp(document.get(key)):
			return _error("Account deletion response has an invalid %s." % key)
	var status := str(document.get("status", ""))
	return {
		"ok": true,
		"error": "",
		"request_id": str(document.get("request_id", "")),
		"status": status if STATUSES.has(status) else UNKNOWN,
		"created_at": str(document.get("created_at", "")),
		"updated_at": str(document.get("updated_at", "")),
		"complete_by": str(document.get("complete_by", "")),
		"state_version": int(state_version),
	}


## A coarse player-facing reason for a failed attempt. It never exposes the raw server message.
static func failure_reason(error: Dictionary) -> String:
	var code := str(error.get("code", ""))
	var category := str(error.get("category", ""))
	var http_status := int(error.get("http_status", 0))
	if code == "backend.unavailable":
		return REASON_NOT_CONFIGURED
	if code.begins_with("network."):
		return REASON_OFFLINE
	if http_status == 429 or category == "rate_limit":
		return REASON_RATE_LIMITED
	if http_status == 426 or category == "version":
		return REASON_UNSUPPORTED_CLIENT
	if category == "authentication" or http_status == 401:
		return REASON_AUTHENTICATION
	if category == "dependency" or http_status >= 500:
		return REASON_UNAVAILABLE
	return REASON_FAILED


static func _failure(outcome: String, possibly_applied: bool, error: Dictionary) -> Dictionary:
	return {
		"outcome": outcome,
		"possibly_applied": possibly_applied,
		"error": error,
		"reason": failure_reason(error),
	}


static func _is_nonnegative_integer(value: Variant) -> bool:
	if value is int:
		return int(value) >= 0
	return value is float and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= 0.0


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
