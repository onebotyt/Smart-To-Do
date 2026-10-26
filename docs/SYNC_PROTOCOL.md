# Sync Protocol (design draft — implement in Milestone 3)

## Principles
Each device owns its DB. No central server. Same-Wi-Fi first; other transports only after validation.

## Per-task consistency fields
UUID, created/updated timestamps, `revision`, `device_id` (last modifier), `deleted` tombstone, change_log entry.

## Sequence
1. **Discover** a previously paired device (mDNS/DNS-SD on LAN).
2. **Authenticate + encrypt** (mutual auth using keys exchanged at pairing; see SECURITY.md).
3. **Exchange version info**: each side sends a version vector (per device_id → highest seq/revision seen).
4. **Transfer only missing changes** incl. tombstones, in batches.
5. **Apply transactionally**, then **acknowledge**; mark change_log rows synced.

## Conflict policy (v1)
- Different fields changed on each side → merge per field.
- Same field changed on both → **last-write-wins** by `updated_at`, tie-break by `device_id`; keep the losing value in a conflict log for later UI.
- Delete vs edit → delete wins unless the edit is newer than the tombstone (then resurrect). Document and test this.
- Tombstones retained for a configurable period (default 30 days) and only purged after all paired devices acked.

## Messages (JSON over encrypted channel, schema-validated)
`hello`, `version_vector`, `changes{batch,seq_range}`, `ack{seq}`, `error`. Every message has a protocol version, a random message id (replay protection), and a monotonic counter.

## Offline
Changes queue locally; sync resumes automatically on reconnect.

## Must-test scenarios
Disconnect mid-transfer, duplicate/replayed messages, simultaneous edits, clock skew, delete/edit races, crash during apply.
