extends Node

# Integration script for Godot 4 (Autoload / Singleton)
# Handles communication with your Gwynbleidd developer API.

signal player_registered(success: bool, response_data: Dictionary)
signal player_logged_in(success: bool, response_data: Dictionary)
signal score_submitted(success: bool, response_data: Dictionary)
signal leaderboard_loaded(success: bool, scores: Array)
signal game_saved(success: bool, response_data: Dictionary)
signal game_loaded(success: bool, data: Dictionary)

#const API_BASE_URL = "http://localhost:4443" # For tests


# Configure these variables according to your dashboard settings
const API_BASE_URL = "https://gwynbleidd.pl" # Change to your API address
var GAME_ID: int = 1 # Your actual Game ID from the dashboard
var API_KEY = "ww_key_71ab0ff88fede4ea982dcedc57f047bfd33fcea59f8ec1279317fad398f2367af2e41b233d6905e8be5e76ef7737f0f073aba1a6"
var API_SECRET = "gw_secret_f42974150aef39118b5411af32286cf420869e90168eaee284931d0c62c898a6416378f88f" 

# Stores the session token of the logged-in player (if Require Authentication is enabled)
var player_token: String = ""

# Universal helper function to make HTTP requests
func _make_request(url: String, method: HTTPClient.Method, body: Dictionary, callback_name: String) -> void:
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self[callback_name].bind(http_request))
	
	# Prepare headers (API key authorization)
	# FastAPI automatically converts 'X-API-Key' to the 'x_api_key' dependency injection
	var headers = [
		"Content-Type: application/json",
		"X-API-Key: " + API_KEY
	]
	
	# If player is logged in, attach their session token
	if not player_token.is_empty():
		headers.append("Authorization: Bearer " + player_token)
		
	var query = JSON.stringify(body) if not body.is_empty() else ""
	var error = http_request.request(url, headers, method, query)
	
	if error != OK:
		push_error("Error initializing HTTP request: " + str(error))
		http_request.queue_free()

# Helper function to generate SHA256 hash in Godot 4
func _generate_sha256(input: String) -> String:
	var ctx = HashingContext.new()
	
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(input.to_utf8_buffer())
	
	var hash_bytes = ctx.finish()
	return hash_bytes.hex_encode()

func setup(api_key: String, api_secret: String, game_id: int) -> void:
	API_KEY = api_key
	API_SECRET = api_secret
	GAME_ID = game_id

# =====================================================================
# SECTION 1: PLAYER MANAGEMENT (REGISTER & LOGIN)
# =====================================================================

# Register a new player for this specific game
func register_player(username: String, password: String) -> void:
	var url = API_BASE_URL + "/api/godot/" + str(GAME_ID) + "/players/register"
	var payload = {
		"username": username,
		"password": password
	}
	_make_request(url, HTTPClient.METHOD_POST, payload, "_on_player_registration_completed")


func _on_player_registration_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest) -> void:
	http_node.queue_free()
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200 or response_code == 201:
		emit_signal("player_registered", true, response)
	else:
		var error_msg = response.get("detail", "Registration failed") if response else "Connection error"
		push_error("Player registration failed: " + error_msg)
		emit_signal("player_registered", false, {"error": error_msg})


# Log in an existing player to obtain a JWT token
func login_player(username: String, password: String) -> void:
	var url = API_BASE_URL + "/api/godot/" + str(GAME_ID) + "/players/login"
	var payload = {
		"username": username,
		"password": password
	}
	_make_request(url, HTTPClient.METHOD_POST, payload, "_on_player_login_completed")


func _on_player_login_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest) -> void:
	http_node.queue_free()
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200:
		if response.has("player_token"):
			player_token = response["player_token"]
		emit_signal("player_logged_in", true, response)
	else:
		var error_msg = response.get("detail", "Login failed") if response else "Connection error"
		push_error("Player login failed: " + error_msg)
		emit_signal("player_logged_in", false, {"error": error_msg})

# =====================================================================
# SECTION 2: LEADERBOARD SYSTEM
# =====================================================================

# Submit a high score safely using SHA256 hashing to verify integrity on the backend
func submit_score(player_name: String, score: int) -> void:
	var url = API_BASE_URL + "/api/godot/"+ str(GAME_ID) + "/scores"
	
	# Recreate the exact string signature matching your backend: f"{payload.player_name}:{payload.score}:"
	var raw_string = player_name + ":" + str(score) + ":" + API_SECRET
	var generated_hash = _generate_sha256(raw_string) 
	print("GODOT RAW STRING TO HASH: ", raw_string) 
	var payload = {
		"player_name": player_name,
		"score": score,
		"hash": generated_hash
	}
	_make_request(url, HTTPClient.METHOD_POST, payload, "_on_score_submitted")


func _on_score_submitted(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest) -> void:
	http_node.queue_free()
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200 or response_code == 201:
		emit_signal("score_submitted", true, response if response else {})
	else:
		var error_msg = response.get("detail", "Failed to save score") if response else "Network error"
		push_error("Score submission error: " + error_msg)
		emit_signal("score_submitted", false, {"error": error_msg})


# Fetch top high scores (optionally filtered by username query parameter)
func fetch_leaderboard(username_filter: String = "") -> void:
	var url = API_BASE_URL + "/api/godot/" + str(GAME_ID) + "/scores"
	if not username_filter.is_empty():
		url += "?username=" + username_filter.uri_encode()
		
	_make_request(url, HTTPClient.METHOD_GET, {}, "_on_leaderboard_loaded")

func _on_leaderboard_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest) -> void:
	http_node.queue_free()
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200 and response != null:
		var scores = response.get("scores", [])
		emit_signal("leaderboard_loaded", true, scores)
	else:
		push_error("Failed to retrieve leaderboard.")
		emit_signal("leaderboard_loaded", false, [])


# =====================================================================
# SECTION 3: SAVE DATA SYSTEM
# =====================================================================

# Sends a Dictionary containing game state data to the cloud save endpoint
func save_game_data(game_state: Dictionary) -> void:
	var url = API_BASE_URL + "/api/godot/" + str(GAME_ID) + "/save"
	var payload = {
		"data": game_state
	}
	_make_request(url, HTTPClient.METHOD_POST, payload, "_on_game_saved_completed")

func _on_game_saved_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest) -> void:
	http_node.queue_free()
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200:
		emit_signal("game_saved", true, response if response else {})
	else:
		var error_msg = response.get("detail", "Failed to save game data") if response else "Network error"
		push_error("Save data error: " + error_msg)
		emit_signal("game_saved", false, {"error": error_msg})

# Fetches the last saved cloud state for the authenticated player
func load_game_data() -> void:
	var url = API_BASE_URL + "/api/godot/" + str(GAME_ID) + "/save"
	_make_request(url, HTTPClient.METHOD_GET, {}, "_on_game_loaded_completed")

func _on_game_loaded_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest) -> void:
	http_node.queue_free()
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200 and response != null:
		emit_signal("game_loaded", true, response)
	else:
		push_error("Failed to load game data from cloud.")
		emit_signal("game_loaded", false, {})
