# MissionState

`scripts/state/MissionState.gd` encapsula el estado vivo del flujo de una mision.

## Responsabilidades

- mantener la cola de eventos de mision
- mantener la cola de lineas y marcadores de UI
- guardar el estado temporal de los dots de busqueda
- guardar el snapshot del botin mostrado al final
- guardar el enemigo actual durante combate

## Objetivo

Quitar de `mission.gd` la mutacion de estado transitorio para acercar la escena al rol de controlador de UI.
