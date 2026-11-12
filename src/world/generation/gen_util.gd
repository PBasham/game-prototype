class_name GenUtil
extends RefCounted
## Small deterministic helpers shared by world generators.


## Deterministic hash of (x, y, seed) to [0, 1).
static func hash01(x: int, y: int, seed: int) -> float:
	var n := (x * 374761393 + y * 668265263 + seed * 982451653) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65536.0


## A sine wave that repeats exactly `cycles` times across the world width,
## so anything built from it is seamless where the world wraps.
static func wrap_wave(x: int, width: int, cycles: int, phase: float) -> float:
	return sin(TAU * float(x) * cycles / width + phase)
