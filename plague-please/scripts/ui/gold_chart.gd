extends Control
class_name GoldChart
## A minimal hand-drawn line chart (Control._draw(), no external plotting
## lib) for DayReportScreen's Finances tab - plots RunManager.day_stats'
## gold_history (a snapshot per add_gold()/spend_gold() call) across the
## day so "how much money did I make/spend" reads as a shape, not just
## two numbers.

var history: Array = [] # Array of {"hour": int, "gold": int}

const LINE_COLOR := Color(0.25, 0.45, 0.2, 1)
const AXIS_COLOR := Color(0.5, 0.4, 0.3, 1)
const MARGIN := 8.0

func set_history(new_history: Array) -> void:
	history = new_history
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_line(Vector2(MARGIN, h - MARGIN), Vector2(w - MARGIN, h - MARGIN), AXIS_COLOR, 1.0)
	if history.size() < 2:
		return

	var min_gold: int = history[0]["gold"]
	var max_gold: int = history[0]["gold"]
	for entry in history:
		min_gold = mini(min_gold, entry["gold"])
		max_gold = maxi(max_gold, entry["gold"])
	if max_gold == min_gold:
		max_gold += 1 # avoid a divide-by-zero; a flat run still draws a flat line, not nothing

	var plot_w := w - MARGIN * 2.0
	var plot_h := h - MARGIN * 2.0
	var points := PackedVector2Array()
	for i in history.size():
		var entry: Dictionary = history[i]
		var x: float = MARGIN + plot_w * (float(i) / float(history.size() - 1))
		var t: float = float(entry["gold"] - min_gold) / float(max_gold - min_gold)
		var y: float = MARGIN + plot_h * (1.0 - t)
		points.append(Vector2(x, y))

	for i in points.size() - 1:
		draw_line(points[i], points[i + 1], LINE_COLOR, 2.0)
	for p in points:
		draw_circle(p, 2.0, LINE_COLOR)
