extends Node


func _ready() -> void:
	var enemy: Node = Node.new()
	var tags: GameplayTagComponent = GameplayTagComponent.new()
	enemy.add_child(tags)
	add_child(enemy)

	# In normal scenes, pick owned_tags from the Inspector. This script path is for examples/tests.
	tags.add_tag(GameplayTagIds.TEAM_ENEMY)
	tags.add_tag(GameplayTagIds.STATE_STUNNED)
	GameplayTags.add_tag_to_node(enemy, GameplayTagIds.DAMAGE_FIRE)

	if GameplayTags.target_has_tag(enemy, GameplayTagIds.TEAM_ENEMY):
		print("Enemy target")

	if GameplayTags.target_has_tag(enemy, GameplayTagIds.STATE):
		print("Hierarchical match: State.Stunned satisfies State")

	var can_damage: bool = GameplayTags.target_has_all(enemy, [GameplayTagIds.TEAM_ENEMY])
	var cannot_act: bool = GameplayTags.target_has_any(enemy, [GameplayTagIds.STATE_STUNNED])

	print("Can damage: ", can_damage)
	print("Cannot act: ", cannot_act)
