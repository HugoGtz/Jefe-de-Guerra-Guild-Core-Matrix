# GuildCoreMatrix — Agent Brief

WoW addon for **TBC Anniversary (2.5.5, Interface 20505)** that manages 10-man
(Karazhan) and 25-man (Gruul / Magtheridon) raid cores by parsing guild
Officer / Public Notes.

## Stack

- Lua 5.1 / WoW Retail-based engine on Anniversary client.
- Private namespace pattern: `local addonName, ns = ...`.
- UI: `BackdropTemplate` mixin, no XML.
- SavedVariables: `GCM_Settings` (account), `GCM_Cache` (per-character).

## Note schema

`[<Type><Id>[:<Role>], ...]` inside Officer or Public Notes.

| Type | Meaning              |
| ---- | -------------------- |
| `k`  | Karazhan 10m core    |
| `K`  | Karazhan 25m core    |
| `G`  | Gruul / Mag 25m core |

Roles: `T`, `H`, `D`. Officer Note hard limit: **31 chars**.

## Layout

```
Core.lua              Event Dispatcher
GuildCoreMatrix.toc   Load order + SavedVariables
Modules/
  Database.lua        SavedVariables + default schedules
  Scanner.lua         Note parser (throttled 2s)
  Calendar.lua        Blizzard_Calendar integration
  UI_Elements.lua     Class color / icon helpers
  UI_Main.lua         Main frame + slash /gcm
  UI_Tabs.lua         Tabbed views (10m / 25m / settings)
  UI_Minimap.lua      Draggable minimap button
Media/logo.tga
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
