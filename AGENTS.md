# Agent Guide: Instance Spell Collector WotLK

## Scope

This repository is intended to become a close backport of enderneko's Instance
Spell Collector for World of Warcraft 3.3.5a and Lua 5.1. Keep changes small,
easy to compare with upstream, and limited to compatibility work unless the
maintainer explicitly requests otherwise.

The runtime addon folder must remain `!InstanceSpellCollector`.

## Copyright and attribution

The original addon is authored by enderneko and is published as All Rights
Reserved. Preserve the original author metadata, project name, and attribution.
Do not add a public license, claim ownership of upstream code, or imply that a
private compatibility effort grants redistribution rights.

No permission document currently exists in this repository. Do not create one
or describe authorization without an explicit, verifiable grant from the
rights holder.

## Sources of truth

Use these references in order:

1. Upstream Instance Spell Collector for behavior and structure.
2. The selected upstream release package for release-only files.
3. Local 3.3.5a API documentation when it is added to `APIDocumentation/`.
4. 3.3.5a FrameXML sources stored under `.agents-cache/` when secure or UI
   behavior needs verification.

`.agents-cache/` is ignored reference storage and must never be packaged or
committed.

## Repository layout and packaging

- Addon runtime files belong under `!InstanceSpellCollector/`.
- `.pkgmeta` defines the user-facing archive and moves that folder to the addon
  archive root.
- Check TOC and XML load order before adding, moving, or removing runtime files.
- Repository documentation and tooling must not become runtime dependencies.
- Do not copy downloaded addon trees into the repository without reviewing
  their origin, version, and differences from upstream.

## Porting rules

- Preserve upstream structure, names, behavior, and saved-data format wherever
  Wrath permits it.
- Use Lua 5.1 syntax and documented 3.3.5a event payloads.
- Keep compatibility helpers local; do not create global Retail API shims.
- Remove unsupported modern metadata and UI behavior only where required.
- Do not edit bundled libraries unless the task specifically requires it.
- Never discard unrelated work from a dirty worktree.

## Validation

For relevant changes:

- Parse each modified Lua file with a Lua 5.1 compiler when available.
- Run `luacheck . -q`.
- Parse modified XML and verify every TOC/XML reference exists.
- Compare behavior with the matching upstream file.
- State clearly what still requires testing in the 3.3.5a client.

GitHub Actions linting is authoritative when the local environment differs.
