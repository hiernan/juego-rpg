# Contrato de datos

Este documento describe el contrato actual de CSVs de la version nueva del juego.

## Reglas generales

- Cada tabla principal debe tener una columna `id`.
- Los `id` deben ser estables, sin espacios, y usarse como referencias internas.
- Las listas dentro de una celda usan `;` como separador.
- Las referencias entre tablas deben validarse con `tools/validate_data.py`.

## Tablas actuales

### enemies.csv

```text
id,name,hp_min,hp_max,dmg_min,dmg_max,gold_min,gold_max,xp,...
```

### weapons.csv

```text
id,name,dmg_min,dmg_max,price,kind
```

Regla: `kind` debe ser `weapon`.

### armors.csv

```text
id,name,armor,price,kind
```

Regla: `kind` debe ser `armor`.

### items.csv

```text
id,name,kind,subkind,heal_pct,heal_hp,stackable,max_stack,rarity,price,tooltip_extra
```

### locations.csv

```text
id,name,flavor_ids,monster_ids,loot_table_id,danger_level,event_ids
```

### loot_tables.csv

```text
id,item_id,weight
```

`item_id` puede apuntar a `items`, `weapons`, `armors` o recompensas built-in.

Recompensas built-in actuales:

- `nothing`
- `gold_small`
- `gold_medium`

### shop_*.csv

```text
id,stock,price_override
```

Reglas:

- `id` debe existir como item, weapon o armor.
- `stock=-1` significa stock infinito.
- `price_override` puede estar vacio o ser un entero.

### texts.csv

```text
id,text_es
```

## Content packs

El objetivo futuro es que cada ambientacion tenga sus propios datos:

```text
content/medieval/data/
content/scifi/data/
```

Por ahora el juego sigue leyendo desde `res://data`.
