# Validacion de datos

El proyecto ahora tiene un validador inicial en `tools/validate_data.py`.

## Que valida

- Que los CSV principales existan.
- Que tengan columnas minimas esperadas.
- Que los ids principales no esten vacios ni duplicados.
- Que las locaciones apunten a enemigos existentes.
- Que las locaciones apunten a textos existentes.
- Que las locaciones apunten a loot tables existentes.
- Que las loot tables apunten a items, armas, armaduras o recompensas built-in conocidas.
- Que los pesos de loot sean enteros no negativos.
- Que weapons y armors tengan el `kind` esperado.

## Resultado inicial

Primer hallazgo:

```text
data/loot_tables.csv references unknown item_id 'chainmail'
```

Correccion aplicada:

```text
chainmail -> chain_mail
```

`chain_mail` es el id real definido en `data/armors.csv`.

## Resultado actual

```text
ERRORS: none
WARNINGS: none
```

## Como ejecutarlo

Con Python disponible en PATH:

```powershell
python tools\validate_data.py
```

En el entorno de Codex se puede usar el Python bundled si hace falta.
