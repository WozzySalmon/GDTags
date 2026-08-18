@tool
extends RefCounted

## Provides persistence and file IO helpers for the Gameplay Tags editor dock.


static func ensure_database_directory(path: String) -> Error:
	return GameplayTagUtils.ensure_parent_directory(path)


## Returns whether [param path] already holds a resource that is not a tag database.
## Checked separately from saving so the dock can report the conflict before it creates
## directories, and so the directory is only ever created once per save.
static func database_path_conflicts(path: String) -> bool:
	return GameplayTagUtils.database_path_conflicts(path)


static func save_database_resource(database: GameplayTagDatabase, path: String) -> Error:
	return ResourceSaver.save(database, path)


static func export_tags_to_csv_file(database: GameplayTagDatabase, path: String) -> Error:
	var directory_error: Error = ensure_database_directory(path)
	if directory_error != OK:
		return directory_error
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ERR_CANT_OPEN
	file.store_string(database.to_csv_text())
	file.close()
	return OK
