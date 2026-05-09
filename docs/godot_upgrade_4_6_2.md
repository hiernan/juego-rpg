# Godot 4.6.2 Upgrade

Rama de upgrade: `codex/upgrade-godot-4-6-2`.

Ejecutable usado:

```powershell
D:\ProyectosGodot\Godot_v4.6.2-stable_win64_console.exe
```

Cambios aplicados:

- `project.godot` pasa de feature `4.5` a `4.6`.
- Se agregan archivos `.uid` generados por Godot para scripts nuevos.
- Se actualiza metadata de importacion de `data/loot_tables.csv`.
- Se explicita el tipo de variables en `InventoryService.gd` para compatibilidad con Godot 4.6.2.

Validaciones:

- `--import` con Godot 4.6.2 termina con exit code 0.
- `tools/validate_data.py` termina sin errores ni warnings.

Nota: en el entorno de Codex, Godot no puede escribir configuracion de editor en `AppData`, por eso el comando de importacion muestra errores de cache/config de editor. No son errores del proyecto.
