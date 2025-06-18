# L4D2-Mob-Rushers
**You'll always be on your toes.**

Mob Rushers is a VScript that will spawn Common Infected around the survivors, making the survivors more prone to attacks.

[![Static Badge](https://img.shields.io/badge/Workshop%20Link-text?style=plastic&logo=steam&color=grey)](https://steamcommunity.com/sharedfiles/filedetails/?id=3443374604)

## Features
- **Dynamic Spawns**: Common Infected appear around survivors at random intervals, based on difficulty and configurable chances.
- **Mini-Hordes**: A chance for larger groups to spawn together.
- **Customizable**: Adjust spawn counts, distances, health, and more via a config file.

## 🛠️ Planned updates
Ideas and planned updates.
- Mini-Horde alert display Setting: Enable/Disable the director and sounds of a Mini-Horde to surprise the player.
- Generalized difficulty settings: Make a pre-made config settings the player can pick from easily, ranging from easy, medium, hard, expert.

## ⚙️ Configurable Settings
Settings are stored in `left4dead2/ems/mob_rushers/config.cfg`.  If you do not see them, start a game, then you should see them. Edit them and restart the level to apply changes. Here are the defaults:

| **Setting Name**             | **Default**     | **Description**                                                                |
|--------------------------|---------------------|--------------------------------------------------------------------------------|
| `SpawnCountMin_Easy`    | `1`                 | Min number of infected spawned on Easy difficulty                               |
| `SpawnCountMax_Easy`    | `3`                 | Max number of infected spawned on Easy difficulty                               |
| `SpawnChance_Easy`      | `10`                 | Spawn frequency on Easy (lower = less frequent, higher = more frequent)  [0/100]|
| `SpawnCountMin_Norm`    | `2`                 | Min for Normal difficulty                                                       |
| `SpawnCountMax_Norm`    | `5`                 | Max for Normal difficulty                                                       |
| `SpawnChance_Norm`      | `15`                | Spawn frequency on Normal                                                       |
| `SpawnCountMin_Adv`     | `3`                 | Min for Advanced difficulty                                                     |
| `SpawnCountMax_Adv`     | `6`                 | Max for Advanced difficulty                                                     |
| `SpawnChance_Adv`       | `25`                | Spawn frequency on Advanced                                                     |
| `SpawnCountMin_Exp`     | `1`                 | Min for Expert difficulty                                                       |
| `SpawnCountMax_Exp`     | `4`                 | Max for Expert difficulty                                                       |
| `SpawnChance_Exp`       | `20`                | Spawn frequency on Expert                                                       |
| `SpawnDistMin`          | `1250`              | Minimum spawn distance from survivors (Hammer Units)                            |
| `SpawnDistMax`          | `2000`              | Maximum spawn distance from survivors (Hammer Units)                            |
| `MaxSpawnedCommonInf`   | `30`                | Max number of script-spawned infected allowed at once                           |
| `HealthForRushers`      | `30`                | Health for rushing Common Infected (excludes Uncommon Infected)                 |
| `ShouldAllRush`         | `false`             | Allow wandering infected to rush survivors                                      |
| `DisableOnGamemodes`    | `["survival", "scavenge", "mutation15"]` | Game modes where the script is disabled                    |
| `MiniHordeChance`       | `20`                | % chance for a mini-horde to spawn                                              |
| `DebugMode`             | `false`             | Enable debug crap in console                                                    |


## 🏆 Credits
- **[VSLib/Admin System](https://steamcommunity.com/sharedfiles/filedetails/?id=214630948&searchtext=Admin+System)**: Utility functions for trace line checks.
- **[LeeusVeep](https://github.com/LeeusVeep)**, **[OfficerSpy](https://github.com/OfficerSpy)**: Testing and feedback.

## 🤝 Contributing
Want to help? Fork the repo, make your changes, and submit a pull request! Suggestions and bug reports are welcome in the [Issues](https://github.com/CombineSlayer24/L4D2-Mob-Rushers/issues) section.
