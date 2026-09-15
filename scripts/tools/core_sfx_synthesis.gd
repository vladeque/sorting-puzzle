extends RefCounted

## Deterministic offline synthesis for the AUDIO-001 generated SFX palette.
##
## Tool-side only: nothing in the shipped game loads this script. scripts/tools/generate_core_sfx.gd
## drives it to write each cue under res://assets/audio/<event>/, and
## tests/audio/test_core_sfx_assets.gd
## re-renders the same cues in memory to prove the committed files are still reproducible.
##
## Everything here is intentionally self-contained arithmetic -- a fixed xorshift PRNG, plain
## additive partials, one-pole filters -- so the same committed seeds and parameters produce the
## same PCM bytes on every run. Do not introduce Godot's global RNG, time, or frame state.
##
## Authoring rules encoded below (see docs/AUDIO_001_GODOT_ONLY_SFX_TICKET.md "Asset and Mix
## Guidelines"): mono 16-bit PCM at one sample rate, DC-blocked, short attack/release fades, and a
## per-cue authored peak target. Cues are deliberately NOT normalized to a common loudness, and
## every target stays at or under the -1 dBFS ceiling.

## Bump whenever a recipe, seed, parameter, or output layout changes. generate_core_sfx.gd refuses
## to overwrite outputs recorded under a different version unless --regenerate is passed.
const GENERATOR_VERSION := "1.1.0"

const SAMPLE_RATE := 44100
const BIT_DEPTH := 16
const CHANNEL_COUNT := 1
## Hard ceiling from the ticket. Authored peaks below are all quieter than this; the encoder still
## asserts against it so a future recipe edit cannot silently ship a hotter file.
const PEAK_CEILING_DB := -1.0
const ATTACK_FADE_SECONDS := 0.0015
const RELEASE_FADE_SECONDS := 0.008
## One-pole DC blocker pole. ~7 Hz corner at 44.1 kHz: it removes the offset that asymmetric
## transients leave behind without audibly thinning a 25 ms click.
const DC_BLOCKER_POLE := 0.999

## Every generated cue, in output order. `peak_db` is the authored relative loudness, not a
## loudness-matched target, so the mix balance is already intentional before the catalog's
## per-event trims.
const CUES: Array[Dictionary] = [
	{"event": "item_select", "name": "item_select_01", "recipe": "item_select", "variant": 0, "seed": 0x1B4C77E9, "duration": 0.055, "peak_db": -14.0},
	{"event": "item_select", "name": "item_select_02", "recipe": "item_select", "variant": 1, "seed": 0x63D2085F, "duration": 0.062, "peak_db": -14.5},
	{"event": "item_select", "name": "item_select_03", "recipe": "item_select", "variant": 2, "seed": 0x0E8B3C21, "duration": 0.048, "peak_db": -13.5},
	{"event": "time_up", "name": "time_up", "recipe": "time_up", "variant": 0, "seed": 0x24E8B76B, "duration": 0.520, "peak_db": -4.0},
	{"event": "coin_gain", "name": "coin_gain", "recipe": "coin_gain", "variant": 0, "seed": 0x48A1D30F, "duration": 0.520, "peak_db": -5.0},
	{"event": "coin_spend", "name": "coin_spend", "recipe": "coin_spend", "variant": 0, "seed": 0x0C57E2A9, "duration": 0.285, "peak_db": -7.0},
]


## Deterministic 32-bit xorshift. Deliberately not RandomNumberGenerator: this keeps the noise
## content of the committed WAVs tied to this file's arithmetic alone.
class DeterministicRng extends RefCounted:
	const MASK := 0xFFFFFFFF

	var _state: int

	func _init(seed_value: int) -> void:
		_state = seed_value & MASK
		if _state == 0:
			_state = 0x9E3779B9

	func next_uint() -> int:
		var value := _state
		value ^= (value << 13) & MASK
		value ^= (value >> 17)
		value ^= (value << 5) & MASK
		_state = value & MASK
		return _state

	## Uniform white noise in [-1, 1].
	func next_bipolar() -> float:
		return float(next_uint()) / 2147483647.5 - 1.0


## Renders one cue from the CUES table to normalized mono float samples in [-1, 1].
static func render_cue(cue: Dictionary) -> PackedFloat32Array:
	var duration := float(cue.get("duration", 0.1))
	var samples := _make_buffer(duration)
	var rng := DeterministicRng.new(int(cue.get("seed", 1)))
	var variant := int(cue.get("variant", 0))

	match str(cue.get("recipe", "")):
		"ui_click":
			_render_ui_click(samples, rng, variant)
		"item_select":
			_render_item_select(samples, rng, variant)
		"star_arrival":
			_render_star_arrival(samples, rng)
		"timer_tick":
			_render_timer_tick(samples, rng, variant)
		"time_up":
			_render_time_up(samples, rng)
		"coin_gain":
			_render_coin_sequence(samples, rng, [1046.50, 1318.51, 1567.98], 0.100, 1.0)
		"coin_spend":
			_render_coin_sequence(samples, rng, [1567.98, 1318.51, 1046.50], 0.075, 0.52)
		"shop_success":
			_render_shop_success(samples, rng)
		"chest_arrival":
			_render_chest_arrival(samples, rng, variant)
		_:
			push_error("Unknown SFX recipe: %s" % cue.get("recipe", ""))

	samples = _block_dc(samples)
	_apply_edge_fades(samples)
	_scale_to_peak_db(samples, float(cue.get("peak_db", -6.0)))
	return samples


## Renders every cue once. `relative_path` groups output by its semantic event.
static func render_all() -> Array[Dictionary]:
	var rendered: Array[Dictionary] = []
	for cue in CUES:
		var samples := render_cue(cue)
		var pcm := encode_wav(samples)
		rendered.append({
			"name": str(cue.get("name", "")),
			"file_name": "%s.wav" % cue.get("name", ""),
			"relative_path": "%s/%s.wav" % [cue.get("event", ""), cue.get("name", "")],
			"samples": samples,
			"duration_seconds": float(samples.size()) / float(SAMPLE_RATE),
			"authored_peak_db": float(cue.get("peak_db", -6.0)),
			"peak_db": measure_peak_db(samples),
			"dc_offset": measure_dc_offset(samples),
			"pcm": pcm,
		})

	return rendered


## Encodes mono float samples as a canonical 16-bit PCM RIFF/WAVE byte stream.
static func encode_wav(samples: PackedFloat32Array) -> PackedByteArray:
	var data_size := samples.size() * 2
	var stream := StreamPeerBuffer.new()
	stream.big_endian = false
	stream.put_data("RIFF".to_ascii_buffer())
	stream.put_u32(36 + data_size)
	stream.put_data("WAVE".to_ascii_buffer())
	stream.put_data("fmt ".to_ascii_buffer())
	stream.put_u32(16)
	stream.put_u16(1)
	stream.put_u16(CHANNEL_COUNT)
	stream.put_u32(SAMPLE_RATE)
	stream.put_u32(SAMPLE_RATE * CHANNEL_COUNT * BIT_DEPTH / 8)
	stream.put_u16(CHANNEL_COUNT * BIT_DEPTH / 8)
	stream.put_u16(BIT_DEPTH)
	stream.put_data("data".to_ascii_buffer())
	stream.put_u32(data_size)
	for sample in samples:
		stream.put_16(to_pcm16(sample))

	return stream.data_array


## Quantization used both by the encoder and by verification, so a measured peak matches the file.
static func to_pcm16(sample: float) -> int:
	return clampi(roundi(clampf(sample, -1.0, 1.0) * 32767.0), -32768, 32767)


static func measure_peak_db(samples: PackedFloat32Array) -> float:
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, absf(float(to_pcm16(sample)) / 32768.0))

	if peak <= 0.0:
		return -INF

	return linear_to_db(peak)


static func measure_dc_offset(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0

	var total := 0.0
	for sample in samples:
		total += sample

	return total / float(samples.size())


static func _make_buffer(duration_seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(maxi(int(round(duration_seconds * SAMPLE_RATE)), 1))
	samples.fill(0.0)
	return samples


## Adds one exponentially decaying sine partial. `glide_ratio` bends the starting frequency by that
## factor and settles onto `frequency` over `glide_seconds`, which is what makes the tonal cues read
## as struck objects rather than steady tones.
static func _add_partial(
	samples: PackedFloat32Array,
	start_seconds: float,
	frequency: float,
	amplitude: float,
	decay_seconds: float,
	attack_seconds := 0.001,
	glide_ratio := 1.0,
	glide_seconds := 0.02
) -> void:
	var start_index := maxi(int(round(start_seconds * SAMPLE_RATE)), 0)
	var phase := 0.0
	for index in range(start_index, samples.size()):
		var elapsed := float(index - start_index) / float(SAMPLE_RATE)
		var envelope := _hit_envelope(elapsed, attack_seconds, decay_seconds)
		if envelope <= 0.0:
			continue

		var glide := 1.0
		if not is_equal_approx(glide_ratio, 1.0) and glide_seconds > 0.0:
			glide = lerpf(glide_ratio, 1.0, clampf(elapsed / glide_seconds, 0.0, 1.0))

		phase += TAU * frequency * glide / float(SAMPLE_RATE)
		samples[index] += sin(phase) * amplitude * envelope


## Adds a band-shaped noise burst. The noise is generated first, filtered as a block, then
## enveloped, so the filter state never depends on where the burst sits in the buffer.
static func _add_noise_burst(
	samples: PackedFloat32Array,
	rng: DeterministicRng,
	start_seconds: float,
	burst_seconds: float,
	amplitude: float,
	lowpass_hz: float,
	highpass_hz: float,
	attack_seconds := 0.0005
) -> void:
	var start_index := maxi(int(round(start_seconds * SAMPLE_RATE)), 0)
	var length := maxi(int(round(burst_seconds * SAMPLE_RATE)), 1)
	var noise := PackedFloat32Array()
	noise.resize(length)
	for index in range(length):
		noise[index] = rng.next_bipolar()

	if lowpass_hz > 0.0:
		noise = _one_pole_lowpass(noise, lowpass_hz)
	if highpass_hz > 0.0:
		noise = _one_pole_highpass(noise, highpass_hz)

	for index in range(length):
		var target_index := start_index + index
		if target_index >= samples.size():
			break

		var elapsed := float(index) / float(SAMPLE_RATE)
		var envelope := _hit_envelope(elapsed, attack_seconds, burst_seconds * 0.45)
		samples[target_index] += noise[index] * amplitude * envelope


## Linear attack into an exponential decay, floored to zero once it is inaudible so long buffers do
## not carry a denormal tail.
static func _hit_envelope(elapsed_seconds: float, attack_seconds: float, decay_seconds: float) -> float:
	if elapsed_seconds < 0.0:
		return 0.0

	if attack_seconds > 0.0 and elapsed_seconds < attack_seconds:
		return elapsed_seconds / attack_seconds

	if decay_seconds <= 0.0:
		return 0.0

	var decayed := exp(-(elapsed_seconds - attack_seconds) / decay_seconds)
	return 0.0 if decayed < 0.0005 else decayed


static func _one_pole_lowpass(samples: PackedFloat32Array, cutoff_hz: float) -> PackedFloat32Array:
	var coefficient := exp(-TAU * cutoff_hz / float(SAMPLE_RATE))
	var filtered := PackedFloat32Array()
	filtered.resize(samples.size())
	var previous := 0.0
	for index in range(samples.size()):
		previous = (1.0 - coefficient) * samples[index] + coefficient * previous
		filtered[index] = previous

	return filtered


static func _one_pole_highpass(samples: PackedFloat32Array, cutoff_hz: float) -> PackedFloat32Array:
	var lowpassed := _one_pole_lowpass(samples, cutoff_hz)
	var filtered := PackedFloat32Array()
	filtered.resize(samples.size())
	for index in range(samples.size()):
		filtered[index] = samples[index] - lowpassed[index]

	return filtered


## Removes the offset that asymmetric transients leave behind. Runs before the edge fades so the
## first and last samples still land on silence afterwards.
static func _block_dc(samples: PackedFloat32Array) -> PackedFloat32Array:
	var filtered := PackedFloat32Array()
	filtered.resize(samples.size())
	var previous_input := 0.0
	var previous_output := 0.0
	for index in range(samples.size()):
		var input := samples[index]
		previous_output = input - previous_input + DC_BLOCKER_POLE * previous_output
		previous_input = input
		filtered[index] = previous_output

	return filtered


static func _apply_edge_fades(samples: PackedFloat32Array) -> void:
	var attack_length := mini(int(round(ATTACK_FADE_SECONDS * SAMPLE_RATE)), samples.size())
	for index in range(attack_length):
		samples[index] *= float(index) / float(attack_length)

	# `index + 1` so the last sample lands on exact silence. Without it a cue whose tail is still
	# loud (coin_gain, shop_purchase_success) ends one fade step above zero and clicks.
	var release_length := mini(int(round(RELEASE_FADE_SECONDS * SAMPLE_RATE)), samples.size())
	for index in range(release_length):
		var target_index := samples.size() - release_length + index
		samples[target_index] *= 1.0 - float(index + 1) / float(release_length)


## Scales the whole cue so its quantized peak lands on the authored target. This sets relative
## loudness between cues; it is not a loudness match across cues.
static func _scale_to_peak_db(samples: PackedFloat32Array, target_peak_db: float) -> void:
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, absf(sample))

	if peak <= 0.0:
		return

	var target_peak := db_to_linear(minf(target_peak_db, PEAK_CEILING_DB))
	var gain := target_peak / peak
	for index in range(samples.size()):
		samples[index] *= gain


static func _render_ui_click(samples: PackedFloat32Array, rng: DeterministicRng, variant: int) -> void:
	var body_hz := [1500.0, 1320.0, 1680.0][variant % 3] as float
	var decay := [0.011, 0.015, 0.012][variant % 3] as float
	var noise_lowpass := [3400.0, 3000.0, 3900.0][variant % 3] as float
	_add_noise_burst(samples, rng, 0.0, 0.008, 0.55, noise_lowpass, 900.0)
	_add_partial(samples, 0.0, body_hz, 0.62, decay, 0.0008)
	_add_partial(samples, 0.0, body_hz * 2.1, 0.16, decay * 0.6, 0.0006)
	_add_partial(samples, 0.0, 240.0, 0.20, 0.012, 0.0012)


static func _render_item_select(samples: PackedFloat32Array, rng: DeterministicRng, variant: int) -> void:
	var base_hz := [700.0, 760.0, 660.0][variant % 3] as float
	var decay := [0.030, 0.034, 0.026][variant % 3] as float
	_add_noise_burst(samples, rng, 0.0, 0.005, 0.24, 4200.0, 1400.0)
	_add_partial(samples, 0.0, base_hz, 0.95, decay, 0.0016, 1.18, 0.018)
	_add_partial(samples, 0.0, base_hz * 2.0, 0.34, decay * 0.62, 0.0014, 1.18, 0.018)
	_add_partial(samples, 0.0, base_hz * 3.0, 0.14, decay * 0.4, 0.0012, 1.18, 0.018)


static func _render_star_arrival(samples: PackedFloat32Array, rng: DeterministicRng) -> void:
	var base_hz := 1567.98
	_add_noise_burst(samples, rng, 0.0, 0.006, 0.14, 9000.0, 3000.0)
	_add_partial(samples, 0.0, base_hz, 1.0, 0.150, 0.004)
	_add_partial(samples, 0.0, base_hz * 2.0, 0.52, 0.095, 0.004)
	_add_partial(samples, 0.0, base_hz * 3.01, 0.28, 0.065, 0.003)
	_add_partial(samples, 0.0, base_hz * 4.72, 0.15, 0.042, 0.003)
	# A single higher grace partial a beat later is what makes this read as "arrived" rather than
	# "struck", without adding a reverb-like tail.
	_add_partial(samples, 0.045, base_hz * 1.5, 0.30, 0.085, 0.004)


static func _render_timer_tick(samples: PackedFloat32Array, rng: DeterministicRng, variant: int) -> void:
	var tick_hz := [2600.0, 2950.0, 2400.0][variant % 3] as float
	var decay := [0.010, 0.008, 0.012][variant % 3] as float
	var body_hz := [190.0, 210.0, 175.0][variant % 3] as float
	_add_noise_burst(samples, rng, 0.0, 0.004, 0.45, 6500.0, 1800.0)
	_add_partial(samples, 0.0, tick_hz, 0.55, decay, 0.0005)
	_add_partial(samples, 0.0, body_hz, 0.38, 0.018, 0.0010)


static func _render_time_up(samples: PackedFloat32Array, rng: DeterministicRng) -> void:
	# A last tick, then the clock stopping: a short downward glide with a damped wooden body. Warm
	# and decisive on purpose -- no siren, no horror-coded dissonance.
	_add_noise_burst(samples, rng, 0.0, 0.004, 0.40, 6500.0, 1800.0)
	_add_partial(samples, 0.0, 2600.0, 0.50, 0.010, 0.0005)
	_add_partial(samples, 0.0, 190.0, 0.34, 0.018, 0.0010)

	_add_noise_burst(samples, rng, 0.070, 0.030, 0.30, 1400.0, 120.0, 0.002)
	_add_partial(samples, 0.070, 392.00, 0.85, 0.200, 0.004, 1.0, 0.0)
	_add_partial(samples, 0.070, 261.63, 0.70, 0.260, 0.005, 1.0, 0.0)
	_add_partial(samples, 0.070, 130.81, 0.55, 0.300, 0.006, 1.0, 0.0)
	# The settling glide down a fifth is the "stopped" gesture.
	_add_partial(samples, 0.215, 196.00, 0.45, 0.230, 0.008, 1.34, 0.130)
	_add_partial(samples, 0.215, 98.00, 0.30, 0.250, 0.010, 1.34, 0.130)


## Shared metallic-coin voice for both currency cues: an inharmonic partial stack per note, played
## as a short ascending or descending sequence. `decay_scale` shortens the whole voice for the
## quicker spend cue.
static func _render_coin_sequence(
	samples: PackedFloat32Array,
	rng: DeterministicRng,
	note_frequencies: Array,
	note_spacing_seconds: float,
	decay_scale: float
) -> void:
	var partials := [
		{"ratio": 1.0, "amplitude": 1.0, "decay": 0.250},
		{"ratio": 2.76, "amplitude": 0.40, "decay": 0.150},
		{"ratio": 5.40, "amplitude": 0.19, "decay": 0.090},
		{"ratio": 8.93, "amplitude": 0.08, "decay": 0.055},
	]
	for note_index in range(note_frequencies.size()):
		var start_seconds := float(note_index) * note_spacing_seconds
		var note_hz := float(note_frequencies[note_index])
		_add_noise_burst(samples, rng, start_seconds, 0.004, 0.10, 9000.0, 3500.0)
		for partial in partials:
			_add_partial(
				samples,
				start_seconds,
				note_hz * float(partial["ratio"]),
				float(partial["amplitude"]),
				float(partial["decay"]) * decay_scale,
				0.002
			)


static func _render_shop_success(samples: PackedFloat32Array, rng: DeterministicRng) -> void:
	# Warm F major, soft mallet attack, deliberately restrained highs so a layered coin_gain still
	# has room above it.
	var chord := [
		{"hz": 349.23, "start": 0.000, "amplitude": 0.85},
		{"hz": 440.00, "start": 0.006, "amplitude": 0.72},
		{"hz": 523.25, "start": 0.012, "amplitude": 0.64},
		{"hz": 698.46, "start": 0.018, "amplitude": 0.48},
	]
	_add_noise_burst(samples, rng, 0.0, 0.012, 0.10, 2600.0, 500.0, 0.003)
	for voice in chord:
		var base_hz := float(voice["hz"])
		var start := float(voice["start"])
		var amplitude := float(voice["amplitude"])
		_add_partial(samples, start, base_hz, amplitude, 0.420, 0.016)
		_add_partial(samples, start, base_hz * 2.0, amplitude * 0.34, 0.260, 0.014)
		_add_partial(samples, start, base_hz * 3.0, amplitude * 0.15, 0.150, 0.012)
		_add_partial(samples, start, base_hz * 4.0, amplitude * 0.06, 0.090, 0.010)


static func _render_chest_arrival(samples: PackedFloat32Array, rng: DeterministicRng, variant: int) -> void:
	# The softer companion to star_hud_arrival: lower, rounder, and without the grace partial, so a
	# staggered flight of these never turns into a shrill stack.
	var base_hz := [1046.50, 1174.66, 1244.51][variant % 3] as float
	_add_noise_burst(samples, rng, 0.0, 0.004, 0.08, 6000.0, 2000.0)
	_add_partial(samples, 0.0, base_hz, 1.0, 0.090, 0.006)
	_add_partial(samples, 0.0, base_hz * 2.0, 0.38, 0.055, 0.005)
	_add_partial(samples, 0.0, base_hz * 3.02, 0.16, 0.034, 0.004)
