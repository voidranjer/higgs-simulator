extends Control

@onready var feedback_text: RichTextLabel = $MarginContainer/FeedbackText

## How long the fade-in effect should take, in seconds.
@export var fade_in_duration: float = 2.0

var has_handled_feedback = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	feedback_text.parse_bbcode(globals.feedback_bbcode)
	
	# Start the text as fully transparent
	feedback_text.modulate.a = 0.0
	
	# Create a new Tween to animate the fade-in
	var tween = create_tween()
	
	# Animate the 'modulate:a' property (the alpha channel) from 0.0 to 1.0
	# This makes the text fade from transparent to opaque
	tween.tween_property(feedback_text, "modulate:a", 1.0, fade_in_duration)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
