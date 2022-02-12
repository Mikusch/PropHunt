# PropHunt Neu

<img alt="PropHunt Neu Logo" src="https://user-images.githubusercontent.com/25514044/142745733-071c7ba2-15c3-4731-b0d8-8100a73ca0c9.png" width="420"/>

PropHunt Neu is my own take on the classic hide 'n seek gamemode for Team Fortress 2.

## Features

* Ability to disguise as any prop on the map
    * Including static props, dynamic props and other model-based entities
    * Player health scales with size of selected prop
* Centralized prop configuration to blacklist and configure props
    * Allows matching multiple props at once using regular expressions
    * No map-specific configuration files required
* Greatly improved Hunter (BLU) gameplay
    * Dynamically calculated self-damage values depending on used weapon
    * Minimal weapon and class restrictions
* Compatibility with almost any arena map without any additional configs
* Functional waiting for players period in arena mode
* Highly configurable using ConVars and configuration files

## Requirements

* SourceMod 1.10+
* [StaticProps](https://github.com/sigsegv-mvm/StaticProps)
* [TF2Items](https://github.com/asherkin/TF2Items)
* [TF2 Econ Data](https://github.com/nosoop/SM-TFEconData)
* [TF2Attributes](https://github.com/nosoop/tf2attributes)
* [DHooks 2 with Detour Support](https://github.com/peace-maker/DHooks2/tree/dynhooks) (included in SM 1.11)
* [More Colors](https://github.com/DoctorMcKay/sourcemod-plugins/blob/master/scripting/include/morecolors.inc) (compile only)

## Special Thanks

* [Powerlord](https://github.com/powerlord) - Creating [Prop Hunt Redux](https://github.com/powerlord/sourcemod-prophunt), the inspiration for this plugin
* [ficool2](https://github.com/ficool2) - Helping out with vector math
* [RatX](https://steamcommunity.com/profiles/76561198058574997) - Designing the PropHunt Neu logo
* [Red Sun Over Paradise](https://redsun.tf) - Playtesting and giving feedback