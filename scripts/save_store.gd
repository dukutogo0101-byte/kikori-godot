extends RefCounted
## localStorage is synchronous, durable across reloads, and independent of IndexedDB flushes.
const KEY = "kikori.phase1.v1"
const FILE = "user://kikori_save.json"
const MAX_BYTES = 100000
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
	if raw.length() > MAX_BYTES:
		message = "保存データを読み込めませんでした。"
		return {}
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary:
		message = "保存データが破損しています。新しく開始します。"
		return {}
	return parsed

func write_save(state: Dictionary) -> bool:
	var payload = state.duplicate(true)
	payload["saved_at"] = Time.get_unix_time_from_system()
	var raw = JSON.stringify(payload, "", true, true)
	if OS.has_feature("web"):
		# JSON.stringify of a string is a safe JS literal, including user-controlled text.
		var script = "(function(){try{localStorage.setItem('%s', %s);return 1;}catch(e){return 0;}})()" % [KEY, JSON.stringify(raw)]
		available = int(JavaScriptBridge.eval(script, true)) == 1
	else:
		var file = FileAccess.open(file_path + ".tmp", FileAccess.WRITE)
		available = file != null
		if file:
			file.store_string(raw)
			file.close()
			available = DirAccess.rename_absolute(file_path + ".tmp", file_path) == OK
	message = "" if available else "保存できません。ブラウザの保存設定を確認してください。"
	return available
