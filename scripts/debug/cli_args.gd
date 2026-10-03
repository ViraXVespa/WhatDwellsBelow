extends Object

## Shared launch-arg reader for debug flags: user args (after --) when present, else the full command line.

static var _web: PackedStringArray = PackedStringArray()
static var _web_done := false

## Web only: URL params that start with wdb- (e.g. ?wdb-seed=42&wdb-playtest) read as --wdb-seed=42 --wdb-playtest.
## A normal URL has none, so normal play is unchanged.
static func web_args() -> PackedStringArray:
	if _web_done or not OS.has_feature("web"):
		return _web
	_web_done = true
	var q: String = str(JavaScriptBridge.eval("String(location.search||'')", true)).lstrip("?")
	for part: String in q.split("&", false):
		if part.begins_with("wdb-"):
			_web.append("--" + part)
	return _web

static func args() -> PackedStringArray:
	var user: PackedStringArray = OS.get_cmdline_user_args()
	if user.size() == 0:
		user = OS.get_cmdline_args()
	var web: PackedStringArray = web_args()
	return user + web if web.size() > 0 else user

static func has(flag: String) -> bool:
	return flag in args()

static func int_arg(key: String, fallback: int) -> int:
	var prefix: String = key + "="
	for a: String in args():
		var s: String = str(a)
		if s.begins_with(prefix):
			return int(s.substr(prefix.length()))
	return fallback

## Opt-in fixed run seed: --wdb-seed=N (or ?wdb-seed=N on web); fallback when absent or not positive.
static func seed_arg(fallback: int) -> int:
	var n: int = int_arg("--wdb-seed", 0)
	return n if n > 0 else fallback
