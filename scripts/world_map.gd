extends Control
class_name WorldMap

signal territory_clicked(id: String, additive: bool)
signal deep_layer_requested(country_code: String)
signal zoom_changed(value: float)

var countries: Array = []
var layers: Dictionary = {}
var deep_countries: Dictionary = {}
var owners: Dictionary = {}
var state_colors: Dictionary = {}
var selected: Array[String] = []
var hovered := ""
var hovered_country := ""
var deep_country := ""
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var drag_origin := Vector2.ZERO
var pan_origin := Vector2.ZERO
var layer_flags := {"political": true, "international": true, "administrative": true, "labels": true}
var spatial_indices: Dictionary = {}
var triangles_cache: Dictionary = {}
var requested_deep: Dictionary = {}
var _label_points: Array[Vector2] = []

func load_world(country_features: Array) -> void:
	countries = country_features
	set_level_data(0, country_features)

func set_level_data(level: int, features: Array) -> void:
	layers[level] = features
	spatial_indices[level] = _build_spatial_index(features)
	queue_redraw()

func set_deep_country_data(country_code: String, level: int, features: Array) -> void:
	var code := country_code.to_upper()
	deep_countries[code] = {"level": level, "features": features, "index": _build_spatial_index(features)}
	deep_country = code
	queue_redraw()

func set_owners(data: Dictionary) -> void:
	owners = data
	queue_redraw()

func set_state_colors(data: Dictionary) -> void:
	state_colors = data
	queue_redraw()

func set_layers(data: Dictionary) -> void:
	for key in data:
		layer_flags[key] = bool(data[key])
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

func _draw() -> void:
	var visible_rect := Rect2(Vector2.ZERO, size)
	draw_rect(visible_rect, Color("#06131d"))
	_draw_graticule()
	_label_points.clear()
	var country_index: Dictionary = spatial_indices.get(0, {})
	var country_view := _features_in_view(countries, country_index)
	for feature in country_view:
		var fill := _feature_color(feature, true)
		if not layer_flags.political: fill = Color("#527076")
		_draw_feature_fill(feature, fill)
		if layer_flags.international:
			_draw_feature_outline(feature, Color("#122936"), 1.25 if zoom < 2.5 else 1.7)
		if layer_flags.labels and zoom < 1.8:
			_draw_label(feature, 10 if zoom < 1.4 else 11, false)
	var active_level := _active_level()
	var active_features: Array = layers.get(active_level, [])
	if active_level > 0 and layer_flags.administrative:
		var active_index: Dictionary = spatial_indices.get(active_level, {})
		for feature in _features_in_view(active_features, active_index):
			if not deep_country.is_empty() and str(feature.country_code) == deep_country and zoom >= 5.0: continue
			_draw_region(feature, active_level)
	if zoom >= 5.0 and layer_flags.administrative and deep_countries.has(hovered_country if not hovered_country.is_empty() else deep_country):
		var code := hovered_country if not hovered_country.is_empty() and deep_countries.has(hovered_country) else deep_country
		var deep: Dictionary = deep_countries[code]
		for feature in _features_in_view(deep.features, deep.index):
			_draw_region(feature, int(deep.level))
	if not hovered.is_empty():
		var feature := _lookup_visible_feature(hovered)
		if not feature.is_empty(): _draw_feature_outline(feature, Color("#fff0bd"), 2.2)
	for id in selected:
		var feature := _lookup_visible_feature(id)
		if not feature.is_empty(): _draw_feature_outline(feature, Color("#fff0bd"), 2.6)
	_draw_map_frame()

func _draw_graticule() -> void:
	for latitude in [-60, -30, 0, 30, 60]:
		var y := _project(Vector2(0, latitude)).y
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.36, 0.52, 0.58, 0.13), 1.0)
	for longitude in [-120, -60, 0, 60, 120]:
		var x := _project(Vector2(longitude, 0)).x
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.36, 0.52, 0.58, 0.12), 1.0)

func _draw_map_frame() -> void:
	var compass := load("res://assets/ui/compass_rose.svg")
	if compass is Texture2D:
		draw_texture_rect(compass, Rect2(Vector2(size.x - 68, 16), Vector2(48, 48)), false, Color(0.8, 0.85, 0.8, 0.82))
	var length := 100.0
	var y := size.y - 26.0
	draw_line(Vector2(20, y), Vector2(20 + length, y), Color("#d9bf82"), 2.0)
	draw_line(Vector2(20, y - 4), Vector2(20, y + 4), Color("#d9bf82"), 1.5)
	draw_line(Vector2(20 + length, y - 4), Vector2(20 + length, y + 4), Color("#d9bf82"), 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(20, y - 8), "WORLD ATLAS  •  %.1fx" % zoom, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b7c9c6"))
	if zoom >= 5.0:
		var code := hovered_country if not hovered_country.is_empty() else deep_country
		if not code.is_empty(): draw_string(ThemeDB.fallback_font, Vector2(20, 20), "DETAILED ADMINISTRATIVE MAP  •  " + code, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#e2cd95"))

func _draw_region(feature: Dictionary, level: int) -> void:
	var is_selected := selected.has(str(feature.id))
	var is_hovered := hovered == str(feature.id)
	var owned_here := owners.has(str(feature.id))
	if (is_selected or is_hovered or owned_here) and layer_flags.political:
		_draw_feature_fill(feature, _feature_color(feature, false).lightened(0.12 if is_selected else 0.04))
	if layer_flags.administrative or is_selected or is_hovered:
		var edge := Color("#728d8d", 0.56) if level == 1 else Color("#98a7a0", 0.42)
		if is_selected: edge = Color("#fff0bd")
		elif is_hovered: edge = Color("#f3d589")
		_draw_feature_outline(feature, edge, 1.15 if is_selected or is_hovered else (0.9 if level == 1 else 0.7))
	if layer_flags.labels and zoom >= 1.7 and zoom < 4.8:
		_draw_label(feature, 10 if level == 1 else 9, true)
	elif layer_flags.labels and (is_selected or is_hovered):
		_draw_label(feature, 11, true)

func _draw_feature_fill(feature: Dictionary, color: Color) -> void:
	for polygon_index in feature.polygons.size():
		var polygon: Array = feature.polygons[polygon_index]
		if polygon.is_empty(): continue
		var points: PackedVector2Array = polygon[0]
		if points.size() < 3: continue
		var screen_points := PackedVector2Array()
		for point in points: screen_points.append(_project(point))
		var cache_key := str(feature.id) + ":" + str(polygon_index)
		var triangles: PackedInt32Array = triangles_cache.get(cache_key, PackedInt32Array())
		if triangles.is_empty():
			triangles = Geometry2D.triangulate_polygon(points)
			triangles_cache[cache_key] = triangles
		for i in range(0, triangles.size(), 3):
			if triangles[i] >= screen_points.size() or triangles[i + 1] >= screen_points.size() or triangles[i + 2] >= screen_points.size(): continue
			var triangle := PackedVector2Array([screen_points[triangles[i]], screen_points[triangles[i + 1]], screen_points[triangles[i + 2]]])
			if absf((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])) < 0.0001: continue
			draw_primitive(triangle, PackedColorArray([color, color, color]), PackedVector2Array(), null)

func _draw_feature_outline(feature: Dictionary, color: Color, width: float) -> void:
	for polygon in feature.polygons:
		for ring in polygon:
			if ring.size() < 3: continue
			var points := PackedVector2Array()
			for point in ring: points.append(_project(point))
			if not points.is_empty():
				points.append(points[0])
				draw_polyline(points, color, width, true)

func _draw_label(feature: Dictionary, font_size: int, is_region: bool) -> void:
	var label := str(feature.get("name", ""))
	if label.is_empty(): return
	var point := _project(Vector2(float(feature.get("lon", 0)), float(feature.get("lat", 0))))
	if not Rect2(Vector2.ZERO, size).has_point(point): return
	var separation := 23.0 if not is_region else 17.0
	for existing in _label_points:
		if existing.distance_to(point) < separation: return
	_label_points.append(point)
	var font := ThemeDB.fallback_font
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, point + Vector2(-text_width * 0.5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#e5ece3"))

func _feature_color(feature: Dictionary, country_base: bool) -> Color:
	var id := str(feature.id)
	var country := str(feature.get("country_code", id))
	var owner := _owner_for(feature, country_base)
	if owner.begins_with("NEW_"):
		return Color(state_colors.get(owner, _color_for(owner)))
	return _color_for(owner)

func _owner_for(feature: Dictionary, country_base: bool = false) -> String:
	var id := str(feature.id)
	if owners.has(id): return str(owners[id])
	if country_base:
		var country := str(feature.get("country_code", id))
		return str(owners.get(country, country))
	var parent := str(feature.get("parent_id", ""))
	while not parent.is_empty():
		if owners.has(parent): return str(owners[parent])
		var parent_feature := WorldMapData.feature_by_id(parent)
		if parent_feature.is_empty(): break
		parent = str(parent_feature.get("parent_id", ""))
	var country := str(feature.get("country_code", id))
	return str(owners.get(country, country))

func _active_level() -> int:
	if zoom >= 3.6 and layers.has(2): return 2
	if zoom >= 1.55 and layers.has(1): return 1
	return 0

func _visible_world_bounds() -> Rect2:
	var a := _unproject(Vector2.ZERO)
	var b := _unproject(size)
	var left := minf(a.x, b.x); var top := minf(a.y, b.y)
	var right := maxf(a.x, b.x); var bottom := maxf(a.y, b.y)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))

func _features_in_view(features: Array, index: Dictionary) -> Array:
	if features.is_empty(): return []
	var world_bounds := _visible_world_bounds()
	var min_cell := _grid_cell(world_bounds.position)
	var max_cell := _grid_cell(world_bounds.end)
	var seen: Dictionary = {}
	var result: Array = []
	for feature_index in index.get(Vector2i(-1, -1), []):
		var feature: Dictionary = features[feature_index]
		if _bounds_intersect(feature.bounds, world_bounds): result.append(feature)
		seen[feature_index] = true
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			for feature_index in index.get(Vector2i(x, y), []):
				if seen.has(feature_index): continue
				seen[feature_index] = true
				var feature: Dictionary = features[feature_index]
				if _bounds_intersect(feature.bounds, world_bounds): result.append(feature)
	return result

func _build_spatial_index(features: Array) -> Dictionary:
	var result: Dictionary = {}
	for i in features.size():
		var bounds: Rect2 = features[i].bounds
		var first := _grid_cell(bounds.position)
		var last := _grid_cell(bounds.end)
		if last.x - first.x > 24 or last.y - first.y > 12:
			if not result.has(Vector2i(-1, -1)): result[Vector2i(-1, -1)] = []
			result[Vector2i(-1, -1)].append(i)
			continue
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var cell := Vector2i(x, y)
				if not result.has(cell): result[cell] = []
				result[cell].append(i)
	return result

func _grid_cell(point: Vector2) -> Vector2i:
	return Vector2i(clampi(floori((point.x + 180.0) / 10.0), 0, 35), clampi(floori((point.y + 90.0) / 10.0), 0, 17))

func _bounds_intersect(a: Rect2, b: Rect2) -> bool:
	return a.position.x <= b.end.x and a.end.x >= b.position.x and a.position.y <= b.end.y and a.end.y >= b.position.y

func _hit_test(point: Vector2) -> Dictionary:
	var level := _active_level()
	var country_at_point := _hit_features(point, countries, spatial_indices.get(0, {}), "")
	var code_at_point := str(country_at_point.get("country_code", ""))
	if zoom >= 5.0 and not code_at_point.is_empty() and deep_countries.has(code_at_point):
		var deep: Dictionary = deep_countries[code_at_point]
		var hit := _hit_features(point, deep.features, deep.index, code_at_point)
		if not hit.is_empty(): return hit
	var features: Array = layers.get(level, countries)
	var index: Dictionary = spatial_indices.get(level, {})
	var hit := _hit_features(point, features, index, code_at_point)
	if not hit.is_empty(): return hit
	return country_at_point

func _hit_features(point: Vector2, features: Array, index: Dictionary, preferred_country: String) -> Dictionary:
	var cell := _grid_cell(point)
	var candidates: Array = index.get(cell, []).duplicate()
	for candidate in index.get(Vector2i(-1, -1), []):
		if not candidates.has(candidate): candidates.append(candidate)
	for i in range(candidates.size() - 1, -1, -1):
		var feature: Dictionary = features[candidates[i]]
		if not preferred_country.is_empty() and str(feature.country_code) != preferred_country: continue
		if not feature.bounds.has_point(point): continue
		for polygon in feature.polygons:
			if polygon.is_empty() or not Geometry2D.is_point_in_polygon(point, polygon[0]): continue
			var in_hole := false
			for hole_index in range(1, polygon.size()):
				if Geometry2D.is_point_in_polygon(point, polygon[hole_index]): in_hole = true; break
			if not in_hole: return feature
	return {}

func _lookup_visible_feature(id: String) -> Dictionary:
	var code := hovered_country if not hovered_country.is_empty() else deep_country
	if zoom >= 5.0 and deep_countries.has(code):
		for feature in deep_countries[code].features:
			if str(feature.id) == id: return feature
	for level in [2, 1, 0]:
		for feature in layers.get(level, []):
			if str(feature.id) == id: return feature
	return {}

func _project(ll: Vector2) -> Vector2:
	var base := minf(size.x / 360.0, size.y / 180.0) * zoom
	return Vector2(size.x * 0.5 + (ll.x + pan.x) * base, size.y * 0.5 - (ll.y + pan.y) * base)

func _unproject(p: Vector2) -> Vector2:
	var base := minf(size.x / 360.0, size.y / 180.0) * zoom
	return Vector2((p.x - size.x * 0.5) / base - pan.x, -(p.y - size.y * 0.5) / base - pan.y)

func _color_for(key: String) -> Color:
	var h: int = absi(key.hash())
	return Color.from_hsv(float(h % 1000) / 1000.0, 0.42, 0.78)

func _request_deep_for_point(local_point: Vector2) -> void:
	if zoom < 5.0: return
	var country_feature := _hit_features(_unproject(local_point), countries, spatial_indices.get(0, {}), "")
	if country_feature.is_empty(): return
	var code := str(country_feature.country_code)
	if code == deep_country: return
	deep_country = code
	if not deep_countries.has(code) and not requested_deep.has(code):
		requested_deep[code] = true
		deep_layer_requested.emit(code)
	queue_redraw()

func _zoom_at(pos: Vector2, factor: float) -> void:
	var before := _unproject(pos)
	zoom = clampf(zoom * factor, 0.75, 9.0)
	var after := _unproject(pos)
	pan += after - before
	_request_deep_for_point(pos)
	zoom_changed.emit(zoom)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_origin = event.position
				pan_origin = pan
			else:
				dragging = false
				if event.position.distance_to(drag_origin) < 5.0:
					var hit := _hit_test(_unproject(event.position))
					if not hit.is_empty(): territory_clicked.emit(str(hit.id), event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.18)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.18)
	elif event is InputEventMouseMotion:
		if dragging:
			var base := minf(size.x / 360.0, size.y / 180.0) * zoom
			var delta: Vector2 = event.position - drag_origin
			pan = pan_origin + Vector2(delta.x, -delta.y) / base
			queue_redraw()
		else:
			var hit := _hit_test(_unproject(event.position))
			var next := str(hit.get("id", ""))
			var country := str(hit.get("country_code", ""))
			if next != hovered or country != hovered_country:
				hovered = next
				hovered_country = country
				_request_deep_for_point(event.position)
				queue_redraw()

func _on_selected_country() -> void:
	for id in selected:
		var feature := _lookup_visible_feature(id)
		if not feature.is_empty() and zoom >= 5.0: deep_country = str(feature.country_code)
	queue_redraw()
