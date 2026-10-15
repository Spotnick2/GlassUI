# Forever probe: Glass UI

What has to be measured on the live client before each wave of skins, and what was found.
`Tools/SkinProbe/` is a ForeverProbe module (`..\ForeverProbe\docs\GUIDE.md`): deploy with
`pwsh Tools\deploy.ps1 -Probe`, `/reload`, then `/fp skin <command>`. Its lines go to the `/fp`
console and to `WTF\Account\<account>\SavedVariables\SkinProbe.lua`. Record the build with every
result.

The probe is discovery. Each skin's acceptance is on its final implementation (docs/PLAN.md,
milestones), not on the probe's copy.

## Wave 1 (#2)

| # | Question | Result |
|---|---|---|
| W1.1 | Merchant, static popups, character sheet, world map: the real frame on this client, protected or not, strata and level | open |
| W1.2 | Each target's region tree (names, parentKeys, layers, templates) the kit will touch | open |
| W1.3 | World map `frameBuffer="true"`: does a child glass panel render correctly? (gates the map skin) | open |
| W1.4 | How the gamepad interface style is detected (the stand-down) | open |
| W1.5 | Is `/gui` already taken by an installed addon? | open |

## Facts already known (don't re-measure)

- wow-ui-source branch `forever` is build 1.60.1.70374, the same as the API dump.
- Leatrix Maps 1.60.23 reads "Simple map frame" once at its `ADDON_LOADED` (default On), applies
  it at `PLAYER_LOGIN`, and writes it back at logout (`Leatrix_Maps.lua:2887, 2956, 2962`).
