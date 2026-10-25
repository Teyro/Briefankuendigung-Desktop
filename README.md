# Briefankündigung – Desktop (Plasma 6 & macOS)

**Letters and parcels announced by Deutsche Post and DHL – on your desktop.**
A KDE Plasma 6 widget and a native macOS app (menu bar + desktop widgets) for the Home Assistant
integration [Briefankündigung](https://github.com/Teyro/Briefankuendigung-HA): see who wrote to you before the
letter is in your mailbox – with the picture of the envelope.

*Deutsch: siehe [README.de.md](README.de.md)*

## Screenshots

| Plasma desktop tiles | macOS menu bar | macOS widgets |
|---|---|---|
| ![](docs/bilder/plasma-schreibtisch.png) | ![](docs/bilder/mac-karten.png) | ![](docs/bilder/mac-widgets.png) |

## Features

- **“3 letters on the way”** at a glance – flip through the envelopes as cards (swipe, mouse wheel, arrows,
  or automatically) or show them as a list: **Today · Still on the way · Arrived**
- Envelope pictures from Deutsche Post, **DHL parcels** with progress (on the way → arriving today → delivered)
  and parcel tracking, **important senders** (tax office, court …) highlighted
- **“Arrived”** – mark a letter as received; it is synced through Home Assistant to all your devices
- **“Check now”** – let Home Assistant read the mailbox immediately
- Several mailboxes (e.g. yours and your partner’s) – show all or one
- Reloads shortly after every mailbox check of the integration (e.g. 2:00 and 5:00)
- **One‑click updates** with “What’s new?”, German and English

### KDE Plasma 6
- Freely resizable **desktop tile**: big cards on a large tile, envelope beside the text on a wide one,
  just an icon with the count on a small one
- In the panel: icon with count (highlighted when something arrives today), list in the popup
- Takes over the connection from **Home Assistant ToolBox** automatically if it is installed

### macOS (14 Sonoma or later, Liquid Glass on macOS 26)
- Menu bar app with cards and list, a window with all letters
- **Desktop widgets** (small, medium, large) – flip through the letters and mark them as arrived right in the widget
- Token stored in the keychain; can take over the connection from Home Assistant ToolBox

## Requirements

Home Assistant with the integration [Briefankündigung](https://github.com/Teyro/Briefankuendigung-HA) **1.3 or later**
(installed via HACS) and a long‑lived access token (your name at the bottom left → Security).

## Installation

**Plasma:** download `briefankuendigung.plasmoid` from the [releases](https://github.com/Teyro/Briefankuendigung-Desktop/releases),
then `kpackagetool6 -t Plasma/Applet -i briefankuendigung.plasmoid` (or *Add Widgets → Get New → Install from file*).
Add “Mail announcements” to the desktop or the panel and enter address and token in the settings.

**macOS:** download `Briefankuendigung-macOS-x.y.z.zip`, unzip, move the app to *Applications*.
The app is not notarized: on first start right‑click → *Open*. Then add the widgets:
right‑click the desktop → *Edit Widgets* → Mail announcements.

## Privacy

The apps only talk to your own Home Assistant (and to GitHub to look for updates).
On Plasma the token is stored in the widget configuration, on macOS in the keychain.

## Development

- `node plasma/test/logik-test.mjs` – logic of the Plasma widget
- `cd macos && swift test` – logic of the Mac app; `./scripts/baue-app.sh` builds the app (Xcode + XcodeGen)
- `node test/ha-mock.mjs 8123` – fake Home Assistant with the integration (token `test-token`)
- `node werkzeuge/texte.mjs` / `node werkzeuge/baue-uebersetzungen.mjs` – translations (`i18n/en.json`)

License: GPL‑3.0‑or‑later
