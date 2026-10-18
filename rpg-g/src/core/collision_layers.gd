class_name CollisionLayers
extends RefCounted

## 2D physics layer bits used by code. The names are in
## project.godot [layer_names] so they can be seen in the Inspector.

const WORLD: int = 1        ## Layer 1: level walls and boundaries
const PLAYER: int = 2       ## Layer 2: player body
const ACTIONABLE: int = 16  ## Layer 5: interactables detected by ActionableFinder
