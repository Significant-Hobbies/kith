# Personal iCloud

## Requirements

### Requirement: Private container on the personal team

The app SHALL use development team `8F7LXHTJZR` and CloudKit container
`iCloud.com.significanthobbies.kith`. It SHALL write only to the owner's
private database.

#### Scenario: Demo launches stay local

- **WHEN** the app launches with `--ui-demo` or `--fresh-demo`
- **THEN** it does not read or write CloudKit
