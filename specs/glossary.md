# Glossary

Domain terms. Use the **Code name** in Swift identifiers, so specs and code read the same way.

| Term | Code name | Meaning | Status |
|---|---|---|---|
| Item | `Item` | Sample record from the scaffold. Removed when spec 0002 is implemented. | scaffold |
| Game | `Game` | One play session with its families, rules and clock; hosted by the Mac Admin. | draft |
| Family | `Family` | One player and their phone: the unit for role, stamps and vote. Role, stamps, vote and life state are per family. | draft |
| Player | `Player` | One person with the iOS app who belongs to exactly one family. | draft |
| Werewolf (Impostor) | `Role.werewolf` | Hidden role. Kills villager families and triggers sabotage. | draft |
| Villager (Crewmate) | `Role.villager` | Role that completes tasks and votes out werewolves. | draft |
| OC | `OC` | Organiser. Either the Town Hall OC on the Mac or a booth OC in the iOS app's OC mode. | draft |
| Town Hall | `townHall` | Lab 1: meeting place, bell, OC control. | draft |
| Booth | `Booth` | One of 7 task stations (Morse, Painting, Message, Right Place, Pattern, Tower, Locks). | draft |
| Sabotage booth | `SabotageKind` | Reactor (Collab 7A, Heist Plan) or Oxygen (Collab 6, Scary Memory). | draft |
| Stamp | n/a | Paper stamp an organiser gives a family at a booth. Tracked outside the app since ADR 0008. | draft |
| Task list | `TaskList` | The 5 of 7 booths randomly assigned to a family. | draft |
| Kill | `Kill` | A werewolf family eliminates a villager family in BLE range, subject to cooldown. | draft |
| Sabotage | `Sabotage` | Werewolf-triggered countdown (1:30) that villagers must resolve at a sabotage booth. | draft |
| Meeting | `Meeting` | Discussion then voting, started only by the Town Hall OC. | draft |
| Expelled | `LifeState.expelled` | A family removed by vote. Sits down; werewolf families can still sabotage. | draft |
| Final vote | `FinalVote` | One vote at 45:00 where the top N families are expelled (N = remaining werewolf families). | draft |
| OC PIN | `ocPin` | Per-game PIN that unlocks OC mode in the iOS app. | draft |
| Public Display | `PublicDisplay` | Mac window shown on the lab TVs through AirPlay; never shows secrets. | draft |
