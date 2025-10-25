class_name LlmApi
extends Node

# Constants
const LLM_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
#const LLM_API_KEY = "<YOUR API KEY HERE>"

# Child nodes
@onready var http_request: HTTPRequest = $HTTPRequest

# Signals
signal message_received(response_text: String)

# Class variables (configuration)
@export var character_name: String = "you"

# State variables
var activity_history: Array[String] = []

func read_sys_prompt() -> String:
	return """# De-escalation Training Simulation

You are an angry and frustrated customer who has been waiting in line at a fancy restaurant for a long time.

The user is an employee in training.
"""

func interact(message: String):
	activity_history.append("[user] " + message)

	var body_dict = {
		"contents": [
			{
				"parts": [
					{
						"text": read_sys_prompt() + """
---

Standing in front of: """ + character_name + """

Activity History:
""" + "\n".join(activity_history) + """
Instruction:

- Provide a voice line from your character.
- The user is expected to respond to this in order to train their de-escalation response.
"""
					}
				]
			}
		],
		"generationConfig": {
			"thinkingConfig": {
				"thinkingBudget": 0 # disable reasoning for speed
			},
			"responseMimeType": "application/json",
			"responseSchema": {
				"type": "OBJECT",
				"properties": {
					#"is_game_over_good_ending": {"type": "BOOLEAN"},
					#"is_game_over_bad_ending": {"type": "BOOLEAN"},
					"voice_line": {"type": "STRING"}
				}
			}
		}
	}
	var body_json_string = JSON.stringify(body_dict)
	
	var headers = [
		"Content-Type: application/json",
		"x-goog-api-key: " + LLM_API_KEY # this is also injected by proxy
	]
	
	if http_request.request(LLM_API_URL, headers, HTTPClient.METHOD_POST, body_json_string) != OK:
		print_rich("[color=red]An error occurred while sending the LlmApi HTTP request.[/color]")
	
	print("LLM API: Request sent.")
	

func _ready() -> void:
	http_request.request_completed.connect(_on_request_completed)


func _on_request_completed(result, response_code, headers, body):
	var response = JSON.parse_string(body.get_string_from_utf8())
	var payload = JSON.parse_string(response["candidates"][0]["content"]["parts"][0]["text"])
	
	activity_history.append("[you] {%s}" % payload.voice_line)
	
	message_received.emit(payload.voice_line)
