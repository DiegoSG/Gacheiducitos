class_name GameTrigger
extends Area2D

## A general trigger that evaluates game variables and runs actions on enter, on exit, or on interaction.

enum TriggerMode {
	ON_ENTER,        ## Activates when stepped on
	ON_EXIT,         ## Activates when leaving the area
	ON_ENTER_AND_EXIT, ## Runs one list on enter and a different list on exit
	INTERACT,        ## Activates with the action button while inside
	AUTO_START       ## Activates automatically as soon as the scene loads
}

@export var trigger_mode: TriggerMode = TriggerMode.ON_ENTER
## In ON_ENTER_AND_EXIT, one "use" is a full enter + exit cycle.
@export var one_shot: bool = true
## Unique ID for persistence. If empty, the state only lasts while the player stays in this level (ephemeral key).
@export var persistence_id: String = ""

@export_group("Condition")
## In ON_ENTER, ON_EXIT, INTERACT, AUTO_START and force_trigger: a true condition (or no condition) runs
## actions_if_true, and a false one runs actions_if_false.
## In ON_ENTER_AND_EXIT the condition is only evaluated on enter: if false, nothing runs
## (neither on enter nor on exit).
## Without a ConditionSet the condition is considered true.
@export var conditions: ConditionSet

@export_group("Actions")
## Actions run if the condition is true (or there is no condition).
## In ON_ENTER_AND_EXIT these are the enter actions.
@export var actions_if_true: Array[ActionResource] = []
## Actions run if the condition is false.
## In ON_ENTER_AND_EXIT these are the exit actions (actions_if_true never runs on exit).
@export var actions_if_false: Array[ActionResource] = []

var _has_triggered: bool = false
var _is_running: bool = false
## ON_ENTER_AND_EXIT only: true between an enter that ran actions_if_true and its matching exit.
var _cycle_open: bool = false
var _agents_inside: Array[Node2D] = []
var _persistence_key: String = ""

func _ready() -> void:
	_persistence_key = PersistenceIdHelper.runtime_key(self, persistence_id)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_restore_state()
	if trigger_mode == TriggerMode.AUTO_START and not _has_triggered:
		call_deferred("_attempt_trigger")

func _restore_state() -> void:
	if _persistence_key.is_empty():
		return
	if WorldStateManager.has_state(_persistence_key):
		_has_triggered = WorldStateManager.load_state(_persistence_key).get("has_triggered", false)

func _on_body_entered(body: Node2D) -> void:
	if not _agents_inside.has(body):
		_agents_inside.append(body)

	if trigger_mode == TriggerMode.ON_ENTER:
		_attempt_trigger()
	elif trigger_mode == TriggerMode.ON_ENTER_AND_EXIT:
		_begin_cycle()

func _on_body_exited(body: Node2D) -> void:
	if _agents_inside.has(body):
		_agents_inside.erase(body)

	if trigger_mode == TriggerMode.ON_EXIT:
		_attempt_trigger()
	elif trigger_mode == TriggerMode.ON_ENTER_AND_EXIT:
		_agents_inside = _agents_inside.filter(func(n: Node2D) -> bool: return is_instance_valid(n))
		if _agents_inside.is_empty():
			_end_cycle()

func _unhandled_input(event: InputEvent) -> void:
	if trigger_mode == TriggerMode.INTERACT and event.is_action_pressed("interact"):
		_agents_inside = _agents_inside.filter(func(n: Node2D) -> bool: return is_instance_valid(n))
		if _agents_inside.size() > 0:
			get_viewport().set_input_as_handled()
			_attempt_trigger()

## For when the trigger is called directly through a manual ActionableFinder
func action() -> void:
	if trigger_mode != TriggerMode.INTERACT:
		return
	_attempt_trigger()

## Lets any other node (or action) force it to fire
func force_trigger() -> void:
	_attempt_trigger()

func _can_trigger() -> bool:
	if _has_triggered and one_shot: return false
	if _is_running: return false
	return true

## Evaluates the configured condition. Without a ConditionSet returns true.
func _evaluate_condition() -> bool:
	if conditions == null:
		return true
	return conditions.evaluate()

## Standard trigger (ON_ENTER, ON_EXIT, INTERACT, AUTO_START, force_trigger):
## true or absent condition -> actions_if_true, false -> actions_if_false.
func _attempt_trigger() -> void:
	if not _can_trigger(): return

	if one_shot:
		_has_triggered = true
		_persist_state()
	_is_running = true

	var array_to_run: Array[ActionResource] = actions_if_true if _evaluate_condition() else actions_if_false
	await ActionRunner.run(array_to_run, self)
	_is_running = false

## ON_ENTER_AND_EXIT: enter. Runs actions_if_true if the condition holds (or there is no condition);
## if false, runs nothing and does not open the cycle (the exit will not run anything either).
func _begin_cycle() -> void:
	if _cycle_open or not _can_trigger(): return
	if not _evaluate_condition(): return

	_cycle_open = true
	_is_running = true
	await ActionRunner.run(actions_if_true, self)
	_is_running = false

## ON_ENTER_AND_EXIT: exit. Only runs actions_if_false if the enter opened the cycle.
## With one_shot, the full cycle (enter + exit) consumes the trigger.
func _end_cycle() -> void:
	if not _cycle_open: return
	_cycle_open = false

	# If the enter actions are still running, wait for them to finish before the exit actions
	while _is_running:
		if not is_inside_tree():
			return
		await get_tree().process_frame

	if one_shot:
		_has_triggered = true
		_persist_state()

	_is_running = true
	await ActionRunner.run(actions_if_false, self)
	_is_running = false

func _persist_state() -> void:
	if _persistence_key.is_empty():
		return
	WorldStateManager.save_state(_persistence_key, {"has_triggered": _has_triggered})
