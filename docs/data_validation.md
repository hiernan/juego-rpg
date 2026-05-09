# Validacion de datos

El proyecto tiene un validador inicial en `tools/validate_data.py`.

## Que valida

- Que los CSV principales existan.
- Que tengan columnas minimas esperadas.
- Que los ids principales no esten vacios ni duplicados.
- Que las locaciones apunten a enemigos existentes.
- Que las locaciones apunten a textos existentes.
- Que las locaciones apunten a loot tables existentes.
- Que las loot tables apunten a items, armas, armaduras o recompensas built-in conocidas.
- Que las tiendas apunten a items, armas o armaduras existentes.
- Que pesos, precios, stock y rangos numericos sean validos.
- Que weapons y armors tengan el `kind` esperado.

## Como ejecutarlo

Con Python disponible en PATH:

```powershell
python tools\validate_data.py
```

En el entorno de Codex se puede usar el Python bundled si hace falta.
