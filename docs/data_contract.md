# Contrato de datos

Este documento describe el contrato actual de CSVs. No es el contrato final ideal, sino la base que el juego usa hoy y que vamos a normalizar de a poco.

## Reglas generales

- Cada tabla principal debe tener una columna `id`.
- Los `id` deben ser estables, sin espacios, y usarse como referencias internas.
- Los textos visibles pueden cambiar por idioma o tematica, pero los `id` deberian mantenerse mientras el contenido exista.
- Las listas dentro de una celda usan `;` como separador.
- Las referencias entre tablas deben validarse con `tools/validate_data.py`.

## Tablas actuales

### enemies.csv

Columnas actuales:

```text
id,name,hp_min,hp_max,dmg_min,dmg_max,gold_min,gold_max,xp
```

Uso actual:

- `id`: referencia desde locaciones y eventos.
- `name`: nombre visible.
- `hp_min` / `hp_max`: rango de vida al crear encuentro.
- `dmg_min` / `dmg_max`: rango de daño enemigo.
- `gold_min` / `gold_max`: oro al derrotar.
- `xp`: experiencia al derrotar.

### weapons.csv

Columnas actuales:

```text
id,name,dmg_min,dmg_max,price,kind
```

Regla:

- `kind` debe ser `weapon`.

### armors.csv

Columnas actuales:

```text
id,name,armor,price,kind
```

Regla:

- `kind` debe ser `armor`.

### items.csv

Columnas actuales:

```text
id,name,kind,subkind,heal_pct,heal_hp,stackable,max_stack,rarity,tooltip_extra
```

Uso actual:

- consumibles curativos usan `kind=consumable` y `subkind=heal`.
- `heal_pct` cura porcentaje de HP maximo.
- `heal_hp` queda como curacion fija alternativa.
- `stackable` define si se agrupa visualmente.

### locations.csv

Columnas actuales:

```text
id,name,flavor_ids,monster_ids,loot_table_id,danger_level,event_ids
```

Uso actual:

- `flavor_ids`: ids de `texts.csv`.
- `monster_ids`: ids de `enemies.csv`.
- `loot_table_id`: id de tabla en `loot_tables.csv`.
- `event_ids`: eventos conocidos por `MissionEvents`.

### loot_tables.csv

Columnas actuales:

```text
id,item_id,weight
```

Uso actual:

- `id`: id de tabla de loot.
- `item_id`: item, arma, armadura o recompensa built-in.
- `weight`: peso entero no negativo.

Recompensas built-in aceptadas hoy:

- `nothing`
- `gold_small`
- `gold_medium`

### texts.csv

Columnas actuales:

```text
id,text_es
```

Uso actual:

- textos de ambientacion referenciados por locaciones.

## Contrato futuro deseado

Cuando avancemos a content packs, la idea es que cada pack tenga sus propios CSVs con el mismo contrato.

Ejemplo:

```text
content/medieval/data/locations.csv
content/scifi/data/locations.csv
```

El core deberia cargar el pack activo sin saber si los datos representan criptas y goblins o estaciones espaciales y drones.
