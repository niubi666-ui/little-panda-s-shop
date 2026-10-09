extends RefCounted
## Reads the authoritative action timer; never advances cooldown or handles input.
static func format_for(player) -> String:
	var events := InputMap.action_get_events("combat_skill")
	var binding: String = events[0].as_text() if not events.is_empty() else TranslationServer.translate("build.action.skill")
	if not player.health.alive() or player.control_locked:
		return TranslationServer.translate("combat.skill.disabled").format({"key":binding})
	var remaining: float = player.runner.cooldown_for("skill")
	if remaining > 0.0:
		return TranslationServer.translate("combat.skill.cooldown").format({"key":binding,"seconds":"%.1f" % (ceilf(remaining * 10.0) / 10.0)})
	return TranslationServer.translate("combat.skill.ready").format({"key":binding})
