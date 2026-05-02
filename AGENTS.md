# GuildCoreMatrix — Agent Brief

WoW addon for **TBC Anniversary** (Interface from `GuildCoreMatrix.toc`) that manages raid **cores** and **bench** via **`[C#]`** and **`[B]`** tags in **guild officer notes**. **`Scanner.lua`** reads **officer notes only** for core parsing; public notes may appear in UI tooltips.

## Stack

- Lua 5.1 / WoW Retail-based engine on Anniversary client.
- Private namespace pattern: `local addonName, ns = ...`.
- UI: `BackdropTemplate` mixin, no XML.
- SavedVariables: `GCM_Settings`, `GCM_Sync` (account), `GCM_Cache` (per-character).

## Note schema

Bracket segments **`[ ... ]`**, comma-separated entries inside one bracket.

| Prefix | Meaning |
| ------ | ------- |
| **`C`** + numeric id | Core slot (optional `:T`/`:H`/`:D`, short label, `:ML`, `*` lead marker — see `Modules/Notes.lua`) |
| **`B`** | Bench pool |

Officer note hard limit: **31 chars**.

## Layout

```
Core.lua              Event dispatcher (after modules load)
GuildCoreMatrix.toc   Load order + SavedVariables
Modules/
  Scanner.lua         Guild roster scan; parses officerNote → cores
  Notes.lua           Segment parse / compose; note length enforcement
  Database.lua        SavedVariables + migrations
  Comms.lua           Guild addon channel
  Schedule.lua Signups.lua Specs.lua Roles.lua PublicNote.lua LFG.lua …
  UI_Main.lua         Main frame + slash /gcm /gcmlang
  UI_Minimap.lua      Minimap button
Media/logo
install.sh            rsync into local WoW client
```

## Conventions (strict)

- No comments in code (no `--`, no block comments, no docstrings).
- All identifiers and embedded strings in English. No mixed-language strings.
- Use `string.format` (lowercase only).
- `IsInGuild()` guard before any guild roster API.
- Reuse frames; never create them in scan loops.
- Validate Officer Note length before any write back.

## Local workflow

1. Edit code.
2. `./install.sh` to rsync into the WoW AddOns folder.
3. `/reload` in-game (full relaunch for TOC / SavedVariables changes).
4. `/gcm` to open the main UI.

See `.cursor/rules/` for the enforced rule set.
