extends Node
## Placeholder sound effects synthesised at startup (no asset files needed).
## Works on Web because everything is a plain AudioStreamWAV.

const MIX_RATE := 22050
const POOL_SIZE := 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_build_library()

func play(name: String, volume_db := 0.0) -> void:
	if not _streams.has(name):
		push_warning("Sfx: unknown sound '%s'" % name)
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = volume_db
			p.play()
			return

# ---------------------------------------------------------------------------

func _build_library() -> void:
	_streams["place"] = _synth(0.09, func(t: float, n: float) -> float:
		return sin(TAU * 620.0 * t) * exp(-n * 6.0) * 0.6 + _noise() * exp(-n * 20.0) * 0.15)
	_streams["miss"] = _synth(0.12, func(t: float, n: float) -> float:
		return sin(TAU * 180.0 * t) * exp(-n * 4.0) * 0.4)
	_streams["warn"] = _synth(0.35, func(t: float, n: float) -> float:
		var gate := 1.0 if fmod(t, 0.175) < 0.1 else 0.0
		return sin(TAU * 880.0 * t) * gate * 0.35 * (1.0 - n * 0.3))
	_streams["stage"] = _synth(0.15, func(t: float, n: float) -> float:
		return sin(TAU * 660.0 * t) * exp(-n * 3.0) * 0.35)
	_streams["danger"] = _synth(0.5, func(t: float, n: float) -> float:
		var gate := 1.0 if fmod(t, 0.125) < 0.07 else 0.0
		return (sin(TAU * 990.0 * t) + sin(TAU * 1320.0 * t) * 0.5) * gate * 0.3 * (1.0 - n * 0.2))
	_streams["resolve"] = _synth(0.4, func(t: float, n: float) -> float:
		return (sin(TAU * 523.0 * t) + sin(TAU * 659.0 * t) + sin(TAU * 784.0 * t)) / 3.0 * exp(-n * 3.0) * 0.5)
	_streams["fall"] = _synth(1.2, func(t: float, n: float) -> float:
		var clicks := 1.0 if fmod(t * (18.0 - n * 10.0), 1.0) < 0.15 else 0.0
		return _noise() * clicks * (1.0 - n) * 0.6)
	_streams["meow"] = _synth(0.4, func(t: float, n: float) -> float:
		var f := lerpf(520.0, 900.0, sin(n * PI)) + sin(t * 60.0) * 20.0
		return sin(TAU * f * t) * sin(n * PI) * 0.35)
	_streams["purr"] = _synth(0.5, func(t: float, n: float) -> float:
		return sin(TAU * 90.0 * t) * (0.6 + 0.4 * sin(TAU * 25.0 * t)) * sin(n * PI) * 0.3)
	_streams["wind"] = _synth(1.6, func(_t: float, n: float) -> float:
		return _noise() * sin(n * PI) * 0.25)
	_streams["creak"] = _synth(0.6, func(t: float, n: float) -> float:
		var f := 180.0 + sin(n * 9.0) * 40.0 + n * 60.0
		return (sin(TAU * f * t) + sin(TAU * f * 2.01 * t) * 0.4) * sin(n * PI) * 0.25)
	_streams["rattle"] = _synth(0.9, func(t: float, n: float) -> float:
		var gate := 1.0 if fmod(t * 22.0, 1.0) < 0.2 else 0.0
		return _noise() * gate * (1.0 - n * 0.5) * 0.3)
	_streams["steps"] = _synth(1.2, func(t: float, n: float) -> float:
		var gate := 1.0 if fmod(t * 3.5, 1.0) < 0.08 else 0.0
		return sin(TAU * 120.0 * t) * gate * (1.0 - n * 0.3) * 0.5)
	_streams["growl"] = _synth(0.7, func(t: float, n: float) -> float:
		return sin(TAU * 75.0 * t) * (0.5 + 0.5 * sin(TAU * 30.0 * t)) * sin(n * PI) * 0.35)
	_streams["thud"] = _synth(0.3, func(t: float, n: float) -> float:
		return sin(TAU * 70.0 * t) * exp(-n * 5.0) * 0.8)
	# The robot's motor. Replayed on a loop while it drives, so it needs to be
	# quiet, dull and slightly wobbly - a hum you stop hearing until it gets
	# close, which is exactly how you notice the real thing.
	_streams["motor"] = _synth(1.0, func(t: float, n: float) -> float:
		var hum := sin(TAU * 108.0 * t) * 0.34 + sin(TAU * 216.0 * t) * 0.11
		var window: float = min(1.0, min(n, 1.0 - n) * 8.0)
		return (hum * (0.85 + 0.15 * sin(TAU * 7.0 * t)) + _noise() * 0.09) * window)
	# Two rising blips: the robot acknowledging a button.
	_streams["beep"] = _synth(0.17, func(t: float, n: float) -> float:
		var f := 760.0 if n < 0.5 else 1040.0
		return sin(TAU * f * t) * exp(-fmod(n, 0.5) * 7.0) * 0.4)
	# A lamp switch: one hard mechanical click, no tone. Two clacks a few
	# milliseconds apart is what a rocker switch actually sounds like, and the
	# second one is what makes it read as a switch rather than as a tap.
	_streams["switch"] = _synth(0.1, func(t: float, n: float) -> float:
		var a := _noise() * exp(-n * 55.0) * 0.7
		var b := _noise() * exp(-maxf(n - 0.28, 0.0) * 40.0) * 0.45 if n > 0.28 else 0.0
		return a + b + sin(TAU * 240.0 * t) * exp(-n * 30.0) * 0.2)
	# The UI click. Deliberately duller and shorter than "beep", which belongs to
	# the robot: a menu is not a character and should not sound like one.
	_streams["ui"] = _synth(0.07, func(t: float, n: float) -> float:
		return sin(TAU * 420.0 * t) * exp(-n * 14.0) * 0.35 + _noise() * exp(-n * 40.0) * 0.1)
	_streams["win"] = _synth(0.9, func(t: float, n: float) -> float:
		var notes := [523.0, 659.0, 784.0, 1046.0]
		var idx: int = min(int(n * 4.0), 3)
		var local := fmod(t, 0.225)
		return sin(TAU * notes[idx] * t) * exp(-local * 6.0) * 0.45)

var _rng := RandomNumberGenerator.new()

func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)

## generator(t_seconds, normalized_0_to_1) -> sample in [-1, 1]
func _synth(duration: float, generator: Callable) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / MIX_RATE
		var v: float = clamp(generator.call(t, t / duration), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
