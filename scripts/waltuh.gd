extends Node2D

@onready var mouth: Sprite2D = $Mouth
@onready var higgs_audio_streamer: HiggsAudioStreamer = $HiggsAudioStreamer
@onready var chat_bubble: Sprite2D = $ChatBubble

# The minimum "squash" of the mouth (closed)
@export var min_scale_y = 0.1
# The maximum "stretch" of the mouth (open)
@export var max_scale_y = 1.5
# How smoothly the mouth animates (higher is faster)
@export var smoothing = 15.0

var mouth_bus_index: int
# Store the original X scale so we only change Y
var base_scale_x: float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Find the audio bus we created ("MouthBus") by its name
	mouth_bus_index = AudioServer.get_bus_index("Master")
	
	# Store the starting X scale
	base_scale_x = mouth.scale.x
	
	# Set the mouth to its closed state initially
	mouth.scale.y = min_scale_y
	
	higgs_audio_streamer.finished_playing_audio.connect(
		func(): chat_bubble.hide()
	)


func _process(delta: float) -> void:
	if higgs_audio_streamer.audio_player == null || not higgs_audio_streamer.audio_player.playing:
		# If no audio, keep the mouth closed
		mouth.scale.y = lerp(mouth.scale.y, min_scale_y, delta * smoothing)
		return

	# 1. Get Amplitude (Using Godot 4.1 functions)
	# CORRECTED: The audio is Mono, so we only read from channel 0.
	# We use "get_bus_peak_volume_left_db" as it's the function for channel 0.
	var volume_db: float = AudioServer.get_bus_peak_volume_left_db(mouth_bus_index, 0)
	
	# 2. Convert to Linear
	# (We no longer need the max() check)
	var amplitude: float = db_to_linear(volume_db)

	# 3. Map to Mouth Scale
	# Use lerp() to map the 0.0-1.0 amplitude to our min/max mouth scales.
	var target_scale_y: float = lerp(min_scale_y, max_scale_y, amplitude)

	# 4. Apply with Smoothing
	# Instead of snapping, smoothly "lerp" the current scale
	# towards the target scale. This looks much more natural.
	mouth.scale.y = lerp(mouth.scale.y, target_scale_y, delta * smoothing)
	
	# Ensure the X scale never changes
	mouth.scale.x = base_scale_x

func speak(text_to_speak: String):
	chat_bubble.show()
	higgs_audio_streamer.speak(text_to_speak, "walter")
