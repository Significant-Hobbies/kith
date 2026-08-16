# People and logs

## Requirements

### Requirement: People are explicit

A person SHALL have a name, a circle, a closeness from 1 to 5, a hue, and
MAY have a birthday, how-we-met text, and standing notes. Closeness SHALL
NOT be inferred from recency or log volume.

#### Scenario: Closeness is set by the person

- **WHEN** a person is saved with closeness 4
- **THEN** their constellation lantern uses the diameter for closeness 4

### Requirement: Logs belong to one person

An entry SHALL have a person, a kind, a happened-on date, and a body. A
person page SHALL list that person's entries newest first.

#### Scenario: A hangout is recorded

- **WHEN** a hangout entry is added for Maya on a given date
- **THEN** Maya's page shows that hangout and last contact becomes that date

### Requirement: Data stays on the device

The document SHALL load and save from the app container. Launch arguments
`--ui-demo` and `--fresh-demo` SHALL NOT read or write the real document.

#### Scenario: Empty launch

- **WHEN** the app launches with `--fresh-demo`
- **THEN** the constellation is empty and invites adding someone
