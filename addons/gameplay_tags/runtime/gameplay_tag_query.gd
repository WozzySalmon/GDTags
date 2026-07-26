@tool
class_name GameplayTagQuery
extends Resource
## A reusable tag condition evaluated against any gameplay tag target.
## Combines its own tags under ALL, ANY, or NONE, and nests other queries through
## [member sub_queries] so conditions like "(A or B) and not C" stay data-driven.

enum Mode {
	ALL,
	ANY,
	NONE,
}

const MAX_SUB_QUERY_DEPTH: int = 16

@export var mode: Mode = Mode.ALL:
	set(value):
		if mode == value:
			return
		mode = value
		emit_changed()

@export var tags: Array[StringName] = []:
	set(value):
		tags = GameplayTagDatabase.canonicalize_valid_tag_array(value)
		emit_changed()

@export var exact: bool = false:
	set(value):
		if exact == value:
			return
		exact = value
		emit_changed()

## Nested queries evaluated alongside [member tags] under the same [member mode].
## ALL requires every sub-query to match, ANY accepts any of them, and NONE rejects
## the target if any of them matches. This is what makes "(A or B) and not C"
## expressible: build the inner queries, then nest them.
@export var sub_queries: Array[GameplayTagQuery] = []:
	set(value):
		sub_queries = value.duplicate()
		emit_changed()


## Builds a query requiring every tag in [param tag_list].
static func all(tag_list: Array[StringName], require_exact: bool = false) -> GameplayTagQuery:
	return _make(Mode.ALL, tag_list, require_exact)


## Builds a query requiring at least one tag in [param tag_list].
static func any(tag_list: Array[StringName], require_exact: bool = false) -> GameplayTagQuery:
	return _make(Mode.ANY, tag_list, require_exact)


## Builds a query rejecting any target owning a tag in [param tag_list].
static func none(tag_list: Array[StringName], require_exact: bool = false) -> GameplayTagQuery:
	return _make(Mode.NONE, tag_list, require_exact)


static func exact_all(tag_list: Array[StringName]) -> GameplayTagQuery:
	return _make(Mode.ALL, tag_list, true)


## Builds a query that only combines other queries, with no tags of its own.
## [code]compose(Mode.ALL, [any([&"Damage.Fire", &"Damage.Ice"]), none([&"State.Immune"])])[/code]
## reads as "(Fire or Ice) and not Immune".
static func compose(query_mode: Mode, nested_queries: Array[GameplayTagQuery]) -> GameplayTagQuery:
	var query: GameplayTagQuery = GameplayTagQuery.new()
	query.mode = query_mode
	query.sub_queries = nested_queries
	return query


## Returns whether [param target] satisfies this query.
## Accepts a container, component, node, or any object the GameplayTags autoload can resolve.
func matches(target: Object) -> bool:
	var container: GameplayTagContainer = _container_from_target(target)
	if container == null:
		return false
	return _matches_container(container, 0)


func _matches_container(container: GameplayTagContainer, depth: int) -> bool:
	if depth > MAX_SUB_QUERY_DEPTH:
		push_error("Gameplay tag query nesting exceeded %d levels." % MAX_SUB_QUERY_DEPTH)
		return false

	# This query's own tags are one clause; each sub-query is another. The mode decides
	# how the clauses combine, so all three modes share the same walk.
	var own_tags_matched: bool = false
	if mode == Mode.ALL:
		own_tags_matched = container.has_all(tags, exact)
	else:
		own_tags_matched = container.has_any(tags, exact)

	var matched: bool = _combine_clause(mode != Mode.ANY, own_tags_matched)
	for sub_query in sub_queries:
		if sub_query != null:
			matched = _combine_clause(matched, sub_query._matches_container(container, depth + 1))
	return matched


func _combine_clause(current: bool, clause_matched: bool) -> bool:
	match mode:
		Mode.ANY:
			return current or clause_matched
		Mode.NONE:
			return current and not clause_matched
	return current and clause_matched


## Nests [param sub_query] inside this one. Returns false for null or for a query that
## would make this one contain itself.
func add_sub_query(sub_query: GameplayTagQuery) -> bool:
	if sub_query == null or sub_query == self or sub_queries.has(sub_query):
		return false
	var updated_sub_queries: Array[GameplayTagQuery] = sub_queries.duplicate()
	updated_sub_queries.append(sub_query)
	sub_queries = updated_sub_queries
	return true


## Removes a previously nested query. Returns whether one was removed.
func remove_sub_query(sub_query: GameplayTagQuery) -> bool:
	var index: int = sub_queries.find(sub_query)
	if index < 0:
		return false
	var updated_sub_queries: Array[GameplayTagQuery] = sub_queries.duplicate()
	updated_sub_queries.remove_at(index)
	sub_queries = updated_sub_queries
	return true


## Adds one tag to this query. Returns false if already present or unusable.
func add_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"" or not GameplayTagDatabase.is_valid_tag_name(tag) or tags.has(tag):
		return false
	var updated_tags: Array[StringName] = tags.duplicate()
	updated_tags.append(tag)
	tags = updated_tags
	return true


## Alias for [method add_tag].
func add(raw_tag: StringName) -> bool:
	return add_tag(raw_tag)


## Adds several tags and returns how many were new.
func add_tags(raw_tags: Array[StringName]) -> int:
	var added: int = 0
	for raw_tag in raw_tags:
		if add_tag(raw_tag):
			added += 1
	return added


## Removes one tag and returns whether it was present.
func remove_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	var index: int = tags.find(tag)
	if index < 0:
		return false
	tags.remove_at(index)
	emit_changed()
	return true


## Alias for [method remove_tag].
func remove(raw_tag: StringName) -> bool:
	return remove_tag(raw_tag)


## Removes several tags and returns how many were present.
func remove_tags(raw_tags: Array[StringName]) -> int:
	var removed: int = 0
	for raw_tag in raw_tags:
		if remove_tag(raw_tag):
			removed += 1
	return removed


## Removes every tag, leaving nested sub-queries untouched.
func clear() -> void:
	if tags.is_empty():
		return
	tags.clear()
	emit_changed()


static func _make(
	query_mode: Mode, tag_list: Array[StringName], require_exact: bool
) -> GameplayTagQuery:
	var query: GameplayTagQuery = GameplayTagQuery.new()
	query.mode = query_mode
	query.exact = require_exact
	query.tags = tag_list
	return query


func _container_from_target(target: Object) -> GameplayTagContainer:
	if target is GameplayTagContainer:
		return target
	if target is GameplayTagComponent:
		return target.get_owned_gameplay_tags()
	var registry: Node = GameplayTagUtils.get_registry()
	if registry != null and registry.has_method("get_owned_gameplay_tags"):
		return registry.get_owned_gameplay_tags(target) as GameplayTagContainer
	return null
