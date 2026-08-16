# Kith agent instructions

- Read `PROJECT_STATUS.md`, `PRODUCT.md`, and `DESIGN.md` before broad work.
- Keep Kith's source, product planning, tests, and release configuration in
  this repository. Fleet Workspace may catalog Kith but does not own its
  product source.
- Kith is device-first. People and logs live in one local JSON document, and
  optionally mirror to the owner's private iCloud database on the personal
  Apple team `8F7LXHTJZR` (`iCloud.com.significanthobbies.kith`). Do not add
  a Kith account, a Kith server, or a third-party analytics SDK.
- Speak about people, closeness, and notes — never contacts, CRM, pipelines,
  or leads.
- Closeness is an explicit 1–5 value the person sets. Do not infer it from
  recency, log volume, or circle.
- Run `ios/scripts/check.sh` after changes under `ios/`. It regenerates the
  Xcode project, runs unit and UI tests, and builds Release unsigned.
- The public site is `site/`, copied from Fleet’s iOS landing template.
  After copy or token changes run `pnpm --dir site check`. Do not invent a
  second page set.
