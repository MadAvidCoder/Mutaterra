extends Node2D

signal chunk_loaded(data: Array)

var request_queue = []
var making_request = false
var peer
var connected = false

func _ready() -> void:
	peer = WebSocketPeer.new()
	var err = peer.connect_to_url("ws://hackclub.app:38461/ws")
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
				process_queue()
		WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
			if connected:
				connected = false
				print("Connection closed.")

	while peer.get_available_packet_count() > 0:
		var msg = peer.get_packet().get_string_from_utf8()
		var data = JSON.parse_string(msg)
		if typeof(data) == TYPE_DICTIONARY and data.get("type") == "chunk":
			chunk_loaded.emit(data)

func process_queue():
	while not request_queue.is_empty():
		var item = request_queue.pop_front()
		fetch_chunk(item[0], item[1])

func fetch_chunk(x, y):
	if connected:
		var msg = "get_chunk %d %d" % [x, y]
		peer.send_text(msg)
	else:
		request_queue.append([x, y])
