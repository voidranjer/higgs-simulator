class_name HiggsUnderstandingApi
extends Node


# Constants
const API_URL = "https://hackathon.boson.ai/v1/chat/completions"
#const API_KEY = "<YOUR API KEY HERE>"
const API_KEY = "bai-yj3wI91TdtKP1iOSwQJSInyxRnz5x4kgz8kO35TVMPetK-kF"

# Child nodes
@onready var http_request: HTTPRequest = $HTTPRequest

# Signals
signal message_received(response_text: String)

func read_sys_prompt() -> String:
	return """# De-escalation Training Simulation

You are an angry and frustrated customer who has been waiting in line at a fancy restaurant for a long time.

The user is an employee in training.
"""

func interact(conversation_history: Array[String], audio_b64: String):
	var body_dict = {
		"model": "higgs-audio-understanding-Hackathon",
		"messages": [
			{"role": "system", "content": read_sys_prompt() + """
---

Activity History:
""" + "\n".join(conversation_history) + """
Instruction:

- Evaluate from the scale of 1 to 5, how well the user has de-escalated the situation.
- Include in your evaluation how patient and kind the user's tone is.
"""},
{
		"role": "user",
		"content": [
		  {
			"type": "input_audio",
			"input_audio": {
			  "data": audio_b64,
			  "format": "wav"
			}
		  }
		]
	  }
		],
	"max_completion_tokens": 256,
	"temperature": 0.0
	}
	var body_json_string = JSON.stringify(body_dict)
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + API_KEY # this is also injected by proxy
	]
	
	if http_request.request(API_URL, headers, HTTPClient.METHOD_POST, body_json_string) != OK:
		print_rich("[color=red]An error occurred while sending the HiggsUnderstandingAPI HTTP request.[/color]")
	
	print("Higgs Understanding API: Request sent.")
	

func _ready() -> void:
	http_request.request_completed.connect(_on_request_completed)


func _on_request_completed(result, response_code, headers, body):
	var response = JSON.parse_string(body.get_string_from_utf8())
	var message = response["choices"][0]["message"]["content"]
	
	#activity_history.append("[you] {%s}" % payload.voice_line)
	
	print(message)
	message_received.emit(message)
