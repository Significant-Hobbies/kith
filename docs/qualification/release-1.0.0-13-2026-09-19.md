# Kith 1.0.0 (13) internal TestFlight qualification

Date: 2026-09-19. Scope: internal TestFlight candidate. Status: source published, provider changes verified and upload artifact exported; physical-device migration qualification and upload remain open.

## Candidate behavior

- Local editing remains available without an account.
- CloudKit receives the complete local mirror and carries optional `hubOwnerID` affiliation on live records and tombstones.
- Hub receives only records explicitly approved for the verified Hub account. Approval is bound to the record payload; later new or changed iCloud content waits for fresh approval.
- Records declaring another Hub owner remain separate. Hub ownership comes from the authenticated transport session, never from payload metadata.
- Person deletion applies before child notes. An approved child becomes an owned tombstone; a pending or unresolved child blocks the parent deletion and leaves the remote page retryable.
- Stable wire record names and note-to-person references survive legacy aliases. Ambiguous and case-variant aliases fail without advancing the cursor.
- After apply changes related records, the shared runtime re-reads the committed transport projection before push, preventing stale children from being uploaded.
- The Hub contract preserves Kith `details` and `listItems`, and accepts closeness only as an integer from 1 through 5.

Kith document schema v2 persists affiliation, content approval fingerprints, original wire names and note references. Schema-v1 documents decode with empty provenance and therefore require fresh consent before Hub upload. Old build 6 cannot read a document after it is saved as schema v2, so the owner-device upgrade and rollback exercise remains a separate migration gate.

## Local verification

All checks used stable Xcode 26.6 (17F113), the iOS 26.5 SDK and simulator `28E413D9-B587-41D3-9D7C-3D903BC6F842`.

| Check | Result |
| --- | --- |
| Kith native gate | 61 unit tests and 10 UI tests passed; Release simulator build passed against remote PersonalSyncKit `6a3d228db6e296013f6ea4dc0221cda7d28591ac`. Log: `/private/tmp/kith-release-remote-pin-158.log`. |
| Final schema-v1 decode regression | 10 KithCore tests passed. Result bundle: `/tmp/kith-core-final-158/Logs/Test/Test-Kith-2026.09.19_18-28-39-+0530.xcresult`. |
| Shared PersonalSyncKit | 76 tests in 5 suites passed locally and both hosted CI jobs passed at `6a3d228db6e296013f6ea4dc0221cda7d28591ac`. |
| Hub backend | Typecheck and 57 tests passed; Worker version `9a7b2cc0-0e6b-4b82-afad-586fcd9ff44c` is live at 100% and `/health` returns 200. |
| Landing/privacy source | `pnpm check` and all nine hosted CI jobs passed. Pages deployment `080d00c2-a61c-4711-b9de-b703d078b08a` is live from `dbd50f5bd75e2be0d3081f2ecdfc3110384bfb26`. |
| Source hygiene | `git diff --check` passed in Kith, shared and landing worktrees. |

The remote-pinned signed archive is retained at `/Users/sarthak/Desktop/fleet/.worktrees/personal-sync-158/evidence/Kith-1.0.0-13-4beda0d.xcarchive`. It contains `com.significanthobbies.kith` version `1.0.0` build `13`, arm64, team `8F7LXHTJZR`, Sign in with Apple and `iCloud.com.significanthobbies.kith` CloudKit entitlements. Its bundled privacy manifest passes `plutil -lint`. The app executable SHA-256 is `5e377dbd4e5506bcfcfed0f70b9844403d0932f10077b06403acbe901ff2dcab`; the manifest SHA-256 is `31868f51db737ce1e824590c9a2b086704a678bacdd0a5c8af12dedb749e93b4`.

App Store Connect export succeeded from that archive. The upload artifact is `evidence/Kith-1.0.0-13-4beda0d-app-store/Kith.ipa`, SHA-256 `8b272692027a866c9c6de950853b597928c4403a52262741ae9d9b03164a39f5`.

The subsequent PR review found that sync requests arriving during an active pass were not drained. The queued-sync repair is newer than this archive: the existing archive, IPA, and native receipts above do not qualify that repair. Rebuild and qualify the exact final source before upload; no upload or device migration is authorized by a source merge.

## Provider observations

App Store Connect app `6803666674` currently has uploaded builds through 1.0.0 (6). Build 13 is unused. The Personal Testing group has automatic Xcode-build distribution enabled, so uploading build 13 may immediately distribute it internally.

The validated schema was imported into development. CloudKit Console could not deploy individual changes, so the owner separately approved its combined immutable delta: legacy `KithDocument`, new `MirrorRecord`, two KithDocument indexes and their role changes. Console confirmed the production deployment. Fresh development and production exports are byte-for-byte identical, SHA-256 `8554a6aa1fda12a30cab49aefaa8d6b2ba5116a1ac06e7e9f0252be268c573ab`.

The corrected privacy page is live at `https://kith.significanthobbies.com/privacy/` from Pages deployment `080d00c2`. App Store Connect privacy answers and policy URL remain blank. These fields, public screenshots, category metadata and account-deletion UI are public App Store submission work, not claimed complete for this internal TestFlight target.

## Release sequence

1. Completed: shared source published at `6a3d228db6e296013f6ea4dc0221cda7d28591ac`, CI passed, and Hub version `9a7b2cc0-0e6b-4b82-afad-586fcd9ff44c` deployed at 100%.
2. Completed: Kith pinned that immutable SHA, regenerated the project/resolution, passed the full native gate, and published source at `4beda0d1ab728d8f7a658b903ed42e5071d9203b`.
3. Completed: landing/privacy source published and verified live from deployment `080d00c2-a61c-4711-b9de-b703d078b08a`.
4. Completed: approved combined CloudKit schema deployed and verified by a fresh production export.
5. Open: connect the paired owner iPhone, back up its Kith container, and run the signed build with disposable records. Verify v1-to-v2 upgrade, offline edit/retry, CloudKit pull/push, Hub approval, account switch, tombstone cascade, retained store after relaunch and rollback behavior.
6. Open: rebuild the archive and App Store Connect IPA from the final queued-sync repair, repeat candidate qualification, and upload only after device qualification and release approval. Then confirm processing and internal-testing assignment.

The earlier source review found no remaining high-priority blocker in the Kith approval/provenance, cascade, shared re-projection, alias or CloudKit-owner paths. The later queued-sync finding and its new qualification requirement are recorded above. Remaining release gates concern rebuilding exact source, migrating the owner's real local document, physical-device verification, and distributing the build. Provider observations here are retained receipts, not a fresh provider audit during PR review.
