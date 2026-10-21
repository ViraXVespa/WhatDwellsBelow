extends Object

## Split from hitch_log.gd: _post, _flush_web, _web_q.

## Web only. A JavaScript eval on every slow frame keeps the present over one refresh.
static var _web_q: PackedStringArray = PackedStringArray()

## Localhost web only. Rows wait here so the frame that measured them does not eval JavaScript.
static func _post(line: String) -> void:
	if not OS.has_feature("web"):
		return
	_web_q.append(line)

static func _flush_web() -> void:
	if not OS.has_feature("web") or _web_q.is_empty():
		return
	var i: int = 0
	while i < _web_q.size():
		var js := ""
		var n: int = 0
		while i < _web_q.size() and n < 40:
			js += "fetch('/_wdb/hitch',{method:'POST',keepalive:true,headers:{'Content-Type':'application/json'},body:%s}).catch(function(){});" % JSON.stringify(_web_q[i])
			i += 1
			n += 1
		JavaScriptBridge.eval(js, false)
	_web_q = PackedStringArray()
