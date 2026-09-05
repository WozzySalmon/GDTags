extends Node
## Runnable example for the Gameplay Tags addon.
##
## Attach this script to a node, or run it from any project that has the addon
## enabled. It registers the tags it needs, so it also runs in a freshly installed
## project before any tags or generated constants exist. See the comment at the end
## of _ready() for the generated-constant workflow to use after setup.


func _ready() -> void:
	# Tags must exist in the central catalog before components can own them. The
	# Gameplay Tags dock does this interactively; this example registers from code.
	var example_tags: Array[StringName] = [&"Team.Enemy", &"State.Stunned", &"Damage.Fire"]
	GameplayTags.add_tags(example_tags)

	var enemy: Node = Node.new()
	var tags: GameplayTagComponent = GameplayTagComponent.new()
	enemy.add_child(tags)
	add_child(enemy)

	# In normal scenes, pick owned_tags from the Inspector. This script path is for examples/tests.
	tags.add_tags(example_tags)

	if GameplayTags.target_has_tag(enemy, &"Team.Enemy"):
		print("Enemy target")

	if GameplayTags.target_has_tag(enemy, &"State"):
		print("Hierarchical match: State.Stunned satisfies State")

	var damage_requirements: Array[StringName] = [&"Team.Enemy"]
	var blocked_states: Array[StringName] = [&"State.Stunned"]
	var can_damage: bool = GameplayTags.target_has_all(enemy, damage_requirements)
	var cannot_act: bool = GameplayTags.target_has_any(enemy, blocked_states)

	print("Can damage: ", can_damage)
	print("Cannot act: ", cannot_act)

	# The example writes tag literals so it compiles in a fresh project, where the
	# generated GameplayTagIds script may already exist but has no constants yet.
	# After enabling the plugin and creating your tags, run Tools > Regenerate IDs in
	# the Gameplay Tags dock and switch gameplay code to the generated constants,
	# which survive renames and turn typos into compile-time errors:
	#
	#	if GameplayTags.target_has_tag(enemy, GameplayTagIds.TEAM_ENEMY):
	#		attack(enemy)
	print("Gameplay Tags example finished.")
