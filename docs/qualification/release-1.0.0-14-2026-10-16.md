# Kith 1.0.0 (14) current-source candidate

Date: 2026-10-16. Scope: qualification before a separate public App Store submission decision. No build was uploaded or submitted here.

Build 13 in internal TestFlight predates the log-card year and person-page long-date fixes. Build 14 comes from source `02721807d9f52183b5663debc306df1885e35bcc`, which includes both fixes, the current SaaSMakerUI adoption, and the dark-default design. The XcodeGen source and generated project both declare build 14.

The exact-source Release archive was built using Xcode 26.6 at `.worktrees/kith-53/evidence/Kith-1.0.0-14-0272180.xcarchive` (relative to the Fleet container). It contains `com.significanthobbies.kith` version 1.0.0 build 14. Code-signature verification and privacy-manifest lint passed. The archived executable SHA-256 is `9bf7764196b2c76f486240a6a07e9cbb85c7ee36638d41fc58dda69c2afbef99`.

A local App Store Connect export, **without upload**, succeeded using the same options as build 13. The retained `Kith.ipa` at `.worktrees/kith-53/evidence/Kith-1.0.0-14-0272180-app-store/` has SHA-256 `9803befc1c9271d9e18a49ca07bacd3066a1a1ada076d82e9d73ea5323032c03`. The exported app's signature verifies; its entitlements show Production CloudKit and `get-task-allow=false`. This proves packaging and signing, not App Store Connect processing or runtime sync.

The isolated hosted native gate passed 62 unit tests, ten UI tests, and the unsigned Release build on the exact build-14 source in [GitHub Actions run 38881427576](https://github.com/Significant-Hobbies/kith/actions/runs/38881427576). Two local `ios/scripts/check.sh` attempts were interrupted after Xcode could not connect to the simulator service: first under Xcode 27 on the shared iPhone 17 Pro, then under stable Xcode 26.6 on a separate iPhone 17e. Neither local attempt provides a test result. The second run's log is `/private/tmp/kith-53-check-stable.log`; no source error appeared before the simulator failure. The hosted gate is the qualification test evidence.

The public support page gate passed separately in ios-landings PR #63: live `/support/` and `/support/index.md` describe public GitHub questions, private TestFlight feedback, internal-only availability, and the privacy and TestFlight paths.

Physical/account qualification for build 14 is **blocked/unverified**. The owner's installed build and personal local document were not replaced for this packaging check. The exact distribution IPA has not been processed in TestFlight, and installing the development-signed archive could change the CloudKit environment while touching the owner's personal container. No exact-build 14 iPhone upgrade, launch, local-record continuity, account-switch, CloudKit convergence, or Hub sync was observed. The build-13 TestFlight and device receipts do not establish those results for build 14. They remain pre-submission runtime gates; no public submission or release is claimed.
