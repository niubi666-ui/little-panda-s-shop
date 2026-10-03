extends Node3D
## Test-only PackedScene consumer: no combat references or autonomous clock.
@export var slot: String = ""
static var records: Array[Dictionary] = []
var elapsed := 0.0
var running := true

func configure_effect(fact: Dictionary) -> void:
	records.append({"method": "configure", "slot": slot, "fact": fact.duplicate(true)})
	# Adapters promise copies. Mutation of the supplied presentation dictionary
	# must not change the runtime snapshot or a sibling effect's metadata.
	fact["revision"] = -999
	fact["position"] = Vector3(999, 999, 999)
	if fact.has("statuses") and not fact.statuses.is_empty(): fact.statuses[0].source.revision = -999

func sync_effect(fact: Dictionary, delta: float) -> void:
	elapsed += delta
	records.append({"method": "sync", "slot": slot, "fact": fact.duplicate(true), "delta": delta, "elapsed": elapsed})
	fact["revision"] = -999

func set_time_running(enabled: bool) -> void:
	running = enabled
	records.append({"method": "clock", "slot": slot, "running": enabled})

func finish(reason: String) -> void:
	records.append({"method": "finish", "slot": slot, "reason": reason})
