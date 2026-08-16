# Kith Design System

## Direction

Kith is a quiet room of lanterns. People are soft circles of clay, apricot,
honey, and rose on linen paper. Closer people take more space. The field
drifts the way a mobile hangs in still air — not a game, not a particle
demo.

References held in mind: a paper lantern cluster, a corkboard of
overlapping Polaroids, the warmth of late-afternoon kitchen light.
Anti-references: Salesforce / Clay CRM tables, neon glassmorphism, candy
bubble-pop games, LinkedIn graphs.

The owner brief selected this direction: floating bubbles, different sizes
for different relationships, warm UI.

## Physical Scene

A person opens Kith in bed or on a sofa after seeing someone. The phone is
close to the face. Light is indoor and warm. The surface should feel like
paper and clay, not like a dashboard.

## Palette

- `linen`: `#f4e6d4` — primary field.
- `cream`: `#fff6ea` — raised cards and sheets.
- `espresso`: `#3a2418` — primary type.
- `clay`: `#c46a4a` — primary action and closest people.
- `apricot`: `#e8a06a` — secondary bubble hue.
- `honey`: `#e0b04a` — secondary bubble hue.
- `rose`: `#d47a78` — secondary bubble hue.
- `rust`: `#9a3f2a` — emphasis and destructive.
- `sand`: `#d7b48a` — quieter bubble hue.
- `sage`: `#8b9a6d` — work-circle hue only.

Color never carries status alone. Closeness is also size and a numeric
label. Circle is also a word.

## Typography

- UI copy uses the rounded system sans (`.rounded`) so names feel spoken,
  not tabulated.
- The wordmark is title-case “Kith”, never letterspaced uppercase.
- Log dates use the system date style. No condensed scoreboard numerals.

## Composition

- The constellation owns the full field. Chrome (wordmark, search, add)
  sits on top and never becomes a tab bar.
- A person page is a cream sheet that rises over the field.
- On the person page the name and bubble lead; logs are a single
  chronological column.
- Corners are fully round on bubbles and softly continuous (24pt) on
  sheets. No hairline cards.

## Components

- **Lantern:** a filled circle with initials, a first name, and a size
  taken from closeness. Soft inner highlight, no hard stroke.
- **Field:** the drifting constellation. Reduced-motion users get the same
  layout frozen in place.
- **Closeness row:** five growing dots, not a slider.
- **Log chip:** kind + date + body, no avatars.
- **Add lantern:** a clay circle with a plus, bottom trailing, 56pt.

## Interaction

- Tap a lantern to open that person.
- Adding a person or a log is a sheet, not a new tab.
- Motion is slow drift and a short settle when a lantern is added. Reduced
  motion removes the drift.
- Destructive actions confirm in a dialog.
- Focus and VoiceOver use names, closeness, and circle — never color alone.
