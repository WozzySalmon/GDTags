@tool
extends RefCounted

## Provides persistence and file IO helpers for the Gameplay Tags editor dock.


static func ensure_database_directory(path: String) -> Error:
	var directory: String = path.get_base_dir()
	if directory.is_empty() or directory == "res://" or directory == "user://":
		return OK
	return DirAccess.make_dir_recursive_absolute(directory)


## Returns whether [param path] already holds a resource that is not a tag database.
## Checked separately from saving so the dock can report the conflict before it creates
## directories, and so the directory is only ever created once per save.
static func database_path_conflicts(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var existing_resource: Resource = ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	return not existing_resource is GameplayTagDatabase


static func save_database_resource(database: GameplayTagDatabase, path: String) -> Error:
	return ResourceSaver.save(database, path)


static func import_tags_from_csv_file(database: GameplayTagDatabase, path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var added: int = database.add_tags_from_csv_text(file.get_as_text())
	file.close()
	return added


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
