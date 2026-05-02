# Jefe de Guerra — Guild Core Matrix

<p align="center">
  <strong>Raid core roster for WoW <em>Burning Crusade Classic — Anniversary</em></strong><br />
  Built for <strong>Jefe de Guerra</strong> · Dreamscythe · Interface from <code>GuildCoreMatrix.toc</code>
</p>

<p align="center">
  <a href="https://www.curseforge.com/wow/addons/guild-core-matrix"><img src="https://img.shields.io/badge/CurseForge-Guild%20Core%20Matrix-F16436?style=for-the-badge" alt="CurseForge" /></a>
</p>

<p align="center">
  <sub>CurseForge project ID · <code>1528360</code> · matches <code>X-Curse-Project-ID</code> in <code>GuildCoreMatrix.toc</code></sub>
</p>

**Jefe de Guerra — Guild Core Matrix** reads **`[C#]`** core and **`[B]`** bench tags from **guild officer notes**. It builds a live **roster view** and shares **schedules**, **signups**, **LFG**, and **talent specs** over the guild addon channel when members run the addon. **Public notes** are stored for display where the UI shows them; **core assignment parsing uses officer notes only** (see `Modules/Scanner.lua`). The client TOC title is localized display (**Jefe de Guerra** / Gestión de Cores); listings and repo branding use **Jefe de Guerra — Guild Core Matrix**.

---

## Features

| Area | What you get |
|------|----------------|
| **Core & bench tags** | **`[C#]`** and **`[B]`** inside brackets in **officer notes**; optional **`:T` / `:H` / `:D`**, short labels, **`:ML`**, **`*`** raid-lead marker per segment. |
| **Roster UI** | **Cores** and **LFG** tabs, filters (search, online, role, class, “mine”), collapsible core cards, invite helpers, resizable window with persisted position/size. |
| **Guild sync** | Addon messages on the **guild** channel for schedules, signups, specs, and LFG data; optional **peer badge / version** hint when another member has the addon. |
| **Raid helpers** | Invite flows, raid formation tooling, master-looter hints derived from notes where **` :ML`** is used. |
| **Locales** | **`enUS`**, **`esES`**, **`esMX`** — switch at runtime with **`/gcmlang`**. |
| **Access** | **`/gcm`** toggles the UI; **minimap** button (LibDBIcon-style placement); slash utilities for officer-note tooling and debugging (see below). |

Officer notes are short: the addon respects WoW’s **31-character officer note** limit when proposing or applying edits.

---

## How it works

1. Officers put **bracketed core/bench tags** in **officer notes** (guild policy may still use public notes for other text — cores are read from officer notes only).
2. On login, roster updates, and **SYNC**, the addon **parses** those notes (throttled) and merges them into a **cache** per member.
3. The UI lists **discovered cores**, **bench**, and **unassigned** members; **SYNC** refreshes from the server and can print a short scan summary.

Schedules, signups, and collapsed-core UI state use **`C#` keys** internally. **`/gcm migrate`** is a maintainer-only saved-data upgrade path in release builds (see in-game messages).

---

## Tag syntax

Put tokens **inside `[` `]`** in the member’s **officer note** (parsing source for cores). Multiple segments in one bracket are **comma-separated**.

### Core & bench

| Pattern | Meaning |
|---------|---------|
| **`[C1]`**, **`[C2:T]`**, **`[C3:MT:T]`** | Core **ID** with optional **role** (`T` / `H` / `D`) and optional **short label** before the role. |
| **`[B]`**, **`[B:T]`**, **`[B:Alt:D]`** | **Bench** pool (single bench); optional role / label. |

Add **` *`** at the end of a segment (before the next comma) to mark **raid lead** for that slot where the UI supports it. Append **` :ML`** on a segment for **master looter** automation hints.

Examples:

```text
[C1:T,C2:H]
[B],[C4:D]
```

---

## Slash commands

| Command | Purpose |
|---------|---------|
| **`/gcm`** | Toggle main window (parses notes when opening). |
| **`/gcm help`** | Print usage summary (localized). |
| **`/gcm officer on \| off \| auto`** | Control whether guild-note edit menus are shown (`auto` uses rank permissions). |
| **`/gcm forcewrite`** | Toggle override when the client misreports note-edit permissions. |
| **`/gcm perms`** | Print effective permission / UI edit flags (debug). |
| **`/gcm reset`** | Reset window position and default size. |
| **`/gcm spec`** | No args: list valid abbreviations for your class. One abbreviation: set **your** synced spec for roster/tooltips. |
| **`/gcm lfg`** | Quick **LFG tag** codes (`HC`, `ND`, `QU`, `MI` and aliases); **`/gcm lfg clear`** clears yours. Longer text belongs in the **LFG** tab. |
| **`/gcm migrate`** | Maintainer-only saved-data migration (**restricted**; gated in `Modules/Database.lua`). |
| **`/gcmlang`** | No args: current locale and available codes. **`/gcmlang enUS`** (etc.) forces locale; **`/gcmlang reset`** clears override. |

---

## Requirements

- **Client:** WoW **TBC Classic — Anniversary** with an **`Interface`** build matching **`## Interface:`** in [`GuildCoreMatrix.toc`](GuildCoreMatrix.toc).
- **Guild:** Full behavior assumes an active **guild** (`IsInGuild`, roster APIs).

---

## Installation

### CurseForge App

Install **[Jefe de Guerra — Guild Core Matrix](https://www.curseforge.com/wow/addons/guild-core-matrix)** (listing) for the **Anniversary** WoW flavor.

### Manual

1. Download **`GuildCoreMatrix-<version>.zip`** from CurseForge **Files**.
2. Extract so you have  
   `World of Warcraft/_anniversary_/Interface/AddOns/GuildCoreMatrix/GuildCoreMatrix.toc`
3. Restart the client or **`/reload`** after first install.

---

## Saved data

| Variable | Scope | Role |
|----------|--------|------|
| **`GCM_Settings`** | Account | Window layout, locale override, officer UI mode, filters, minimap angle, schema version, etc. |
| **`GCM_Sync`** | Account | Shared guild-facing payloads (e.g. schedules, preferences). |
| **`GCM_Cache`** | Per character | Parsed roster cache for performance / offline display. |

Removing the addon folder does **not** delete saved variables; reset via Blizzard’s **Addon List** options or by clearing the corresponding `SavedVariables` files if you need a clean slate.

---

## Repository layout (developers)

| Path | Role |
|------|------|
| **`Core.lua`** | Load bootstrap: DB init, locale, events, optional module `Init` hooks. |
| **`Modules/Scanner.lua`** | Guild note scan orchestration and cache updates. |
| **`Modules/Notes.lua`** | Parse **`[…]`** segments, enforce note length on writes. |
| **`Modules/Database.lua`** | SavedVariables defaults, migrations. |
| **`Modules/Comms.lua`** | Guild addon channel protocol (hello / chunked payloads). |
| **`Modules/Schedule.lua`**, **`Signups.lua`**, **`Specs.lua`**, **`LFG.lua`** | Feature logic + sync hooks. |
| **`Modules/UI_*.lua`** | Frames: main window, lists, filters, LFG, schedule, minimap. |
| **`Locales/*.lua`** | Locale registration. |
| **`.pkgmeta`** | CurseForge packaging (ignore dev scripts, package-as name). |

Local iteration:

```bash
./install.sh
```

Copies the addon into your `_anniversary_` AddOns folder (override **`GCM_WOW_ROOT`** in the script if needed).

```bash
./package.sh
```

Builds **`dist/GuildCoreMatrix-<version>.zip`** using the version from **`## Version:`** in the TOC.

### Releases & CurseForge

Packaging from Git typically uses **`.pkgmeta`** plus a [CurseForge repository webhook](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging). **Annotated git tags** (`v1.2.3`) drive published versions.

With a **clean** working tree:

```bash
./scripts/release.sh
```

→ bump **patch** in **`GuildCoreMatrix.toc`** → commit TOC → tag **`v…`** → **`git push origin HEAD`** → **`git push origin v…`**.  
Same entry point: **`./package.sh release`**.

| Flag | Behavior |
|------|----------|
| **`--no-push`** | Bump, commit, tag locally only. |
| **`--bump-only`** | Edit TOC only (no git). |
| **`--tag-only`** | Tag current **committed** HEAD (no version bump); **`--push`** publishes HEAD then tag. **`--allow-dirty`** allows unrelated dirty files if TOC matches HEAD. |

If the webhook does not fire, check GitHub **Settings → Webhooks → Recent Deliveries**.

---

## Author

**Hugo Gutierrez** — *Jefe de Guerra*, Dreamscythe.

---

## License

See the license on the [CurseForge project](https://www.curseforge.com/wow/addons/guild-core-matrix) page (this repo may add a **`LICENSE`** file to match).
