class_name LlmApi
extends Node

# Constants
var LLM_API_URL = ProjectSettings.get_setting("custom_apis/llm_endpoint")
var LLM_API_KEY = ProjectSettings.get_setting("custom_apis/llm_api_key")

# Child nodes
@onready var http_request: HTTPRequest = $HTTPRequest

# Signals
signal message_received(response_text: String)
signal aggression_level_changed(new_level: int)

# State variables
var aggression_level: int = 8
var conversation_history: Array[String] = [] # james's format (for feedback)
var conversation = [] # raymond's format (for LLM generation)
var is_expecting_feedback: bool = false

@export_multiline var sys_instr: String =  """	
Your name is Walter. 

You are a customer at "The Higgs Bistro", a very fancy and expensive restaurant.

You and your partner are here for your 10th wedding anniversary. You have been waiting for 20 minutes past your reservation time.

You are speaking to a waiter, and the name badge on his uniform has the name "Murdock" on it.

The restaurant is full. The kitchen is running slow, and a large party at a prime table is lingering over dessert, refusing to leave. There is no table for you right now. The best the waiter can do is assure you that your party is the very next to be seated.

aggression_level describes how annoyed and impatient you currently are as a customer.
aggression_level is an integer on a scale of 1 to 10.
aggression_level should increase, decrease or stay the same based on how Murdock's choice of words as a waiter affected your emotional state.
aggression_level can increase or decrease by steps of 3, 4, or 5 based on how affected you were.

    aggression_level increases if Murdock:

		Dismiss your feelings (e.g., "I understand, but...")

		Give vague, non-committal answers (e.g., "It'll be soon," "Just a few more minutes.")

		Blame other customers (e.g., "Those people just won't leave.")

        Sound robotic or like I'm reading a script.

		Make a promise I can't keep (e.g., "I'll get you a table in 5 minutes.")

    aggression_level decreases if Murdock:

        Use active listening and show genuine empathy (e.g., "A 40-minute wait for your anniversary is completely unacceptable. You have every right to be upset.")

        Take ownership of the problem (e.g., "I apologize for our poor planning.")

        Give a clear, honest (but diplomatic) explanation.

        Offer a proactive, reasonable solution to make the wait more comfortable (e.g., "While you are first in line for the next table, can I please bring you and your partner a glass of champagne on the house?").
	
	At the end of the game, you will be asked to provide an evaluation on how well Murdock performed (as a third-party. Think of this as an evaluation on a recorded conversation). Set 'is_feedback_message' to true when providing such messages.
"""

@export_multiline var first_prompt: String = """
current aggression_level: 8 out of 10

You go up to Murdock at his host stand.
Deliver your first line.
"""

var feedback_sys_prompt = """# Employee Training Module: Handling an Angry Customer - Walter's 10th Anniversary Wait

## Instruction

- You are a third party employee performance evaluator.

- Based on the following conversation record, identify which de-escalation techniques were used effectively by the employee and which could have been improved. Provide specific examples from the conversation to support your analysis.

- Be succinct.

- Deliver your report formatted in BBCode.

"""

func prompt(waiter_line, aggr_lvl) -> String:
	return "Current aggression_level is " + str(aggr_lvl) + ". Murdock says \"" + waiter_line + "\"" + \
'''
	
Deliver your voice_line, and provide your new aggression_level.
'''

func interact(message: String):
	var is_initial_message = message == "<|initial|>"
	var is_feedback_message = message == "<|feedback|>"
	
	var body_dict
	
	if is_feedback_message:
		is_expecting_feedback = true

		body_dict = {
			"system_instruction":{
				"parts":[
					{
						"text": feedback_sys_prompt
					}
				]
			},
			"contents": {
				"role": "user",
				"parts":[
					{
						"text": "\nConversation Log:\n" + "\n".join(conversation_history)
					}
				]
			},
			"generationConfig": {
				"thinkingConfig": {
					"thinkingBudget": 0 # disable reasoning for speed
				},
			}
		}
	
	else:
		if not is_initial_message:
			conversation_history.append("[employee] " + message)
		
		conversation.append({
			"role": "user",
			"parts":[
				{
					"text": first_prompt if is_initial_message else prompt(message, aggression_level)
				}
			]
		})

		body_dict = {
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
						"aggression_level": {"type": "INTEGER"},
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

	if is_expecting_feedback:
		print("FEEDBACK RECEIVED")
		globals.feedback_bbcode = content
		get_tree().change_scene_to_file("res://scenes/feedback_board.tscn")
		return

	var payload = JSON.parse_string(content)
	aggression_level = payload.aggression_level
	
	conversation_history.append("[customer] %s" % payload.voice_line)
	conversation.append({
		"role": "model",
		"parts":[
			{
				"text": "Current aggression_level is " + str(aggression_level) + ". " + payload.voice_line
			}
		]
	})
	print(conversation[-1])
	
	message_received.emit(payload.voice_line)
	aggression_level_changed.emit(payload.aggression_level)
