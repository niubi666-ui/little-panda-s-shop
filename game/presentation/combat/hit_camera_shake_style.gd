extends Resource
## Presentation-only screen-plane displacement. All tuning lives in the .tres.

@export var amplitude_meters: Vector2
@export var frequencies_hz: Vector2
@export var phase_radians: Vector2
@export var duration_seconds: float
@export var envelope_power: float
@export var maximum_offset_meters: float


func validation_error() -> String:
	if not amplitude_meters.is_finite() or amplitude_meters.x < 0.0 or amplitude_meters.y < 0.0:
		return "amplitude_meters must contain finite nonnegative values"
	if not frequencies_hz.is_finite() or frequencies_hz.x <= 0.0 or frequencies_hz.y <= 0.0:
		return "frequencies_hz must contain finite positive values"
	if not phase_radians.is_finite():
		return "phase_radians must contain finite values"
	if not is_finite(duration_seconds) or duration_seconds <= 0.0:
		return "duration_seconds must be finite and positive"
	if not is_finite(envelope_power) or envelope_power <= 0.0:
		return "envelope_power must be finite and positive"
	if not is_finite(maximum_offset_meters) or maximum_offset_meters <= 0.0:
		return "maximum_offset_meters must be finite and positive"
	return ""
