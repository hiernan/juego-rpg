# CsvLoader

`scripts/data/CsvLoader.gd` centraliza operaciones simples de carga y parsing de archivos CSV.

Por ahora `GameData.gd` mantiene sus helpers privados (`_read_csv`, `_to_int`, `_to_float`, `_to_list`) como fachada para no cambiar todos los loaders al mismo tiempo. Internamente esos helpers delegan en `CsvLoader`.

Esto deja preparado el camino para extraer un futuro `DataCatalog` que cargue enemigos, items, locaciones, tiendas, textos y tablas de loot desde una capa de datos independiente de la logica global del juego.

`scripts/data/DataLoaders.gd` empieza esa capa con la carga de `combat_constants.csv`. La idea es mover ahi, de a poco, cada loader especifico que hoy vive en `GameData.gd`.

El loader de `items.csv` tambien vive en `DataLoaders.gd`. Conserva el contrato actual del diccionario `items`: `name`, `kind`, `subkind`, `rarity`, `tooltip_extra`, `heal_pct`, `heal_hp`, `price`, `max_stack` y `stackable`.
