# Agent Guide: Instance Spell Collector WotLK Port

This repository is a Wrath of the Lich King 3.3.5a port of enderneko's
Instance Spell Collector. Treat upstream Instance Spell Collector r20 as the
primary design and behavior reference, and this repository as a compatibility
port.

---

## 1. Project Goal

- **Project:** Instance Spell Collector, ported/adapted for WoW WotLK 3.3.5a.
- **Target game version:** Wrath of the Lich King, patch 3.3.5a, build 12340.
- **Interface version:** `30300`.
- **Language/runtime:** Lua 5.1, World of Warcraft addon environment.
- **Runtime addon folder:** `!InstanceSpellCollector`.
- **Primary objective:** Keep this codebase as close as practical to upstream
  r20 while making it run correctly on 3.3.5a.

This is intended to be a close port. Prefer the smallest compatibility change
over an original implementation.

Maintainer policy: if a feature does not exist upstream, it normally does not
belong in this repository. New feature ideas should go upstream first. Add
port-only behavior only when the user explicitly confirms that the WotLK fork
should diverge.

Do not add custom architecture, speculative rewrites, or multi-client support.

---

## 2. Porting Rules

- Before changing behavior, check how upstream r20 implements it.
- Keep file layout, function names, tables, SavedVariable shapes, export
  formats, and control flow close to upstream.
- Make the smallest 3.3.5a compatibility change that solves the problem.
- Prefer direct Wrath APIs. Add a local helper only when it replaces a genuinely
  unavailable API, centralizes repeated compatibility logic, or enforces an
  important invariant.
- Keep compatibility helpers local. Do not publish global Retail API shims.
- Remove unsupported modern and non-Wrath branches instead of maintaining dead
  paths.
- Do not modernize Lua syntax beyond what WoW 3.3.5a supports.
- If an upstream feature cannot work on 3.3.5a, preserve the surrounding
  structure and disable or degrade only that part.
- Keep diffs narrow and easy to compare with upstream. Do not mix a fix with
  unrelated formatting, renaming, or refactoring.

The ideal patch looks like upstream r20 with only the necessary WotLK
differences.

---

## 3. WotLK API Context

`APIDocumentation/` is the preferred local source of truth when documentation
is available. Verified 3.3.5a FrameXML and addon references may be kept under
`.agents-cache/`.

- Verify exact functions, events, arguments, and return values against 3.3.5a
  sources rather than current Retail documentation.
- `UNIT_SPELLCAST_*` provides a spell name, not a reliable spell ID.
- The 3.3.5a `UnitAura`/`UnitBuff`/`UnitDebuff` tuple includes the spell ID;
  preserve its real return order.
- Use the Wrath `GetSpellInfo` tuple for name, icon, and cast time. Do not add a
  `C_Spell` branch.
- Read spell descriptions from a hidden `GameTooltip` populated with a spell
  hyperlink. `GetSpellDescription` and `GameTooltip:SetSpellByID` are not
  available.
- `C_Timer` is unavailable. The local compatibility code must use one shared
  timer frame and queue, never one frame per callback. Do not add a global
  `C_Timer` shim.
- `SOUNDKIT` is unavailable. Use the Wrath sound names directly, including
  `"UChatScrollButton"`, `"igMainMenuOptionCheckBoxOn"`, and
  `"igMainMenuOptionCheckBoxOff"`.
- `Texture:SetColorTexture` is unavailable. Use
  `Texture:SetTexture(r, g, b, a)` for solid colors.
- `SetAtlas` is unsupported. Resolve an upstream atlas to a verified Wrath
  texture path or record its atlas, file ID, or art ID for manual mapping.
- `SetIgnoreParentScale` and `ActionButtonUseKeyDown` are unavailable.
- Avoid `SetMapToCurrentZone`; it changes map state and must not run repeatedly
  for instance detection.

Be especially careful with combat-log payloads, aura tuples, GUID parsing,
spell APIs, tooltip scanning, map APIs, and events that only exist on modern
clients.

---

## 4. Load Order

Always respect `!InstanceSpellCollector.toc`. WoW addon files load
sequentially, and later files depend on state created earlier.

Current runtime order:

1. `Libs/LoadLibs_Classic.xml`
2. `InstanceNames.lua`
3. `Core.lua`
4. `Collector.lua`
5. `MinimapButton.lua`

Before moving code, adding a dependency, or introducing a file:

- Check the TOC and every relevant XML file.
- Prefer editing the corresponding upstream file over adding a new one.
- If a file must be added, place it after all dependencies.
- Verify every referenced path exists with the correct case.
- Do not assume modules can be imported like normal Lua packages.

---

## 5. Repository Layout

### Root

- `AGENTS.md`: agent rules for this port.
- `CONTRIBUTING.md`: contribution scope and process.
- `.luacheckrc`: Luacheck configuration used by GitHub Actions.
- `.pkgmeta`: release packaging rules.
- `.agents-cache/`: ignored reference and test storage; never package or commit
  it.

### Runtime addon

- `!InstanceSpellCollector/!InstanceSpellCollector.toc`: metadata,
  SavedVariables, optional dependencies, and load order.
- `!InstanceSpellCollector/InstanceNames.lua`: localized-to-English Wrath
  instance names.
- `!InstanceSpellCollector/Core.lua`: initialization, SavedVariables,
  migrations, shared UI behavior, and slash command.
- `!InstanceSpellCollector/Collector.lua`: collection events, collector UI,
  spell metadata, encounter grouping, and export.
- `!InstanceSpellCollector/MinimapButton.lua`: LibDataBroker and LibDBIcon
  launcher.
- `!InstanceSpellCollector/Libs/`: bundled libraries and shared UI code.
- `!InstanceSpellCollector/Media/`: dispel-type textures.

The `.pkgmeta` archive root must remain `!InstanceSpellCollector`. The first
component of a `move-folders` source is the `package-as` staging directory, not
the GitHub repository name. A repository rename does not change that source.

---

## 6. Data And Collection Rules

The declared SavedVariables are `ISC_Config`, `ISC_Data`, `ISC_Spell`,
`ISC_AuraDesc`, `ISC_NpcId`, and `ISC_Ignore`.

- Treat their table shapes, key types, absent fields, `nil`, and `false` as
  persistent compatibility behavior.
- Migrate existing data in `Core.lua` when a necessary compatibility change
  alters a key or shape. Never discard collected user data silently.
- Use canonical English instance names as persistent instance keys. Do not use
  map or area IDs; those can differ between 3.3.5a servers and even inside an
  instance.
- Read the localized name with `GetInstanceInfo()` and normalize it through
  `ISC.instanceNames`.
- Preserve deterministic ordering in copied or exported output.
- Obtain NPC IDs from validated Wrath GUIDs and spell IDs from event fields
  that actually provide them.
- Do not blacklist a spell based on one capture. Verify the spell and its scope
  first. Keep Wrath-only ignore data free of unsupported expansion IDs.

DBM-Core is optional. DBM-Warmane can provide reliable encounter IDs and boss
names, allowing spells to be grouped under the correct encounter. Collection
must continue normally without DBM, using the instance-wide or NPC grouping.
Never fabricate an encounter ID or make DBM a required dependency.

---

## 7. UI And Frame Rules

WoW 3.3.5a supports frame levels from 0 through 127. Keep base frame levels low
and the hierarchy shallow.

- Every created frame with a frame parent must use exactly
  `parent:GetFrameLevel() + 1`.
- Do not use arbitrary high levels to cover another frame. Normalize the
  hierarchy at its source. Clamp only when a dynamic parent can genuinely
  reach the limit, and never pass a value above 127.
- A widget with `OnEnter` or `OnLeave` must have mouse interaction enabled if
  it is not already guaranteed. Use `EnableMouse(true)` when uncertain.
- Movable top-level windows must use `SetClampedToScreen(true)`. Use neutral
  clamp insets unless a visible edge is intentionally required.
- Independent windows need a visible and clickable `X` close control. Do not
  rely on unsupported atlas artwork.
- Parent hidden spell-description tooltips to `UIParent` so collector scaling
  does not make them oversized.
- Preserve Cell-WotLK PixelPerfect behavior. Before changing
  `PixelPerfect.lua` or `LibWidgets.lua`, compare the Cell reference and test
  scale, anchors, scrolling, frame levels, and mouse behavior.
- Reuse the existing spell tooltip and shared timer frame. Do not allocate a
  frame per spell, event, tooltip query, or delayed callback.
- Avoid modifying Blizzard-owned or protected frames during combat.

---

## 8. Coding Standards

Follow the existing file style and upstream r20 conventions.

- Keep Lua 5.1 compatibility.
- Match surrounding indentation and preserve local line endings.
- Avoid unnecessary churn and broad reformatting.
- Do not create a helper for a single direct API call unless it enforces a real
  compatibility boundary.
- Localize WoW API globals in hot paths only when the surrounding code follows
  that pattern.
- Avoid repeated scans, temporary tables, tooltip work, and closures in combat
  log and aura handlers unless required for correct collection.
- Explain non-obvious ownership, lifecycle, or compatibility decisions. Do not
  add comments that only repeat the code.
- Maintain `.luacheckrc` by hand. Add only genuine WoW or SavedVariable globals
  and keep temporary toolchain source trees excluded.
- Do not rewrite bundled libraries or media unless the task explicitly
  requires it.
- Preserve unrelated work in a dirty worktree.

---

## 9. Diagnostics And Validation

Luacheck and the GitHub Actions lint workflow are the validation priority.

Cached Lua/LuaRocks installations contain absolute workspace paths. Include
the repository name and toolchain versions in their cache keys, and do not use
fallback keys that restore installations from an old repository path.

When possible:

1. Run `git diff --check`.
2. Parse each changed Lua file with `luac -p`. Prefer Lua 5.1; a newer compiler
   catches syntax errors but does not prove Lua 5.1 compatibility.
3. Run `luacheck . -q`.
4. Parse changed XML and verify TOC/XML references and load order.
5. Compare runtime changes with the matching upstream r20 file.
6. Run `.agents-cache/smoke_wotlk.lua` when the ignored harness is available.

Also test the relevant boundary:

- Collection changes: combat log, aura tuples, NPC GUIDs, source/target
  filtering, instance selection, and encounter grouping.
- SavedVariable changes: empty data, old data, migration, reset, reload, and
  export.
- UI changes: scale, tooltip size, mouse input, close controls, clamping, and
  the full frame-level hierarchy.
- DBM changes: both with DBM-Warmane and without DBM loaded.
- Launcher changes: LibDataBroker registration, LibDBIcon coexistence, click
  behavior, and minimap position persistence.
- Packaging changes: dry-run package contents and the
  `!InstanceSpellCollector` archive root.

Treat GitHub Actions as authoritative when local tool versions differ. Many
issues can only be verified inside WoW 3.3.5a; state clearly what still needs
in-client testing.

---

## 10. Files To Treat Carefully

Avoid editing these unless the task requires it:

- `!InstanceSpellCollector/Libs/`
- media assets such as `.tga`
- `.pkgmeta` archive layout
- SavedVariable migration code
- generated or downloaded reference data
- copyright, attribution, and upstream metadata

When a bundled library needs a 3.3.5a fix, keep the patch minimal, preserve its
attribution, and raise its LibStub minor revision when needed so the corrected
copy wins version selection.

Do not copy downloaded addon trees into the runtime directory without checking
their origin, version, license, and differences from upstream.

---

## 11. Release, Copyright, And Attribution

The original addon is authored by enderneko and published as All Rights
Reserved.

- Preserve the original author metadata, project name, upstream links, and
  attribution.
- Do not add a public license, claim ownership of upstream code, or imply that
  this compatibility effort grants redistribution rights.
- No permission document currently exists in this repository. Do not create
  or describe one without an explicit, verifiable grant from the rights holder.
- Keep `.agents-cache/`, repository documentation, and development tooling out
  of release packages.
- Do not run release workflows or create tags unless the user explicitly asks.

Use sources in this order:

1. Upstream Instance Spell Collector behavior and structure.
2. The selected upstream r20 release package.
3. Local `APIDocumentation/` sources when available.
4. Verified 3.3.5a FrameXML and addon references in `.agents-cache/`.

---

## 12. Agent Behavior

When working in this repository:

- Preserve upstream Instance Spell Collector intent.
- Prefer porting and compatibility fixes over custom feature code.
- Keep diffs minimal and easy to compare with upstream.
- Search before changing shared systems.
- Explain unavoidable divergence from upstream.
- Do not make broad refactors as part of a bug fix.
- Do not revert, overwrite, or include unrelated user changes.
- Do not claim a validation passed unless it was run locally or GitHub reports
  it as passed.
- Update this guide when review feedback establishes a durable repository-wide
  rule. Record the rule, not the one incident that revealed it.

The maintainer wants upstream behavior ported to 3.3.5a, not new behavior
invented for this fork.
