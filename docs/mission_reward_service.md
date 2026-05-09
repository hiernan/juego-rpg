# MissionRewardService

`MissionRewardService.gd` concentra la mutacion del botin temporal de mision.

## Responsabilidades

- crear y limpiar el estado `run_rewards`
- sumar oro y XP del run
- agregar items al run y a la `loot_bag`
- aplicar recompensas al avatar al volver al pueblo
- consumir items de la bolsa durante la mision

## Objetivo

Quitar de `mission.gd` la logica de mutacion del botin para que la escena quede mas enfocada en UI y flujo.
