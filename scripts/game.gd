extends Control

const MapView = preload("res://scripts/world_map.gd")
const MapData = preload("res://scripts/map_data.gd")
const FlagView = preload("res://scripts/nation_flag.gd")
const CityLib = preload("res://scripts/city_data.gd")
const MilitaryLib = preload("res://scripts/military_system.gd")

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
var right_container: VBoxContainer
var eventlog: Label

# Top resource indicators (European War Style)
var gold_label: Label
var industry_label: Label
var manpower_label: Label

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
	var eyebrow := _label("GRAND STRATEGY & WARFARE  •  TACTICAL CAMPAIGN", 14, GOLD)
	root.add_child(eyebrow)
	var seal := TextureRect.new(); seal.texture = load("res://assets/ui/crown_seal.svg"); seal.custom_minimum_size = Vector2(58, 58); seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; root.add_child(seal)
	var title := _label("WORLD\nDOMINION", 58, Color("#f4ead3"))
	root.add_child(title)
	var sub := _label("Tactical warfare, real army regiments, cities and generals.", 17, MUTED)
	root.add_child(sub)
	var rule := _panel(PANEL_ALT); rule.custom_minimum_size.y = 2; root.add_child(rule)
	var start := _button("COMMENCER UNE NOUVELLE CAMPAGNE")
	root.add_child(start)
	root.add_child(_label("Choisissez la nation que vous dirigerez :", 14, MUTED))
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
	var resume := _button("CHARGER UNE SAUVEGARDE")
	root.add_child(resume)
	var quit := _button("QUITTER LE JEU")
	root.add_child(quit)
	root.add_child(_label("WORLD DOMINION  •  TACTICAL WARFARE EDITION", 11, Color("#9a8b6c")))
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
		countries[f.id] = {
			"id": f.id,
			"name": f.name,
			"budget": 172.0 + (abs(f.id.hash()) % 120),
			"industry": 145.0 + (abs(f.id.hash()) % 80),
			"manpower": 1390.0 + (abs(f.id.hash()) % 500),
			"population": 2.0 + (abs(f.id.hash()) % 400),
			"stability": 80,
			"government": "Empire",
			"color": Color.from_hsv(float(abs(f.id.hash()) % 100) / 100.0, 0.45, 0.78).to_html(false)
		}

	# Initialize Cities
	var cities: Array = CityLib.get_default_cities().duplicate(true)
	for c in cities:
		c["owner"] = owners.get(c.country_code, c.country_code)

	# Initialize Divisions matching the European War screenshot aesthetic
	var units: Array = []

	# French forces (Metz, Nancy, Paris)
	units.append(MilitaryLib.create_unit("artillery", "FRA", 6.17, 49.12, "Artillerie Lourde de Metz", "METZ", true, "Général"))
	units.append(MilitaryLib.create_unit("infantry", "FRA", 6.30, 48.95, "5e Div. Fusiliers de Metz", "METZ"))
	units.append(MilitaryLib.create_unit("cavalry", "FRA", 6.18, 48.69, "4e Régiment de Cuirassiers", "NANCY"))
	units.append(MilitaryLib.create_unit("infantry", "FRA", 2.35, 48.86, "Garde Impériale de Paris", "PARIS", true, "Maréchal"))
	units.append(MilitaryLib.create_unit("artillery", "FRA", 2.50, 48.70, "Batterie d'Artillerie de Paris", "PARIS"))

	# German / Saxon / Prussian forces (Karlsruhe, Weilburg, Jena, Wiesbaden, Berlin)
	units.append(MilitaryLib.create_unit("cavalry", "DEU", 8.40, 49.01, "Garde de Cavalerie de Karlsruhe", "KARLSRUHE", true, "Blücher"))
	units.append(MilitaryLib.create_unit("infantry", "DEU", 8.55, 48.92, "7e Régiment Grenadiers", "KARLSRUHE"))
	units.append(MilitaryLib.create_unit("artillery", "DEU", 8.26, 50.49, "Artillerie de Campagne Weilburg", "WEILBURG"))
	units.append(MilitaryLib.create_unit("infantry", "DEU", 8.24, 50.08, "2e Div. Wiesbaden", "WIESBADEN"))
	units.append(MilitaryLib.create_unit("infantry", "DEU", 11.59, 50.93, "Infanterie de Ligne Jena", "JENA", true, "Braunschweig"))
	units.append(MilitaryLib.create_unit("artillery", "DEU", 11.75, 50.85, "Batterie Royale de Jena", "JENA"))
	units.append(MilitaryLib.create_unit("infantry", "DEU", 13.40, 52.52, "Garde Royale de Berlin", "BERLIN", true, "Général d'Armée"))
	units.append(MilitaryLib.create_unit("armor", "DEU", 13.55, 52.38, "Brigade Blindée de Berlin", "BERLIN"))

	# Other Major World Nations starting forces
	units.append(MilitaryLib.create_unit("infantry", "GBR", -0.12, 51.51, "Royal Coldstream Guards", "LONDON", true, "Wellington"))
	units.append(MilitaryLib.create_unit("artillery", "GBR", 0.05, 51.40, "Royal Horse Artillery", "LONDON"))
	units.append(MilitaryLib.create_unit("infantry", "RUS", 37.62, 55.76, "Garde Impériale de Moscou", "MOSKVA", true, "Koutouzov"))
	units.append(MilitaryLib.create_unit("artillery", "RUS", 37.80, 55.65, "Artillerie Lourde de Moscou", "MOSKVA"))
	units.append(MilitaryLib.create_unit("cavalry", "RUS", 30.36, 59.93, "Cosaques de Leningrad", "LENINGRAD"))
	units.append(MilitaryLib.create_unit("infantry", "ITA", 12.50, 41.90, "Légion de Rome", "ROMA"))
	units.append(MilitaryLib.create_unit("infantry", "USA", -77.04, 38.91, "1st Continental Infantry", "WASHINGTON", true, "General"))
	units.append(MilitaryLib.create_unit("cavalry", "USA", -77.20, 38.80, "US Cavalry Regiment", "WASHINGTON"))

	state = {
		"turn": 1,
		"year": 1805,
		"player": chosen.id,
		"owners": owners,
		"countries": countries,
		"statuses": {},
		"alliances": [],
		"cities": cities,
		"units": units,
		"selected_unit": "",
		"selected_city": "",
		"logs": ["La campagne débute ! Les armées et généraux sont en position sur le théâtre européen."],
		"next_state": 1
	}
	_show_game()

func _show_game() -> void:
	_clear()
	var backdrop := ColorRect.new(); backdrop.color = BG; backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(backdrop)

	# TOP BAR WITH EUROPEAN WAR / EASYTECH RESOURCE COUNTERS
	var top := _panel(PANEL)
	top.add_theme_stylebox_override("panel", _style(PANEL, Color("#294451")))
	var top_style: StyleBoxFlat = top.get_theme_stylebox("panel").duplicate()
	top_style.content_margin_top = 2
	top_style.content_margin_bottom = 2
	top.add_theme_stylebox_override("panel", top_style)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 60
	add_child(top)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(bar)

	# Brand / Title
	var compass := TextureRect.new(); compass.texture = load("res://assets/ui/compass_rose.svg"); compass.custom_minimum_size = Vector2(36, 36); compass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; compass.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; bar.add_child(compass)
	var brand := _label("WORLD DOMINION", 18, GOLD)
	bar.add_child(brand)

	# Tactical Resource Badges (Gold, Wrench/Industry, Rations/Manpower)
	var res_box := HBoxContainer.new()
	res_box.add_theme_constant_override("separation", 20)
	bar.add_child(res_box)

	gold_label = _label("🪙  172", 16, Color("#ffeaa7"))
	res_box.add_child(gold_label)

	industry_label = _label("🔧  145", 16, Color("#74b9ff"))
	res_box.add_child(industry_label)

	manpower_label = _label("🍖  1390", 16, Color("#ff7675"))
	res_box.add_child(manpower_label)

	header_label = _label("", 16, Color("#e9e4d7"))
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(header_label)

	var save_btn := _button("SAVE"); save_btn.pressed.connect(_save_dialog); bar.add_child(save_btn)
	var layers_btn := _button("LAYERS"); bar.add_child(layers_btn)
	var layers_popup := PopupMenu.new()
	layers_popup.add_check_item("Political colors", 0)
	layers_popup.add_check_item("International borders", 1)
	layers_popup.add_check_item("Administrative limits", 2)
	layers_popup.add_check_item("Country and region names", 3)
	layers_popup.add_check_item("Cities & Forts", 4)
	layers_popup.add_check_item("Military Units & Generals", 5)
	for item_id in range(6): layers_popup.set_item_checked(item_id, true)
	add_child(layers_popup)
	layers_btn.pressed.connect(func(): layers_popup.position = Vector2i(layers_btn.global_position + Vector2(0, layers_btn.size.y)); layers_popup.popup())
	layers_popup.id_pressed.connect(func(id: int):
		var keys := ["political", "international", "administrative", "labels", "cities", "units"]
		layers_popup.set_item_checked(id, not layers_popup.is_item_checked(id))
		map_view.set_layers({keys[id]: layers_popup.is_item_checked(id)})
	)

	var menu_btn := _button("MENU"); menu_btn.pressed.connect(_show_title); bar.add_child(menu_btn)
	var body := HBoxContainer.new(); body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); body.offset_top = 60; body.offset_bottom = -34; body.add_theme_constant_override("separation", 0); add_child(body)

	# Left panel
	var left := _panel(PANEL); left.custom_minimum_size.x = 250; body.add_child(left)
	var leftscroll := ScrollContainer.new(); leftscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; leftscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; left.add_child(leftscroll)
	var leftbox := VBoxContainer.new(); leftbox.add_theme_constant_override("separation", 10); leftbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL; leftscroll.add_child(leftbox)
	leftbox.add_child(_label("NATION ET ÉTAT-MAJOR", 13, GOLD))
	var player_flag := _nation_flag(state.player); leftbox.add_child(player_flag)
	info_label = _label("", 15, Color("#e9e4d7")); info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL; leftbox.add_child(info_label)

	var military := _button("FORCES ARMÉES & GÉNÉRAUX"); military.pressed.connect(_show_military_dialog); leftbox.add_child(military)
	var diplomacy := _button("DIPLOMATIE"); diplomacy.pressed.connect(func(): _notice("Diplomatie", "Les relations internationales et traités de paix sont gérés par le ministère.")); leftbox.add_child(diplomacy)
	var economy := _button("INDUSTRIE & RAVITAILLEMENT"); economy.pressed.connect(func(): _notice("Économie de guerre", "Chaque ville contrôlée produit de l'or, de l'acier et des rations pour vos armées.")); leftbox.add_child(economy)

	# Center map
	var center := VBoxContainer.new(); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; center.add_theme_constant_override("separation", 0); body.add_child(center)
	var map_frame := PanelContainer.new(); map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL; map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL; map_frame.add_theme_stylebox_override("panel", _style(Color("#071521"), Color("#294451"))); center.add_child(map_frame)

	map_view = MapView.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.load_world(world)

	var p_owners: Dictionary = state.owners.duplicate()
	p_owners["player_id"] = state.player
	map_view.set_owners(p_owners)
	map_view.set_state_colors(_state_color_table())
	map_view.set_cities(state.cities)
	map_view.set_units(state.units)

	# Center view on French/German front at startup
	map_view.pan = -Vector2(7.2, 49.5)
	map_view.zoom = 3.6

	# Signals
	map_view.territory_clicked.connect(_on_territory_clicked)
	map_view.city_clicked.connect(_on_city_clicked)
	map_view.unit_clicked.connect(_on_unit_clicked)
	map_view.unit_move_requested.connect(_on_unit_move_requested)
	map_view.deep_layer_requested.connect(_load_deep_layer)
	map_view.zoom_changed.connect(_on_zoom_changed)
	map_frame.add_child(map_view)

	var bottom := _panel(PANEL); bottom.custom_minimum_size.y = 52; center.add_child(bottom)
	var tools := HBoxContainer.new(); tools.add_theme_constant_override("separation", 9); bottom.add_child(tools)
	selection_label = _label("Sélectionnez vos régiments, villes ou territoires", 14, MUTED); selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tools.add_child(selection_label)
	var create := _button("FONDER UN ÉTAT"); create.pressed.connect(_create_state_dialog); tools.add_child(create)
	var next := _button("FIN DU TOUR  ▶"); next.add_theme_stylebox_override("normal", _style(Color("#604b2c"), GOLD)); next.pressed.connect(_next_turn); tools.add_child(next)

	# Right panel (dynamic)
	var right := _panel(PANEL); right.custom_minimum_size.x = 295; body.add_child(right)
	var rightscroll := ScrollContainer.new(); rightscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; rightscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right.add_child(rightscroll)
	right_container = VBoxContainer.new(); right_container.add_theme_constant_override("separation", 12); right_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rightscroll.add_child(right_container)

	_show_default_right_panel()

	eventlog = _label("DERNIER ÉVÉNEMENT  •  " + str(state.logs.back()), 12, MUTED)
	eventlog.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	eventlog.offset_top = -34
	eventlog.custom_minimum_size.y = 34
	add_child(eventlog)

	_refresh_header()
	update_overview()

func _show_default_right_panel() -> void:
	_clear_container(right_container)
	right_container.add_child(_label("ORDRES ET ÉTAT-MAJOR", 13, GOLD))
	var desc := _label("COMMANDES TACTIQUES :\n\n• Cliquez sur vos soldats, cavaliers, chars ou artillerie pour les sélectionner.\n• Clic droit ou clic destination sur la carte pour déplacer ou attaquer !\n• Cliquez sur une VILLE pour recruter des régiments d'infanterie, batteries d'artillerie et cavalerie.\n• Molette : zoom\n• Glisser : déplacer la carte", 14, Color("#d8e0de"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_container.add_child(desc)

# ==============================================================================
# CITY INTERACTION & RECRUITMENT
# ==============================================================================
func _on_city_clicked(city_id: String) -> void:
	state.selected_city = city_id
	state.selected_unit = ""
	map_view.selected.clear()
	selection_label.text = "Ville sélectionnée : %s" % city_id
	_show_city_detail(city_id)

func _show_city_detail(city_id: String) -> void:
	var city := _find_city(city_id)
	if city.is_empty(): return
	_clear_container(right_container)

	var is_capital: bool = str(city.get("type", "")) == "capital"
	var tier_val: int = int(city.get("tier", 3))
	right_container.add_child(_label("VILLE ET FORTERESSE", 13, GOLD))

	var title_lbl := _label("%s %s  (%s)" % ["★" if is_capital else "◆", str(city.name).to_upper(), MilitaryLib.roman_numeral(tier_val)], 18, Color("#ffeaa5") if is_capital else Color("#e0ede7"))
	right_container.add_child(title_lbl)

	var owner_code: String = str(city.get("owner", city.get("country_code", "")))
	var c_record: Dictionary = state.countries.get(owner_code, {"name": owner_code})
	var is_player_city: bool = owner_code == state.player
	var has_fort: bool = bool(city.get("has_fort", false))

	var info := "Contrôle : %s\nNiveau urbain : Rang %s\nFortification : %s\nPopulation : %.1f M\nProduction : +%.0f Or / tour\nBonus Défense : +%d%%\nPosition : %.2f°N, %.2f°E" % [
		c_record.name,
		MilitaryLib.roman_numeral(tier_val),
		"Forteresse Vauban" if has_fort else "Remparts standards",
		float(city.get("population", 1.0)),
		float(city.get("income", 10.0)),
		int(city.get("defense", 20)),
		float(city.lat), float(city.lon)
	]
	var info_lbl := _label(info, 14, Color("#d8e0de"))
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_container.add_child(info_lbl)

	# Garrison list
	var garrison := _units_at_coords(float(city.lon), float(city.lat))
	var gar_title := _label("GARNISON PRÉSENTE (%d) :" % garrison.size(), 13, GOLD)
	right_container.add_child(gar_title)
	for u in garrison:
		var u_owner := str(u.owner)
		var gen_tag := " ★ " if bool(u.get("has_general", false)) else ""
		var u_lbl := _label("• %s%s (%s, %d HP)" % [gen_tag, str(u.name), str(u.type).capitalize(), int(u.hp)], 12, Color("#a5d6a7") if u_owner == state.player else Color("#ef9a9a"))
		right_container.add_child(u_lbl)

	if is_player_city:
		var recruit_title := _label("RECRUTER DES RENFORTS :", 13, GOLD)
		right_container.add_child(recruit_title)

		var rec_inf := _button("RECRUTER INFANTERIE (25 Or • 150 Hommes)")
		rec_inf.pressed.connect(func(): _recruit_unit("infantry", city))
		right_container.add_child(rec_inf)

		var rec_art := _button("PRODUIRE ARTILLERIE (40 Or • 100 Hommes)")
		rec_art.pressed.connect(func(): _recruit_unit("artillery", city))
		right_container.add_child(rec_art)

		var rec_cav := _button("LEVER CAVALERIE / CHARS (45 Or • 120 Hommes)")
		rec_cav.pressed.connect(func(): _recruit_unit("cavalry", city))
		right_container.add_child(rec_cav)
	else:
		var intel := _label("Ville étrangère. Envoyez vos régiments militaires pour la capturer !", 13, Color("#ffab91"))
		intel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right_container.add_child(intel)

func _recruit_unit(type: String, city: Dictionary) -> void:
	var def: Dictionary = MilitaryLib.TYPES.get(type, MilitaryLib.TYPES["infantry"])
	var cost := float(def.cost)
	var p_country: Dictionary = state.countries[state.player]
	if float(p_country.budget) < cost:
		_notice("Trésor insuffisant", "Il vous faut %.0f Or pour recruter cette division. Trésor actuel : %.0f." % [cost, float(p_country.budget)])
		return

	p_country.budget -= cost
	p_country.manpower = maxf(0, float(p_country.get("manpower", 1000)) - 100.0)

	var u_name := "%s %s" % [str(city.name), str(def.name)]
	var new_u := MilitaryLib.create_unit(type, state.player, float(city.lon) + randf_range(-0.25, 0.25), float(city.lat) + randf_range(-0.25, 0.25), u_name, str(city.id))
	state.units.append(new_u)

	state.logs.append("%s a levé une nouvelle division : %s (-%.0f Or)." % [str(city.name), new_u.name, cost])
	_log_latest()
	map_view.set_units(state.units)
	_refresh_header()
	update_overview()
	_show_city_detail(str(city.id))

# ==============================================================================
# MILITARY UNIT INTERACTION & COMBAT
# ==============================================================================
func _on_unit_clicked(unit_id: String) -> void:
	state.selected_unit = unit_id
	state.selected_city = ""
	map_view.selected.clear()
	var u := _find_unit(unit_id)
	if not u.is_empty():
		selection_label.text = "Régiment sélectionné : %s (%s)" % [str(u.name), str(u.owner)]
	_show_unit_detail(unit_id)

func _show_unit_detail(unit_id: String) -> void:
	var u := _find_unit(unit_id)
	if u.is_empty(): _show_default_right_panel(); return
	_clear_container(right_container)

	var is_player: bool = str(u.owner) == state.player
	var has_gen: bool = bool(u.get("has_general", false))
	right_container.add_child(_label("FICHE MILITAIRE", 13, GOLD))

	var name_prefix := "★ " if has_gen else "◆ "
	var name_lbl := _label(name_prefix + str(u.name).to_upper(), 16, Color("#ffeaa5") if is_player else Color("#ffab91"))
	right_container.add_child(name_lbl)

	var type_name := "Division d'Infanterie (Fusiliers)"
	if u.type == "artillery": type_name = "Batterie d'Artillerie Lourde"
	elif u.type == "cavalry": type_name = "Régiment de Cavalerie (Cuirassiers)"
	elif u.type == "armor": type_name = "Division Blindée (Chars d'Assaut)"

	var gen_info := ("Commandant : " + str(u.general_name) + "\n") if has_gen else ""
	var info := "%sType : %s\nNation : %s\nRang tactique : %s\nPoints de vie : %d / %d HP\nPoints de mouvement : %d / %d MP\nPuissance d'attaque : %d\nValeur de défense : %d\nCoordonnées : %.2f°N, %.2f°E" % [
		gen_info,
		type_name,
		str(u.owner),
		MilitaryLib.roman_numeral(int(u.get("rank", 3))),
		int(u.hp), int(u.max_hp),
		int(u.mp), int(u.max_mp),
		int(u.attack),
		int(u.defense),
		float(u.lat), float(u.lon)
	]
	var info_lbl := _label(info, 14, Color("#d8e0de"))
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_container.add_child(info_lbl)

	if is_player:
		var order_lbl := _label("ORDRES STRATÉGIQUES :", 13, GOLD)
		right_container.add_child(order_lbl)

		var move_tip := _label("Pour attaquer ou vous déplacer : faites un clic droit ou clic gauche sur la cible sur la carte.", 13, MUTED)
		move_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right_container.add_child(move_tip)

		var fortify_btn := _button("SE RETRANCHER (+10 DEF)")
		fortify_btn.pressed.connect(func():
			if int(u.mp) <= 0: _notice("Mouvement épuisé", "Cette division n'a plus de MP ce tour."); return
			u.defense = int(u.defense) + 10
			u.mp = 0
			state.logs.append("%s s'est retranchée sur ses positions (+10 DEF)." % u.name)
			_log_latest()
			map_view.set_units(state.units)
			_show_unit_detail(u.id)
		)
		right_container.add_child(fortify_btn)

		var disband_btn := _button("DÉMANTELER LE RÉGIMENT (+15 Or)")
		disband_btn.pressed.connect(func():
			state.countries[state.player].budget += 15.0
			state.units.erase(u)
			state.logs.append("La division %s a été démobilisée (+15 Or)." % u.name)
			_log_latest()
			map_view.clear_entity_selection()
			map_view.set_units(state.units)
			_refresh_header()
			update_overview()
			_show_default_right_panel()
		)
		right_container.add_child(disband_btn)
	else:
		var intel := _label("Division ennemie ! Approchez vos troupes pour engager la bataille.", 13, Color("#ff8a80"))
		intel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right_container.add_child(intel)

func _on_unit_move_requested(unit_id: String, target_lon: float, target_lat: float, target_city: String, target_unit: String) -> void:
	var u := _find_unit(unit_id)
	if u.is_empty(): return
	if str(u.owner) != state.player:
		_notice("Ordre refusé", "Vous ne pouvez donner des ordres qu'à vos propres divisions.")
		return
	if int(u.mp) <= 0:
		_notice("Mouvement épuisé", "Cette division a déjà manoeuvré ce tour.")
		return

	# Case 1: Attacking an enemy unit directly
	if not target_unit.is_empty() and target_unit != unit_id:
		var enemy := _find_unit(target_unit)
		if not enemy.is_empty():
			if str(enemy.owner) == state.player:
				_notice("Troupes amies", "Cette division est déjà sous votre commandement.")
				return
			_execute_combat(u, enemy)
			return

	# Case 2: Moving to a City (friendly or enemy)
	if not target_city.is_empty():
		var city := _find_city(target_city)
		if not city.is_empty():
			var defenders := _units_at_coords(float(city.lon), float(city.lat), state.player)
			if not defenders.is_empty():
				_execute_combat(u, defenders[0], true)
				return
			u.lon = float(city.lon)
			u.lat = float(city.lat)
			u.stationed_city = str(city.id)
			u.mp = maxi(0, int(u.mp) - 1)

			var c_owner: String = str(city.get("owner", city.get("country_code", "")))
			if c_owner != state.player:
				city["owner"] = state.player
				state.owners[str(city.country_code)] = state.player
				state.statuses[str(city.country_code)] = "Occupé par %s" % state.countries[state.player].name
				state.logs.append("VICTOIRE ÉCLATANTE ! %s a capturé la ville de %s !" % [u.name, city.name])
			else:
				state.logs.append("%s est entrée dans la ville de %s." % [u.name, city.name])

			_finalize_movement(u)
			return

	# Case 3: Open ground movement
	var current_pos := Vector2(float(u.lon), float(u.lat))
	var target_pos := Vector2(target_lon, target_lat)
	var dist := current_pos.distance_to(target_pos)

	var max_step := 7.5
	if u.type == "cavalry" or u.type == "armor": max_step = 10.5
	elif u.type == "artillery": max_step = 5.0

	var final_pos := target_pos
	if dist > max_step:
		final_pos = current_pos + (target_pos - current_pos).normalized() * max_step

	u.lon = final_pos.x
	u.lat = final_pos.y
	u.stationed_city = ""
	u.mp = maxi(0, int(u.mp) - 1)
	state.logs.append("%s a manoeuvré vers (%.1f°, %.1f°)." % [u.name, u.lat, u.lon])

	_finalize_movement(u)

func _execute_combat(attacker: Dictionary, defender: Dictionary, in_city: bool = false) -> void:
	var result: Dictionary = MilitaryLib.resolve_combat(attacker, defender, in_city)
	var atk_name: String = str(attacker.name)
	var def_name: String = str(defender.name)

	var report := "BATAILLE : %s vs %s ! Pertes : -%d HP (%s) / -%d HP (%s)." % [
		atk_name, def_name,
		int(result.attacker_damage), atk_name,
		int(result.defender_damage), def_name
	]
	state.logs.append(report)

	if bool(result.defender_destroyed):
		state.logs.append("VICTOIRE ! La division ennemie %s a capitulé !" % def_name)
		state.units.erase(defender)
		attacker.lon = defender.lon
		attacker.lat = defender.lat
		attacker.stationed_city = defender.get("stationed_city", "")

		if not str(attacker.stationed_city).is_empty():
			var city := _find_city(attacker.stationed_city)
			if not city.is_empty() and str(city.get("owner", "")) != state.player:
				city["owner"] = state.player
				state.owners[str(city.country_code)] = state.player
				state.logs.append("La ville de %s est tombée sous nos couleurs !" % city.name)

	if bool(result.attacker_destroyed):
		state.logs.append("DÉFAITE ! Notre régiment %s a succombé au combat." % atk_name)
		state.units.erase(attacker)
		map_view.clear_entity_selection()
		_show_default_right_panel()

	_finalize_movement(attacker)

func _finalize_movement(u: Dictionary) -> void:
	_log_latest()
	map_view.set_units(state.units)
	map_view.set_cities(state.cities)
	map_view.set_owners(state.owners)
	update_overview()
	_refresh_header()
	if not state.selected_unit.is_empty():
		_show_unit_detail(state.selected_unit)
	elif not state.selected_city.is_empty():
		_show_city_detail(state.selected_city)

# ==============================================================================
# GENERAL HEADQUARTERS DIALOG
# ==============================================================================
func _show_military_dialog() -> void:
	var d := AcceptDialog.new()
	d.title = "Grand État-Major des Armées"
	d.ok_button_text = "RETOURNER AU FRONT"

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(580, 480)
	box.add_theme_constant_override("separation", 10)
	d.add_child(box)

	var p_units: Array = []
	var inf_count := 0
	var cav_count := 0
	var art_count := 0
	var gen_count := 0
	for u in state.units:
		if str(u.owner) == state.player:
			p_units.append(u)
			if bool(u.get("has_general", false)): gen_count += 1
			if u.type == "infantry": inf_count += 1
			elif u.type == "cavalry" or u.type == "armor": cav_count += 1
			elif u.type == "artillery": art_count += 1

	var stat_box := _panel(PANEL_ALT)
	var stat_text := "ORDRE DE BATAILLE : %d Régiments actifs  •  %d Généraux\n• Infanterie : %d   • Cavalerie / Chars : %d   • Artillerie : %d\nTrésor : %.0f Or   • Ravitaillement : %.0f Rations" % [
		p_units.size(), gen_count, inf_count, cav_count, art_count, float(state.countries[state.player].budget), float(state.countries[state.player].manpower)
	]
	stat_box.add_child(_label(stat_text, 14, GOLD))
	box.add_child(stat_box)

	box.add_child(_label("REGISTRE DES DIVISIONS ET COMMANDANTS :", 13, MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var list_box := VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)

	for u in p_units:
		var row := HBoxContainer.new()
		var gen_star := "★ " if bool(u.get("has_general", false)) else "  "
		var u_desc := "%s%s  •  %s  •  %d/%d HP  •  %d MP" % [gen_star, str(u.name), str(u.type).capitalize(), int(u.hp), int(u.max_hp), int(u.mp)]
		var row_lbl := _label(u_desc, 13, Color("#e0ede7"))
		row_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(row_lbl)

		var locate_btn := _button("VOIR")
		locate_btn.custom_minimum_size = Vector2(70, 28)
		locate_btn.pressed.connect(func():
			map_view.pan = -Vector2(float(u.lon), float(u.lat))
			map_view.zoom = 3.6
			map_view.select_unit(str(u.id))
			_on_unit_clicked(str(u.id))
			d.queue_free()
		)
		row.add_child(locate_btn)
		list_box.add_child(row)

	add_child(d)
	d.popup_centered()

# ==============================================================================
# TURN PROGRESSION & AI LOGIC
# ==============================================================================
func _next_turn() -> void:
	state.turn += 1
	if state.turn > 12: state.turn = 1; state.year += 1

	# 1. Replenish MP and heal garrisons in friendly cities
	for u in state.units:
		u.mp = u.max_mp
		if not str(u.get("stationed_city", "")).is_empty():
			u.hp = clampi(int(u.hp) + 18, 0, int(u.max_hp))

	# 2. Add City Income to Nation Budgets
	for c in state.cities:
		var c_owner: String = str(c.get("owner", c.country_code))
		if state.countries.has(c_owner):
			state.countries[c_owner].budget += float(c.get("income", 12.0))
			state.countries[c_owner].industry += 8.0
			state.countries[c_owner].manpower += 60.0

	# 3. Country Treasury & Stability
	for id in state.countries:
		var c: Dictionary = state.countries[id]
		var territory_count := 0
		for owner in state.owners.values():
			if owner == id: territory_count += 1
		var variation := float((abs((id + str(state.turn)).hash()) % 17) - 6) / 100.0
		c.budget = maxf(0, float(c.budget) + territory_count * 1.5 + variation * float(c.budget))
		c.stability = clampi(int(c.stability) + (1 if c.budget > 20 else -2), 10, 99)

	# 4. AI Strategic turns
	_execute_ai_turns()

	state.logs.append("Tour %d terminé (Année %d). Ravitaillement et régiments réapprovisionnés." % [state.turn, state.year])
	_log_latest()

	map_view.set_units(state.units)
	map_view.set_cities(state.cities)
	map_view.set_owners(state.owners)
	_refresh_header()
	update_overview()
	if not state.selected_unit.is_empty(): _show_unit_detail(state.selected_unit)
	elif not state.selected_city.is_empty(): _show_city_detail(state.selected_city)

func _execute_ai_turns() -> void:
	var majors := ["DEU", "RUS", "GBR", "FRA", "ITA", "USA"]
	for id in majors:
		if id == state.player: continue
		if not state.countries.has(id): continue
		var country: Dictionary = state.countries[id]

		# AI Recruitment if budget permits
		if float(country.budget) >= 60.0:
			var cap := CityLib.get_capital_for_country(id)
			if not cap.is_empty():
				var u_type := "cavalry" if randf() > 0.5 else "artillery"
				var cost: float = MilitaryLib.TYPES[u_type].cost
				country.budget -= cost
				var new_u := MilitaryLib.create_unit(
					u_type, id,
					float(cap.lon) + randf_range(-0.6, 0.6),
					float(cap.lat) + randf_range(-0.6, 0.6),
					"%s %s" % [id, MilitaryLib.TYPES[u_type].name],
					str(cap.id)
				)
				state.units.append(new_u)

		# AI Units movement & patrols
		for u in state.units:
			if str(u.owner) == id and int(u.mp) > 0:
				if randf() > 0.6:
					u.lon += randf_range(-0.8, 0.8)
					u.lat += randf_range(-0.6, 0.6)
					u.mp = 0

# ==============================================================================
# TERRITORY ADMINISTRATION & DIALOGS
# ==============================================================================
func _on_territory_clicked(id: String, additive: bool) -> void:
	if not additive: map_view.selected.clear()
	if map_view.selected.has(id): map_view.selected.erase(id)
	else: map_view.selected.append(id)
	map_view.selected = map_view.selected
	map_view.queue_redraw()
	selection_label.text = "%d territoire(s) sélectionné(s)" % map_view.selected.size()
	_show_region_detail(id)

func _show_region_detail(id: String) -> void:
	var f: Dictionary = _feature(id)
	var owner := _owner_of(id, f)
	var c: Dictionary = state.countries.get(owner, {"name": f.get("name", id), "budget": 0, "population": 0, "stability": 50, "government": "Unknown"})
	var status := str(state.statuses.get(id, "Territoire National"))
	var metadata: Dictionary = MapData.metadata_for(str(f.get("country_code", id)), int(f.get("admin_level", 0)))
	var boundary_source := "geoBoundaries gbOpen"
	if not metadata.is_empty():
		boundary_source = "geoBoundaries gbOpen (Réf: %s)" % str(metadata.get("year", "1805"))

	_clear_container(right_container)
	right_container.add_child(_label("PROVINCE ET TERRITOIRE", 13, GOLD))
	var desc := _label("%s\n\nContrôle : %s\nStatut : %s\nPopulation : %.1f M\nTrésor : %.0f Or\nStabilité : %d%%\n\nSource géographique : %s" % [
		f.get("name", id), c.name, status, float(c.population), float(c.budget), int(c.stability), boundary_source
	], 14, Color("#d8e0de"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_container.add_child(desc)

	var annex := _button("ANNEXER POUR LA NATION"); annex.pressed.connect(func(): _set_selected_owner(state.player, "annexé")); right_container.add_child(annex)
	var occupy := _button("PLACER SOUS OCCUPATION MILITAIRE"); occupy.pressed.connect(func(): _set_selected_owner(state.player, "occupé")); right_container.add_child(occupy)
	var release := _button("RESTAURER LE PROPRIÉTAIRE D'ORIGINE"); release.pressed.connect(_restore_selected); right_container.add_child(release)

func _set_selected_owner(owner: String, status: String) -> void:
	if map_view.selected.is_empty(): return
	for id in map_view.selected:
		state.owners[id] = owner
		state.statuses[id] = status.capitalize()
	state.logs.append("%d territoires placés sous le statut : %s." % [map_view.selected.size(), status])
	_log_latest()
	map_view.set_owners(state.owners); update_overview(); _refresh_header()

func _restore_selected() -> void:
	for id in map_view.selected:
		var f := _feature(id)
		if int(f.get("admin_level", 0)) == 0: state.owners[id] = id
		else: state.owners.erase(id)
		state.statuses.erase(id)
	map_view.set_owners(state.owners); update_overview()

func _create_state_dialog() -> void:
	if map_view.selected.is_empty(): _notice("Aucun territoire sélectionné", "Sélectionnez d'abord un ou plusieurs territoires sur la carte."); return
	var dialog := ConfirmationDialog.new(); dialog.title = "Fonder un nouvel État"; dialog.ok_button_text = "PROCLAMER LA SOUVERAINETÉ"
	var form := VBoxContainer.new(); form.custom_minimum_size.x = 390; dialog.add_child(form)
	form.add_child(_label("Les territoires sélectionnés formeront une nouvelle nation souveraine.", 13, MUTED))
	var name_input := LineEdit.new(); name_input.placeholder_text = "Nom du nouvel État"; name_input.text = "République Nouvelle"; form.add_child(name_input)
	var gov := OptionButton.new(); gov.add_item("République"); gov.add_item("Monarchie Constitutionnelle"); gov.add_item("Fédération"); gov.add_item("Régime Militaire"); form.add_child(gov)
	var relation := OptionButton.new(); relation.add_item("Allié fraternel"); relation.add_item("Partenaire autonome"); relation.add_item("Neutre souverain"); form.add_child(relation)
	var color_picker := ColorPickerButton.new(); color_picker.color = Color("#59a6bd"); color_picker.custom_minimum_size = Vector2(120, 38); form.add_child(color_picker)
	add_child(dialog)
	dialog.confirmed.connect(func():
		if name_input.text.strip_edges().is_empty(): return
		var new_id := "NEW_%03d" % int(state.next_state); state.next_state += 1
		var new_country := {
			"id": new_id,
			"name": name_input.text.strip_edges(),
			"budget": 35.0 * map_view.selected.size(),
			"industry": 30.0,
			"manpower": 500.0,
			"population": 0.0,
			"stability": 65,
			"government": gov.get_item_text(gov.selected),
			"color": color_picker.color.to_html(false),
			"relation": relation.get_item_text(relation.selected),
			"creator": state.player
		}
		state.countries[new_id] = new_country
		for id in map_view.selected:
			state.owners[id] = new_id
			state.statuses[id] = "État Indépendant"
			new_country.population += float(_country_for(id).get("population", 20))
		state.logs.append("%s a proclamé son indépendance sur %d territoires !" % [new_country.name, map_view.selected.size()])
		_log_latest()
		map_view.set_owners(state.owners)
		map_view.set_state_colors(_state_color_table())
		update_overview(); _refresh_header(); dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

# ==============================================================================
# HELPERS, SAVE & LOAD
# ==============================================================================
func _find_unit(id: String) -> Dictionary:
	for u in state.get("units", []):
		if str(u.id) == id: return u
	return {}

func _find_city(id: String) -> Dictionary:
	for c in state.get("cities", []):
		if str(c.id) == id: return c
	return {}

func _units_at_coords(lon: float, lat: float, exclude_owner: String = "") -> Array:
	var result: Array = []
	for u in state.get("units", []):
		if not exclude_owner.is_empty() and str(u.owner) == exclude_owner: continue
		if Vector2(float(u.lon), float(u.lat)).distance_to(Vector2(lon, lat)) < 1.4:
			result.append(u)
	return result

func _log_latest() -> void:
	if is_instance_valid(eventlog) and not state.logs.is_empty():
		eventlog.text = "DERNIER ÉVÉNEMENT  •  " + str(state.logs.back())

func _refresh_header() -> void:
	if not is_instance_valid(header_label): return
	var c: Dictionary = state.countries[state.player]
	header_label.text = "%s     •     TOUR %02d     •     ANNÉE %d" % [c.name.to_upper(), state.turn, state.year]
	if is_instance_valid(gold_label):
		gold_label.text = "🪙  %.0f" % float(c.budget)
	if is_instance_valid(industry_label):
		industry_label.text = "🔧  %.0f" % float(c.get("industry", 145))
	if is_instance_valid(manpower_label):
		manpower_label.text = "🍖  %.0f" % float(c.get("manpower", 1390))

func update_overview() -> void:
	if not is_instance_valid(info_label): return
	var c: Dictionary = state.countries[state.player]
	var count := 0
	for owner in state.owners.values():
		if owner == state.player: count += 1
	var army_count := 0
	for u in state.get("units", []):
		if str(u.owner) == state.player: army_count += 1
	var city_count := 0
	for city in state.get("cities", []):
		if str(city.get("owner", city.country_code)) == state.player: city_count += 1

	info_label.text = "%s\n%s\n\nTRÉSOR DE GUERRE\n%.0f Or\n\nPRODUCTION INDUSTRIELLE\n%.0f Usines\n\nRAVITAILLEMENT\n%.0f Hommes\n\nPOPULATION NATIONALE\n%.1f millions\n\nTERRITOIRES & PROVINCES\n%d\n\nVILLES & FORTERESSES\n%d\n\nRÉGIMENTS ACTIFS\n%d\n\nSTABILITÉ\n%d%%\n\n────────────────\nCampagne : Année %d" % [
		c.name.to_upper(), "NATION SOUS VOTRE COMMANDEMENT", c.budget, float(c.get("industry", 145)), float(c.get("manpower", 1390)), c.population, count, city_count, army_count, c.stability, state.year
	]

func _save_dialog() -> void:
	var d := ConfirmationDialog.new(); d.title = "Sauvegarder la campagne"; d.ok_button_text = "SAUVEGARDER"
	var input := LineEdit.new(); input.text = "Campagne %d" % state.year; input.custom_minimum_size.x = 300; d.add_child(input); add_child(d)
	d.confirmed.connect(func(): _save_game(input.text.strip_edges()); d.queue_free())
	d.canceled.connect(func(): d.queue_free())
	d.popup_centered()

func _save_game(name: String) -> void:
	if name.is_empty(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var safe := name.validate_filename()
	var f := FileAccess.open(SAVE_DIR.path_join(safe + ".json"), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(state, "\t")); f.close()
	_notice("Campagne sauvegardée", name)

func _show_saves() -> void:
	_clear()
	var bg := ColorRect.new(); bg.color = BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var box := VBoxContainer.new(); box.position = Vector2(350, 110); box.size = Vector2(740, 680); box.add_theme_constant_override("separation", 12); add_child(box)
	box.add_child(_label("ARCHIVES DES CAMPAGNES", 32, GOLD))
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
	var load_btn := _button("CHARGER LA CAMPAGNE"); var delete_btn := _button("SUPPRIMER"); var back := _button("RETOUR")
	actions.add_child(load_btn); actions.add_child(delete_btn); actions.add_child(back)
	load_btn.pressed.connect(func():
		if listing.is_anything_selected():
			var f := FileAccess.open(SAVE_DIR.path_join(listing.get_item_text(listing.get_selected_items()[0]) + ".json"), FileAccess.READ)
			if f:
				var parsed = JSON.parse_string(f.get_as_text()); f.close()
				if parsed is Dictionary:
					state = parsed
					if not state.has("cities"): state["cities"] = CityLib.get_default_cities().duplicate(true)
					if not state.has("units"): state["units"] = []
					_show_game()
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

func _clear_container(c: Container) -> void:
	for child in c.get_children(): child.queue_free()

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", font_size); l.add_theme_color_override("font_color", color); l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35)); l.add_theme_constant_override("shadow_offset_x", 1); l.add_theme_constant_override("shadow_offset_y", 1); return l

func _style(color: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = color; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(3); s.content_margin_left = 12; s.content_margin_right = 12; s.content_margin_top = 8; s.content_margin_bottom = 8; return s

func _panel(color: Color) -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", _style(color, Color("#294451"))); return p

func _button(text: String) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size.y = 38; b.add_theme_font_size_override("font_size", 13); b.add_theme_color_override("font_color", Color("#f2e9d8")); b.add_theme_color_override("font_hover_color", Color("#fff3cf")); b.add_theme_stylebox_override("normal", _style(PANEL_ALT, Color("#47616a"))); b.add_theme_stylebox_override("hover", _style(Color("#234251"), GOLD)); b.add_theme_stylebox_override("pressed", _style(Color("#304a4d"), GOLD)); return b
