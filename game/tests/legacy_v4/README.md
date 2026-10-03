# Historical schema v4 test sources

These text files preserve former global-rank assertions for reference only.
They are not executable Godot scripts and are not current validation gates.
The remaining old script names are aliases to current action-bound test entry points.
An alias does **not** establish equivalent coverage of every historical assertion.

Current replacements:
- `../bound_build_session.gd`: action-bound sampling and transactional choices/presets.
- `../bound_build_policy.gd`: shared operation evaluator, capabilities and compilation.
- `../action_build_runtime.gd`: dual actions, direct/projectile mechanisms and explicit debug-action fixtures.
- `../action_build_integration.gd`: current playable scene, preset/choice UI and lifecycle integration.

Run the current source entry once instead of re-running every alias. Consult its
actual assertions and latest output before claiming coverage. Archived v4 scripts
refer to the old API and cannot be enabled by simply renaming `.txt` to `.gd`.
