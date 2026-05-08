# InventoryService

`scripts/services/InventoryService.gd` es el primer servicio extraido desde `GameData`.

## Objetivo

Centralizar operaciones de inventario/equipo para que las escenas de UI no manipulen el estado del avatar directamente.

## Contenedores actuales

- `inventory`
- `stash`
- `equipped_weapon`
- `equipped_armor`

## Operaciones cubiertas

- agregar/quitar items de contenedores
- leer/escribir contenedores
- mover items entre contenedores
- tomar/devolver items durante drag and drop
- equipar con swap
- consultar item equipado
- contar unidades en un contenedor

## Estado de migracion

`GameData` sigue funcionando como fachada temporal para no romper llamadas existentes desde `inn.gd`, `mission.gd` y scripts de UI.

Ya delegan directamente en `InventoryService`:

- `add_item_to_container`
- `remove_item_from_container`
- `is_stackable`
- `_get_container_ref`
- `_set_container_ref`
- `take_item`
- `give_item`
- `count_in_container`

`inn.gd` ya usa `GameData.count_in_container()` en vez de contar items manualmente.

## Proximo paso

Mover gradualmente `move_item`, `move_item_between_containers`, `swap_equip` y `get_equipped_id` para que sean wrappers puros, despues de probar el flujo completo en Godot.
