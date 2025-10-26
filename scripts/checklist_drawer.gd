# UI.gd (attached to the CanvasLayer node)

extends CanvasLayer

# --- Node References ---
# Assign these in the Inspector by dragging the nodes
@onready var menu_button: Button = $MenuButton
@onready var checklist_panel: PanelContainer = $ChecklistPanel

# --- Animation Properties ---
@export var slide_duration: float = 0.5  # How long the slide takes in seconds

# --- Position Variables ---
var offscreen_position: Vector2
var onscreen_position: Vector2
var is_menu_visible: bool = false

func _ready() -> void:
	# 1. Calculate positions based on screen and panel size
	var screen_width = get_viewport().get_visible_rect().size.x
	var panel_width = checklist_panel.size.x
	
	# The panel will be aligned to the top-right
	onscreen_position = Vector2(screen_width - panel_width, 0)
	offscreen_position = Vector2(screen_width, 0) # Fully hidden to the right
	
	# 2. Set the initial state: panel hidden off-screen
	checklist_panel.position = offscreen_position
	
	# 3. Connect the button's "pressed" signal to our function
	menu_button.pressed.connect(_on_menu_button_pressed)


# This function is called when the button is clicked
func _on_menu_button_pressed() -> void:
	# Toggle the menu's visibility state
	is_menu_visible = not is_menu_visible
	
	if is_menu_visible:
		slide_in()
	else:
		slide_out()


# Function to slide the panel ON-screen
func slide_in() -> void:
	# Create a new Tween (Godot's system for animation)
	var tween = create_tween()
	
	# Animate the 'position' property of the panel
	# from its current position to the 'onscreen_position'
	# over 'slide_duration' seconds.
	tween.tween_property(
		checklist_panel,                # The node to animate
		"position",                     # The property to animate
		onscreen_position,              # The final value
		slide_duration                  # The duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# .set_ease/set_trans makes the animation look smooth (e.g., slows down at the end)


# Function to slide the panel OFF-screen
func slide_out() -> void:
	var tween = create_tween()
	
	# Animate the 'position' property back to the 'offscreen_position'
	tween.tween_property(
		checklist_panel,
		"position",
		offscreen_position,
		slide_duration
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
