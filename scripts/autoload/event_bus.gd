extends Node
## Global signal hub. Systems talk through here so they stay decoupled.
## Nothing in here holds state - it only relays signals.

# --- Environmental events / warnings ---
signal warning_started(event: EnvironmentalEvent)
## Fires on every stage change; `phase` is the EnvironmentalEvent.Phase.
signal warning_stage_changed(event: EnvironmentalEvent, stage_index: int, stage_text: String)
signal warning_ended(event: EnvironmentalEvent, resolved: bool)
## The event hit the table and the player did NOT mitigate it.
signal impact_started(event: EnvironmentalEvent)
## The event hit but the player's action (e.g. shield) absorbed it.
signal impact_mitigated(event: EnvironmentalEvent)

# --- Task / work ---
signal task_progress(placed: int, total: int)
signal task_completed()
## A chain reaction has settled: how many toppled, how many stood before it.
signal collapse_finished(knocked: int, standing_before: int)

# --- Focus / awareness ---
signal focus_changed(is_focus: bool)

# --- Game flow ---
signal game_failed(reason: String)
signal game_won()

# --- UI feedback ---
signal notify(text: String, color: Color)
