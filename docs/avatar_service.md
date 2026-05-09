# AvatarService

`scripts/services/AvatarService.gd` centraliza helpers de estado del avatar: vida, daño, muerte, equipo equipado y valores derivados de arma/armadura.

`GameData.gd` mantiene fachadas como `apply_damage()`, `heal()`, `is_dead()`, `get_armor_value()` y `get_weapon_damage_range()` para no romper llamadas actuales desde escenas.
