# TF-GiveJumper
Allows players to give themselves Rocket Jumpers for any class.  Meant for jump maps.

## Instructions
Requires the TF2Items extension.

Enable the plugin by setting `sm_grantjumper_enabled` before a map starts &mdash; changing it while a map is running will not have any effect.

Admins can then toggle Rocket Jumpers on themselves using the command `sm_togglejumper` or by typing `!togglejumper` or `/togglejumper` in text chat.  By default, the command requires the 'cheats' admin flag; [it can be overwritten](https://wiki.alliedmods.net/Overriding_Command_Access_%28Sourcemod%29) with the `jumper` command group.

The plugin disables `func_regenerate` and provides its own resupply via OnTouch hooks to prevent the Rocket Jumper from being dropped; plugins that use the `TF2_RegeneratePlayer` native may cause problems.
