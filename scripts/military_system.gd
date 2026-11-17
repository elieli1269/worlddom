extends RefCounted
class_name MilitarySystem

const TYPES := {
	"infantry": {
		"name": "Division d'Infanterie",
		"cost": 25.0,
		"attack": 28,
		"defense": 38,
		"max_mp": 2,
		"max_hp": 100,
		"range_deg": 6.5,
		"icon": "res://assets/military/infantry_squad.svg",
		"badge_icon": "infantry",
		"description": "Ligne de fusiliers en rangs serrés avec baïonnettes. Excellente défense urbaine."
	},
	"cavalry": {
		"name": "Division de Cavalerie",
		"cost": 45.0,
		"attack": 42,
		"defense": 24,
		"max_mp": 3,
		"max_hp": 110,
		"range_deg": 9.0,
		"icon": "res://assets/military/cavalry_mounted.svg",
		"badge_icon": "cavalry",
		"description": "Cuirassiers montés et sabres au clair. Mobilité et percée éclair."
	},
	"armor": {
		"name": "Division Blindée (Chars)",
		"cost": 55.0,
		"attack": 48,
		"defense": 26,
		"max_mp": 3,
		"max_hp": 120,
		"range_deg": 9.5,
		"icon": "res://assets/military/tank_armor.svg",
		"badge_icon": "armor",
		"description": "Blindés lourds d'assaut motorisés et fer de lance."
	},
	"artillery": {
		"name": "Batterie d'Artillerie",
		"cost": 40.0,
		"attack": 54,
		"defense": 18,
		"max_mp": 1,
		"max_hp": 85,
		"range_deg": 4.5,
		"icon": "res://assets/military/artillery_crew.svg",
		"badge_icon": "artillery",
		"description": "Pièces d'artillerie lourdes sur affût. Dévastateur contre villes et fortifications."
	}
}

static func roman_numeral(val: int) -> String:
	match val:
		1: return "I"
		2: return "II"
		3: return "III"
		4: return "IV"
		5: return "V"
		6: return "VI"
		7: return "VII"
		8: return "VIII"
		_: return "V"

static func create_unit(type: String, country_id: String, lon: float, lat: float, custom_name: String = "", stationed_city: String = "", has_general: bool = false, general_name: String = "") -> Dictionary:
	var def: Dictionary = TYPES.get(type, TYPES["infantry"])
	var unit_id := "U_%s_%d" % [country_id, randi() % 900000 + 100000]
	var unit_name := custom_name
	if unit_name.is_empty():
		unit_name = "%s %s" % [country_id, def.name]
	
	var rank := randi_range(2, 5)
	if has_general: rank = 5
	
	return {
		"id": unit_id,
		"name": unit_name,
		"type": type,
		"owner": country_id,
		"lon": lon,
		"lat": lat,
		"hp": int(def.max_hp),
		"max_hp": int(def.max_hp),
		"mp": int(def.max_mp),
		"max_mp": int(def.max_mp),
		"attack": int(def.attack),
		"defense": int(def.defense),
		"rank": rank,
		"chevrons": 2 if has_general else (1 if randf() > 0.4 else 0),
		"has_general": has_general,
		"general_name": general_name if has_general else "",
		"stationed_city": stationed_city
	}

static func resolve_combat(attacker: Dictionary, defender: Dictionary, in_city: bool = false) -> Dictionary:
	var atk_def_spec: Dictionary = TYPES.get(attacker.type, TYPES["infantry"])
	var def_def_spec: Dictionary = TYPES.get(defender.type, TYPES["infantry"])
	
	var atk_ratio := float(attacker.hp) / float(attacker.max_hp)
	var def_ratio := float(defender.hp) / float(defender.max_hp)
	
	var city_bonus := 1.35 if in_city else 1.0
	var gen_bonus_atk := 1.25 if bool(attacker.get("has_general", false)) else 1.0
	var gen_bonus_def := 1.25 if bool(defender.get("has_general", false)) else 1.0
	
	var atk_roll := (float(attacker.attack) * atk_ratio * gen_bonus_atk) * randf_range(0.85, 1.25)
	var def_roll := (float(defender.defense) * def_ratio * city_bonus * gen_bonus_def) * randf_range(0.85, 1.25)
	
	var damage_to_defender := clampi(int(atk_roll * 0.75), 10, 85)
	var damage_to_attacker := clampi(int(def_roll * 0.50), 5, 60)
	
	if attacker.type == "cavalry" or attacker.type == "armor":
		if not in_city: damage_to_defender = int(damage_to_defender * 1.2)
	if defender.type == "infantry" and in_city:
		damage_to_attacker = int(damage_to_attacker * 1.3)
	if attacker.type == "artillery":
		# Artillery deals long range barrage with less retaliatory damage taken
		damage_to_attacker = int(damage_to_attacker * 0.6)
	
	defender.hp = clampi(int(defender.hp) - damage_to_defender, 0, int(defender.max_hp))
	attacker.hp = clampi(int(attacker.hp) - damage_to_attacker, 0, int(attacker.max_hp))
	attacker.mp = 0
	
	var defender_destroyed := int(defender.hp) <= 0
	var attacker_destroyed := int(attacker.hp) <= 0
	var attacker_won := defender_destroyed and not attacker_destroyed
	
	return {
		"attacker_damage": damage_to_attacker,
		"defender_damage": damage_to_defender,
		"defender_destroyed": defender_destroyed,
		"attacker_destroyed": attacker_destroyed,
		"attacker_won": attacker_won
	}
