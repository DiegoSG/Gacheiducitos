extends CharacterBody2D

@export var speed = 100.0
@onready var actionable_finder: Area2D = $ActionableFinder

var is_dialogue_active = false

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
		# Rotate the interaction area to face movement direction
		actionable_finder.rotation = direction.angle() - PI/2
	else:
		velocity = Vector2.ZERO

	move_and_slide()

# Trasladamos la interacción a _unhandled_input para respetar los CanvasLayer (UI)
func _unhandled_input(event: InputEvent) -> void:
	if is_dialogue_active:
		return
		
	if event.is_action_pressed("ui_accept"):
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			get_viewport().set_input_as_handled()
			actionables[0].action()
