@tool
extends RefCounted

## Builds the Gameplay Tags hierarchy displayed by the editor dock.


static func include_ancestor_tags(
	database: GameplayTagDatabase,
	matched_tags: Array[StringName],
) -> Array[StringName]:
	var tree_tags: Array[StringName] = matched_tags.duplicate()
	for tag in matched_tags:
		var parent_text: String = String(tag)
		while parent_text.contains("."):
			parent_text = parent_text.left(parent_text.rfind("."))
			var parent_tag: StringName = StringName(parent_text)
			if database.has_tag(parent_tag) and not tree_tags.has(parent_tag):
				tree_tags.append(parent_tag)
	return GameplayTagDatabase.canonicalize_tag_array(tree_tags)


static func populate(
	tag_tree: Tree,
	database: GameplayTagDatabase,
	tree_tags: Array[StringName],
) -> Dictionary[StringName, TreeItem]:
	var tree_items_by_tag: Dictionary[StringName, TreeItem] = {}
	var root: TreeItem = tag_tree.create_item()
	for tag in tree_tags:
		var tag_text: String = String(tag)
		var parent_item: TreeItem = root
		var separator_index: int = tag_text.rfind(".")
		if separator_index >= 0:
			var parent_tag: StringName = StringName(tag_text.left(separator_index))
			parent_item = tree_items_by_tag.get(parent_tag, root)

		var item: TreeItem = tag_tree.create_item(parent_item)
		item.set_text(0, tag_text.get_slice(".", tag_text.get_slice_count(".") - 1))
		item.set_metadata(0, tag)
		var description: String = String(database.tag_descriptions.get(tag_text, ""))
		var tooltip: String = tag_text
		if not description.is_empty():
			tooltip += "\n%s" % description
		item.set_tooltip_text(0, tooltip)
		tree_items_by_tag[tag] = item
	return tree_items_by_tag
