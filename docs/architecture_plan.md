# Plan de arquitectura

Este proyecto apunta a ser un RPG minimalista tipo AFK/auto-adventure. La meta de la reestructuracion es separar el motor del juego del contenido tematico para que sea facil agregar locaciones, eventos y eventualmente cambiar de ambientacion sin reescribir la logica principal.

## Objetivos

- Mantener el juego funcional despues de cada cambio importante.
- Separar reglas internas de textos, imagenes y ambientacion.
- Hacer que agregar contenido sea principalmente editar datos.
- Reducir la cantidad de decisiones de gameplay dentro de las escenas UI.
- Tener validadores para detectar referencias rotas entre CSVs.

## Capas propuestas

### Core

Reglas internas independientes del tema:

- inventario y equipo
- combate
- loot y recompensas
- progresion
- generacion y resolucion de misiones
- resolucion de eventos

Esta capa no deberia saber si el juego es medieval, sci-fi u otra cosa.

### Data/catalog

Datos estaticos cargados desde CSVs:

- items
- weapons
- armors
- enemies
- locations
- loot tables
- texts
- event pools

En una segunda etapa estos datos deberian vivir dentro de content packs.

### Game state

Estado vivo de la partida:

- avatar
- inventario
- baul/stash
- equipo actual
- oro y XP
- progreso desbloqueado
- mision actual
- loot temporal de mision

### Presentation/theme

Todo lo que cambia por ambientacion:

- textos visibles
- fondos
- iconos
- sonidos
- nombres de stats
- nombres de slots
- estilos visuales

### Scenes/UI

Las escenas Godot deberian mostrar estado y enviar acciones. La logica de reglas deberia vivir en servicios reutilizables.

Ejemplo deseado:

```gdscript
InventoryService.move_item("inventory", "stash", item_id, qty)
```

en vez de manipular arrays del avatar directamente desde la UI.

## Estructura futura sugerida

```text
scripts/
  autoload/
    GameData.gd
  data/
    DataCatalog.gd
    CsvLoader.gd
  state/
    PlayerState.gd
    MissionState.gd
  services/
    InventoryService.gd
    CombatResolver.gd
    MissionRunner.gd
    RewardResolver.gd
  presentation/
    MissionLogFormatter.gd

content/
  medieval/
    data/
    images/
    audio/
  scifi/
    data/
    images/
    audio/
```

## Sprints recomendados

1. Baseline y seguridad
   - documentar arquitectura
   - agregar validador de datos
   - registrar inconsistencias actuales

2. Inventario y equipo
   - extraer helpers de inventario/equipo a un servicio
   - hacer que Inn use ese servicio
   - preservar drag and drop actual

3. Datos y estado
   - separar catalogos de estado vivo
   - dejar GameData como fachada temporal
   - normalizar contratos de CSVs

4. Misiones
   - separar MissionRunner, CombatResolver y RewardResolver
   - dejar mission.gd como controlador de UI/log

5. Content packs
   - mover contenido medieval a content/medieval
   - soportar selector de pack activo
   - crear un mini pack scifi de prueba

6. Herramientas
   - ampliar validadores
   - documentar como agregar locaciones, enemigos, loot y eventos
   - preparar plantillas de CSV

## Primer criterio de exito

Agregar una locacion nueva debe requerir editar datos, no scripts.

## Segundo criterio de exito

Cambiar de ambientacion debe requerir cambiar un content pack, no la logica interna del juego.
