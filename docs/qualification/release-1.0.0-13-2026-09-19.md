# Kith 1.0.0 (13) internal TestFlight qualification

Date: 2026-09-19. Scope: internal TestFlight. Status: released to the one-tester Personal Testing group after exact-source archive qualification, owner-device upgrade, provider rollout and App Store Connect processing.

## Candidate behavior

- Local editing remains available without an account.
- CloudKit receives the complete local mirror and carries optional `hubOwnerID` affiliation on live records and tombstones.
- Hub receives only records explicitly approved for the verified Hub account. Approval is bound to the record payload; later new or changed iCloud content waits for fresh approval.
- Records declaring another Hub owner remain separate. Hub ownership comes from the authenticated transport session, never from payload metadata.
- Person deletion applies before child notes. An approved child becomes an owned tombstone; a pending or unresolved child blocks the parent deletion and leaves the remote page retryable.
- Stable wire record names and note-to-person references survive legacy aliases. Ambiguous and case-variant aliases fail without advancing the cursor.
- After apply changes related records, the shared runtime re-reads the committed transport projection before push, preventing stale children from being uploaded.
- The Hub contract preserves Kith `details` and `listItems`, and accepts closeness only as an integer from 1 through 5.

Kith document schema v2 persists affiliation, content approval fingerprints, original wire names and note references. Schema-v1 documents decode with empty provenance and therefore require fresh consent before Hub upload. The owner device upgraded from development build 7 to build 13 without replacing its local container. Its two-person schema-v1 document loaded intact and remained byte-for-byte unchanged because the acceptance run made no personal-data edit; the first subsequent save will persist schema v2. The pre-upgrade container backup remains the rollback artifact.

## Local verification

All checks used stable Xcode 26.6 (17F113), the iOS 26.5 SDK and simulator `28E413D9-B587-41D3-9D7C-3D903BC6F842`.

| Check | Result |
| --- | --- |
| Kith native gate | 61 unit tests and 10 UI tests passed; Release simulator build passed against remote PersonalSyncKit `6a3d228db6e296013f6ea4dc0221cda7d28591ac`. Log: `/private/tmp/kith-release-remote-pin-158.log`. |
| Final source and hosted gate | PR #32 passed the complete hosted Xcode gate at `5cbfcf944138ffe03ecebf8855f676c2c28d4e77`; its tree is the tree merged to `main` as `bf98f309056afcca518eab821f8093d1182b6670`. |
| Shared PersonalSyncKit | 76 tests in 5 suites passed locally and both hosted CI jobs passed at `6a3d228db6e296013f6ea4dc0221cda7d28591ac`. |
| Hub backend | Typecheck and 57 tests passed; Worker version `9a7b2cc0-0e6b-4b82-afad-586fcd9ff44c` is live at 100% and `/health` returns 200. |
| Landing/privacy source | `pnpm check` and all nine hosted CI jobs passed. Pages deployment `080d00c2-a61c-4711-b9de-b703d078b08a` is live from `dbd50f5bd75e2be0d3081f2ecdfc3110384bfb26`. |
| Source hygiene | `git diff --check` passed in Kith, shared and landing worktrees. |

The exact-final-source signed archive is retained at `/Users/sarthak/Desktop/fleet/.worktrees/personal-sync-158/evidence/Kith-1.0.0-13-5cbfcf9.xcarchive`. It contains `com.significanthobbies.kith` version `1.0.0` build `13`, arm64, team `8F7LXHTJZR`, Sign in with Apple and `iCloud.com.significanthobbies.kith` CloudKit entitlements. Its bundled privacy manifest passes `plutil -lint`. The app executable SHA-256 is `f1dbe39cf1a95cf5c16c1a35db6bcb9e0148ed92f53cf769a33ffde4f19d4015`; the manifest SHA-256 is `31868f51db737ce1e824590c9a2b086704a678bacdd0a5c8af12dedb749e93b4`.

App Store Connect export succeeded from that archive. The delivered upload artifact is `evidence/Kith-1.0.0-13-5cbfcf9-app-store/Kith.ipa`, SHA-256 `7e8f0cae769eec02c895faf1162b0e90e238ed8a1d3827cfd3b616e1c05626a6`.

Before installation, the build-7 app data container was copied to `/Users/sarthak/Desktop/fleet/.worktrees/personal-sync-158/evidence/Kith-device-backup-build7-20260919T1443`. Build 13 then installed over build 7 on the paired iPhone 16 Pro without replacing the container. Before and after launch, the local document retained two people, zero entries and zero deletion dates; its SHA-256 remained `529e72726d70d023e81dd40fefa3c7d47062e25414a31665b4cac3776922d347`. Launch created the new mirror ledger with one ledger entry, one pull token, one pushed fingerprint and a successful-sync timestamp. There was no Kith crash report; the instrumented development process was later terminated by iOS with signal 9 after the device locked.

## Provider observations

Transporter delivered app `6803666674` version 1.0.0 build 13 at 21:26 IST. App Store Connect completed processing, reports the binary as validated with non-exempt encryption `No`, and lists build 13 as `Testing` with a 90-day expiry in the one-tester `Personal Testing` internal group. The group now contains seven builds.

The validated schema was imported into development. CloudKit Console could not deploy individual changes, so the owner separately approved its combined immutable delta: legacy `KithDocument`, new `MirrorRecord`, two KithDocument indexes and their role changes. Console confirmed the production deployment. Fresh development and production exports are byte-for-byte identical, SHA-256 `8554a6aa1fda12a30cab49aefaa8d6b2ba5116a1ac06e7e9f0252be268c573ab`.

The corrected privacy page is live at `https://kith.significanthobbies.com/privacy/` from Pages deployment `080d00c2`. App Store Connect privacy answers and policy URL remain blank. These fields, public screenshots, category metadata and account-deletion UI are public App Store submission work, not claimed complete for this internal TestFlight target.

## Release sequence

1. Completed: shared source published at `6a3d228db6e296013f6ea4dc0221cda7d28591ac`, CI passed, and Hub version `9a7b2cc0-0e6b-4b82-afad-586fcd9ff44c` deployed at 100%.
2. Completed: Kith pinned that immutable SHA, included the queued-sync repair, passed local and hosted native gates, and merged PR #32 to `main` as `bf98f309056afcca518eab821f8093d1182b6670`.
3. Completed: landing/privacy source published and verified live from deployment `080d00c2-a61c-4711-b9de-b703d078b08a`.
4. Completed: approved combined CloudKit schema deployed and verified by a fresh production export.
5. Completed: backed up the owner-device container, installed build 13 over build 7, retained the existing local records, initialized and completed the mirror pass, and retained the backup for rollback.
6. Completed: archived and exported exact source `5cbfcf944138ffe03ecebf8855f676c2c28d4e77`, delivered the IPA, completed App Store Connect processing, and verified build 13 as `Testing` in `Personal Testing`.

The internal TestFlight release gate is complete. The acceptance run deliberately did not mutate the owner's personal records, so a post-save schema-v2 rollback drill and broader manual account-switch/tombstone journeys remain useful follow-up coverage rather than blockers for this internal build. Public App Store metadata, privacy answers, screenshots, account-deletion UI and review submission remain outside this release.
