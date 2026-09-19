# Kith 1.0.0 (13) internal TestFlight qualification

Date: 2026-09-19. Scope: internal TestFlight candidate. Status: source and local build qualified; publication, provider mutation, device migration and upload require explicit authorization.

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
| Kith native gate | 61 unit tests and 10 UI tests passed; Release simulator build passed. Log: `/private/tmp/kith-release-full-final-158.log`. |
| Final schema-v1 decode regression | 10 KithCore tests passed. Result bundle: `/tmp/kith-core-final-158/Logs/Test/Test-Kith-2026.09.19_18-28-39-+0530.xcresult`. |
| Shared PersonalSyncKit | 76 tests in 5 suites passed. Log: `/private/tmp/shared-release-root-tests-158.log`. |
| Hub backend | Typecheck passed; 57 tests passed. Logs: `/private/tmp/kith-hub-check-158.log` and `/private/tmp/kith-hub-tests-158.log`. |
| Landing/privacy source | `pnpm check` passed. Log: `/private/tmp/kith-privacy-check-158.log`. |
| Source hygiene | `git diff --check` passed in Kith, shared and landing worktrees. |

The current signed development archive is retained at `/Users/sarthak/Desktop/fleet/.worktrees/personal-sync-158/evidence/Kith-1.0.0-13-current.xcarchive`. It contains `com.significanthobbies.kith` version `1.0.0` build `13`, arm64, team `8F7LXHTJZR`, Sign in with Apple and `iCloud.com.significanthobbies.kith` CloudKit entitlements. Its bundled privacy manifest passes `plutil -lint`. The app executable SHA-256 is `e27b89f2d64357c0b3dc5a48d62cbf18edffda02c545ee432f1892f822bbd558`; the manifest SHA-256 is `31868f51db737ce1e824590c9a2b086704a678bacdd0a5c8af12dedb749e93b4`.

This archive uses an Apple Development identity and the local qualification package path. It is evidence that the current source archives; it is not the upload artifact. Export/upload must follow immutable remote pinning and CI.

## Provider observations

App Store Connect app `6803666674` currently has uploaded builds through 1.0.0 (6). Build 13 is unused. The Personal Testing group has automatic Xcode-build distribution enabled, so uploading build 13 may immediately distribute it internally.

CloudKit production currently contains only the built-in `Users` type. Development contains `Users` and the legacy `KithDocument.payload`; neither environment contains `MirrorRecord` or `hubOwnerID`. The exact production candidate is `cloudkit-schema-2026-09-19/production-proposed.ckdb`, SHA-256 `14e3a9efc56468c49caa263844cf38c562034cacc1ef035d7792e9d53acdcb70`. It adds only `MirrorRecord` and does not promote the legacy `KithDocument` type. The equivalent development proposal validates with `cktool`; Apple does not expose production validation through that endpoint. Nothing has been imported or deployed.

The live privacy page remains stale until the prepared `ios-landings` change is committed and deployed. App Store Connect privacy answers and policy URL are blank. These fields, public screenshots, category metadata and account-deletion UI are public App Store submission work, not claimed complete for this internal TestFlight target.

## Release sequence requiring authorization

1. Commit and push the shared PersonalSyncKit and Hub contract repair; wait for its CI and record the immutable shared commit SHA.
2. Replace Kith's qualification-only local package reference with that remote SHA, regenerate the project and resolved package, then rerun the full native gate.
3. Commit and push Kith and the landing/privacy correction; wait for CI. Deploy the corrected privacy page before distributing a build whose in-app link relies on it.
4. Import and deploy only the reviewed `production-proposed.ckdb` additions, then export the production schema again and compare it with the proposal.
5. Back up the owner document and run the signed build on a physical device using disposable records. Verify v1-to-v2 upgrade, offline edit/retry, CloudKit pull/push, Hub approval, account switch, tombstone cascade, retained store after relaunch and rollback behavior.
6. Archive from the exact pushed Kith and shared SHAs, validate/export for App Store Connect, upload build 13, and confirm processing plus its internal-testing assignment.

Astra's final source review found no remaining high-priority source blocker in the Kith approval/provenance, cascade, shared re-projection, alias or CloudKit-owner paths. The open gates above concern publishing exact source, changing provider schemas/backend/privacy hosting, migrating the owner's real local document and distributing the build.
