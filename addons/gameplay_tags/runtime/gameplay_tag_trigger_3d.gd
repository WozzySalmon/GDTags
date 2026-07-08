@tool
class_name GameplayTagTrigger3D
extends Area3D

signal tagged_body_entered(body: Node)
signal tagged_area_entered(area: Area3D)

enum MatchMode {
	ALL,
	ANY,
}

@export var required_tags: Array[StringName] = []:
	set(value):
		required_tags = GameplayTagDatabase.canonicalize_tag_array(value)

@export var match_mode: MatchMode = MatchMode.ALL
@export var exact_match: bool = false
@export var trigger_once: bool = false

var _has_triggered := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func can_trigger(target: Node) -> bool:
	var allowed := false
	if target != null and not (trigger_once and _has_triggered):
		if required_tags.is_empty():
			allowed = true
		else:
			var registry := _get_registry()
			if registry != null:
				match match_mode:
					MatchMode.ALL:
						allowed = bool(registry.target_has_all(target, required_tags, exact_match))
					MatchMode.ANY:
						allowed = bool(registry.target_has_any(target, required_tags, exact_match))
	return allowed


func get_matching_overlapping_bodies() -> Array[Node]:
	var matches: Array[Node] = []
	for body in get_overlapping_bodies():
		if body is Node and can_trigger(body):
			matches.append(body)
	return matches


func get_matching_overlapping_areas() -> Array[Area3D]:
	var matches: Array[Area3D] = []
	for area in get_overlapping_areas():
		if area is Area3D and can_trigger(area):
			matches.append(area)
	return matches


func _on_body_entered(body: Node) -> void:
	if not can_trigger(body):
		return
	_has_triggered = true
	tagged_body_entered.emit(body)


func _on_area_entered(area: Area3D) -> void:
	if not can_trigger(area):
		return
	_has_triggered = true
	tagged_area_entered.emit(area)


func _get_registry() -> Node:
	return GameplayTagUtils.get_registry(self)
