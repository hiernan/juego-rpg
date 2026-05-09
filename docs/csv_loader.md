# CsvLoader

`scripts/data/CsvLoader.gd` centraliza operaciones simples de carga y parsing de archivos CSV.

Por ahora `GameData.gd` mantiene sus helpers privados (`_read_csv`, `_to_int`, `_to_float`, `_to_list`) como fachada para no cambiar todos los loaders al mismo tiempo. Internamente esos helpers delegan en `CsvLoader`.

Esto deja preparado el camino para extraer un futuro `DataCatalog` que cargue enemigos, items, locaciones, tiendas, textos y tablas de loot desde una capa de datos independiente de la logica global del juego.

`scripts/data/DataLoaders.gd` empieza esa capa con la carga de `combat_constants.csv`. La idea es mover ahi, de a poco, cada loader especifico que hoy vive en `GameData.gd`.

El loader de `items.csv` tambien vive en `DataLoaders.gd`. Conserva el contrato actual del diccionario `items`: `name`, `kind`, `subkind`, `rarity`, `tooltip_extra`, `heal_pct`, `heal_hp`, `price`, `max_stack` y `stackable`.

Los loaders de `weapons.csv` y `armors.csv` tambien fueron movidos a `DataLoaders.gd`. `GameData.gd` mantiene `_load_weapons()` y `_load_armors()` solo como fachada de compatibilidad.

El loader de `enemies.csv` tambien se movio a `DataLoaders.gd`, incluyendo soporte para la columna opcional `armor`.

Los loaders de `locations.csv`, `loot_tables.csv` y `texts.csv` tambien viven en `DataLoaders.gd`. Esto separa buena parte del contenido de mundo y narrativa de `GameData.gd`.

Los CSV de tiendas (`shop_blacksmith.csv`, `shop_healer.csv`, `shop_tavern.csv`) tambien se cargan desde `DataLoaders.gd`, manteniendo `stock` y `price_override`.

`scripts/data/DataCatalog.gd` agrupa que archivos componen el contenido actual del juego. `GameData.gd` ya no necesita conocer cada ruta CSV en `load_all()`; pide el catalogo completo y asigna los diccionarios resultantes.
