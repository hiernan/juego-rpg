# CombatFormulaService

`scripts/services/CombatFormulaService.gd` contiene formulas puras de combate: lectura de constantes, reduccion por stats, mapeo de atributo primario/secundario, ataque y defensa.

`GameData.gd` mantiene fachadas como `build_offense()`, `build_defense()` y `get_primary_secondary_for_action()` para no romper consumidores existentes como `Combat.gd`.

La intencion es que `GameData.gd` conserve estado y compatibilidad, mientras las reglas de combate quedan en un servicio dedicado y mas facil de testear o reemplazar.
