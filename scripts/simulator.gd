extends Node2D

@onready var walter: Node = $Waltuh
@onready var llm_api: LlmApi = $LlmApi
@onready var transcript_receiver: TranscriptReceiver = $TranscriptReceiver
@onready var aggression_meter: ProgressBar = $AggressionMeter

var is_player_turn: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	llm_api.message_received.connect(
		func(voice_line: String): walter.speak(voice_line)
	)
	transcript_receiver.transcript_received.connect(
		func(message: String): llm_api.interact(message)
	)
	llm_api.aggression_level_changed.connect(
		func(new_level: int): aggression_meter.health = new_level
	)
	
	aggression_meter.init_health(10)
	aggression_meter.health = 7
	
	llm_api.interact("<|initial|>")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#if not is_player_turn:
		#is_player_turn = true
	pass


func _on_button_pressed() -> void:
	llm_api.interact("<|feedback|>")
	#get_tree().change_scene_to_file("res://scenes/video_stream_player.tscn")
