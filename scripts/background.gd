extends Sprite2D

@export var oscillate_distance: float = 120.0 # Amplitude (2 units)
@export var oscillation_speed: float = 0.05   # How fast it oscillates
@export var initial_offset: float = 0.0      # To start at a different point in the cycle

var initial_x: float
var time_elapsed: float = 0.0

func _ready():
	initial_x = global_position.x
	time_elapsed = initial_offset

func _process(delta):
	time_elapsed += delta * oscillation_speed

	# Calculate the new x position using a sine wave
	# sin() returns values between -1 and 1
	var offset = sin(time_elapsed) * oscillate_distance

	# Apply the offset to the initial x position
	global_position.x = initial_x + offset
