# Description

Please include a summary of the change, the issue it fixes, and the relevant motivation and context.

Fixes #(issue)

## Scope

This repository is maintained as a close WotLK 3.3.5a port of upstream Instance Spell Collector. Changes should fix this WotLK port, improve 3.3.5a compatibility, or port existing upstream behavior.

Maintainer policy: if a feature does not exist upstream, it is not accepted in this WotLK port unless the maintainer explicitly approves the divergence. Propose client-independent features upstream first at [enderneko/InstanceSpellCollector](https://github.com/enderneko/InstanceSpellCollector).

- [ ] This change fixes a bug in the WotLK port
- [ ] This change is required for WotLK 3.3.5a compatibility
- [ ] This change ports existing upstream behavior
- [ ] This change was discussed with the maintainer before implementation
- [ ] This change is not a port-only custom feature

## Type of change

Please delete options that are not relevant.

- [ ] Bug fix
- [ ] Upstream behavior port
- [ ] WotLK compatibility fix
- [ ] Breaking change
- [ ] Repository or documentation maintenance

## How Has This Been Tested

Describe the checks and in-client tests used to verify the change. Include enough detail to reproduce them.

- [ ] Modified Lua files parse with Lua 5.1
- [ ] `luacheck . -q` passes
- [ ] TOC/XML load order and references were verified
- [ ] Compared with the relevant upstream implementation
- [ ] Tested in a WotLK 3.3.5a client where applicable

## Checklist

- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review
- [ ] I have explained hard-to-understand compatibility decisions
- [ ] I have updated documentation or changelog entries when required
- [ ] My changes generate no new warnings
- [ ] Original attribution and author metadata remain intact
- [ ] No bundled library or generated data was changed unnecessarily

<!-- Add any remaining work to the checklist above. -->
