extends RefCounted
class_name WorldMapData

const CORE_ARCHIVE := "res://data/maps/admin_layers.zip"
const DEEP_ARCHIVES := [
	"res://data/maps/admin3_philippines.zip",
	"res://data/maps/admin3_other.zip",
	"res://data/maps/admin4.zip",
	"res://data/maps/admin5.zip"
]

static var _layer_cache: Dictionary = {}
static var _deep_cache: Dictionary = {}
static var _country_regions: Dictionary = {}
static var _regions_by_level_country: Dictionary = {}
static var _id_cache: Dictionary = {}
static var _manifest_cache: Dictionary = {}

static func load_layer(level: int) -> Array:
	if _layer_cache.has(level): return _layer_cache[level]
	if level < 0 or level > 2: return []
	var reader := ZIPReader.new()
	if reader.open(CORE_ARCHIVE) != OK:
		push_error("Unable to open the bundled GeoBoundaries world atlas.")
		return []
	var entry := "adm%d.topojson" % level
	var bytes := reader.read_file(entry)
	reader.close()
	if bytes.is_empty():
		push_error("Missing GeoBoundaries layer: " + entry)
		return []
	var topology = JSON.parse_string(bytes.get_string_from_utf8())
	if not topology is Dictionary:
		push_error("Invalid TopoJSON layer: " + entry)
		return []
	var result := _decode_topology(topology, level, "")
	_layer_cache[level] = result
	for feature in result: _id_cache[str(feature.id)] = feature
	if level == 1: _index_adm1_by_country(result)
	if level == 2: _assign_adm2_parents(result)
	return result

static func load_deepest_country(country_code: String) -> Dictionary:
	if _deep_cache.has(country_code): return _deep_cache[country_code]
	var code := country_code.to_upper()
	for archive_path in DEEP_ARCHIVES:
		var reader := ZIPReader.new()
		if reader.open(archive_path) != OK: continue
		var entries := reader.get_files()
		for level in [5, 4, 3]:
			var entry := "%s_ADM%d.topojson" % [code, level]
			if entries.has(entry):
				var bytes := reader.read_file(entry)
				reader.close()
				var topology = JSON.parse_string(bytes.get_string_from_utf8())
				if topology is Dictionary:
					var features := _decode_topology(topology, level, code)
					_assign_deep_parents(features, code)
					var result := {"level": level, "features": features}
					_deep_cache[code] = result
					for feature in features: _id_cache[str(feature.id)] = feature
					return result
		reader.close()
	_deep_cache[code] = {}
	return {}

static func feature_by_id(id: String) -> Dictionary:
	if _id_cache.has(id): return _id_cache[id]
	for level in [0, 1, 2]: load_layer(level)
	return _id_cache.get(id, {})

static func max_level_for_country(country_code: String) -> int:
	var result := load_deepest_country(country_code)
	if not result.is_empty(): return int(result.level)
	return 2

static func metadata_for(country_code: String, level: int) -> Dictionary:
	if _manifest_cache.is_empty():
		var manifest_file := FileAccess.open("res://data/maps/geoboundaries_manifest.json", FileAccess.READ)
		if manifest_file == null: return {}
		var parsed = JSON.parse_string(manifest_file.get_as_text())
		manifest_file.close()
		if not parsed is Array: return {}
		for row in parsed:
			_manifest_cache["%s-%s" % [str(row.get("iso", "")).to_upper(), str(row.get("level", ""))]] = row
	return _manifest_cache.get("%s-ADM%d" % [country_code.to_upper(), level], {})

static func _decode_topology(topology: Dictionary, level: int, country_filter: String) -> Array:
	var objects: Dictionary = topology.get("objects", {})
	if objects.is_empty(): return []
	var object: Dictionary = objects[objects.keys()[0]]
	var geometries: Array = object.get("geometries", []) if object.get("type", "") == "GeometryCollection" else [object]
	var source_arcs: Array = topology.get("arcs", [])
	var transform: Dictionary = topology.get("transform", {})
	var scale := Vector2(float(transform.get("scale", [1.0, 1.0])[0]), float(transform.get("scale", [1.0, 1.0])[1]))
	var translate := Vector2(float(transform.get("translate", [0.0, 0.0])[0]), float(transform.get("translate", [0.0, 0.0])[1]))
	var decoded_arcs: Array = []
	decoded_arcs.resize(source_arcs.size())
	var result: Array = []
	for i in geometries.size():
		var geometry: Dictionary = geometries[i]
		var properties: Dictionary = geometry.get("properties", {})
		var country_code := str(properties.get("shapeGroup", country_filter)).to_upper()
		if country_filter != "" and country_code != country_filter: continue
		var geometry_type := str(geometry.get("type", ""))
		if geometry_type != "Polygon" and geometry_type != "MultiPolygon": continue
		var raw_polygons: Array = [geometry.get("arcs", [])] if geometry_type == "Polygon" else geometry.get("arcs", [])
		var polygons: Array = []
		var bounds := Rect2(Vector2(INF, INF), Vector2(-INF, -INF))
		var center_sum := Vector2.ZERO
		var center_count := 0
		var has_bounds := false
		for raw_polygon in raw_polygons:
			var rings: Array = []
			for raw_ring in raw_polygon:
				var ring := _join_ring(raw_ring, source_arcs, decoded_arcs, scale, translate)
				if ring.size() < 3: continue
				if ring.size() > 3 and ring[0].is_equal_approx(ring[ring.size() - 1]): ring.remove_at(ring.size() - 1)
				rings.append(ring)
				if rings.size() == 1:
					for point in ring:
						if not has_bounds:
							bounds = Rect2(point, Vector2.ZERO)
							has_bounds = true
						else:
							bounds = bounds.expand(point)
						center_sum += point
						center_count += 1
			if not rings.is_empty(): polygons.append(rings)
		if polygons.is_empty(): continue
		var fallback_id := "%s_%05d" % [country_code, i]
		var source_id := str(properties.get("shapeID", ""))
		var feature_id := country_code if level == 0 else "ADM%d_%s" % [level, source_id if source_id != "" else fallback_id]
		var parent_id := "" if level == 0 else (country_code if level == 1 else "")
		var center := center_sum / maxf(1.0, float(center_count))
		var feature := {
			"id": feature_id,
			"name": str(properties.get("shapeName", country_code)),
			"country_code": country_code,
			"admin_level": level,
			"parent_id": parent_id,
			"polygons": polygons,
			"bounds": bounds,
			"lon": center.x,
			"lat": center.y,
			"triangles": []
		}
		result.append(feature)
	return result

static func _join_ring(references: Array, source_arcs: Array, decoded_arcs: Array, scale: Vector2, translate: Vector2) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for reference in references:
		var arc_index := int(reference) if int(reference) >= 0 else -int(reference) - 1
		if arc_index < 0 or arc_index >= source_arcs.size(): continue
		if decoded_arcs[arc_index] == null:
			decoded_arcs[arc_index] = _decode_arc(source_arcs[arc_index], scale, translate)
		var arc: PackedVector2Array = decoded_arcs[arc_index]
		var reversed := int(reference) < 0
		var start := arc.size() - 1 if reversed else 0
		var finish := -1 if reversed else arc.size()
		var step := -1 if reversed else 1
		for point_index in range(start, finish, step):
			if ring.is_empty() or point_index != start: ring.append(arc[point_index])
	return ring

static func _decode_arc(raw_arc: Array, scale: Vector2, translate: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var x := 0
	var y := 0
	for pair in raw_arc:
		x += int(pair[0]); y += int(pair[1])
		result.append(Vector2(float(x) * scale.x + translate.x, float(y) * scale.y + translate.y))
	return result

static func _index_adm1_by_country(features: Array) -> void:
	_country_regions.clear()
	_regions_by_level_country[1] = {}
	for feature in features:
		var code := str(feature.country_code)
		if not _country_regions.has(code): _country_regions[code] = []
		_country_regions[code].append(feature)
		if not _regions_by_level_country[1].has(code): _regions_by_level_country[1][code] = []
		_regions_by_level_country[1][code].append(feature)

static func _index_adm2_by_country(features: Array) -> void:
	var by_country: Dictionary = {}
	for feature in features:
		var code := str(feature.country_code)
		if not by_country.has(code): by_country[code] = []
		by_country[code].append(feature)
	_regions_by_level_country[2] = by_country

static func _assign_adm2_parents(features: Array) -> void:
	if not _layer_cache.has(1): return
	for feature in features:
		var country := str(feature.country_code)
		var candidates: Array = _country_regions.get(country, [])
		var center := Vector2(float(feature.lon), float(feature.lat))
		for parent in candidates:
			if not parent.bounds.has_point(center): continue
			if _feature_contains(parent, center):
				feature.parent_id = parent.id
				break
	_index_adm2_by_country(features)

static func _assign_deep_parents(features: Array, country_code: String) -> void:
	var candidates: Array = _regions_by_level_country.get(2, {}).get(country_code, [])
	if candidates.is_empty(): candidates = _regions_by_level_country.get(1, {}).get(country_code, [])
	for feature in features:
		var center := Vector2(float(feature.lon), float(feature.lat))
		for parent in candidates:
			if not parent.bounds.has_point(center): continue
			if _feature_contains(parent, center):
				feature.parent_id = parent.id
				break

static func _feature_contains(feature: Dictionary, point: Vector2) -> bool:
	for polygon in feature.polygons:
		if polygon.is_empty(): continue
		if Geometry2D.is_point_in_polygon(point, polygon[0]): return true
	return false
