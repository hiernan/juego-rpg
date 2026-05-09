# ShopService

`scripts/services/ShopService.gd` centraliza la logica de economia y tiendas.

## Objetivo

Separar de `GameData` las reglas de:

- precios base
- precios por tienda
- stock
- compra
- venta
- pago y suma de oro
- curacion completa

## Tiendas actuales

- `blacksmith`
- `healer`
- `tavern`

## Estado de migracion

`GameData` sigue funcionando como fachada temporal para no romper llamadas existentes desde UI.

Ya delegan en `ShopService`:

- `get_shop_items`
- `get_shop_stock`
- `get_shop_price`
- `get_item_price`
- `can_afford`
- `pay_gold`
- `add_gold`
- `shop_buy`
- `shop_sell`
- `heal_full`

## Nota tecnica

Los loaders de tiendas (`_load_shop`) y el diccionario `shops` siguen viviendo en `GameData`. Mas adelante deberian moverse a una capa de catalogo o estado economico.

## Proximo paso

Limpiar cuerpos viejos que quedaron como respaldo temporal en `GameData`, y luego extraer `DataCatalog` para separar carga de CSVs del estado vivo de partida.
