class_name PerfStats
extends RefCounted
## Timing samples by key, for finding hitches. Cheap enough to leave on: a sample is
## one append. DevCli `--perf` prints the summary when the run quits.
##
##   var t := Time.get_ticks_usec()
##   ...work...
##   PerfStats.add("light rebuild", Time.get_ticks_usec() - t)

static var _samples: Dictionary[String, PackedInt64Array] = {}


static func add(key: String, usec: int) -> void:
	if not _samples.has(key):
		_samples[key] = PackedInt64Array()
	_samples[key].append(usec)


static func clear() -> void:
	_samples.clear()


static func count(key: String) -> int:
	return _samples[key].size() if _samples.has(key) else 0


## Largest sample in milliseconds (0 if none).
static func max_ms(key: String) -> float:
	if not _samples.has(key) or _samples[key].is_empty():
		return 0.0
	var s := _samples[key].duplicate()
	s.sort()
	return s[s.size() - 1] / 1000.0


## Samples above `usec`.
static func count_over(key: String, usec: int) -> int:
	var n := 0
	if _samples.has(key):
		for v in _samples[key]:
			if v > usec:
				n += 1
	return n


## Short form for the debug overlay: "n 12  med 3.2  max 45.1 ms".
static func brief(key: String) -> String:
	if not _samples.has(key) or _samples[key].is_empty():
		return "-"
	var s := _samples[key].duplicate()
	s.sort()
	return "n %d  med %.1f  max %.1f ms" % [s.size(), s[s.size() / 2] / 1000.0, s[s.size() - 1] / 1000.0]


## One line per key: count, median, p95, max and total, in milliseconds.
static func summary() -> String:
	var lines := PackedStringArray()
	lines.append("%-22s %6s %8s %8s %8s %9s" % ["key", "n", "median", "p95", "max", "total"])
	for key: String in _samples:
		var s := _samples[key].duplicate()
		if s.is_empty():
			continue
		s.sort()
		var total := 0
		for v in s:
			total += v
		var n := s.size()
		lines.append("%-22s %6d %8.2f %8.2f %8.2f %9.1f" % [key, n, s[n / 2] / 1000.0,
			s[mini(n - 1, int(n * 0.95))] / 1000.0, s[n - 1] / 1000.0, total / 1000.0])
	return "\n".join(lines)
