extends Node2D

@onready var walter_streamer: Node = $Waltuh/HiggsAudioStreamer
@onready var llm_api: LlmApi = $LlmApi
@onready var transcript_receiver: TranscriptReceiver = $TranscriptReceiver
@onready var aggression_meter: ProgressBar = $AggressionMeter

var is_player_turn: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	llm_api.message_received.connect(
		func(voice_line: String): walter_streamer.speak(voice_line, "walter")
	)
	transcript_receiver.transcript_received.connect(
		func(message: String): llm_api.interact(message)
	)
	
	aggression_meter.init_health(10)
	aggression_meter.health = 7

	#walter_streamer.speak("""It is 8:10 PM at The Higgs Bistro. Beyond your polished podium, the main dining room glows with warm light, filled with the soft clinking of crystal and the polite murmur of conversation.
#
#But here in the foyer, the air is tense. It is crowded. You are the Maître d', and you know you are running significantly behind schedule.
#
#A man who has been standing stiffly by the door, checking his watch every few minutes, finally sighs loud enough to be heard. He leaves his partner's side and strides toward you. His face is a tight mask of frustration. He stops directly in front of your podium and says, in a low, tight voice:
#
#'This is completely unacceptable. Our reservation was for 7:30. It is now 8:10. We are waiting 40 minutes for a table we booked weeks ago for our anniversary. What exactly is going on here?'
	#""", "walter")
	
	#llm_api.interact("Good evening.")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#if not is_player_turn:
		#is_player_turn = true
	pass
