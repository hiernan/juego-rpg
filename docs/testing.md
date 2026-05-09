# Testing

## Carga headless de Godot

```powershell
& 'D:\ProyectosGodot\Godot_v4.5-stable_win64.exe' --headless --path 'D:\ProyectosGodot\juego-rpg' --quit
```

Esta validacion confirma que Godot puede abrir el proyecto y parsear recursos/scripts sin cortar por errores de carga.

## Validacion de datos

```powershell
& 'C:\Users\HiernaN\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools\validate_data.py
```

Esta validacion revisa consistencia entre CSV de contenido.

## Nota sobre smoke tests Godot

Se intento ejecutar un smoke test GDScript con `-s/--script`, que es la forma documentada por Godot para scripts de linea de comandos. En esta instalacion local, Godot 4.5 crashea antes de ejecutar incluso un script minimo, asi que por ahora no queda como validacion confiable.
