# Backend Ticket: Synchronize Public Avatar Frames

Status: **Open**

Owner repository: `../sorting-puzzle-backend`

Client implementation: the Godot client stores `avatar_frame_id` locally in save schema `8`,
renders it in the profile editor and Main Menu profile widget, and deliberately omits it from
protocol-v2 `profile_edit` operations until this ticket is implemented.

## Problem

The authoritative profile currently contains only `display_name` and `avatar_id`. A selected avatar
frame therefore does not survive account recovery or multi-device merge and cannot be shown for
remote players in leaderboards. Sending `avatar_frame_id` now would be rejected because the v2 save
schema and save-operation validation forbid unknown profile-edit fields.

## Required behavior

- Add `avatar_frame_id` to the authoritative public player profile.
- Allow only these launch IDs: `frame_classic`, `frame_gold`, `frame_leaf`, `frame_rose`,
  `frame_coral`, `frame_sky`, `frame_plum`, `frame_cocoa`, and `frame_cream`.
- Use `frame_classic` for existing profiles and for invalid legacy values.
- Accept frame-only edits and combined name/avatar/frame edits.
- Resolve frame conflicts by the same most-recent explicit profile-selection policy used for avatar
  and display name.
- Return the frame in player-state checkpoints and leaderboard rows so remote profiles render the
  correct customization.
- Keep uploaded frame images and arbitrary frame URLs unsupported.

## Backend implementation scope

1. Requirements and contract

   - Amend canonical `BACKEND_REQUIREMENTS.md` and `docs/PLAYER_PROFILES.md`.
   - Extend the v1 profile update DTO and protocol-v2 profile/checkpoint/leaderboard schemas with
     the allowlisted `avatar_frame_id`.
   - Add backward-compatible fixtures proving older clients can omit the field and receive the
     classic default.

2. Persistence and merging

   - Add an ordered migration for `player_profiles.avatar_frame_id` with a non-null classic default
     and allowlist constraint.
   - Add the field to `save_profile_edit_values` or its approved replacement so offline frame
     changes remain auditable.
   - Include the frame in guest bootstrap, account merge, state materialization, export, deletion,
     support/admin reads, and explicit-selection timestamps.

3. Mutation and synchronization

   - Update `PATCH /v1/player/profile` validation and persistence.
   - Allow `avatar_frame_id` in protocol-v2 `profile_edit` payloads.
   - Update sync replay, checkpoint projection, idempotency, rate-limit, redaction, and conflict
     tests for frame-only and combined edits.

4. Public reads

   - Return `avatar_frame_id` from player state and public-safe profile mapping.
   - Add it to Weekly, Country, and World leaderboard entries and cached page invalidation.
   - Apply `frame_classic` when a stored value cannot be safely exposed.

5. Verification

   - Unit tests for all nine allowlisted IDs and rejection of unknown IDs/URLs.
   - Database integration tests for migration, mutation, merge, state, leaderboard, export, and
     deletion paths.
   - Protocol-v2 golden fixtures for save state, save sync, and leaderboard responses.
   - Run `pnpm lint`, `pnpm typecheck`, `pnpm test:unit`, `pnpm test:integration`, and `pnpm build`.

## Client follow-up after backend release

- Add `avatar_frame_id` to the Godot `profile_edit` journal payload and backend read parsers.
- Map the authoritative checkpoint frame into `PlayerProgress` instead of preserving it as a
  local-only preference.
- Render returned frames in remote leaderboard rows.
- Add cross-repository conformance fixtures and record the backend/client commits in this ticket.

## Acceptance criteria

- A frame selected offline synchronizes after reconnect and appears on another device.
- A frame-only operation is accepted and does not alter name or avatar.
- Concurrent devices converge according to documented profile receipt ordering.
- Existing players receive `frame_classic` without migration errors.
- Leaderboard rows expose only allowlisted frames and never accept client-authored image data.
