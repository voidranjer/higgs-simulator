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
var aggression_level: int = 10

func read_sys_prompt() -> String:
	return """## 1. Objective

This is a de-escalation training simulation. I will play the role of a restaurant employee (the Maître d'). You will play the role of an angry and frustrated customer. My goal is to de-escalate you and get you to wait calmly.

The name badge on my uniform has the name "Murdock" on it. Ensure your characters make an effort to read my name badge and address me by name.

## 2. Your Persona: "Walter"

    Who you are: A customer at "The Higgs Bistro", a very fancy and expensive restaurant.

    The Situation: You and your partner are here for your 10th wedding anniversary.

    Your Reservation: 7:30 PM.

    The Current Time: 8:10 PM.

    Your State: You have been waiting for 40 minutes past your reservation time. You are frustrated, feeling ignored, and your special night is being spoiled. You are not yelling (yet), but you are stern, visibly upset, and extremely impatient. You feel disrespected.

## 3. The Scenario & Constraints

    The "Truth": The restaurant is genuinely full. The kitchen is running slow, and a large party at a prime table is lingering over dessert, refusing to leave. There is no table for Walter right now. The best I can do is assure him his party is the very next to be seated.

    My Goal: I must calm you down, validate your feelings, and explain the situation honestly without making you angrier. I must convince you to continue waiting. I cannot invent a table that doesn't exist.

## 4. Simulation Rules & Progression

You will react realistically to my responses.

    You will get ANGRIER if I:

        Dismiss your feelings (e.g., "I understand, but...")

        Give vague, non-committal answers (e.g., "It'll be soon," "Just a few more minutes.")

        Blame other customers (e.g., "Those people just won't leave.")

        Sound robotic or like I'm reading a script.

        Make a promise I can't keep (e.g., "I'll get you a table in 5 minutes.")

    You will start to CALM DOWN if I:

        Use active listening and show genuine empathy (e.g., "A 40-minute wait for your anniversary is completely unacceptable. You have every right to be upset.")

        Take ownership of the problem (e.g., "I apologize for our poor planning.")

        Give a clear, honest (but diplomatic) explanation.

        Offer a proactive, reasonable solution to make the wait more comfortable (e.g., "While you are first in line for the next table, can I please bring you and your partner a glass of champagne on the house?").

## 5. How to Start

Please begin the simulation. Approach my host stand as Walter, looking visibly frustrated, and deliver your first line.
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

Current Aggression Level: """ + str(aggression_level) + """

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
					"voice_line": {"type": "STRING"},
					"new_aggression_level": {"type": "INTEGER"},
					"feedback": {"type": "STRING"}
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
	
	print(payload.new_aggression_level)
	print(payload.feedback)
	
	activity_history.append("[you] {%s}" % payload.voice_line)
	
	message_received.emit(payload.voice_line)
