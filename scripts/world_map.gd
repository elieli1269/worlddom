extends Control
class_name WorldMap

signal territory_clicked(id: String, additive: bool)

var features: Array = []
var owners: Dictionary = {}
var state_colors: Dictionary = {}
var selected: Array[String] = []
var hovered := ""
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var drag_origin := Vector2.ZERO
var pan_origin := Vector2.ZERO
var palette := [Color("#d7a45a"), Color("#5b9f91"), Color("#6682b7"), Color("#c86f61"), Color("#ad8fbf"), Color("#8ca34d"), Color("#d28d55"), Color("#50a8bc")]
var rng := RandomNumberGenerator.new()

func load_world(data: Array) -> void:
	features = data
	queue_redraw()

func set_owners(data: Dictionary) -> void:
	owners = data
	queue_redraw()

func set_state_colors(data: Dictionary) -> void:
	state_colors = data
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	rng.randomize()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#071521"))
	# Faint graticule lends geographic scale without obscuring borders.
	for lat in [-60, -30, 0, 30, 60]:
		var y := _project(Vector2(0, lat)).y
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.34, 0.49, 0.55, 0.15), 1.0)
	for lon in [-120, -60, 0, 60, 120]:
		var x := _project(Vector2(lon, 0)).x
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.34, 0.49, 0.55, 0.12), 1.0)
	for feature in features:
		var id: String = feature.id
		var color: Color = feature.get("color", _color_for(id))
		if owners.has(id):
			var owner: String = str(owners[id])
			color = Color(state_colors.get(owner, _color_for(owner))) if owner.begins_with("NEW_") else _color_for(owner)
		for poly in feature.polygons:
			if poly.is_empty() or poly[0].size() < 3: continue
			var points := PackedVector2Array()
			for coord in poly[0]:
				points.append(_project(Vector2(float(coord[0]), float(coord[1]))))
			var triangles := Geometry2D.triangulate_polygon(points)
			if points.size() >= 3:
				var fill := color.lightened(0.08)
				if selected.has(id): fill = Color("#f4d27d")
				elif hovered == id: fill = color.lightened(0.27)
				if not triangles.is_empty(): draw_colored_polygon(points, fill)
				var edge := Color("#102331")
				if selected.has(id): edge = Color("#fff0bd")
				draw_polyline(points + PackedVector2Array([points[0]]), edge, 1.15 if zoom < 2.5 else 1.65, true)
		var label := str(feature.get("name", id))
		if zoom >= 1.35 or selected.has(id) or hovered == id:
			var center := _project(Vector2(float(feature.get("lon", 0)), float(feature.get("lat", 0))))
			if Rect2(Vector2.ZERO, size).has_point(center):
				var f := ThemeDB.fallback_font
				var fs := 10 if zoom < 1.8 else 12
				draw_string(f, center + Vector2(-f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.91, 0.94, 0.92, 0.9))

func _project(ll: Vector2) -> Vector2:
	var base := minf(size.x / 360.0, size.y / 150.0) * zoom
	return Vector2(size.x * 0.5 + (ll.x + pan.x) * base, size.y * 0.5 - (ll.y + pan.y) * base)

func _unproject(p: Vector2) -> Vector2:
	var base := minf(size.x / 360.0, size.y / 150.0) * zoom
	return Vector2((p.x - size.x * 0.5) / base - pan.x, -(p.y - size.y * 0.5) / base - pan.y)

func _color_for(key: String) -> Color:
	var h: int = absi(key.hash())
	return Color.from_hsv(float(h % 1000) / 1000.0, 0.42, 0.78)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_origin = event.position
				pan_origin = pan
			else:
				dragging = false
				if event.position.distance_to(drag_origin) < 5:
					var hit := _hit_test(_unproject(event.position))
					if hit != "": territory_clicked.emit(hit, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.18)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.18)
	elif event is InputEventMouseMotion:
		if dragging:
			var base := minf(size.x / 360.0, size.y / 150.0) * zoom
			var delta: Vector2 = event.position - drag_origin
			pan = pan_origin + Vector2(delta.x, -delta.y) / base
			queue_redraw()
		else:
			var next := _hit_test(_unproject(event.position))
			if next != hovered:
				hovered = next
				queue_redraw()

func _zoom_at(pos: Vector2, factor: float) -> void:
	var before := _unproject(pos)
	zoom = clampf(zoom * factor, 0.7, 8.0)
	var after := _unproject(pos)
	pan += after - before
	queue_redraw()

func _hit_test(ll: Vector2) -> String:
	for i in range(features.size() - 1, -1, -1):
		var feature: Dictionary = features[i]
		for poly in feature.polygons:
			if poly.is_empty(): continue
			if Geometry2D.is_point_in_polygon(ll, PackedVector2Array(poly[0].map(func(c): return Vector2(float(c[0]), float(c[1]))))):
				var in_hole := false
				for j in range(1, poly.size()):
					var hole := PackedVector2Array(poly[j].map(func(c): return Vector2(float(c[0]), float(c[1]))))
					if Geometry2D.is_point_in_polygon(ll, hole): in_hole = true
				if not in_hole: return str(feature.id)
	return ""
