extends SceneTree
## Placeholder sound effects (assets/sounds/<id>.wav), synthesized: sweeps, blips and
## noise bursts, 22 kHz mono. Patrick replaces them with real sounds of the same names
## (or .ogg). Existing files are kept unless --force; --only=a,b makes just those.
##
##   godot --headless --path . --script res://tools/make_sounds.gd
##
## Each sound is a list of layers: [wave, start Hz, end Hz, seconds, volume, delay].
## Waves: sine, square, tri, saw, noise (noise uses the Hz as a low-pass cutoff).

const OUT := "res://assets/sounds"
const RATE := 22050

const SOUNDS := {
	# Spells (cast_<type>, plus their own moments).
	&"cast_projectile": [["square", 900, 1400, 0.08, 0.25, 0.0], ["noise", 3000, 1500, 0.07, 0.15, 0.0]],
	&"cast_gust": [["noise", 1200, 300, 0.35, 0.5, 0.0]],
	&"cast_blink": [["sine", 300, 1800, 0.12, 0.35, 0.0], ["sine", 1800, 600, 0.12, 0.25, 0.12]],
	&"cast_light": [["sine", 660, 990, 0.25, 0.25, 0.0], ["sine", 990, 1320, 0.25, 0.15, 0.08]],
	&"cast_buff": [["tri", 440, 880, 0.2, 0.3, 0.0], ["tri", 660, 1320, 0.2, 0.2, 0.1]],
	&"cast_zone": [["sine", 330, 495, 0.5, 0.3, 0.0], ["sine", 495, 660, 0.5, 0.2, 0.15]],
	&"cast_ward": [["square", 220, 180, 0.15, 0.2, 0.0], ["tri", 880, 880, 0.1, 0.15, 0.1]],
	&"cast_summon": [["tri", 500, 900, 0.18, 0.3, 0.0], ["sine", 1200, 1500, 0.1, 0.2, 0.15]],
	&"cast_conjure": [["tri", 300, 600, 0.2, 0.3, 0.0], ["noise", 2500, 2500, 0.1, 0.08, 0.0]],
	&"cast_chain": [["noise", 6000, 3000, 0.25, 0.45, 0.0], ["square", 1800, 600, 0.2, 0.15, 0.0]],
	&"cast_ritual": [["sine", 220, 220, 0.6, 0.25, 0.0]],
	&"cast_sense": [["sine", 1200, 1200, 0.08, 0.25, 0.0], ["sine", 1200, 1200, 0.08, 0.18, 0.18], ["sine", 1200, 1200, 0.08, 0.1, 0.36]],
	&"bolt_charge": [["saw", 150, 600, 0.6, 0.18, 0.0]],
	&"bolt_fire": [["square", 600, 200, 0.2, 0.3, 0.0], ["noise", 2500, 600, 0.2, 0.25, 0.0]],
	&"gel_cushion_used": [["sine", 300, 90, 0.18, 0.55, 0.0], ["noise", 900, 300, 0.12, 0.25, 0.0]],
	&"ward_trigger": [["noise", 5000, 1500, 0.2, 0.5, 0.0], ["square", 1400, 300, 0.15, 0.2, 0.0]],
	&"familiar_shot": [["square", 1500, 2200, 0.05, 0.15, 0.0]],
	&"platform_fade": [["sine", 700, 300, 0.25, 0.2, 0.0]],
	&"shield_pop": [["sine", 400, 1200, 0.15, 0.4, 0.0], ["tri", 1200, 1200, 0.3, 0.15, 0.1]],
	&"shield_block": [["tri", 1000, 800, 0.1, 0.3, 0.0]],
	&"buff_end": [["tri", 660, 440, 0.15, 0.2, 0.0]],
	&"ritual_start": [["sine", 220, 330, 0.4, 0.3, 0.0]],
	&"ritual_done": [["sine", 440, 880, 0.2, 0.35, 0.0], ["sine", 660, 1320, 0.25, 0.3, 0.12], ["noise", 4000, 4000, 0.2, 0.08, 0.1]],
	&"toggle_on": [["tri", 500, 800, 0.1, 0.25, 0.0]],
	&"toggle_off": [["tri", 800, 500, 0.1, 0.2, 0.0]],
	# Combat.
	&"player_hurt": [["square", 300, 150, 0.15, 0.3, 0.0], ["noise", 1500, 400, 0.1, 0.25, 0.0]],
	&"enemy_hit": [["noise", 2500, 600, 0.08, 0.45, 0.0], ["sine", 220, 120, 0.08, 0.3, 0.0]],
	&"enemy_die": [["sine", 500, 80, 0.22, 0.45, 0.0], ["noise", 1200, 300, 0.15, 0.25, 0.05]],
	&"slime_hop": [["sine", 160, 320, 0.09, 0.25, 0.0]],
	&"slime_land": [["sine", 220, 90, 0.08, 0.25, 0.0]],
	&"swing": [["noise", 2200, 800, 0.12, 0.3, 0.0]],
	# World.
	&"mine_hit": [["noise", 1800, 900, 0.06, 0.35, 0.0], ["square", 160, 120, 0.04, 0.15, 0.0]],
	# Gathering spells: the phantom tool lands (a soft, ringing thunk).
	&"phantom_mine": [["noise", 1600, 700, 0.05, 0.25, 0.0], ["sine", 660, 440, 0.12, 0.15, 0.0]],
	&"phantom_chop": [["noise", 900, 500, 0.06, 0.28, 0.0], ["sine", 520, 380, 0.12, 0.15, 0.0]],
	&"block_break": [["noise", 1400, 300, 0.16, 0.45, 0.0]],
	&"block_place": [["noise", 900, 600, 0.05, 0.35, 0.0], ["sine", 180, 140, 0.05, 0.3, 0.0]],
	&"item_pickup": [["sine", 880, 1320, 0.07, 0.25, 0.0]],
	&"craft": [["noise", 2000, 1200, 0.06, 0.3, 0.0], ["noise", 2000, 1200, 0.06, 0.3, 0.12], ["tri", 900, 900, 0.08, 0.15, 0.22]],
	&"eat": [["noise", 1200, 700, 0.06, 0.3, 0.0], ["noise", 1200, 700, 0.06, 0.25, 0.12]],
	&"door": [["square", 140, 110, 0.12, 0.2, 0.0], ["noise", 700, 400, 0.1, 0.2, 0.0]],
	&"learn_spell": [["sine", 523, 523, 0.12, 0.25, 0.0], ["sine", 659, 659, 0.12, 0.25, 0.1], ["sine", 784, 784, 0.2, 0.25, 0.2]],
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var force := args.has("--force")
	var only: PackedStringArray = []
	for a in args:
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var written := 0
	for id: StringName in SOUNDS:
		if not only.is_empty() and not String(id) in only:
			continue
		var path := ProjectSettings.globalize_path("%s/%s.wav" % [OUT, id])
		if FileAccess.file_exists(path) and not force:
			continue
		var wav := _render(SOUNDS[id])
		wav.save_to_wav(path)
		written += 1
	print("make_sounds: %d written" % written)
	quit()


func _render(layers: Array) -> AudioStreamWAV:
	var length := 0.0
	for l: Array in layers:
		length = maxf(length, float(l[3]) + float(l[5]))
	var n := int((length + 0.02) * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(layers)
	for l: Array in layers:
		var wave: String = l[0]
		var f0 := float(l[1])
		var f1 := float(l[2])
		var dur := float(l[3])
		var vol := float(l[4])
		var start := int(float(l[5]) * RATE)
		var phase := 0.0
		var low := 0.0
		for i in int(dur * RATE):
			var t := float(i) / (dur * RATE)
			var f := lerpf(f0, f1, t)
			phase += f / RATE
			var v := 0.0
			match wave:
				"sine":
					v = sin(TAU * phase)
				"square":
					v = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				"tri":
					v = 1.0 - 4.0 * absf(fmod(phase, 1.0) - 0.5)
				"saw":
					v = 2.0 * fmod(phase, 1.0) - 1.0
				"noise":
					# White noise through a one-pole low-pass at f.
					var k := clampf(TAU * f / RATE, 0.0, 1.0)
					low += (rng.randf_range(-1.0, 1.0) - low) * k
					v = low * 2.0
			# A quick attack and a smooth decay.
			var env := minf(t / 0.04, 1.0) * pow(1.0 - t, 1.6)
			var j := start + i
			if j < n:
				buf[j] += v * env * vol
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
