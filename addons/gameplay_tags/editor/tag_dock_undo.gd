@tool
extends RefCounted

## Commits full Gameplay Tags database state changes to the editor undo history.


static func make_step(
	tags: Array[StringName],
	descriptions: Dictionary[String, String],
	redirects: Dictionary[StringName, StringName],
	status_message: String,
	selected_tag: StringName,
) -> Dictionary:
	return {
		"tags": tags,
		"descriptions": descriptions,
		"redirects": redirects,
		"status_message": status_message,
		"selected_tag": selected_tag,
	}


static func commit_state_change(
	manager: EditorUndoRedoManager,
	dock: Object,
	owner_resource: Resource,
	action_name: String,
	do_step: Dictionary,
	undo_step: Dictionary,
) -> void:
	var do_tags: Array[StringName] = do_step["tags"] as Array[StringName]
	var do_descriptions: Dictionary[String, String] = (
		do_step["descriptions"] as Dictionary[String, String]
	)
	var do_redirects: Dictionary[StringName, StringName] = (
		do_step["redirects"] as Dictionary[StringName, StringName]
	)
	var do_status: String = String(do_step["status_message"])
	var do_selected: StringName = StringName(do_step["selected_tag"])
	var undo_tags: Array[StringName] = undo_step["tags"] as Array[StringName]
	var undo_descriptions: Dictionary[String, String] = (
		undo_step["descriptions"] as Dictionary[String, String]
	)
	var undo_redirects: Dictionary[StringName, StringName] = (
		undo_step["redirects"] as Dictionary[StringName, StringName]
	)
	var undo_status: String = String(undo_step["status_message"])
	var undo_selected: StringName = StringName(undo_step["selected_tag"])

	manager.create_action(action_name, UndoRedo.MERGE_DISABLE, owner_resource)
	(
		manager
		. add_do_method(
			dock,
			"_apply_database_state",
			owner_resource,
			do_tags,
			do_descriptions,
			do_redirects,
			do_status,
			do_selected,
		)
	)
	(
		manager
		. add_undo_method(
			dock,
			"_apply_database_state",
			owner_resource,
			undo_tags,
			undo_descriptions,
			undo_redirects,
			undo_status,
			undo_selected,
		)
	)
	manager.commit_action()
