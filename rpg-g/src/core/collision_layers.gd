class_name CollisionLayers
extends RefCounted

## Bits de las capas de física 2D usadas por código. Los nombres están en
## project.godot [layer_names] para verlos en el Inspector.

const WORLD: int = 1        ## Capa 1: muros y límites del nivel
const PLAYER: int = 2       ## Capa 2: cuerpo del jugador
const ACTIONABLE: int = 16  ## Capa 5: interactuables detectados por ActionableFinder
