# Contributing to Instance Spell Collector for WotLK

This repository is intended as a close World of Warcraft 3.3.5a compatibility
backport of upstream
[Instance Spell Collector](https://github.com/enderneko/InstanceSpellCollector).

Contributions should focus on:

- WotLK 3.3.5a compatibility.
- Bug fixes introduced by the backport.
- Preserving upstream behavior where the Wrath API permits it.
- Repository and documentation maintenance.

New product features should be proposed to upstream first. This project should
not develop into a separate addon with unrelated behavior.

## Code standards

- Keep Lua compatible with Lua 5.1 and the WoW 3.3.5a addon environment.
- Preserve upstream structure, naming, control flow, and saved-data shapes.
- Prefer documented 3.3.5a APIs over broad compatibility shims.
- Keep compatibility code scoped to Instance Spell Collector.
- Do not edit bundled libraries or generated data unless the task requires it.
- Preserve enderneko's original authorship and attribution.
- Add release notes under a `CHANGELOG.md` heading matching the intended tag.

## Pull requests

1. Search or open an issue before starting a non-trivial change.
2. Create a focused branch from `main`.
3. Implement and test the change on a WotLK 3.3.5a client.
4. Parse modified Lua files with Lua 5.1 and run `luacheck . -q`.
5. Confirm that every TOC/XML reference exists and loads in the intended order.
6. Open a pull request with reproduction and testing details.

## Reporting issues

Include the addon version, client locale, server, reproduction steps, Lua errors,
screenshots where useful, and whether the problem occurs with only this addon
enabled.

The upstream project is published as All Rights Reserved. Contributions here
must not remove attribution, relicense upstream code, or imply ownership of
enderneko's work.
