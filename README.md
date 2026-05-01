# Guild Core Matrix

<p align="center">
  <strong>Raid core roster for WoW <em>Burning Crusade Classic — Anniversary</em></strong><br />
  Built for <strong>Jefe de Guerra</strong> · Dreamscythe · Interface <code>20505</code>
</p>

<p align="center">
  <a href="https://www.curseforge.com/wow/addons/guild-core-matrix"><img src="https://img.shields.io/badge/CurseForge-Guild%20Core%20Matrix-F16436?style=for-the-badge" alt="CurseForge" /></a>
</p>

<p align="center">
  <sub>CurseForge project ID · <code>1528360</code> · <code>X-Curse-Project-ID</code> in <code>GuildCoreMatrix.toc</code></sub>
</p>

---

## What it does

Guild Core Matrix reads **Karazhan** and **Gruul / Magtheridon** core assignments from your guild’s **public** and **officer** notes, then presents them in a focused **roster UI**: who is in which core, roles, online status, and guild-wide sync for schedules, signups, and specs when members run the addon.

Officer notes are tiny. The addon respects WoW’s **31-character officer note** cap whenever it helps you edit notes.

---

## Features

| Area | Details |
|------|---------|
| **Core tags** | Parse `k` / `K` / `G` tokens from bracketed segments in guild notes |
| **Roles** | Optional `:T`, `:H`, `:D` suffixes on each slot |
| **UI** | Resizable main window, filters, core cards, composition hints, invite helpers |
| **Sync** | Schedules, signups, and talent specs shared via addon communication |
| **Locales** | `enUS`, `esES`, `esMX` |
| **Slash** | `/gcm` opens the window |

---

## Tag syntax

Place tokens **inside square brackets** in the member’s public or officer note (your guild’s convention may prefer one or the other).

| Token | Meaning |
|-------|---------|
| `k` | Karazhan **10-man** core |
| `K` | Karazhan **25-man** core |
| `G` | Gruul / Magtheridon **25-man** core |

**Role suffixes (optional):** `:T` tank · `:H` healer · `:D` DPS  

**Example**

```text
[K1:T,G2:H]
```

*Karazhan 25 core 1 as tank, Gruul/Mag core 2 as healer.*

---

## Requirements

- **Game:** WoW TBC Classic **Anniversary** build matching `## Interface: 20505` in `GuildCoreMatrix.toc`
- **Guild:** Roster APIs need an active **guild** context for full behavior

---

## Install

### CurseForge App

Subscribe to **Guild Core Matrix** on [CurseForge](https://www.curseforge.com/wow/addons/guild-core-matrix) and install into the **Anniversary** WoW flavor.

### Manual

1. Download **`GuildCoreMatrix-<version>.zip`**
2. Extract so you get `World of Warcraft/_anniversary_/Interface/AddOns/GuildCoreMatrix/GuildCoreMatrix.toc`
3. Relaunch the client or `/reload` after first install

### Developers (this repository)

```bash
./install.sh
```

Copies the addon into your local `_anniversary_` client (see script for `GCM_WOW_ROOT`).

```bash
./package.sh
```

Builds `dist/GuildCoreMatrix-<version>.zip` (CurseForge layout). Automatic builds from Git can use `.pkgmeta` plus a [CurseForge repository webhook](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging).

**CurseForge release:** packaging uses an annotated tag (`v` + semver) on the commit that contains that `GuildCoreMatrix.toc` version.

Default flow (clean git tree required):

```bash
./scripts/release.sh
```

Bump **patch** → commit TOC → tag → **`git push origin HEAD`** → **`git push origin vX.Y.Z`**. Same via `./package.sh release`. Use `minor`, `major`, or `set X.Y.Z` before any flags.

- **`--no-push`** — bump, commit, and tag locally only.
- **`--bump-only`** — only edits the TOC (no git).
- **`--tag-only`** — tag the **current committed** HEAD (no bump); no push unless you add **`--push`** (then HEAD first, then tag).

`--tag-only` fails if the TOC has uncommitted edits. **`--allow-dirty`** allows other modified files; the TOC must still match `HEAD`.

Pushing the branch alone often does not publish a new build; **tags** are the usual trigger. Check GitHub **Webhooks → Recent Deliveries** if nothing appears.

---

## Author

**Hugo Gutierrez** — *Jefe de Guerra*, Dreamscythe.

---

## License

See the license selected on the [CurseForge project](https://www.curseforge.com/wow/addons/guild-core-matrix) page (repository may add a `LICENSE` file to match).
