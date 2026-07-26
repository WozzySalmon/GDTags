@tool
extends RefCounted

## Maps a Gameplay Tags dock status message to an editor theme colour name.
## Split out of the dock so message classification can be read and changed on its own.

const SUCCESS_PREFIXES: Array[String] = [
	"Added",
	"Cleared",
	"Removed",
	"Updated",
	"Restored",
	"Imported",
	"Exported",
	"Regenerated",
	"Renamed",
]
const ERROR_PREFIXES: Array[String] = [
	"Could not",
	"Refusing",
	"Database path",
	"Tag already",
]
const WARNING_PREFIXES: Array[String] = ["Enter", "No "]
const WARNING_SUBSTRINGS: Array[String] = ["could not be regenerated"]


## Returns the editor theme colour name for [param message], or an empty StringName
## when the message should keep the label's default colour.
static func get_status_color_name(message: String) -> StringName:
	for substring in WARNING_SUBSTRINGS:
		if message.contains(substring):
			return &"warning_color"
	if _has_any_prefix(message, SUCCESS_PREFIXES):
		return &"success_color"
	if _has_any_prefix(message, ERROR_PREFIXES):
		return &"error_color"
	if _has_any_prefix(message, WARNING_PREFIXES):
		return &"warning_color"
	return &""


static func _has_any_prefix(message: String, prefixes: Array[String]) -> bool:
	for prefix in prefixes:
		if message.begins_with(prefix):
			return true
	return false
