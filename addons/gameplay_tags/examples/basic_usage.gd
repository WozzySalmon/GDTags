extends Node


func _ready() -> void:
	var enemy := Node.new()
	var tags := GameplayTagComponent.new()
	enemy.add_child(tags)
	add_child(enemy)

	# In normal scenes, pick owned_tags from the Inspector. This script path is for examples/tests.
	tags.add_tag("Team.Enemy")
	tags.add_tag("State.Stunned")

	if GameplayTags.target_has_tag(enemy, "Team.Enemy"):
		print("Enemy target")

	if GameplayTags.target_has_tag(enemy, "State"):
		print("Hierarchical match: State.Stunned satisfies State")

	var can_damage := GameplayTags.target_has_all(enemy, ["Team.Enemy"])
	var cannot_act := GameplayTags.target_has_any(enemy, ["State.Stunned", "State.Rooted"])

	print("Can damage: ", can_damage)
	print("Cannot act: ", cannot_act)
