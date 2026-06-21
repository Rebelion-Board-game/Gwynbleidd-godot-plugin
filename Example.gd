extends Node

func _ready():
	# Connect to the signals from our API helper
	GwynbleiddApi.player_registered.connect(_on_user_registered)
	GwynbleiddApi.score_submitted.connect(_on_score_submitted)
	GwynbleiddApi.leaderboard_loaded.connect(_on_leaderboard_loaded)
	
	# Connect save system signals
	GwynbleiddApi.game_saved.connect(_on_game_saved)
	GwynbleiddApi.game_loaded.connect(_on_game_loaded)
	
	var api_key = "ww_key_356d27ddf87ff2c0407cad0298171a43c5ee9a4176380c0d427adf7f95ee626852817247ccc4c9ea5977b783753d8459c10545a041378c445e43f65e591aea11"
	var api_secret = "gw_secret_42f308ec885c5999f293f10b6de7f527152fe27c089d9dc8806dad49dfb1d3f4c2cfb36866fafcd83ded1a21a9aceaa8200e9512ba7772442efd9c8b445e971a"
	
	GwynbleiddApi.setup(api_key,api_secret,8)
	
	# Submit score to leaderboard without authorization
	GwynbleiddApi.submit_score("geralt",2000)
	
	# Download leaderboard
	GwynbleiddApi.fetch_leaderboard()
	
	# Register User
	GwynbleiddApi.register_player("test","dupsko1234")
	
	# WAIT for the registration signal before moving forward
	var reg_result = await GwynbleiddApi.player_registered
	
	if reg_result[0]:
		print("Registration complete! Now attempting login...")
	else:
		push_error("Registration failed")
	
	await get_tree().create_timer(0.1).timeout # wait for baceknd to process registraion
	
	# 3. Try login with wrong password
	GwynbleiddApi.login_player("test", "wrongpassword")
	var login_fail_res = await GwynbleiddApi.player_logged_in
	print("Login with wrong password success status: ", login_fail_res[0]) # Should be false
	
	# 4. Try login with correct password
	GwynbleiddApi.login_player("test", "dupsko1234")
	var login_success_res = await GwynbleiddApi.player_logged_in
	print("Login with correct password success status: ", login_success_res[0]) # Should be true
	
	# =====================================================================
	# NEW: TESTING CLOUD SAVE SYSTEM (Requires valid login_success_res)
	# =====================================================================
	if login_success_res[0]:
		print("\n--- Starting Cloud Save Tests ---")
		
		# Create a dummy game state dictionary to save
		var dummy_save_state = {
			"level": 14,
			"health": 85.5,
			"gold": 420,
			"inventory": ["silver_sword", "swallow_potion", "gwent_card_geralt"]
		}
		
		print("Attempting to upload save data...")
		GwynbleiddApi.save_game_data(dummy_save_state)
		
		# Wait for save confirmation
		var save_res = await GwynbleiddApi.game_saved
		if save_res[0]:
			print("Save confirmation received via await.")
			
			# Now let's try to load it back
			print("Attempting to download save data...")
			GwynbleiddApi.load_game_data()


func _on_user_registered(success: bool, data: Dictionary):
	if success:
		print("Player successfully registered/logged in!")
	else:
		print("Player registration failed: ", data.get("error"))

func _on_score_submitted(success: bool, data: Dictionary):
	if success:
		print("Score successfully saved on the server!")

func _on_leaderboard_loaded(success: bool, scores: Array):
	if success:
		print("Leaderboard loaded successfully:")
		for entry in scores:
			print(entry["player_name"], ": ", entry["score"])

func _on_game_saved(success: bool, response_data: Dictionary):
	if success:
		print("Callback: Save synchronized with cloud.")
	else:
		print("Callback: Save failed: ", response_data.get("error"))

func _on_game_loaded(success: bool, data: Dictionary):
	if success:
		print("Callback: Load finished. Cloud state data: ", data.get("data", {}))
	else:
		print("Callback: Load failed.")
