extends Node

@onready var higgs_audio_streamer: HiggsAudioStreamer = $"../HiggsAudioStreamer"
@onready var higgs_understanding_api: HiggsUnderstandingApi = $"../HiggsUnderstandingApi"

# Define the port to listen on. Make sure it's not blocked by a firewall.
const PORT = 9080

var server: TCPServer
var clients: Array[StreamPeerTCP] = []

func _ready() -> void:
	server = TCPServer.new()
	
	# Start listening for connections.
	var err: Error = server.listen(PORT)
	if err != OK:
		printerr("Failed to start server. Error: %s" % error_string(err))
		set_process(false) # Disable processing if server fails
		return
		
	print("Audio server started. Listening on port %s..." % PORT)

func _process(delta: float) -> void:
	# 1. Check for new connections
	if server.is_connection_available():
		var client: StreamPeerTCP = server.take_connection()
		if client:
			clients.append(client)
			print("Client connected: %s" % client.get_connected_host())

	# 2. Process existing clients
	for i in range(clients.size() - 1, -1, -1): # Iterate backwards for safe removal
		var client: StreamPeerTCP = clients[i]
		
		# Check if client is still connected
		if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			print("Client disconnected.")
			clients.remove_at(i)
			continue
			
		# Check for incoming data
		var available_bytes: int = client.get_available_bytes()
		
		if available_bytes > 4: # We need at least 4 bytes for the size prefix
			# Read the 4-byte size prefix (unsigned 32-bit integer)
			var payload_size: int = client.get_u32()
			
			# Check if we have received the full payload yet
			if available_bytes >= payload_size + 4:
				# Read the actual payload data
				var payload_data: PackedByteArray = client.get_data(payload_size)[1]
				
				# Convert the payload (which is a base64 string) to a Godot string
				var b64_string: String = payload_data.get_string_from_utf8()
				
				print("Received %d bytes of base64 audio data." % payload_size)
				# You can print a snippet to verify, but not the whole thing!
				print("Data snippet: %s..." % b64_string.substr(0, 50))
				higgs_understanding_api.interact(["[you] Why haven't I gotten service yet?"], b64_string)
				
				# ---
				# At this point, you have the base64 string in `b64_string`.
				# You can now decode it and create an AudioStream.
				# Example (uncomment to use):
				# var wav_data: PackedByteArray = Marshalls.base64_to_raw(b64_string)
				# var audio_stream = AudioStreamWAV.new()
				# audio_stream.data = wav_data
				# 
				# # Now you can play it, e.g., if you have an AudioStreamPlayer node
				# # $AudioStreamPlayer.stream = audio_stream
				# # $AudioStreamPlayer.play()
				# ---
			else:
				# Not all data has arrived yet, put the size back
				# (This is a simple way, a better way is to store the expected size)
				client.put_u32(payload_size)
