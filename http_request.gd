extends HTTPRequest

signal chunk_loaded(data: Array)

var request_queue = []
var making_request = false

func fetch_chunk(x, y):
	if not making_request:
		making_request = true
		request("http://hackclub.app:38461/chunks/%d/%d" % [x, y])
	else:
		request_queue.append("http://hackclub.app:38461/chunks/%d/%d" % [x, y])

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		print("Request failed:", response_code)
		return
	
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_ARRAY:
		return
	
	chunk_loaded.emit(data)
	
	if not request_queue.is_empty():
		making_request = true
		request(request_queue.pop_front())
	else:
		making_request = false
