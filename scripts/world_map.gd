extends Control
class_name WorldMap

signal territory_clicked(id: String, additive: bool)
signal city_clicked(city_id: String)
signal unit_clicked(unit_id: String)
signal unit_move_requested(unit_id: String, target_lon: float, target_lat: float, target_city: String, target_unit: String)
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
var layer_flags := {
	"political": true,
	"international": true,
	"administrative": true,
	"labels": true,
	"cities": true,
	"units": true
}
var spatial_indices: Dictionary = {}
var triangles_cache: Dictionary = {}
var requested_deep: Dictionary = {}
var _label_points: Array[Vector2] = []

# Cities and military units
var cities: Array = []
var units: Array = []
var selected_unit_id := ""
var selected_city_id := ""
var hovered_unit_id := ""
var hovered_city_id := ""
var last_mouse_pos := Vector2.ZERO

# Graphic Textures (European War / EasyTech Visual Style)
var tex_city_cluster: Texture2D
var tex_fort_bastion: Texture2D
var tex_flag_fra: Texture2D
var tex_flag_deu: Texture2D
var tex_flag_gen: Texture2D
var tex_infantry_squad: Texture2D
var tex_artillery_crew: Texture2D
var tex_cavalry_mounted: Texture2D
var tex_tank_armor: Texture2D
var tex_general_medallion: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_load_textures()

func _load_textures() -> void:
	tex_city_cluster = load("res://assets/cities/city_cluster.svg")
	tex_fort_bastion = load("res://assets/cities/fort_bastion.svg")
	tex_flag_fra = load("res://assets/cities/flagpole_france.svg")
	tex_flag_deu = load("res://assets/cities/flagpole_germany.svg")
	tex_flag_gen = load("res://assets/cities/flagpole_generic.svg")
	tex_infantry_squad = load("res://assets/military/infantry_squad.svg")
	tex_artillery_crew = load("res://assets/military/artillery_crew.svg")
	tex_cavalry_mounted = load("res://assets/military/cavalry_mounted.svg")
	tex_tank_armor = load("res://assets/military/tank_armor.svg")
	tex_general_medallion = load("res://assets/military/general_medallion.svg")

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

func set_cities(data: Array) -> void:
	cities = data
	queue_redraw()

func set_units(data: Array) -> void:
	units = data
	queue_redraw()

func select_unit(unit_id: String) -> void:
	selected_unit_id = unit_id
	selected_city_id = ""
	queue_redraw()

func select_city(city_id: String) -> void:
	selected_city_id = city_id
	selected_unit_id = ""
	queue_redraw()

func clear_entity_selection() -> void:
	selected_unit_id = ""
	selected_city_id = ""
	queue_redraw()

func _draw() -> void:
	var visible_rect := Rect2(Vector2.ZERO, size)
	draw_rect(visible_rect, Color("#091b26"))
	_draw_graticule()
	_label_points.clear()

	var country_index: Dictionary = spatial_indices.get(0, {})
	var country_view := _features_in_view(countries, country_index)
	for feature in country_view:
		var fill := _feature_color(feature, true)
		if not layer_flags.political: fill = Color("#527076")
		_draw_feature_fill(feature, fill)
		if layer_flags.international:
			_draw_feature_outline(feature, Color("#152d3a"), 1.25 if zoom < 2.5 else 1.8)
		if layer_flags.labels and zoom < 1.7:
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

	# Draw tactical map layers in true European War style:
	_draw_cities()
	_draw_unit_movement_range()
	_draw_units()

	_draw_map_frame()

func _draw_graticule() -> void:
	for latitude in [-60, -30, 0, 30, 60]:
		var y := _project(Vector2(0, latitude)).y
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.36, 0.52, 0.58, 0.10), 1.0)
	for longitude in [-120, -60, 0, 60, 120]:
		var x := _project(Vector2(longitude, 0)).x
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.36, 0.52, 0.58, 0.10), 1.0)

func _draw_map_frame() -> void:
	var compass := load("res://assets/ui/compass_rose.svg")
	if compass is Texture2D:
		draw_texture_rect(compass, Rect2(Vector2(size.x - 68, 16), Vector2(48, 48)), false, Color(0.8, 0.85, 0.8, 0.82))
	var length := 100.0
	var y := size.y - 26.0
	draw_line(Vector2(20, y), Vector2(20 + length, y), Color("#d9bf82"), 2.0)
	draw_line(Vector2(20, y - 4), Vector2(20, y + 4), Color("#d9bf82"), 1.5)
	draw_line(Vector2(20 + length, y - 4), Vector2(20 + length, y + 4), Color("#d9bf82"), 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(20, y - 8), "TACTICAL ATLAS  •  %.1fx" % zoom, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b7c9c6"))

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
	draw_string(font, point + Vector2(-text_width * 0.5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#e5ece3", 0.75))

# ==============================================================================
# EUROPEAN WAR STYLE: CITIES RENDERING
# ==============================================================================
func _draw_cities() -> void:
	if not layer_flags.get("cities", true): return
	var font := ThemeDB.fallback_font

	for city in cities:
		var pos := _project(Vector2(float(city.lon), float(city.lat)))
		if not Rect2(-Vector2(60, 60), size + Vector2(120, 120)).has_point(pos):
			continue

		var is_selected := str(city.id) == selected_city_id
		var is_hovered := str(city.id) == hovered_city_id
		var city_owner: String = str(city.get("owner", city.get("country_code", "")))
		var has_fort: bool = bool(city.get("has_fort", false))
		var tier_val: int = int(city.get("tier", 3))

		# 1. Selection / Hover halo on the terrain
		if is_selected:
			draw_circle(pos, 32.0, Color("#fff0bd", 0.45))
			draw_arc(pos, 32.0, 0, TAU, 32, Color("#ffe082"), 2.5)
		elif is_hovered:
			draw_circle(pos, 28.0, Color("#ffe082", 0.25))
			draw_arc(pos, 28.0, 0, TAU, 32, Color("#ffe082"), 1.8)

		# 2. 3D Isometric City Buildings Cluster
		var cluster_sz := Vector2(48, 36)
		var cluster_rect := Rect2(pos - Vector2(cluster_sz.x * 0.5, cluster_sz.y * 0.7), cluster_sz)
		if tex_city_cluster != null:
			draw_texture_rect(tex_city_cluster, cluster_rect, false)

		# 3. Vauban Star Fort / Bastion (if fortified)
		if has_fort and tex_fort_bastion != null:
			var fort_sz := Vector2(38, 30)
			var fort_pos := pos + Vector2(18, -12)
			draw_texture_rect(tex_fort_bastion, Rect2(fort_pos, fort_sz), false)

		# 4. Flying National Flagpole on top-left of the city
		var flag_tex := _flag_texture_for_country(city_owner)
		if flag_tex != null:
			var flag_sz := Vector2(24, 28)
			var flag_pos := pos + Vector2(-cluster_sz.x * 0.5 - 6, -cluster_sz.y * 0.9)
			draw_texture_rect(flag_tex, Rect2(flag_pos, flag_sz), false)

		# 5. Bold City Name (crisp white with deep black drop-shadow like in screenshot)
		var name_str: String = str(city.name).to_upper()
		var font_size := 12
		var name_w := font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var name_pos := Vector2(pos.x - name_w * 0.5, pos.y + 16)

		# Multiple shadow offsets for rich outline effect
		for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(0, 2)]:
			draw_string(font, name_pos + off, name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#000000"))
		draw_string(font, name_pos, name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#ffffff"))

		# 6. Roman Numeral Tier below City Name (e.g. II, IV, V)
		var roman_str: String = MilitarySystem.roman_numeral(tier_val)
		var roman_sz := 11
		var roman_w := font.get_string_size(roman_str, HORIZONTAL_ALIGNMENT_LEFT, -1, roman_sz).x
		var roman_pos := Vector2(pos.x - roman_w * 0.5, name_pos.y + 14)

		for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_string(font, roman_pos + off, roman_str, HORIZONTAL_ALIGNMENT_LEFT, -1, roman_sz, Color("#000000"))
		draw_string(font, roman_pos, roman_str, HORIZONTAL_ALIGNMENT_LEFT, -1, roman_sz, Color("#f1f2f6"))

		# 7. Circular city production / garrison badge below Roman numeral
		var badge_pos := Vector2(pos.x, roman_pos.y + 12)
		draw_circle(badge_pos, 7.0, Color("#1e272e"))
		var badge_color := _color_for(city_owner)
		if state_colors.has(city_owner): badge_color = Color(state_colors[city_owner])
		draw_circle(badge_pos, 5.5, badge_color)
		draw_arc(badge_pos, 5.5, 0, TAU, 16, Color("#ffffff", 0.6), 1.0)

func _flag_texture_for_country(country_code: String) -> Texture2D:
	var code := country_code.to_upper()
	match code:
		"FRA": return tex_flag_fra
		"DEU": return tex_flag_deu
		_: return tex_flag_gen

# ==============================================================================
# EUROPEAN WAR STYLE: MILITARY UNITS RENDERING
# ==============================================================================
func _draw_units() -> void:
	if not layer_flags.get("units", true): return
	var font := ThemeDB.fallback_font
	var groups := _group_units_by_proximity()

	for unit in units:
		var pos := _project(Vector2(float(unit.lon), float(unit.lat)))
		var offset: Vector2 = groups.get(str(unit.id), Vector2.ZERO)
		var center := pos + offset
		if not Rect2(-Vector2(60, 60), size + Vector2(120, 120)).has_point(center):
			continue

		var is_selected := str(unit.id) == selected_unit_id
		var is_hovered := str(unit.id) == hovered_unit_id
		var unit_owner: String = str(unit.owner)
		var is_player: bool = unit_owner == owners.get("player_id", "FRA")
		var has_gen: bool = bool(unit.get("has_general", false))
		var rank_val: int = int(unit.get("rank", 4))
		var chevrons_val: int = int(unit.get("chevrons", 1))

		# 1. Circular Ground Base / Tactile Disc under feet (Red for enemy, Blue for player)
		var base_color := Color("#0984e3", 0.40) if is_player else Color("#e74c3c", 0.45)
		var border_color := Color("#74b9ff") if is_player else Color("#ff7675")
		if is_selected:
			base_color = Color("#f1c40f", 0.55)
			border_color = Color("#ffeaa7")

		draw_circle(center + Vector2(0, 18), 26.0, base_color)
		draw_arc(center + Vector2(0, 18), 26.0, 0, TAU, 32, border_color, 2.2 if is_selected else 1.5)

		# 2. Detailed Military Figurine (Soldiers / Artillery Crew / Cavalry / Armor)
		var unit_tex := _texture_for_unit(str(unit.type))
		if unit_tex != null:
			var sprite_sz := Vector2(56, 50)
			var sprite_rect := Rect2(center - Vector2(sprite_sz.x * 0.5, sprite_sz.y * 0.7), sprite_sz)
			draw_texture_rect(unit_tex, sprite_rect, false)

		# 3. Flying National Flag on Pole next to division
		var flag_tex := _flag_texture_for_country(unit_owner)
		if flag_tex != null:
			var flag_sz := Vector2(20, 24)
			var flag_pos := center + Vector2(-28, -22)
			draw_texture_rect(flag_tex, Rect2(flag_pos, flag_sz), false)

		# 4. General / Commander Medallion floating above division (Napoleon / Blücher style)
		if has_gen and tex_general_medallion != null:
			var med_sz := Vector2(28, 28)
			var med_pos := center + Vector2(-med_sz.x * 0.5, -44)
			draw_texture_rect(tex_general_medallion, Rect2(med_pos, med_sz), false)
			# Connecting staff/pin to unit
			draw_line(med_pos + Vector2(med_sz.x * 0.5, med_sz.y), center + Vector2(0, -16), Color("#f1c40f"), 1.5)

		# 5. Golden Veterancy Chevrons (^^) over unit
		if chevrons_val > 0:
			var chev_y := center.y - (32.0 if not has_gen else 46.0)
			for c_idx in range(chevrons_val):
				var chev_pos := Vector2(center.x + 14 + (c_idx * 5), chev_y)
				draw_polyline(PackedVector2Array([chev_pos + Vector2(-3, 3), chev_pos, chev_pos + Vector2(3, 3)]), Color("#f1c40f"), 2.0)

		# 6. Circular Tactical Badge at the base (Weapon symbol & Roman numeral)
		var badge_pos := center + Vector2(0, 24)
		var b_color := Color("#1e3799") if is_player else Color("#c0392b")
		var b_rim := Color("#dcdde1") if not is_selected else Color("#f1c40f")

		draw_circle(badge_pos, 10.0, Color("#111111"))
		draw_circle(badge_pos, 8.5, b_color)
		draw_arc(badge_pos, 8.5, 0, TAU, 24, b_rim, 1.8)

		# Weapon emblem inside badge
		_draw_weapon_glyph(badge_pos, str(unit.type))

		# Roman Numeral under the tactical badge (e.g. II, IV, V, VII)
		var r_num := MilitarySystem.roman_numeral(rank_val)
		var r_sz := 10
		var r_w := font.get_string_size(r_num, HORIZONTAL_ALIGNMENT_LEFT, -1, r_sz).x
		var r_pos := Vector2(badge_pos.x - r_w * 0.5, badge_pos.y + 15)
		for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_string(font, r_pos + off, r_num, HORIZONTAL_ALIGNMENT_LEFT, -1, r_sz, Color("#000000"))
		draw_string(font, r_pos, r_num, HORIZONTAL_ALIGNMENT_LEFT, -1, r_sz, Color("#ffffff"))

		# 7. Unit Health / HP Bar
		var hp_bar_w := 24.0
		var hp_bar_h := 3.2
		var hp_ratio := clampf(float(unit.hp) / maxf(1.0, float(unit.max_hp)), 0.0, 1.0)
		var bar_rect := Rect2(badge_pos.x - hp_bar_w * 0.5, badge_pos.y + 18, hp_bar_w, hp_bar_h)
		draw_rect(bar_rect, Color("#111"))
		var hp_col := Color("#2ecc71")
		if hp_ratio < 0.35: hp_col = Color("#e74c3c")
		elif hp_ratio < 0.65: hp_col = Color("#f39c12")
		draw_rect(Rect2(bar_rect.position.x, bar_rect.position.y, hp_bar_w * hp_ratio, hp_bar_h), hp_col)

		# Movement readiness indicator dot
		var mp_ready: bool = int(unit.mp) > 0
		var mp_pos := badge_pos + Vector2(10, -7)
		draw_circle(mp_pos, 3.5, Color("#111"))
		draw_circle(mp_pos, 2.5, Color("#2ecc71") if mp_ready else Color("#7f8c8d"))

		# Unit Name Banner on Hover or Selection
		if is_selected or is_hovered:
			var gen_prefix := ("★ " + str(unit.general_name) + " — ") if has_gen and not str(unit.get("general_name", "")).is_empty() else ""
			var tag_text := "%s%s (%d HP)" % [gen_prefix, str(unit.name), int(unit.hp)]
			var tag_w := font.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var tag_rect := Rect2(center.x - tag_w * 0.5 - 6, center.y - 56, tag_w + 12, 16)
			draw_rect(tag_rect, Color(0.06, 0.12, 0.18, 0.92))
			draw_rect(tag_rect, Color("#f1c40f"), false, 1.0)
			draw_string(font, Vector2(center.x - tag_w * 0.5, center.y - 43), tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffffff"))

func _draw_weapon_glyph(pos: Vector2, type: String) -> void:
	match type:
		"artillery":
			# Mini cannon tube
			draw_line(pos + Vector2(-4, 2), pos + Vector2(4, -2), Color("#ffffff"), 2.0)
			draw_circle(pos + Vector2(-1, 1), 2.0, Color("#ffffff"))
		"cavalry":
			# Mini horse / saber
			draw_line(pos + Vector2(-3, 3), pos + Vector2(3, -3), Color("#ffffff"), 1.8)
			draw_line(pos + Vector2(-1, 4), pos + Vector2(2, 1), Color("#ffffff"), 1.8)
		"armor":
			# Mini tank rectangle
			draw_rect(Rect2(pos - Vector2(4, 2), Vector2(8, 4)), Color("#ffffff"))
			draw_line(pos + Vector2(0, 0), pos + Vector2(5, 0), Color("#ffffff"), 1.5)
		_:
			# Infantry: Crossed rifles
			draw_line(pos + Vector2(-3, -3), pos + Vector2(3, 3), Color("#ffffff"), 1.8)
			draw_line(pos + Vector2(3, -3), pos + Vector2(-3, 3), Color("#ffffff"), 1.8)

func _draw_unit_movement_range() -> void:
	if selected_unit_id.is_empty(): return
	var unit := _lookup_unit(selected_unit_id)
	if unit.is_empty(): return
	var unit_pos := _project(Vector2(float(unit.lon), float(unit.lat)))

	if int(unit.mp) > 0:
		var range_deg := 6.5
		if unit.type == "cavalry" or unit.type == "armor": range_deg = 9.0
		elif unit.type == "artillery": range_deg = 4.5
		var base := minf(size.x / 360.0, size.y / 180.0) * zoom
		var pixel_radius := range_deg * base * 0.9
		draw_arc(unit_pos, pixel_radius, 0, TAU, 48, Color("#ffe082", 0.4), 1.6)
		draw_circle(unit_pos, pixel_radius, Color("#ffe082", 0.05))

	if last_mouse_pos != Vector2.ZERO and Rect2(Vector2.ZERO, size).has_point(last_mouse_pos):
		var target_color := Color("#ffe082", 0.85)
		var is_attack := false
		if not hovered_unit_id.is_empty() and hovered_unit_id != selected_unit_id:
			var target_u := _lookup_unit(hovered_unit_id)
			if str(target_u.get("owner", "")) != str(unit.get("owner", "")):
				target_color = Color("#f44336", 0.95)
				is_attack = true
		elif not hovered_city_id.is_empty():
			var target_c := _lookup_city(hovered_city_id)
			if str(target_c.get("owner", target_c.get("country_code", ""))) != str(unit.get("owner", "")):
				target_color = Color("#ff9800", 0.95)

		draw_dashed_line(unit_pos, last_mouse_pos, target_color, 2.2, 6.0)
		draw_circle(last_mouse_pos, 5.0, target_color)
		if is_attack:
			draw_arc(last_mouse_pos, 12.0, 0, TAU, 24, target_color, 2.0)

func _texture_for_unit(type: String) -> Texture2D:
	match type:
		"artillery": return tex_artillery_crew
		"cavalry": return tex_cavalry_mounted
		"armor": return tex_tank_armor
		_: return tex_infantry_squad

func _group_units_by_proximity() -> Dictionary:
	var offsets: Dictionary = {}
	var clusters: Dictionary = {}
	for u in units:
		var key := "%d_%d" % [roundi(float(u.lon) * 2.5), roundi(float(u.lat) * 2.5)]
		if not clusters.has(key): clusters[key] = []
		clusters[key].append(str(u.id))
	for key in clusters:
		var list: Array = clusters[key]
		if list.size() > 1:
			for i in list.size():
				var angle := (float(i) / float(list.size())) * TAU
				var dist := 22.0 if list.size() <= 3 else 26.0
				offsets[list[i]] = Vector2(cos(angle), sin(angle)) * dist
	return offsets

# ==============================================================================
# SPATIAL & HIT TESTING
# ==============================================================================
func _feature_color(feature: Dictionary, country_base: bool) -> Color:
	var id := str(feature.id)
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

func _hit_unit(mouse_pos: Vector2) -> Dictionary:
	if not layer_flags.get("units", true): return {}
	var groups := _group_units_by_proximity()
	for i in range(units.size() - 1, -1, -1):
		var u: Dictionary = units[i]
		var offset: Vector2 = groups.get(str(u.id), Vector2.ZERO)
		var center := _project(Vector2(float(u.lon), float(u.lat))) + offset
		if mouse_pos.distance_to(center + Vector2(0, 10)) <= 25.0:
			return u
	return {}

func _hit_city(mouse_pos: Vector2) -> Dictionary:
	if not layer_flags.get("cities", true): return {}
	for i in range(cities.size() - 1, -1, -1):
		var c: Dictionary = cities[i]
		var center := _project(Vector2(float(c.lon), float(c.lat)))
		if mouse_pos.distance_to(center) <= 26.0:
			return c
	return {}

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

func _lookup_unit(unit_id: String) -> Dictionary:
	for u in units:
		if str(u.id) == unit_id: return u
	return {}

func _lookup_city(city_id: String) -> Dictionary:
	for c in cities:
		if str(c.id) == city_id: return c
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
				if event.position.distance_to(drag_origin) < 6.0:
					_handle_click(event.position, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.18)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.18)
	elif event is InputEventMouseMotion:
		last_mouse_pos = event.position
		if dragging:
			var base := minf(size.x / 360.0, size.y / 180.0) * zoom
			var delta: Vector2 = event.position - drag_origin
			pan = pan_origin + Vector2(delta.x, -delta.y) / base
			queue_redraw()
		else:
			var prev_u := hovered_unit_id
			var prev_c := hovered_city_id
			var hit_u := _hit_unit(event.position)
			var hit_c := _hit_city(event.position)
			hovered_unit_id = str(hit_u.get("id", ""))
			hovered_city_id = str(hit_c.get("id", ""))

			var hit := _hit_test(_unproject(event.position))
			var next := str(hit.get("id", ""))
			var country := str(hit.get("country_code", ""))
			if next != hovered or country != hovered_country or prev_u != hovered_unit_id or prev_c != hovered_city_id:
				hovered = next
				hovered_country = country
				_request_deep_for_point(event.position)
				queue_redraw()
			elif not selected_unit_id.is_empty():
				queue_redraw()

func _handle_click(pos: Vector2, shift_pressed: bool) -> void:
	# Priority 1: Military Unit Click
	var clicked_unit := _hit_unit(pos)
	if not clicked_unit.is_empty():
		if not selected_unit_id.is_empty() and selected_unit_id != str(clicked_unit.id):
			var sel := _lookup_unit(selected_unit_id)
			if not sel.is_empty() and str(sel.owner) != str(clicked_unit.owner):
				# Attack enemy unit
				unit_move_requested.emit(selected_unit_id, float(clicked_unit.lon), float(clicked_unit.lat), "", str(clicked_unit.id))
				return
		selected_unit_id = str(clicked_unit.id)
		selected_city_id = ""
		unit_clicked.emit(selected_unit_id)
		queue_redraw()
		return

	# Priority 2: City Click
	var clicked_city := _hit_city(pos)
	if not clicked_city.is_empty():
		if not selected_unit_id.is_empty():
			var sel := _lookup_unit(selected_unit_id)
			if not sel.is_empty() and int(sel.mp) > 0:
				unit_move_requested.emit(selected_unit_id, float(clicked_city.lon), float(clicked_city.lat), str(clicked_city.id), "")
				return
		selected_city_id = str(clicked_city.id)
		selected_unit_id = ""
		city_clicked.emit(selected_city_id)
		queue_redraw()
		return

	# Priority 3: Unit movement to open coordinates
	if not selected_unit_id.is_empty() and not shift_pressed:
		var sel := _lookup_unit(selected_unit_id)
		if not sel.is_empty() and int(sel.mp) > 0:
			var world_pt := _unproject(pos)
			unit_move_requested.emit(selected_unit_id, world_pt.x, world_pt.y, "", "")
			return
		selected_unit_id = ""
		queue_redraw()

	# Priority 4: Territory Selection
	var hit := _hit_test(_unproject(pos))
	if not hit.is_empty():
		selected_unit_id = ""
		selected_city_id = ""
		territory_clicked.emit(str(hit.id), shift_pressed)

func _handle_right_click(pos: Vector2) -> void:
	if selected_unit_id.is_empty(): return
	var clicked_unit := _hit_unit(pos)
	var clicked_city := _hit_city(pos)
	var world_pt := _unproject(pos)
	if not clicked_unit.is_empty():
		unit_move_requested.emit(selected_unit_id, float(clicked_unit.lon), float(clicked_unit.lat), "", str(clicked_unit.id))
	elif not clicked_city.is_empty():
		unit_move_requested.emit(selected_unit_id, float(clicked_city.lon), float(clicked_city.lat), str(clicked_city.id), "")
	else:
		unit_move_requested.emit(selected_unit_id, world_pt.x, world_pt.y, "", "")
