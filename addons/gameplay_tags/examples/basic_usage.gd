extends Node


func _ready() -> void:
	var enemy: Node = Node.new()
	var tags: GameplayTagComponent = GameplayTagComponent.new()
	enemy.add_child(tags)
	add_child(enemy)

	# In normal scenes, pick owned_tags from the Inspector. This script path is for examples/tests.
	var initial_tags: Array[StringName] = [
		GameplayTagIds.TEAM_ENEMY,
		GameplayTagIds.STATE_STUNNED,
		GameplayTagIds.DAMAGE_FIRE,
	]
	tags.add_tags(initial_tags)

	if GameplayTags.target_has_tag(enemy, GameplayTagIds.TEAM_ENEMY):
		print("Enemy target")

	if GameplayTags.target_has_tag(enemy, GameplayTagIds.STATE):
		print("Hierarchical match: State.Stunned satisfies State")

	var damage_requirements: Array[StringName] = [GameplayTagIds.TEAM_ENEMY]
	var blocked_states: Array[StringName] = [GameplayTagIds.STATE_STUNNED]
	var can_damage: bool = GameplayTags.target_has_all(enemy, damage_requirements)
	var cannot_act: bool = GameplayTags.target_has_any(enemy, blocked_states)

	print("Can damage: ", can_damage)
	print("Cannot act: ", cannot_act)
