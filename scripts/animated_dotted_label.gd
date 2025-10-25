extends Label

@onready var timer: Timer = $Timer

# This array holds the animation "frames"
var dot_animation = ["", ".", "..", "..."]
var current_step = 0

func _ready():
	# Connect the timer's "timeout" signal to our function
	timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout():
	# Advance to the next step
	current_step = (current_step + 1) % dot_animation.size()
	
	# Update the label's text
	text = dot_animation[current_step]
