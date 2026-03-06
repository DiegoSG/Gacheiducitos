extends CharacterBody2D

@export var speed = 100.0
@onready var actionable_finder: Area2D = $ActionableFinder
@onready var hitbox_component: HitboxComponent = $HitboxComponent

var is_dialogue_active = false
var is_attacking = false
var last_direction = Vector2.DOWN

func _ready():
	add_to_group("player")
	
	# Conectarse a las señales de Dialogue Manager
	var dm = Engine.get_singleton("DialogueManager")
	if dm:
		dm.dialogue_started.connect(_on_dialogue_started)
		dm.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_started(_resource: DialogueResource):
	is_dialogue_active = true
	velocity = Vector2.ZERO # Detenemos al jugador inmediatamente

func _on_dialogue_ended(_resource: DialogueResource):
	# Damos un pequeñísimo delay para no atrapar el mismo input que cerró el diálogo
	await get_tree().create_timer(0.1).timeout
	is_dialogue_active = false

@warning_ignore("unused_parameter")
func _physics_process(delta):
	if is_dialogue_active:
		return
		
	# Get input direction
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction:
		velocity = direction * speed
		last_direction = direction
		# Rotate the interaction area and hitbox to face movement direction
		actionable_finder.rotation = direction.angle() - PI/2
		hitbox_component.rotation = direction.angle() - PI/2
	else:
		velocity = Vector2.ZERO

	if is_attacking:
		velocity = Vector2.ZERO # Stop moving while attacking

	move_and_slide()

func attack():
	if is_attacking: return
	is_attacking = true
	# Activar hitbox por un instante
	hitbox_component.set_active(true)
	await get_tree().create_timer(0.2).timeout
	hitbox_component.set_active(false)
	is_attacking = false

# Trasladamos la interacción a _unhandled_input para respetar los CanvasLayer (UI)
func _unhandled_input(event: InputEvent) -> void:
	if is_dialogue_active:
		return
		
	if event.is_action_pressed("ui_accept"):
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			get_viewport().set_input_as_handled()
			actionables[0].action()

	# Accion de golpear, asumiendo "attack" map action. En caso no estar,
	# por defecto lo vincularemos a "ui_select" (barra espaciadora) si es que "ui_accept" 
	# es la tecla de interacción, o crearemos la de UI provisional. Usaremos una tecla 'Z'
	# si el usuario lo necesita, pero temporalmente probamos ui_cancel u otra, o "attack" si existiese.
	# Dejaremos un print o if event.is_action_pressed("attack"). Godot no fallará
	# si mapeamos un Input normal de teclado, pero if event.is_action_pressed() requiere que exista.
	# Haremos fallback a la tecla Z.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Z:
			attack()
