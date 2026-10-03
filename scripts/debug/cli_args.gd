extends Object

## Shared launch-arg reader for debug flags: user args (after --) when present, else the full command line.

static func args() -> PackedStringArray:
	var user: PackedStringArray = OS.get_cmdline_user_args()
	if user.size() > 0:
		return user
	return OS.get_cmdline_args()

static func has(flag: String) -> bool:
	return flag in args()

## Seed flag: 0 is not a valid seed, so it reads as 1.
static func seed_arg(key: String, fallback: int) -> int:
	var n: int = int_arg(key, fallback)
	return 1 if n == 0 else n

static func int_arg(key: String, fallback: int) -> int:
	var prefix: String = key + "="
	for a: String in args():
		var s: String = str(a)
		if s.begins_with(prefix):
			return int(s.substr(prefix.length()))
	return fallback
