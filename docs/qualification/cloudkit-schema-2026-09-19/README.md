# Kith internal TestFlight CloudKit schema review

Observed 19 September 2026 using schema-only `cktool export-schema` reads for team `8F7LXHTJZR`, container `iCloud.com.significanthobbies.kith`. `read-receipt.json` preserves the original read commands, UTC times, and SHA-256 hashes. No credentials were printed or manually read and no records were queried. After approval, the additive proposal was imported into development; production remains unchanged. CloudKit Console was used only for the deployment-delta review; no data view was opened.

## Actual provider state

- Production contains only built-in `Users`. Neither `KithDocument` nor `MirrorRecord` is deployed.
- Development now contains `Users`, `KithDocument.payload: BYTES QUERYABLE SORTABLE`, and the imported `MirrorRecord` proposal.
- `hubOwnerID` remains absent from production and is present on development's `MirrorRecord`.
- Schema export describes types and fields, not private database zone existence or record contents. The `Sync` zone has not been queried or verified.

## Exact proposed additive change

`production-proposed.ckdb` is the exact production deployment candidate: the observed production schema remains verbatim after a new `MirrorRecord` declaration. It adds `modifiedAt TIMESTAMP`, `payload BYTES`, `appendOnly INT64`, and `hubOwnerID STRING`, plus the standard CloudKit system fields. It deliberately does not add the development-only legacy `KithDocument` type to production. No query indexes are proposed because the transport fetches named records and zone changes.

`development-proposed.ckdb` carries the same additive `MirrorRecord` declaration on top of the observed development schema. Apple accepted that file with `cktool validate-schema` and it was imported into development after explicit authorization on 19 September 2026. A fresh export at `/private/tmp/kith-development-post-import-158.ckdb` contains `KithDocument`, `MirrorRecord` with the four proposed fields, and `Users`; only declaration order and equivalent grant formatting differ from the proposal. The validation receipt is retained at `/private/tmp/kith-cloudkit-schema-validation-158.txt`.

Apple rejects both `validate-schema` and `import-schema` when `--environment production` is supplied with `endpoint not applicable in the environment 'production'`; neither command altered production. CloudKit Console's deployment review did not allow selecting individual changes and proposed both `Create KithDocument type` and `Create MirrorRecord type`, plus KithDocument indexes and role updates. The owner explicitly approved that combined immutable delta. CloudKit Console confirmed `Changes Deployed` and `The schema is deployed to Production`.

A fresh production export is checked in as `production-post-deploy.ckdb`, SHA-256 `8554a6aa1fda12a30cab49aefaa8d6b2ba5116a1ac06e7e9f0252be268c573ab`. It is byte-for-byte identical to the fresh post-import development export and contains exactly `KithDocument`, `MirrorRecord`, and `Users` with the reviewed fields and grants.

The new type grants create permission to authenticated iCloud users and read/write to the creator. This is limited to the creator. CloudKit role grants govern public-database records, while this app uses only `privateCloudDatabase`. The development form has been validated and imported, and the approved combined delta has been deployed to production.

CloudKit custom fields permit absence. `hubOwnerID` is additive affiliation metadata, not an authentication claim: missing fields in older records must remain representable. The proposed caller/transport repair must preserve known affiliation on live records and payload-nil soft tombstones, reject conflicting affiliation, and treat unproven hard deletions conservatively. Schema presence does not prove these behaviors.

## Legacy identity and path

`ios/Sources/KithCore/CloudStore.swift` declares the legacy record type `KithDocument`, record name `current`, and payload key `payload` (lines 23–25). It reads/writes `container.privateCloudDatabase` using `CKRecord.ID(recordName: "current")`, which is the default zone. Preserve this type and field for old clients and import compatibility; do not move, clear, or re-seed its record.

The shared `CloudKitMirrorTransport` defaults to custom zone `Sync`, record type `MirrorRecord`, also in the private database. The schema proposal creates no zone and moves no records. The production candidate adds only `MirrorRecord`; it does not promote the legacy development-only `KithDocument` type.

## Approval and qualification boundary

The task is internal-only Kith TestFlight. Public App Store metadata, screenshots, account-deletion UI, and review submissions are separate unfinished work; they are not asserted here as newly required internal-beta feature gates.

Production CloudKit schema availability IS relevant to TestFlight: distribution builds use the production environment, which rejects unknown record types/fields. Source fixes, a successful simulator gate, or an unsigned archive cannot establish that production CloudKit sync works.

Production now includes the approved legacy `KithDocument` and new `MirrorRecord` types. Do not reset either environment, remove records, replace unrelated fields, or assume a binary rollback can undo schema deployment. CloudKit production schema additions cannot be removed; rollback must keep old clients compatible with the additions.

The schema-only export verifies the exact fields. The signed production-environment candidate still needs physical-device qualification with explicit, disposable test data; do not label sync continuity verified from this schema receipt alone.

Apple references checked 19 September 2026:

- https://developer.apple.com/documentation/cloudkit/integrating-a-text-based-schema-into-your-workflow
- https://developer.apple.com/documentation/CloudKit/deploying-an-icloud-container-s-schema
- https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/DesigningforCloudKit/DesigningforCloudKit.html
