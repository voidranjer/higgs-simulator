extends Node2D

@onready var higgs_audio_streamer: HiggsAudioStreamer = $HiggsAudioStreamer
@onready var llm_api: LlmApi = $LlmApi

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	llm_api.message_received.connect(
		func(voice_line: String): higgs_audio_streamer.speak(voice_line, "walter")
	)
	
	llm_api.interact("What's up?")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
