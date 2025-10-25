extends AudioStreamPlayer

# --- Node References ---
@onready var record_button: Button = $RecordButton
@onready var play_button: Button = $PlayButton
@onready var print_button: Button = $PrintButton
@onready var status_label: Label = $Status
@onready var higgs_understanding_api: HiggsUnderstandingApi = $"../HiggsUnderstandingApi"

# --- State Variables ---
var effect
var recording: AudioStreamWAV

func _ready():

	# Get the "Record" bus effect
	var idx = AudioServer.get_bus_index("Record")
	effect = AudioServer.get_bus_effect(idx, 1)

	# Ensure playback/print buttons are disabled at start
	play_button.disabled = true
	print_button.disabled = true
	
	# --- Programmatically connect signals ---
	# We connect the "pressed" signal of each button to its handler function.
	record_button.pressed.connect(_on_record_button_pressed)
	play_button.pressed.connect(_on_play_button_pressed)
	print_button.pressed.connect(_on_print_button_pressed)
	# ----------------------------------------
	
	higgs_understanding_api.message_received.connect(
		func(message): print(message)
	)


func _on_record_button_pressed():
	if effect.is_recording_active():
		# --- Stop Recording ---
		recording = effect.get_recording()
		
		# Enable playback and print buttons
		play_button.disabled = false
		print_button.disabled = false 
		
		# Update UI
		effect.set_recording_active(false)
		record_button.text = "Record"
		status_label.text = "Recording stopped."
	else:
		# --- Start Recording ---
		# Clear previous recording and disable buttons
		recording = null
		play_button.disabled = true
		print_button.disabled = true 
		
		# Update UI
		effect.set_recording_active(true)
		record_button.text = "Stop"
		status_label.text = "Recording..."


func _on_play_button_pressed():
	if recording:
		# Since this script extends AudioStreamPlayer, 'self' is the player.
		self.stream = recording
		self.play()
	else:
		print("No recording available to play.")


func _on_print_button_pressed():
	var save_path = "/Users/james/Desktop/sample.wav"
	recording.save_to_wav(save_path)
	$Status.text = "Saved WAV file to: %s\n(%s)" % [save_path, ProjectSettings.globalize_path(save_path)]
	
	"""
	Converts the recorded audio data to Base64 and prints it to the console.
	"""
	if recording:
		# 1. Get the raw audio data (as a PackedByteArray)
		var data: PackedByteArray = recording.get_data()
		
		if data.is_empty():
			print("Recording is empty. Nothing to print.")
			return

		# 2. Convert the raw byte array to a Base64 string using Marshalls
		var base64_string: String = Marshalls.raw_to_base64(data)
		
		# 3. Print to the console for easy copying
		#print("--- BEGIN AUDIO BASE64 ---")
		#print(base64_string)
		#print("--- END AUDIO BASE64 ---")
		
		higgs_understanding_api.interact(["[user] Are you done here?\n[you] What do you think?"], base64_string)
	else:
		print("No recording data found. Press 'Record' first.")
