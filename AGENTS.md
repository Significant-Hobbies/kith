# Kith agent instructions

- Read `PROJECT_STATUS.md`, `PRODUCT.md`, and `DESIGN.md` before broad work.
- Keep Kith's source, product planning, tests, and release configuration in
  this repository. Fleet Workspace may catalog Kith but does not own its
  product source.
- Kith is device-first. People and logs live in one local JSON document. Do
  not add an account, a server, a network call, or a third-party analytics
  SDK to the relationship path.
- Speak about people, closeness, and notes — never contacts, CRM, pipelines,
  or leads.
- Closeness is an explicit 1–5 value the person sets. Do not infer it from
  recency, log volume, or circle.
- Run `ios/scripts/check.sh` after changes under `ios/`. It regenerates the
  Xcode project, runs unit and UI tests, and builds Release unsigned.
