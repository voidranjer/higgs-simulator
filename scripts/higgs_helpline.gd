extends Node2D

@onready var morgan: Node2D = $TalkingHead
@onready var llm_api_2: LlmApi2 = $LlmApi2
@onready var transcript_receiver: TranscriptReceiver = $TranscriptReceiver
@onready var checklist_drawer: CanvasLayer = $ChecklistDrawer

func handle_checklist_update(new_checklist):
	var all_trues = true
	for i in range(new_checklist.size()):
		if not new_checklist[i]:
			all_trues = false
			break
	if all_trues:
		get_tree().change_scene_to_file("res://scenes/morgan_dancing.tscn")
	
	checklist_drawer.set_checklist_values(new_checklist)
	
	# Pop open the drawer programatically
	checklist_drawer._on_menu_button_pressed()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	llm_api_2.message_received.connect(
		func(voice_line: String): morgan.speak(voice_line)
	)
	llm_api_2.checklist_updated.connect(handle_checklist_update)
	transcript_receiver.transcript_received.connect(
		func(message: String): llm_api_2.interact(message)
	)
	
	llm_api_2.interact("<|initial|>")
