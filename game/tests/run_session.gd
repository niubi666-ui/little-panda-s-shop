extends SceneTree
## Memory-only run transactions. No scene loading, actors, files, or RNG side effects.
const RunSession = preload("res://app/session/run_session.gd")
const BuildLoader = preload("res://content/builds/build_loader.gd")
const BuildSession = preload("res://app/session/training_build_session.gd")
var failures: Array[String] = []
var checks := 0
var initial_build: Dictionary = {}
var initial_program: Dictionary = {}
var plan_calls := 0
var commit_calls := 0
var plan_failure := false
var wrong_plan := false
var commit_failure := false
var mutate_commit := false
var retained_plan: Dictionary = {}
var retained_candidate: Dictionary = {}
var reenter
var reentry_errors: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func finish() -> void:
	print("RUN_SESSION ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	var loader := BuildLoader.new()
	var catalog = loader.load_catalog()
	check(catalog != null, "starter Build catalog validates: " + str(loader.errors))
	if catalog == null:
		finish()
		return
	var starter := BuildSession.new()
	starter.configure(catalog, 71, func(_candidate): return OK)
	check(starter.apply_test_preset("left_blast_right_freeze").ok, "starter Build uses real evaluated preset")
	initial_build = starter.snapshot()
	initial_program = starter.program()
	check_configuration()
	check_staging_and_failure()
	check_route_and_lifecycle()
	check_death_priority_and_restart()
	finish()

func route() -> Dictionary:
	return {"id": "session_fixture", "start_node_ids": ["start"],
		"nodes": [node("start",0,1),node("left",1,0),node("right",1,2),node("merge",2,1),node("end",3,1,"terminal")],
		"edges": [{"from":"start","to":"left"},{"from":"start","to":"right"},
			{"from":"left","to":"merge"},{"from":"right","to":"merge"},{"from":"merge","to":"end"}]}
func node(id: String, layer: int, column: int, kind: String = "battle") -> Dictionary:
	return {"id":id,"layer":layer,"column":column,"kind":kind,"depth":layer+1,"template_id":"graybox","reward_id":"none"}
func fresh(seed_value: int = 17) -> RunSession:
	plan_calls = 0
	commit_calls = 0
	plan_failure = false
	wrong_plan = false
	commit_failure = false
	mutate_commit = false
	reenter = null
	reentry_errors.clear()
	var session := RunSession.new()
	check(session.configure(route(),seed_value,100.0,initial_build,initial_program,build_plan,commit), "session configures")
	return session
func build_plan(definition: Dictionary, seed_value: int) -> Dictionary:
	plan_calls += 1
	if reenter != null:
		reentry_errors.append(reenter.prepare_enter("start").error_key)
		reentry_errors.append(reenter.commit_enter("fake").error_key)
	if plan_failure: return {}
	retained_plan = {"node_id":"wrong" if wrong_plan else definition.id,
		"template_id":definition.template_id,"depth":definition.depth,"kind":definition.kind,"reward_id":definition.reward_id,
		"encounter_plan":{"seed":str(seed_value),"id":"%s:%s" % [seed_value,definition.id],"waves":[{"id":"locked_wave"}]}}
	definition.id = "mutated_input"
	return retained_plan
func commit(candidate: Dictionary) -> Error:
	commit_calls += 1
	retained_candidate = candidate
	if reenter != null:
		reentry_errors.append(reenter.prepare_enter("start").error_key)
		reentry_errors.append(reenter.defeat("fake").error_key)
		check(not reenter.configure(route(),1,100.0,initial_build,initial_program,build_plan,commit), "configure cannot reenter a transaction")
	if mutate_commit:
		candidate.hp = 9999.0
		candidate.phase = "invalid"
		candidate.build_state.selections.clear()
		candidate.active_room_plan.clear()
	return ERR_CANT_CREATE if commit_failure else OK
func enter(session: RunSession, id: String) -> String:
	var prepared: Dictionary = session.prepare_enter(id)
	check(prepared.ok, "prepare legal node " + id)
	if not prepared.ok: return ""
	check(session.commit_enter(prepared.ticket.id).ok, "commit legal node " + id)
	return str(prepared.ticket.id)
func clear_and_map(session: RunSession, entry_id: String, hp: float) -> void:
	check(session.complete_room(entry_id,hp).ok, "clear current room")
	check(session.return_to_map(entry_id).ok, "return after clear")
func map_node(session: RunSession, id: String) -> Dictionary:
	for item in session.map_snapshot().nodes:
		if item.id == id: return item
	return {}

func check_configuration() -> void:
	var session := RunSession.new()
	check(session.snapshot().is_empty() and not session.prepare_enter("start").ok, "unconfigured session rejects commands")
	check(not session.configure(route(),17,0.0,initial_build,initial_program,build_plan,commit), "cannot start dead run")
	check(not session.configure(route(),17,INF,initial_build,initial_program,build_plan,commit), "nonfinite initial health rejected")
	var malformed: Dictionary = initial_build.duplicate(true)
	malformed.revision += 1
	check(not session.configure(route(),17,100.0,malformed,initial_program,build_plan,commit), "Build revision must match compiled snapshot")
	var input: Dictionary = route()
	var build_input: Dictionary = initial_build.duplicate(true)
	var program_input: Dictionary = initial_program.duplicate(true)
	check(session.configure(input,1234567890123456789,100.0,build_input,program_input,build_plan,commit), "64-bit seed and detached inputs accepted")
	input.nodes[0].column = 99
	build_input.selections.clear()
	program_input.actions.clear()
	check(session.snapshot().seed == "1234567890123456789", "seed retains all integer digits")
	check(map_node(session,"start").column == 1 and not session.snapshot().build_state.selections.is_empty() and session.snapshot().build_program.actions.has("primary"), "caller cannot mutate route or Build after configure")
	check(session.snapshot().phase == "map" and session.snapshot().room_count == 0 and session.map_snapshot().available_node_ids == ["start"], "entry starts on map with only configured start")
	check(map_node(session,"start").state == "available" and map_node(session,"end").state == "locked", "map derives available and locked states")
	check(session.snapshot().is_read_only() and session.snapshot().build_state.selections.is_read_only() and session.map_snapshot().nodes.is_read_only(), "published snapshots recursively immutable")

func check_staging_and_failure() -> void:
	var session := fresh()
	var before := session.snapshot()
	check(not session.prepare_enter("end").ok and not session.prepare_enter("missing").ok and plan_calls == 0, "illegal nodes never invoke planner")
	plan_failure = true
	check(not session.prepare_enter("start").ok and session.snapshot() == before, "planner failure preserves all authoritative state")
	plan_failure = false
	wrong_plan = true
	check(not session.prepare_enter("start").ok and session.snapshot() == before, "plan for wrong node cannot stage")
	wrong_plan = false
	reenter = session
	var prepared := session.prepare_enter("start")
	reenter = null
	check(prepared.ok and session.snapshot() == before, "prepare does not advance room counter, revision, HP or Build")
	check(reentry_errors.all(func(key):return key == "run.error.busy"), "planner reentry rejected")
	check(prepared.ticket.room_ordinal == 1 and prepared.ticket.base_revision == before.revision and prepared.ticket.run_id == before.run_id, "ticket locks ordinal and revision")
	retained_plan.encounter_plan.waves.clear()
	check(not prepared.ticket.plan.encounter_plan.waves.is_empty(), "retained planner return cannot mutate ticket")
	var calls_before := plan_calls
	check(session.prepare_enter("start").ticket == prepared.ticket and plan_calls == calls_before, "repeated prepare reuses exact locked plan")
	commit_failure = true
	check(not session.commit_enter(prepared.ticket.id).ok and session.snapshot() == before, "failed entry commit keeps counter and phase")
	check(session.prepare_enter("start").ticket == prepared.ticket, "same entry ticket can retry after failed commit")
	commit_failure = false
	mutate_commit = true
	reenter = session
	check(session.commit_enter(prepared.ticket.id).ok, "retry commits once")
	reenter = null
	mutate_commit = false
	check(reentry_errors.all(func(key):return key == "run.error.busy"), "commit reentry rejected")
	check(session.snapshot().room_count == 1 and session.snapshot().hp == 100.0 and session.snapshot().phase == "combat", "adapter mutation cannot alter committed entry")
	check(session.snapshot().build_state == initial_build and not session.snapshot().active_room_plan.is_empty(), "entry preserves evaluated Build and locked plan")
	retained_candidate.clear()
	check(not session.snapshot().active_room_plan.is_empty(), "adapter retained dictionary cannot mutate later")
	before = session.snapshot()
	calls_before = commit_calls
	var repeat := session.commit_enter(prepared.ticket.id)
	check(repeat.ok and not repeat.changed and session.snapshot() == before and commit_calls == calls_before, "duplicate entry commit is a no-op")
	check(not session.cancel_enter(prepared.ticket.id).ok and not session.prepare_enter("left").ok, "committed room cannot cancel or enter another room before clear")

func check_route_and_lifecycle() -> void:
	var session := fresh()
	var first := enter(session,"start")
	var before := session.snapshot()
	check(not session.return_to_map(first).ok, "uncleared room cannot return to route")
	check(not session.complete_room(first,NAN).ok and not session.complete_room(first,-1.0).ok and session.snapshot() == before, "invalid health cannot alter state")
	commit_failure = true
	check(not session.complete_room(first,71.0).ok and session.snapshot() == before, "clear commit failure preserves combat and checkpoint")
	commit_failure = false
	check(session.complete_room(first,71.0).ok and session.snapshot().phase == "cleared", "clear commits HP and intermediate phase")
	before = session.snapshot()
	check(session.complete_room(first,99.0).ok and session.snapshot() == before, "duplicate clear cannot heal or clear twice")
	commit_failure = true
	check(not session.return_to_map(first).ok and session.snapshot() == before, "map transition failure preserves cleared phase")
	commit_failure = false
	check(session.return_to_map(first).ok and session.map_snapshot().available_node_ids == ["left","right"], "clear unlocks the authored split")
	before = session.snapshot()
	check(session.return_to_map(first).ok and session.snapshot() == before, "duplicate return is a no-op")
	var canceled := session.prepare_enter("left")
	check(session.cancel_enter(canceled.ticket.id).ok and session.snapshot() == before, "canceled load preserves room ordinal")
	check(not session.commit_enter(canceled.ticket.id).ok, "canceled ticket cannot commit")
	var left := session.prepare_enter("left")
	plan_failure = true
	check(not session.prepare_enter("right").ok and session.snapshot() == before, "failed alternate plan preserves map state")
	plan_failure = false
	var right := session.prepare_enter("right")
	check(right.ticket.id != left.ticket.id and not session.commit_enter(left.ticket.id).ok, "new successful prepare supersedes previous candidate")
	check(session.commit_enter(right.ticket.id).ok, "chosen branch commits")
	check(session.snapshot().room_count == 2 and session.snapshot().hp == 71.0 and session.snapshot().build_state == initial_build, "next room inherits HP and exact Build without advancing for failures")
	before = session.snapshot()
	check(not session.complete_room(first,100.0).ok and not session.defeat(first).ok and session.snapshot() == before, "old room completion/death callbacks cannot affect new room")
	clear_and_map(session,right.ticket.id,51.0)
	check(session.map_snapshot().available_node_ids == ["merge"] and map_node(session,"left").state == "locked", "selected branch reaches merge; skipped sibling stays locked")
	check(map_node(session,"start").state == "completed" and map_node(session,"right").state == "current", "map history is completed with current-node priority")
	check(not session.prepare_enter("start").ok, "cannot revisit a completed node")
	var merged := enter(session,"merge")
	clear_and_map(session,merged,39.0)
	var terminal := enter(session,"end")
	check(session.complete_room(terminal,29.0).ok and session.snapshot().phase == "completed", "terminal clear completes run without another reward")
	before = session.snapshot()
	check(not session.return_to_map(terminal).ok and not session.prepare_enter("start").ok, "terminal run cannot enter more nodes")
	check(session.complete_room(terminal,99.0).ok and session.snapshot() == before, "terminal duplicate remains idempotent")
	check(session.snapshot().room_count == 4 and session.snapshot().build_state == initial_build and session.snapshot().build_program == initial_program, "only successful path entries count; starter Build remains exact")
	var twin := fresh()
	var plan_a: Dictionary = twin.prepare_enter("start").ticket.plan
	var another := fresh()
	check(another.prepare_enter("start").ticket.plan == plan_a, "same seed and node reproduce final plan across runs")

func check_death_priority_and_restart() -> void:
	var session := fresh()
	var entry := enter(session,"start")
	var before := session.snapshot()
	commit_failure = true
	check(not session.defeat(entry).ok and session.snapshot() == before, "death commit failure preserves authority")
	commit_failure = false
	check(session.defeat(entry).ok and session.snapshot().phase == "defeated" and session.snapshot().hp == 0.0, "death marks failed run")
	before = session.snapshot()
	check(session.defeat(entry).ok and not session.complete_room(entry,50.0).ok and session.snapshot() == before, "death first defeats later clear callback")
	check(not session.return_to_map(entry).ok and not session.prepare_enter("left").ok, "dead run cannot continue")
	var old_run_id: String = session.snapshot().run_id
	check(session.configure(route(),17,100.0,initial_build,initial_program,build_plan,commit), "explicit restart configures a fresh generation")
	check(session.snapshot().run_id != old_run_id and session.snapshot().room_count == 0 and session.snapshot().hp == 100.0, "restart resets run with fresh identity")
	before = session.snapshot()
	check(not session.complete_room(entry,80.0).ok and not session.commit_enter(entry).ok and session.snapshot() == before, "old-generation room callbacks and tickets rejected")
	entry = enter(session,"start")
	clear_and_map(session,entry,75.0)
	var pending := session.prepare_enter("left")
	check(session.defeat(entry).ok and session.snapshot().phase == "defeated", "same-entry death overrides clear/map callback order")
	check(not session.snapshot().cleared_node_ids.has("start") and not session.commit_enter(pending.ticket.id).ok, "death removes provisional clear and cancels staged continuation")
	session = fresh()
	entry = enter(session,"start")
	check(session.complete_room(entry,0.0).ok and session.snapshot().phase == "defeated", "zero-HP completion uses death priority")
