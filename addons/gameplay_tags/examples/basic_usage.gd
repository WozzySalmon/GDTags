extends Node

func _ready() -> void:
	var container := GameplayTags.make_container([
		"State.Stunned",
		"Damage.Fire",
		"Team.Enemy",
	])

	var can_damage := GameplayTags.make_query_all([
		"Damage",
		"Team.Enemy",
	])

	var cannot_act := GameplayTags.make_query_any([
		"State.Stunned",
		"State.Rooted",
	])

	print("Can damage: ", container.matches_query(can_damage))
	print("Cannot act: ", container.matches_query(cannot_act))
