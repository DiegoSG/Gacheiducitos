class_name AnimAction
extends ActionResource

## Plays an animation on an AnimationPlayer or AnimatedSprite2D.

## The NodePath pointing to the node containing the animation.
@export var target_node: NodePath

## The exact name of the animation to play.
@export var animation_name: String = ""

## Force the animation to loop eternally. (Warning: if Wait To Finish is on, the sequence will never continue).
@export var loop: bool = false

func get_action_name() -> String:
	return "AnimAction (%s)" % animation_name

func execute(trigger_node: Node) -> void:
	if target_node.is_empty():
		push_warning("AnimAction: empty NodePath")
		finished.emit()
		return

	var t_node: Node = trigger_node.get_node_or_null(target_node)
	if not t_node:
		push_warning("AnimAction: Target not found at path ", target_node)
		finished.emit()
		return
		
	var handled: bool = false
	AudioManager.play_sfx(&"sfx_anim_action")
	
	# Case 1: AnimationPlayer
	var ap: AnimationPlayer = null
	if t_node is AnimationPlayer:
		ap = t_node
	elif t_node.has_node("AnimationPlayer"):
		ap = t_node.get_node("AnimationPlayer")
		
	if ap and ap.has_animation(animation_name):
		handled = true
		var anim: Animation = ap.get_animation(animation_name)
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		ap.play(animation_name)
		if wait_to_finish and not loop:
			if not ap.animation_finished.is_connected(_on_anim_finished):
				ap.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
			return

	# Case 2: AnimatedSprite2D
	var as2d: AnimatedSprite2D = null
	if t_node is AnimatedSprite2D:
		as2d = t_node
	elif t_node.has_node("AnimatedSprite2D"):
		as2d = t_node.get_node("AnimatedSprite2D")
		
	if as2d and as2d.sprite_frames and as2d.sprite_frames.has_animation(animation_name):
		handled = true
		as2d.play(animation_name)
		# On AnimatedSprite2D the animation's loop is usually preconfigured in the SpriteFrames.
		# Here we assume that if it is not looping and is sequential, we wait.
		var sf: SpriteFrames = as2d.sprite_frames
		var is_anim_looping: bool = sf.get_animation_loop(animation_name) if sf.has_animation(animation_name) else false
		
		# We force ignoring the wait if the original animation loops or if the user set loop.
		if wait_to_finish and not loop and not is_anim_looping:
			if not as2d.animation_finished.is_connected(_on_anim_finished):
				as2d.animation_finished.connect(func() -> void: _on_anim_finished(""),CONNECT_ONE_SHOT)
			return

	if not handled:
		push_warning("AnimAction: Could not play ", animation_name, " on ", target_node)

	finished.emit()

func _on_anim_finished(_anim: String) -> void:
	finished.emit()
