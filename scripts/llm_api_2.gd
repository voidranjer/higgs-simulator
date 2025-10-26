class_name LlmApi2
extends Node

# Constants
var LLM_API_URL = ProjectSettings.get_setting("custom_apis/llm_endpoint")
var LLM_API_KEY = ProjectSettings.get_setting("custom_apis/llm_api_key")

# Child nodes
@onready var http_request: HTTPRequest = $HTTPRequest

# Signals
signal message_received(response_text: String)
signal checklist_updated(new_checklist: Array)

# State variables
var checklist_bools = [false, false, false, false, false]
var conversation = [] # raymond's format (for LLM generation)

@export_multiline var sys_instr: String =  """	
Your name is Morgan. 

You are an 80 year old man who lives alone.

You heard knocking at your door, and now you are at the door.

You are speaking to a man on the other side of the door. He is wearing a shirt that says Higgs Helpline and a nametag that says "Murdock".

You slipped three days ago, and it is hard for you to move around. That is why you have not picked up your newspaper. You are bruised and there is no further serious injury.

You are hesitant to reveal that information until you gain trust in Murdock.

Here is the list of boolean variables:

	self_identify: Murdock has identified himself and stated that he is here for a welfare check.

	state_peace: Murdock has stated in some way that he comes in peace. For example, he confirms that he is here to make sure you are safe, or confirms that he is not here to arrest you or cause trouble.

	state_concern: Murdock showed the reason for concern by stating that your newspaper has not been collected for three days.

	show_understanding: Murdock has validated your hesitation or shows understanding of your worries.

	direct_assessment: Murdock has asked you if you are hurt or in danger.
	
These boolean variables should be switched from false to true based on what Murdock says. Never switch the variables from true to false.
"""

@export_multiline var first_prompt: String = """
The current states of the boolean variables are:
self_identify: false
state_peace: false
state_concern: false
show_understanding: false
direct_assessment: false

You have just arrived at your door and read Murdock's shirt and nametag. Deliver your first voice_line.
Provide the updated boolean variable values.
"""

func prompt(helper_line, checklist) -> String:
	return """
The current states of the boolean variables are:
self_identify: %s
state_peace: %s
state_concern: %s
show_understanding: %s
direct_assessment: %s

""" % checklist \
+ \
"""Murdock says \"%s\". Deliver your voice_line, and provide the updated boolean variables. 
""" % helper_line

func interact(message: String):
	var is_initial_message = message == "<|initial|>"
			
	conversation.append({
		"role": "user",
		"parts":[
			{
				"text": first_prompt if is_initial_message else prompt(message, checklist_bools)
			}
		]
	})

	var body_dict = {
		"system_instruction":{
			"parts":[
				{
					"text": sys_instr
				}
			]
		},
		"contents": conversation,
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
					"voice_line": {"type": "STRING"},
					"self_identify": {"type": "BOOLEAN"},
					"state_peace": {"type": "BOOLEAN"},
					"state_concern": {"type": "BOOLEAN"},
					"show_understanding": {"type": "BOOLEAN"},
					"direct_assessment": {"type": "BOOLEAN"}
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
	var content = response["candidates"][0]["content"]["parts"][0]["text"]

	var payload = JSON.parse_string(content)
	
	var new_checklist_bools = [payload.self_identify,
						payload.state_peace,
						payload.state_concern,
						payload.show_understanding,
						payload.direct_assessment]
						
	# If not equal, open drawer
	for i in range(new_checklist_bools.size()):
		if new_checklist_bools[i] != checklist_bools[i]:
			#checklist_updated.emit(new_checklist_bools)
			checklist_updated.emit([true, true, true, true, true])
			checklist_bools = new_checklist_bools
			break
	
	conversation.append({
		"role": "model",
		"parts":[
			{
				"text": '''
The current states of the boolean variables are:
self_identify: %s
state_peace: %s
state_concern: %s
show_understanding: %s
direct_assessment: %s

''' % checklist_bools + payload.voice_line
			}
		]
	})
	
	message_received.emit(payload.voice_line)
