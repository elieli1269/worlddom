extends Control

const MapView = preload("res://scripts/world_map.gd")
const MapData = preload("res://scripts/map_data.gd")
const FlagView = preload("res://scripts/nation_flag.gd")
const SAVE_DIR := "user://saves"
const BG := Color("#091925")
const PANEL := Color("#102431")
const PANEL_ALT := Color("#162f3d")
const GOLD := Color("#d9b56c")
const MUTED := Color("#91a6ad")

var world: Array = []
var state := {}
var map_view: WorldMap
var info_label: Label
var header_label: Label
var selection_label: Label
var country_option: OptionButton
var current_panel: PanelContainer
var loaded_levels: Dictionary = {0: true}

func _ready() -> void:
	get_tree().root.content_scale_size = Vector2i(1440, 900)
	_load_world()
	_show_title()

func _load_world() -> void:
	world = MapData.load_layer(0)

func _show_title() -> void:
	_clear()
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/ui/menu_atlas.svg")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var shade := ColorRect.new(); shade.color = Color(0.015, 0.035, 0.05, 0.33); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var root := VBoxContainer.new()
	root.position = Vector2(104, 90)
	root.size = Vector2(590, 720)
	root.add_theme_constant_override("separation", 13)
	add_child(root)
	var eyebrow := _label("GRAND STRATEGY  •  1936 CAMPAIGN", 14, GOLD)
	root.add_child(eyebrow)
	var seal := TextureRect.new(); seal.texture = load("res://assets/ui/crown_seal.svg"); seal.custom_minimum_size = Vector2(58, 58); seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; root.add_child(seal)
	var title := _label("WORLD\nDOMINION", 58, Color("#f4ead3"))
	root.add_child(title)
	var sub := _label("Shape borders. Build nations. Rewrite history.", 17, MUTED)
	root.add_child(sub)
	var rule := _panel(PANEL_ALT); rule.custom_minimum_size.y = 2; root.add_child(rule)
	var start := _button("BEGIN NEW CAMPAIGN")
	root.add_child(start)
	root.add_child(_label("Choose the nation you will lead", 14, MUTED))
	country_option = OptionButton.new()
	country_option.custom_minimum_size.y = 44
	country_option.add_theme_font_size_override("font_size", 17)
	country_option.add_theme_color_override("font_color", Color("#f1e8d4"))
	country_option.add_theme_stylebox_override("normal", _style(PANEL_ALT, GOLD))
	var default_index := 0
	for i in world.size():
		country_option.add_item(world[i].name)
		if world[i].id == "FRA": default_index = i
	country_option.select(default_index)
	root.add_child(country_option)
	var resume := _button("LOAD A SAVE")
	root.add_child(resume)
	var quit := _button("QUIT")
	root.add_child(quit)
	root.add_child(_label("WORLD DOMINION  •  FIELD EDITION 0.1", 11, Color("#9a8b6c")))
	start.pressed.connect(_new_game)
	resume.pressed.connect(_show_saves)
	quit.pressed.connect(func(): get_tree().quit())

func _new_game() -> void:
	var idx := country_option.selected
	var chosen: Dictionary = world[idx]
	var owners := {}
	var countries := {}
	for f in world:
		owners[f.id] = f.id
		countries[f.id] = {"id": f.id, "name": f.name, "budget": 100.0 + (abs(f.id.hash()) % 180), "population": 2.0 + (abs(f.id.hash()) % 400), "stability": 70, "government": "Republic", "color": Color.from_hsv(float(abs(f.id.hash()) % 100) / 100.0, 0.45, 0.78).to_html(false)}
	state = {"turn": 1, "year": 1936, "player": chosen.id, "owners": owners, "countries": countries, "statuses": {}, "alliances": [], "logs": ["La campagne commence. L'avenir est à écrire."], "next_state": 1}
	_show_game()

func _show_game() -> void:
	_clear()
	var backdrop := ColorRect.new(); backdrop.color = BG; backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(backdrop)
	var top := _panel(PANEL); top.add_theme_stylebox_override("panel", _style(PANEL, Color("#294451"))); var top_style: StyleBoxFlat = top.get_theme_stylebox("panel").duplicate(); top_style.content_margin_top = 3; top_style.content_margin_bottom = 3; top.add_theme_stylebox_override("panel", top_style); top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); top.offset_bottom = 64; add_child(top)
	var bar := HBoxContainer.new(); bar.add_theme_constant_override("separation", 18); bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(bar)
	var compass := TextureRect.new(); compass.texture = load("res://assets/ui/compass_rose.svg"); compass.custom_minimum_size = Vector2(38, 38); compass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; compass.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; bar.add_child(compass)
	var brand := _label("◆  WORLD DOMINION", 19, GOLD); bar.add_child(brand)
	header_label = _label("", 16, Color("#e9e4d7")); header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bar.add_child(header_label)
	var save_btn := _button("SAVE"); save_btn.pressed.connect(_save_dialog); bar.add_child(save_btn)
	var layers_btn := _button("LAYERS"); bar.add_child(layers_btn)
	var layers_popup := PopupMenu.new(); layers_popup.add_check_item("Political colors", 0); layers_popup.add_check_item("International borders", 1); layers_popup.add_check_item("Administrative limits", 2); layers_popup.add_check_item("Country and region names", 3)
	for item_id in range(4): layers_popup.set_item_checked(item_id, true)
	add_child(layers_popup); layers_btn.pressed.connect(func(): layers_popup.position = Vector2i(layers_btn.global_position + Vector2(0, layers_btn.size.y)); layers_popup.popup())
	layers_popup.id_pressed.connect(func(id: int): layers_popup.set_item_checked(id, not layers_popup.is_item_checked(id)); map_view.set_layers({["political", "international", "administrative", "labels"][id]: layers_popup.is_item_checked(id)}) )
	var menu_btn := _button("MENU"); menu_btn.pressed.connect(_show_title); bar.add_child(menu_btn)
	var body := HBoxContainer.new(); body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); body.offset_top = 64; body.offset_bottom = -36; body.add_theme_constant_override("separation", 0); add_child(body)
	var left := _panel(PANEL); left.custom_minimum_size.x = 250; body.add_child(left)
	var leftscroll := ScrollContainer.new(); leftscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; leftscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; left.add_child(leftscroll)
	var leftbox := VBoxContainer.new(); leftbox.add_theme_constant_override("separation", 10); leftbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL; leftscroll.add_child(leftbox)
	leftbox.add_child(_label("NATION OVERVIEW", 13, GOLD))
	var player_flag := _nation_flag(state.player); leftbox.add_child(player_flag)
	info_label = _label("", 15, Color("#e9e4d7")); info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL; leftbox.add_child(info_label)
	var diplomacy := _button("DIPLOMACY"); diplomacy.pressed.connect(func(): _notice("Diplomacy", "International relations are developing.")); leftbox.add_child(diplomacy)
	var economy := _button("ECONOMY"); economy.pressed.connect(func(): _notice("National economy", "Build infrastructure and manage the national budget.")); leftbox.add_child(economy)
	var military := _button("MILITARY"); military.pressed.connect(func(): _notice("Armed forces", "Strategic units will be added in a later campaign update.")); leftbox.add_child(military)
	var center := VBoxContainer.new(); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; center.add_theme_constant_override("separation", 0); body.add_child(center)
	var map_frame := PanelContainer.new(); map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL; map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL; map_frame.add_theme_stylebox_override("panel", _style(Color("#071521"), Color("#294451"))); center.add_child(map_frame)
	map_view = MapView.new(); map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL; map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL; map_view.load_world(world); map_view.set_owners(state.owners); map_view.set_state_colors(_state_color_table()); map_view.territory_clicked.connect(_on_territory_clicked); map_view.deep_layer_requested.connect(_load_deep_layer); map_view.zoom_changed.connect(_on_zoom_changed); map_frame.add_child(map_view)
	var bottom := _panel(PANEL); bottom.custom_minimum_size.y = 54; center.add_child(bottom)
	var tools := HBoxContainer.new(); tools.add_theme_constant_override("separation", 9); bottom.add_child(tools)
	selection_label = _label("Select territories • Shift-click to add or remove", 14, MUTED); selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tools.add_child(selection_label)
	var create := _button("FOUND NEW STATE"); create.pressed.connect(_create_state_dialog); tools.add_child(create)
	var next := _button("END TURN  ▶"); next.add_theme_stylebox_override("normal", _style(Color("#604b2c"), GOLD)); next.pressed.connect(_next_turn); tools.add_child(next)
	var right := _panel(PANEL); right.custom_minimum_size.x = 275; body.add_child(right)
	var rightscroll := ScrollContainer.new(); rightscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; rightscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right.add_child(rightscroll)
	var rbox := VBoxContainer.new(); rbox.add_theme_constant_override("separation", 12); rbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rightscroll.add_child(rbox)
	rbox.add_child(_label("TERRITORY DOSSIER", 13, GOLD))
	var detail := _label("Click a country to inspect it.\n\nHold Shift and click to assemble a new state from multiple territories.\n\nWheel: zoom\nDrag: pan", 15, Color("#d8e0de")); detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; detail.size_flags_vertical = Control.SIZE_EXPAND_FILL; rbox.add_child(detail)
	var annex := _button("ANNEX FOR PLAYER"); annex.pressed.connect(func(): _set_selected_owner(state.player, "annexed")); rbox.add_child(annex)
	var occupy := _button("PLACE UNDER OCCUPATION"); occupy.pressed.connect(func(): _set_selected_owner(state.player, "occupied")); rbox.add_child(occupy)
	var release := _button("RESTORE ORIGINAL OWNER"); release.pressed.connect(_restore_selected); rbox.add_child(release)
	var eventlog := _label("LATEST  •  " + str(state.logs.back()), 12, MUTED); eventlog.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); eventlog.offset_top = -36; eventlog.custom_minimum_size.y = 36; add_child(eventlog)
	_refresh_header()
	map_view.set_meta("detail", detail)
	map_view.territory_clicked.connect(func(id, _add): _show_region_detail(id, detail))
	update_overview()

func _on_territory_clicked(id: String, additive: bool) -> void:
	if not additive: map_view.selected.clear()
	if map_view.selected.has(id): map_view.selected.erase(id)
	else: map_view.selected.append(id)
	map_view.selected = map_view.selected
	map_view.queue_redraw()
	selection_label.text = "%d territory selected" % map_view.selected.size()

func _show_region_detail(id: String, detail: Label) -> void:
	var f: Dictionary = _feature(id)
	var owner := _owner_of(id, f)
	var c: Dictionary = state.countries.get(owner, {"name": f.name, "budget": 0, "population": 0, "stability": 50, "government": "Unknown"})
	var status := str(state.statuses.get(id, "National territory"))
	var metadata: Dictionary = MapData.metadata_for(str(f.get("country_code", id)), int(f.get("admin_level", 0)))
	var boundary_source := "geoBoundaries gbOpen · date varies by source"
	if not metadata.is_empty(): boundary_source = "geoBoundaries gbOpen · reference %s · source updated %s" % [str(metadata.get("year", "unknown")), str(metadata.get("source_updated", "unknown"))]
	detail.text = "%s\n\nOwner: %s\nStatus: %s\nPopulation: %.1f M\nTreasury: %.0f¤\nStability: %d%%\n\nBoundary: %s\n\nSelect several territories with Shift-click, then found a new state." % [f.get("name", id), c.name, status, float(c.population), float(c.budget), int(c.stability), boundary_source]

func _set_selected_owner(owner: String, status: String) -> void:
	if map_view.selected.is_empty(): return
	for id in map_view.selected:
		state.owners[id] = owner
		state.statuses[id] = status.capitalize()
	state.logs.append("%d territories placed under %s." % [map_view.selected.size(), status])
	map_view.set_owners(state.owners); update_overview(); _refresh_header()

func _restore_selected() -> void:
	for id in map_view.selected:
		var f := _feature(id)
		if int(f.get("admin_level", 0)) == 0: state.owners[id] = id
		else: state.owners.erase(id)
		state.statuses.erase(id)
	map_view.set_owners(state.owners); update_overview()

func _create_state_dialog() -> void:
	if map_view.selected.is_empty(): _notice("No territory selected", "Select one or more territories on the map first."); return
	var dialog := ConfirmationDialog.new(); dialog.title = "Found a new state"; dialog.ok_button_text = "FOUND STATE"
	var form := VBoxContainer.new(); form.custom_minimum_size.x = 390; dialog.add_child(form)
	form.add_child(_label("The selected territories will become a new sovereign country.", 13, MUTED))
	var name_input := LineEdit.new(); name_input.placeholder_text = "State name"; name_input.text = "New Republic"; form.add_child(name_input)
	var gov := OptionButton.new(); gov.add_item("Republic"); gov.add_item("Constitutional Monarchy"); gov.add_item("Federation"); gov.add_item("People's Republic"); form.add_child(gov)
	var relation := OptionButton.new(); relation.add_item("Friendly ally"); relation.add_item("Autonomous partner"); relation.add_item("Neutral sovereign"); form.add_child(relation)
	var color_picker := ColorPickerButton.new(); color_picker.color = Color("#59a6bd"); color_picker.custom_minimum_size = Vector2(120, 38); form.add_child(color_picker)
	add_child(dialog)
	dialog.confirmed.connect(func():
		if name_input.text.strip_edges().is_empty(): return
		var new_id := "NEW_%03d" % int(state.next_state); state.next_state += 1
		var player_country: Dictionary = state.countries[state.player]
		var new_country := {"id": new_id, "name": name_input.text.strip_edges(), "budget": 30.0 * map_view.selected.size(), "population": 0.0, "stability": 62, "government": gov.get_item_text(gov.selected), "color": color_picker.color.to_html(false), "relation": relation.get_item_text(relation.selected), "creator": state.player}
		state.countries[new_id] = new_country
		for id in map_view.selected:
			state.owners[id] = new_id; state.statuses[id] = "Independent state"; new_country.population += float(_country_for(id).get("population", 20))
		state.logs.append("%s declared independence across %d territories." % [new_country.name, map_view.selected.size()])
		map_view.set_owners(state.owners); map_view.set_state_colors(_state_color_table()); update_overview(); _refresh_header(); dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

func _next_turn() -> void:
	state.turn += 1
	if state.turn > 12: state.turn = 1; state.year += 1
	for id in state.countries:
		var c: Dictionary = state.countries[id]
		var territory_count := 0
		for owner in state.owners.values():
			if owner == id: territory_count += 1
		var variation := float((abs((id + str(state.turn)).hash()) % 17) - 6) / 100.0
		c.budget = maxf(0, float(c.budget) + territory_count * 1.8 + variation * float(c.budget))
		c.stability = clampi(int(c.stability) + (1 if c.budget > 20 else -2), 10, 99)
	state.logs.append("Turn %d complete. National revenues and stability updated." % state.turn)
	_refresh_header(); update_overview()

func _refresh_header() -> void:
	if not is_instance_valid(header_label): return
	var c: Dictionary = state.countries[state.player]
	header_label.text = "%s     •     TURN %02d     •     %d     •     TREASURY  %.0f¤" % [c.name.to_upper(), state.turn, state.year, c.budget]

func update_overview() -> void:
	if not is_instance_valid(info_label): return
	var c: Dictionary = state.countries[state.player]
	var count := 0
	for owner in state.owners.values():
		if owner == state.player: count += 1
	info_label.text = "%s\n%s\n\nNATIONAL TREASURY\n%.0f¤\n\nPOPULATION\n%.1f million\n\nTERRITORIES\n%d\n\nSTABILITY\n%d%%\n\nGOVERNMENT\n%s\n\n────────────────\nCampaign year %d" % [c.name.to_upper(), "PLAYER NATION", c.budget, c.population, count, c.stability, c.government, state.year]

func _save_dialog() -> void:
	var d := ConfirmationDialog.new(); d.title = "Save campaign"; d.ok_button_text = "SAVE"
	var input := LineEdit.new(); input.text = "Campaign %d" % state.year; input.custom_minimum_size.x = 300; d.add_child(input); add_child(d)
	d.confirmed.connect(func(): _save_game(input.text.strip_edges()); d.queue_free())
	d.canceled.connect(func(): d.queue_free())
	d.popup_centered()

func _save_game(name: String) -> void:
	if name.is_empty(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var safe := name.validate_filename()
	var f := FileAccess.open(SAVE_DIR.path_join(safe + ".json"), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(state, "\t")); f.close()
	_notice("Campaign saved", name)

func _show_saves() -> void:
	_clear()
	var bg := ColorRect.new(); bg.color = BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var box := VBoxContainer.new(); box.position = Vector2(350, 110); box.size = Vector2(740, 680); box.add_theme_constant_override("separation", 12); add_child(box)
	box.add_child(_label("CAMPAIGN ARCHIVE", 32, GOLD))
	var listing := ItemList.new(); listing.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(listing)
	var path := ProjectSettings.globalize_path(SAVE_DIR); DirAccess.make_dir_recursive_absolute(path)
	var dir := DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if file.ends_with(".json"): listing.add_item(file.trim_suffix(".json"))
			file = dir.get_next()
	var actions := HBoxContainer.new(); box.add_child(actions)
	var load_btn := _button("LOAD SELECTED"); var delete_btn := _button("DELETE SELECTED"); var back := _button("BACK")
	actions.add_child(load_btn); actions.add_child(delete_btn); actions.add_child(back)
	load_btn.pressed.connect(func():
		if listing.is_anything_selected():
			var f := FileAccess.open(SAVE_DIR.path_join(listing.get_item_text(listing.get_selected_items()[0]) + ".json"), FileAccess.READ)
			if f:
				var parsed = JSON.parse_string(f.get_as_text()); f.close()
				if parsed is Dictionary: state = parsed; _show_game()
	)
	delete_btn.pressed.connect(func():
		if listing.is_anything_selected(): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_DIR.path_join(listing.get_item_text(listing.get_selected_items()[0]) + ".json"))); _show_saves()
	)
	back.pressed.connect(_show_title)

func _feature(id: String) -> Dictionary:
	return MapData.feature_by_id(id)

func _country_for(id: String) -> Dictionary:
	var f := _feature(id)
	if f.is_empty(): return {}
	var code := str(f.get("country_code", id))
	return MapData.feature_by_id(code)

func _owner_of(id: String, feature: Dictionary = {}) -> String:
	if state.owners.has(id): return str(state.owners[id])
	if feature.is_empty(): feature = _feature(id)
	var parent := str(feature.get("parent_id", ""))
	while not parent.is_empty():
		if state.owners.has(parent): return str(state.owners[parent])
		var parent_feature := _feature(parent)
		if parent_feature.is_empty(): break
		parent = str(parent_feature.get("parent_id", ""))
	var country := str(feature.get("country_code", id))
	return str(state.owners.get(country, country))

func _on_zoom_changed(value: float) -> void:
	for level in [1, 2]:
		var threshold := 1.55 if level == 1 else 3.6
		if value >= threshold and not loaded_levels.has(level):
			loaded_levels[level] = true
			map_view.set_level_data(level, MapData.load_layer(level))

func _load_deep_layer(country_code: String) -> void:
	var result := MapData.load_deepest_country(country_code)
	if not result.is_empty(): map_view.set_deep_country_data(country_code, int(result.level), result.features)

func _state_color_table() -> Dictionary:
	var result := {}
	for id in state.countries:
		if str(id).begins_with("NEW_"):
			result[id] = str(state.countries[id].get("color", "#59a6bd"))
	return result

func _nation_flag(country_id: String) -> Control:
	var banner := FlagView.new()
	var color := Color("#6682b7")
	if state.countries.has(country_id):
		var raw: Variant = state.countries[country_id].get("color", "")
		if str(raw).begins_with("#"): color = Color(str(raw))
		else: color = Color.from_hsv(float(abs(country_id.hash()) % 1000) / 1000.0, 0.42, 0.78)
	banner.nation_color = color
	banner.seed_value = abs(country_id.hash())
	return banner

func _notice(title: String, message: String) -> void:
	var d := AcceptDialog.new(); d.title = title; d.dialog_text = message; add_child(d); d.confirmed.connect(func(): d.queue_free()); d.popup_centered()

func _clear() -> void:
	for child in get_children(): child.queue_free()

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", font_size); l.add_theme_color_override("font_color", color); l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35)); l.add_theme_constant_override("shadow_offset_x", 1); l.add_theme_constant_override("shadow_offset_y", 1); return l

func _style(color: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = color; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(3); s.content_margin_left = 12; s.content_margin_right = 12; s.content_margin_top = 8; s.content_margin_bottom = 8; return s

func _panel(color: Color) -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", _style(color, Color("#294451"))); return p

func _button(text: String) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size.y = 38; b.add_theme_font_size_override("font_size", 13); b.add_theme_color_override("font_color", Color("#f2e9d8")); b.add_theme_color_override("font_hover_color", Color("#fff3cf")); b.add_theme_stylebox_override("normal", _style(PANEL_ALT, Color("#47616a"))); b.add_theme_stylebox_override("hover", _style(Color("#234251"), GOLD)); b.add_theme_stylebox_override("pressed", _style(Color("#304a4d"), GOLD)); return b
