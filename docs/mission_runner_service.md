# MissionRunnerService

`scripts/services/MissionRunnerService.gd` concentra resoluciones de mision que antes vivian dentro de `mission.gd`.

## Responsabilidades actuales

- resolver el resultado de un `search_room` a partir de `loot_tables`
- construir la instancia viva de un enemigo desde `enemies.csv`

## Objetivo

Dejar `mission.gd` como controlador de UI/log y mover la logica de resolucion a servicios reutilizables.

## Proximo paso sugerido

Extraer tambien:

- resolucion de trampas
- resolucion de recompensas
- avance del estado de mision por tick o evento
