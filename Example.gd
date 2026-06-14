extends Node

func _ready():
	# Connect to the signals from our API helper
	GwynbleiddApi.player_registered.connect(_on_user_registered)
	GwynbleiddApi.score_submitted.connect(_on_score_submitted)
	GwynbleiddApi.leaderboard_loaded.connect(_on_leaderboard_loaded)
	
	var api_key = "ww_key_"
	var api_secret = "gw_secret_"
	
	GwynbleiddApi.setup(api_key,api_secret,1)
	
	# Submit score to leaderboard without authorization
	GwynbleiddApi.submit_score("geralt",2000)
	
	# Download leaderboard
	GwynbleiddApi.fetch_leaderboard()
	
	# Register User
	GwynbleiddApi.register_player("test","dupsko1234")
	
	# WAIT for the registration signal before moving forward
	var reg_result = await GwynbleiddApi.player_registered
	
	if reg_result[0]: # If success == true
		print("Registration complete! Now attempting login...")
		
		# 3. Try login with wrong password
		GwynbleiddApi.login_player("test", "wrongpassword")
		var login_fail_res = await GwynbleiddApi.player_logged_in
		print("Login with wrong password success status: ", login_fail_res[0]) # Should be false
		
		# 4. Try login with correct password
		GwynbleiddApi.login_player("test", "dupsko1234")
		var login_success_res = await GwynbleiddApi.player_logged_in
		print("Login with correct password success status: ", login_success_res[0]) # Should be true
	else:
		print("Registration failed: ", reg_result[1])


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
