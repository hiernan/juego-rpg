# InventoryService

`scripts/services/InventoryService.gd` es el primer servicio extraido desde `GameData`.

## Objetivo

Centralizar operaciones primitivas de inventario/equipo para que las escenas de UI no tengan que manipular el estado del avatar directamente.

## Contenedores actuales

- `inventory`
- `stash`
- `equipped_weapon`
- `equipped_armor`

## Operaciones cubiertas

- agregar/quitar items de contenedores
- leer/escribir contenedores
- tomar/devolver items durante drag and drop
- consultar si un item es stackeable
- contar unidades en un contenedor

## Estado de migracion

`GameData` sigue funcionando como fachada temporal para no romper llamadas existentes desde `inn.gd`, `healer.gd`, `blacksmith.gd`, `mission.gd` y scripts de UI.

Ya delegan directamente en `InventoryService`:

- `add_item_to_container`
- `remove_item_from_container`
- `is_stackable`
- `_get_container_ref`
- `_set_container_ref`
- `take_item`
- `give_item`
- `count_in_container`

`inn.gd` y `healer.gd` ya usan `GameData.count_in_container()`.

## Proximo paso

Extraer `ShopService` para que `shop_buy`, `shop_sell`, precios, stock y curacion no vivan directamente en `GameData`.
