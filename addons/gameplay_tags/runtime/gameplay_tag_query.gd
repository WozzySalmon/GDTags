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

# Includes the root query: valid query trees occupy depths 0 through 15.
const MAX_SUB_QUERY_DEPTH: int = 16

@export var mode: Mode = Mode.ALL:
	set(value):
		if mode == value:
			return
		mode = value
		emit_changed()

@export var tags: Array[StringName] = []:
	set(value):
		var canonical_tags: Array[StringName] = GameplayTagDatabase.canonicalize_valid_tag_array(
			value
		)
		if tags == canonical_tags:
			return
		tags = canonical_tags
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
		if sub_queries == value:
			return
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


## Returns a human-readable trace of how [param target] was evaluated, one line per
## clause, ending in the overall verdict. Intended for debugging a query that returns
## an unexpected answer; the verdict always agrees with [method matches].
func explain(target: Object) -> String:
	var container: GameplayTagContainer = _container_from_target(target)
	if container == null:
		return "target could not be resolved to any owned tags"

	var trace: Array[String] = []
	trace.append("owned: %s" % _format_tags(container.get_tags()))
	var matched: bool = _explain_container(container, 0, "", trace)
	trace.append("result: %s" % ("MATCH" if matched else "NO MATCH"))
	return "\n".join(trace)


## Checks this query for problems that make it unsatisfiable or meaningless, without
## evaluating it against a target. Returns one message per issue, empty when sound.
## Falls back to the autoload's database when [param database] is omitted.
func validate(database: GameplayTagDatabase = null) -> PackedStringArray:
	var resolved_database: GameplayTagDatabase = database
	if resolved_database == null:
		var registry: Node = GameplayTagUtils.get_registry()
		if registry != null and registry.has_method("get_database"):
			resolved_database = registry.get_database()

	var issues: PackedStringArray = PackedStringArray()
	var visiting: Dictionary[int, bool] = {}
	_validate_node(resolved_database, "query", 0, visiting, issues)
	return issues


func _matches_container(container: GameplayTagContainer, depth: int) -> bool:
	if depth >= MAX_SUB_QUERY_DEPTH:
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


# Mirrors _matches_container while recording a line per clause. Kept separate so the
# matching hot path allocates nothing; a regression test cross-checks the two verdicts.
func _explain_container(
	container: GameplayTagContainer, depth: int, indent: String, trace: Array[String]
) -> bool:
	if depth >= MAX_SUB_QUERY_DEPTH:
		trace.append("%snesting limit of %d exceeded" % [indent, MAX_SUB_QUERY_DEPTH])
		return false

	trace.append("%s%s%s" % [indent, _mode_name(), " exact" if exact else ""])
	var child_indent: String = indent + "  "

	var own_tags_matched: bool = false
	if mode == Mode.ALL:
		own_tags_matched = container.has_all(tags, exact)
	else:
		own_tags_matched = container.has_any(tags, exact)

	if not tags.is_empty():
		var verdict: String = "pass" if own_tags_matched else "fail"
		var detail: String = _explain_tag_clause(container)
		var clause: String = (
			"%stags [%s] -> %s%s" % [child_indent, _format_tags(tags), verdict, detail]
		)
		trace.append(clause)

	var matched: bool = _combine_clause(mode != Mode.ANY, own_tags_matched)
	for sub_query in sub_queries:
		if sub_query != null:
			matched = _combine_clause(
				matched, sub_query._explain_container(container, depth + 1, child_indent, trace)
			)
	trace.append("%s-> %s" % [indent, "pass" if matched else "fail"])
	return matched


# Names the tags responsible for a clause's verdict: what ALL is missing, or what an
# ANY/NONE clause actually found.
func _explain_tag_clause(container: GameplayTagContainer) -> String:
	var listed: Array[StringName] = []
	if mode == Mode.ALL:
		for tag in tags:
			if not container.has_tag(tag, exact):
				listed.append(tag)
		if listed.is_empty():
			return ""
		return " (missing %s)" % _format_tags(listed)

	for tag in tags:
		if container.has_tag(tag, exact):
			listed.append(tag)
	if listed.is_empty():
		return " (owns none)"
	return " (owns %s)" % _format_tags(listed)


func _validate_node(
	database: GameplayTagDatabase,
	path: String,
	depth: int,
	visiting: Dictionary[int, bool],
	issues: PackedStringArray,
) -> void:
	var instance_id: int = get_instance_id()
	if visiting.has(instance_id):
		issues.append("%s: query is nested inside itself" % path)
		return
	if depth >= MAX_SUB_QUERY_DEPTH:
		issues.append("%s: nesting exceeds %d levels" % [path, MAX_SUB_QUERY_DEPTH])
		return
	visiting[instance_id] = true

	if database != null:
		for tag in tags:
			if not database.has_tag(tag):
				issues.append("%s: tag %s is not in the database" % [path, tag])

	if mode == Mode.ANY and tags.is_empty() and sub_queries.is_empty():
		issues.append("%s: ANY with no tags and no sub-queries can never match" % path)

	_validate_contradictions(path, issues)

	var index: int = 0
	for sub_query in sub_queries:
		if sub_query != null:
			sub_query._validate_node(
				database, "%s.sub_queries[%d]" % [path, index], depth + 1, visiting, issues
			)
		index += 1

	visiting.erase(instance_id)


# A tag this node requires cannot also be forbidden by one of its direct children, and
# vice versa. Only flagged when the forbidding clause actually covers the required one:
# forbidding exactly A does not rule out satisfying a non-exact A with A.B.
func _validate_contradictions(path: String, issues: PackedStringArray) -> void:
	if mode == Mode.ANY:
		return

	for sub_query in sub_queries:
		if sub_query == null:
			continue
		var required: Array[StringName] = []
		var forbidden: Array[StringName] = []
		var require_exact: bool = false
		var forbid_exact: bool = false
		if mode == Mode.ALL and sub_query.mode == Mode.NONE:
			required = tags
			forbidden = sub_query.tags
			require_exact = exact
			forbid_exact = sub_query.exact
		elif mode == Mode.NONE and sub_query.mode == Mode.ALL:
			required = sub_query.tags
			forbidden = tags
			require_exact = sub_query.exact
			forbid_exact = exact
		else:
			continue

		if forbid_exact and not require_exact:
			continue
		for tag in required:
			if forbidden.has(tag):
				issues.append("%s: tag %s is both required and forbidden" % [path, tag])


func _mode_name() -> String:
	match mode:
		Mode.ANY:
			return "ANY"
		Mode.NONE:
			return "NONE"
	return "ALL"


func _format_tags(tag_list: Array[StringName]) -> String:
	if tag_list.is_empty():
		return "none"
	var parts: PackedStringArray = PackedStringArray()
	for tag in tag_list:
		parts.append(String(tag))
	return ", ".join(parts)


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
