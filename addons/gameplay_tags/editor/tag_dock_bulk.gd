@tool
extends RefCounted

## Builds and commits undoable bulk tag additions for paste and CSV import.

const TagCodeGenerator: Script = preload(
	"res://addons/gameplay_tags/editor/gameplay_tag_code_generator.gd"
)
const TagDockUndo: Script = preload("res://addons/gameplay_tags/editor/tag_dock_undo.gd")


static func make_addition(
	database: GameplayTagDatabase, candidates: Array[StringName]
) -> Dictionary:
	var before_tags: Array[StringName] = database.get_all_tags()
	var before_descriptions: Dictionary[String, String] = database.tag_descriptions.duplicate(true)
	var before_redirects: Dictionary[StringName, StringName] = database.tag_redirects.duplicate(
		true
	)
	var preview: GameplayTagDatabase = GameplayTagDatabase.new()
	preview.set_state(before_tags, before_descriptions, before_redirects)
	var added: int = preview.add_tags(candidates)
	return {
		"added": added,
		"has_collisions": not TagCodeGenerator.get_constant_name_collisions(preview).is_empty(),
		"before_tags": before_tags,
		"before_descriptions": before_descriptions,
		"before_redirects": before_redirects,
		"after_tags": preview.get_all_tags(),
		"after_descriptions": preview.tag_descriptions.duplicate(true),
		"after_redirects": preview.tag_redirects.duplicate(true),
	}


static func commit_addition(
	manager: EditorUndoRedoManager,
	dock: Object,
	database: GameplayTagDatabase,
	plan: Dictionary,
	action_name: String,
	status_message: String,
	undo_status_message: String,
) -> void:
	var after_tags: Array[StringName] = plan["after_tags"] as Array[StringName]
	var after_descriptions: Dictionary[String, String] = (
		plan["after_descriptions"] as Dictionary[String, String]
	)
	var after_redirects: Dictionary[StringName, StringName] = (
		plan["after_redirects"] as Dictionary[StringName, StringName]
	)
	if manager == null:
		(
			dock
			. call(
				"_apply_database_state",
				database,
				after_tags,
				after_descriptions,
				after_redirects,
				status_message,
			)
		)
		return

	var before_tags: Array[StringName] = plan["before_tags"] as Array[StringName]
	var before_descriptions: Dictionary[String, String] = (
		plan["before_descriptions"] as Dictionary[String, String]
	)
	var before_redirects: Dictionary[StringName, StringName] = (
		plan["before_redirects"] as Dictionary[StringName, StringName]
	)
	var do_step: Dictionary = (
		TagDockUndo
		. make_step(
			after_tags,
			after_descriptions,
			after_redirects,
			status_message,
			&"",
		)
	)
	var undo_step: Dictionary = (
		TagDockUndo
		. make_step(
			before_tags,
			before_descriptions,
			before_redirects,
			undo_status_message,
			&"",
		)
	)
	(
		TagDockUndo
		. commit_state_change(
			manager,
			dock,
			database,
			action_name,
			do_step,
			undo_step,
		)
	)
