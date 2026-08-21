# Kith agent instructions

- Read `PROJECT_STATUS.md`, `PRODUCT.md`, and `DESIGN.md` before broad work.
- Keep Kith's source, product planning, tests, and release configuration in
  this repository. Site Health may catalog Kith but does not own its product
  source.
- Kith is device-first. People and logs live in one local JSON document. The
  private CloudKit mirror remains during transition; signed-in synchronization
  uses PersonalSyncKit and Personal Platform. Do not make network access block
  local use or add a third-party analytics SDK.
- Speak about people, closeness, and notes — never contacts, CRM, pipelines,
  or leads.
- Closeness is an explicit 1–5 value the person sets. Do not infer it from
  recency, log volume, or circle.
- Run `ios/scripts/check.sh` after changes under `ios/`. It regenerates the
  Xcode project, runs unit and UI tests, and builds Release unsigned.
- The public site source of truth is `ios-landings` (`PRODUCT=kith`).
  This repo still has a buildable `site/` copy so Kith stays independent.
  After local site edits run `pnpm --dir site check`. Do not invent a
  second page set.
