# LootBagService

`scripts/services/LootBagService.gd` centraliza la bolsa temporal de mision y la logica de consumibles curativos.

`GameData.gd` mantiene las fachadas existentes (`loot_bag_add`, `bag_consume`, `apply_potion_effect`, etc.) para no romper escenas actuales como `mission.gd`.

Esta separacion deja mas claro que `GameData.gd` conserva estado global y compatibilidad, mientras la mecanica de bolsa de botin vive en un servicio dedicado.
