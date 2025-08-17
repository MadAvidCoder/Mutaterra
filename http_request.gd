extends Node2D

signal chunk_loaded(data: Array)

var request_queue = []
var making_request = false
var peer
var connected = false
var reqs_per_frame = 4

func _ready() -> void:
	peer = WebSocketPeer.new()
	var err = peer.connect_to_url("ws://mutaterra.madavidcoder.hackclub.app/ws")
	if err != OK:
		print("Failed to connect:", err)
	else:
		print("Connecting to websocket...")

func _process(delta: float) -> void:
	peer.poll()
	
	match peer.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not connected:
				connected = true
				print("Connected!")
		WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
			if connected:
				connected = false
				print("Connection closed.")

	while peer.get_available_packet_count() > 0:
		var msg = peer.get_packet().get_string_from_utf8()
		var data = JSON.parse_string(msg)
		if typeof(data) == TYPE_DICTIONARY and data.get("type") == "chunk":
			chunk_loaded.emit(data)
	
	for i in range(reqs_per_frame):
		if connected and not request_queue.is_empty():
			var item = request_queue.pop_front()
			var msg = "get_chunk %d %d" % item
			peer.send_text(msg)

func fetch_chunk(x, y):
	request_queue.append([x, y])
