class_name PDDashboardStyle
extends RefCounted

## Shared visual constants for the performance dashboard UI.

const PANEL_BG := Color(0.08, 0.09, 0.11, 0.94)
const PANEL_BORDER := Color(0.22, 0.25, 0.30, 1.0)
const TEXT_PRIMARY := Color(0.92, 0.93, 0.95)
const TEXT_MUTED := Color(0.62, 0.66, 0.72)
const ACCENT := Color(0.35, 0.72, 0.95)
const BAR_CURRENT := Color(0.32, 0.62, 0.92)
const BAR_TARGET := Color(0.28, 0.30, 0.34)
const STATUS_OK := Color(0.30, 0.78, 0.52)
const STATUS_WARN := Color(0.92, 0.76, 0.28)
const STATUS_BAD := Color(0.90, 0.35, 0.35)
const ROW_ALT := Color(1, 1, 1, 0.03)

## Ratio of current/target at which the bar turns yellow (lower-is-better metrics).
const WARN_RATIO := 0.75
## Ratio at which the bar turns red.
const FAIL_RATIO := 1.0

const UI_UPDATE_HZ := 8.0
## Opens / closes the dashboard overlay (only while the tool is armed).
const TOGGLE_KEY := KEY_O
## Arms / disarms the whole tool for the current session (debug builds only).
const ARM_KEY := KEY_O
## ProjectSettings key — persistent master switch between runs.
const SETTING_ENABLED := "performance_dashboard/enabled"
const SETTING_ENABLED_DEFAULT := false


static func status_color(current: float, target: float, higher_is_better: bool) -> Color:
	if target <= 0.0:
		return STATUS_OK
	if higher_is_better:
		var ratio := current / target
		if ratio >= 1.0:
			return STATUS_OK
		if ratio >= WARN_RATIO:
			return STATUS_WARN
		return STATUS_BAD
	else:
		var ratio_lo := current / target
		if ratio_lo >= FAIL_RATIO:
			return STATUS_BAD
		if ratio_lo >= WARN_RATIO:
			return STATUS_WARN
		return STATUS_OK


static func is_exceeding(current: float, target: float, higher_is_better: bool) -> bool:
	if target <= 0.0:
		return false
	if higher_is_better:
		return current < target
	return current > target
