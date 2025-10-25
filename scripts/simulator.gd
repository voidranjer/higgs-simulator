extends Node2D

@onready var walter_streamer: Node = $Waltuh/HiggsAudioStreamer
@onready var llm_api: LlmApi = $LlmApi
@onready var transcript_receiver: TranscriptReceiver = $TranscriptReceiver

var is_player_turn: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	llm_api.message_received.connect(
		func(voice_line: String): walter_streamer.speak(voice_line, "walter")
	)
	transcript_receiver.transcript_received.connect(
		func(message: String): llm_api.interact(message)
	)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_player_turn:
		is_player_turn = true
