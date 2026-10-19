extends RefCounted
## localStorage is synchronous, durable across reloads, and independent of IndexedDB flushes.
const KEY = "kikori.watersheds.v5"
const FILE = "user://kikori_watersheds_v5.json"
const MAX_BYTES = 64000000
const MAX_STORED_CHARS = 2400000
const PREFIX = "KZ1:"
var available = true
var message = ""
var file_path = FILE

func _init(native_path: String = FILE) -> void:
	file_path = native_path

func read_save() -> Dictionary:
	var raw = ""
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s') || '';}catch(e){return '__UNAVAILABLE__';}})()" % KEY, true)
		if result is String:
			raw = result
		if raw == "__UNAVAILABLE__":
			available = false
			message = "保存が制限されています。このタブでは遊べます。"
			return {}
	elif FileAccess.file_exists(file_path):
		raw = FileAccess.get_file_as_string(file_path)
	if raw.is_empty():
		return {}
	if raw.begins_with(PREFIX):
		if raw.length() > MAX_STORED_CHARS:
			message = "保存データを読み込めませんでした。"
			return {}
		var packed = Marshalls.base64_to_raw(raw.substr(PREFIX.length()))
		# Bound expansion before parsing; never allocate from an untrusted length.
		var decoded = packed.decompress_dynamic(MAX_BYTES, FileAccess.COMPRESSION_GZIP)
		if decoded.is_empty():
			message = "保存データが破損しています。新しく開始します。"
			return {}
		raw = decoded.get_string_from_utf8()
	if raw.to_utf8_buffer().size() > MAX_BYTES:
		message = "保存データを読み込めませんでした。"
		return {}
	var parser = JSON.new()
	var error = parser.parse(raw)
	if error != OK or not parser.data is Dictionary:
		message = "保存データが破損しています。新しく開始します。"
		return {}
	return parser.data

func write_save(state: Dictionary) -> bool:
	var payload = state.duplicate(false)
	payload["saved_at"] = Time.get_unix_time_from_system()
	var raw = JSON.stringify(payload, "", true, true)
	if raw.to_utf8_buffer().size() > MAX_BYTES:
		available = false
		message = "保存データが大きすぎます。既存の保存は保持されています。"
		return false
	# Keep synchronous save acknowledgement while fitting large physical stocks
	# inside mobile localStorage. Existing plain JSON remains readable.
	raw = PREFIX + Marshalls.raw_to_base64(raw.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	if raw.length() > MAX_STORED_CHARS:
		available = false
		message = "保存データが大きすぎます。既存の保存は保持されています。"
		return false
	if OS.has_feature("web"):
		# JSON.stringify of a string is a safe JS literal, including user-controlled text.
		var script = "(function(){try{localStorage.setItem('%s', %s);return 1;}catch(e){return 0;}})()" % [KEY, JSON.stringify(raw)]
		available = int(JavaScriptBridge.eval(script, true)) == 1
	else:
		var file = FileAccess.open(file_path + ".tmp", FileAccess.WRITE)
		available = file != null
		if file:
			file.store_string(raw)
			file.flush()
			available = file.get_error() == OK
			file.close()
			if available:
				available = DirAccess.rename_absolute(file_path + ".tmp", file_path) == OK
			else:
				DirAccess.remove_absolute(file_path + ".tmp")
	message = "" if available else "保存できません。ブラウザの保存設定を確認してください。"
	return available
