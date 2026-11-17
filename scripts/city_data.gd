extends RefCounted
class_name CityData

# Database of world cities with historical fortifications and industrial tiers
static func get_default_cities() -> Array:
	return [
		# Western Europe (Matches the screenshot regions: Metz, Nancy, Karlsruhe, Jena, Weilburg, Wiesbaden, etc.)
		{"id": "METZ", "name": "METZ", "country_code": "FRA", "lon": 6.1757, "lat": 49.1193, "type": "city", "tier": 2, "has_fort": true, "population": 1.2, "income": 14.0, "defense": 30},
		{"id": "NANCY", "name": "NANCY", "country_code": "FRA", "lon": 6.1844, "lat": 48.6921, "type": "city", "tier": 4, "has_fort": false, "population": 1.4, "income": 16.0, "defense": 20},
		{"id": "PARIS", "name": "PARIS", "country_code": "FRA", "lon": 2.3522, "lat": 48.8566, "type": "capital", "tier": 5, "has_fort": true, "population": 2.8, "income": 26.0, "defense": 35},
		{"id": "MARSEILLE", "name": "MARSEILLE", "country_code": "FRA", "lon": 5.3698, "lat": 43.2965, "type": "city", "tier": 3, "has_fort": true, "population": 1.2, "income": 12.0, "defense": 20},
		{"id": "LYON", "name": "LYON", "country_code": "FRA", "lon": 4.8357, "lat": 45.7640, "type": "city", "tier": 3, "has_fort": false, "population": 1.1, "income": 13.0, "defense": 20},

		# Germanic / Central Europe
		{"id": "KARLSRUHE", "name": "KARLSRUHE", "country_code": "DEU", "lon": 8.4037, "lat": 49.0069, "type": "city", "tier": 5, "has_fort": true, "population": 1.5, "income": 18.0, "defense": 28},
		{"id": "WEILBURG", "name": "WEILBURG", "country_code": "DEU", "lon": 8.2612, "lat": 50.4851, "type": "city", "tier": 2, "has_fort": false, "population": 0.8, "income": 10.0, "defense": 15},
		{"id": "WIESBADEN", "name": "WIESBADEN", "country_code": "DEU", "lon": 8.2417, "lat": 50.0820, "type": "city", "tier": 3, "has_fort": true, "population": 1.1, "income": 14.0, "defense": 22},
		{"id": "JENA", "name": "JENA", "country_code": "DEU", "lon": 11.5899, "lat": 50.9272, "type": "city", "tier": 4, "has_fort": false, "population": 1.0, "income": 12.0, "defense": 18},
		{"id": "BERLIN", "name": "BERLIN", "country_code": "DEU", "lon": 13.4050, "lat": 52.5200, "type": "capital", "tier": 5, "has_fort": true, "population": 4.3, "income": 28.0, "defense": 35},
		{"id": "MUNICH", "name": "MÜNCHEN", "country_code": "DEU", "lon": 11.5820, "lat": 48.1351, "type": "city", "tier": 4, "has_fort": false, "population": 1.5, "income": 16.0, "defense": 20},
		{"id": "HAMBURG", "name": "HAMBURG", "country_code": "DEU", "lon": 9.9937, "lat": 53.5511, "type": "city", "tier": 4, "has_fort": true, "population": 1.6, "income": 18.0, "defense": 25},

		# British Isles
		{"id": "LONDON", "name": "LONDON", "country_code": "GBR", "lon": -0.1278, "lat": 51.5074, "type": "capital", "tier": 5, "has_fort": true, "population": 4.2, "income": 30.0, "defense": 35},
		{"id": "MANCHESTER", "name": "MANCHESTER", "country_code": "GBR", "lon": -2.2426, "lat": 53.4808, "type": "city", "tier": 4, "has_fort": false, "population": 1.4, "income": 18.0, "defense": 15},
		{"id": "EDINBURGH", "name": "EDINBURGH", "country_code": "GBR", "lon": -3.1883, "lat": 55.9533, "type": "city", "tier": 3, "has_fort": true, "population": 0.9, "income": 12.0, "defense": 25},

		# Southern Europe
		{"id": "ROMA", "name": "ROMA", "country_code": "ITA", "lon": 12.4964, "lat": 41.9028, "type": "capital", "tier": 5, "has_fort": true, "population": 2.5, "income": 20.0, "defense": 30},
		{"id": "MILANO", "name": "MILANO", "country_code": "ITA", "lon": 9.1900, "lat": 45.4642, "type": "city", "tier": 4, "has_fort": false, "population": 1.8, "income": 18.0, "defense": 20},
		{"id": "MADRID", "name": "MADRID", "country_code": "ESP", "lon": -3.7038, "lat": 40.4168, "type": "capital", "tier": 4, "has_fort": true, "population": 2.0, "income": 16.0, "defense": 25},
		{"id": "BARCELONA", "name": "BARCELONA", "country_code": "ESP", "lon": 2.1734, "lat": 41.3851, "type": "city", "tier": 3, "has_fort": true, "population": 1.6, "income": 15.0, "defense": 20},
		{"id": "LISBOA", "name": "LISBOA", "country_code": "PRT", "lon": -9.1393, "lat": 38.7223, "type": "capital", "tier": 3, "has_fort": true, "population": 1.1, "income": 12.0, "defense": 20},

		# Eastern Europe & Russia
		{"id": "MOSKVA", "name": "MOSKVA", "country_code": "RUS", "lon": 37.6173, "lat": 55.7558, "type": "capital", "tier": 5, "has_fort": true, "population": 4.5, "income": 30.0, "defense": 40},
		{"id": "LENINGRAD", "name": "LENINGRAD", "country_code": "RUS", "lon": 30.3609, "lat": 59.9311, "type": "city", "tier": 5, "has_fort": true, "population": 3.0, "income": 24.0, "defense": 35},
		{"id": "STALINGRAD", "name": "STALINGRAD", "country_code": "RUS", "lon": 44.5133, "lat": 48.7080, "type": "city", "tier": 4, "has_fort": true, "population": 1.5, "income": 18.0, "defense": 30},
		{"id": "WARSZAWA", "name": "WARSZAWA", "country_code": "POL", "lon": 21.0122, "lat": 52.2297, "type": "capital", "tier": 4, "has_fort": true, "population": 2.1, "income": 16.0, "defense": 25},
		{"id": "WIEN", "name": "WIEN", "country_code": "AUT", "lon": 16.3738, "lat": 48.2082, "type": "capital", "tier": 4, "has_fort": true, "population": 1.9, "income": 18.0, "defense": 25},
		{"id": "BRUXELLES", "name": "BRUXELLES", "country_code": "BEL", "lon": 4.3517, "lat": 50.8503, "type": "capital", "tier": 4, "has_fort": true, "population": 1.3, "income": 15.0, "defense": 20},
		{"id": "AMSTERDAM", "name": "AMSTERDAM", "country_code": "NLD", "lon": 4.9041, "lat": 52.3676, "type": "capital", "tier": 4, "has_fort": true, "population": 1.2, "income": 16.0, "defense": 20},

		# North America
		{"id": "WASHINGTON", "name": "WASHINGTON", "country_code": "USA", "lon": -77.0369, "lat": 38.9072, "type": "capital", "tier": 5, "has_fort": true, "population": 3.5, "income": 32.0, "defense": 35},
		{"id": "NEW_YORK", "name": "NEW YORK", "country_code": "USA", "lon": -74.0060, "lat": 40.7128, "type": "city", "tier": 5, "has_fort": true, "population": 7.4, "income": 38.0, "defense": 25},
		{"id": "CHICAGO", "name": "CHICAGO", "country_code": "USA", "lon": -87.6298, "lat": 41.8781, "type": "city", "tier": 4, "has_fort": false, "population": 3.8, "income": 26.0, "defense": 20},
		{"id": "OTTAWA", "name": "OTTAWA", "country_code": "CAN", "lon": -75.6972, "lat": 45.4215, "type": "capital", "tier": 4, "has_fort": false, "population": 1.2, "income": 16.0, "defense": 20},

		# Asia
		{"id": "TOKYO", "name": "TOKYO", "country_code": "JPN", "lon": 139.6503, "lat": 35.6762, "type": "capital", "tier": 5, "has_fort": true, "population": 5.8, "income": 32.0, "defense": 35},
		{"id": "BEIJING", "name": "BEIPING", "country_code": "CHN", "lon": 116.4074, "lat": 39.9042, "type": "capital", "tier": 5, "has_fort": true, "population": 3.5, "income": 22.0, "defense": 30},
		{"id": "SHANGHAI", "name": "SHANGHAI", "country_code": "CHN", "lon": 121.4737, "lat": 31.2304, "type": "city", "tier": 5, "has_fort": true, "population": 4.0, "income": 28.0, "defense": 25},
		{"id": "NEW_DELHI", "name": "NEW DELHI", "country_code": "IND", "lon": 77.2090, "lat": 28.6139, "type": "capital", "tier": 4, "has_fort": true, "population": 2.5, "income": 18.0, "defense": 25},

		# Africa & Middle East
		{"id": "CAIRO", "name": "AL QAHIRAH", "country_code": "EGY", "lon": 31.2357, "lat": 30.0444, "type": "capital", "tier": 4, "has_fort": true, "population": 2.2, "income": 18.0, "defense": 25},
		{"id": "ALGIERS", "name": "ALGER", "country_code": "DZA", "lon": 3.0588, "lat": 36.7538, "type": "capital", "tier": 3, "has_fort": true, "population": 1.1, "income": 12.0, "defense": 20}
	]

static func get_capital_for_country(country_code: String) -> Dictionary:
	var code := country_code.to_upper()
	for city in get_default_cities():
		if str(city.country_code).to_upper() == code and str(city.type) == "capital":
			return city
	for city in get_default_cities():
		if str(city.country_code).to_upper() == code:
			return city
	return {}
