# MissionRewardService

`scripts/services/MissionRewardService.gd` concentra el estado temporal de recompensas de una mision.

## Responsabilidades actuales

- crear y resetear `run_rewards`
- acumular oro, XP e items
- aplicar recompensas al avatar al terminar la mision
- consumir items temporales durante la run

## Objetivo

Quitar de `mission.gd` la mutacion manual del diccionario de recompensas.
