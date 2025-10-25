class_name TranscriptReceiver
extends Node

var server = TCPServer.new()
var connections = []
const PORT = 9080

signal transcript_received(message: String)

func _ready():
	# Start listening on the specified port
	var err = server.listen(PORT)
	if err != OK:
		printerr("Failed to start server on port %d" % PORT)
		set_process(false)
	else:
		print("HTTP server listening on port %d" % PORT)

func _process(delta):
	# Check for new incoming connections
	if server.is_connection_available():
		var conn = server.take_connection()
		if conn:
			print("New connection received.")
			connections.append(conn)
	
	# Iterate through all active connections (backwards, to safely remove)
	for i in range(connections.size() - 1, -1, -1):
		var conn = connections[i]
		
		# Check if connection is still active
		if not conn or conn.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			if conn:
				conn.disconnect_from_host()
			# --- FIX 2 ---
			connections.remove_at(i) 
			continue
			
		# Check if there's data to read
		var available = conn.get_available_bytes()
		if available > 0:
			# Read the raw request data
			var data = conn.get_data(available)[1]
			var request_str = data.get_string_from_utf8()
			
			# Process the request
			handle_http_request(conn, request_str)
			
			# For this simple server, we close the connection after one request
			conn.disconnect_from_host()
			# --- FIX 2 ---
			connections.remove_at(i)


func handle_http_request(conn: StreamPeerTCP, request_str: String):
	# --- Very simple HTTP parser ---
	var lines = request_str.split("\r\n")
	if lines.is_empty():
		send_response(conn, 400, "Bad Request", "")
		return

	# Parse the first line (e.g., "POST /message HTTP/1.1")
	var request_line_parts = lines[0].split(" ")
	if request_line_parts.size() < 3:
		send_response(conn, 400, "Bad Request", "")
		return
		
	var method = request_line_parts[0]
	var path = request_line_parts[1]
	
	# Find the start of the body (after the double newline)
	var body_start = request_str.find("\r\n\r\n")
	var body = ""
	if body_start != -1:
		body = request_str.substr(body_start + 4)
	
	# --- Handle the specific endpoint ---
	if method == "POST" and path == "/message":
		var json = JSON.new()
		var err = json.parse(body)
		
		if err == OK:
			var data = json.get_data()
			if data.has("message"):
				# SUCCESS: Print the message
				print("Received message: %s" % data["message"])
				transcript_received.emit(data["message"])
				send_response(conn, 200, "OK", '{"status": "received"}')
			else:
				print("Request body missing 'message' key.")
				send_response(conn, 400, "Bad Request", '{"error": "Missing message key"}')
		else:
			print("Failed to parse JSON body: %s" % body)
			send_response(conn, 400, "Bad Request", '{"error": "Invalid JSON"}')
	else:
		# Handle all other requests with 404
		send_response(conn, 404, "Not Found", '{"error": "Not Found"}')


func send_response(conn: StreamPeerTCP, code: int, status: String, body: String):
	# Construct the HTTP response
	var response_body = body
	var response_headers = [
		"HTTP/1.1 %d %s" % [code, status],
		"Content-Type: application/json",
		"Content-Length: %d" % response_body.to_utf8_buffer().size(),
		"Connection: close", # Tell client we will close the connection
		"\r\n" # Empty line signifies end of headers
	]
	
	var response_str = "\r\n".join(response_headers) + response_body
	
	# Send the response back to the client
	conn.put_data(response_str.to_utf8_buffer())
