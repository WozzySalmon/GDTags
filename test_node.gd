extends Node3D

@export var StartingTags: Array[StringName] = [&"State.Bruh"]
var tags: Variant

func _ready() -> void:
	tags = GameplayTags.make_container(StartingTags)
	test()
	

func test()-> void:
	if tags.has(&"State.Bruh"):
		print(StartingTags)
