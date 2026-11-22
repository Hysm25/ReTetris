class_name MusicBytecodePlayer
extends RefCounted

## Authentic 1989 NES Tetris 2A03 APU Music Bytecode Interpreter.
## Reverse-engineered from main.asm (loadMusicTrack $EA70, updateMusicFrame $EBE6).
## Runs synchronously at 60 TPS (_physics_process) to drive Pulse 1, Pulse 2,
## Triangle, and Noise channels using authentic PRG-ROM sound routines and envelopes.

const Constants = preload("res://src/core/constants.gd")

class ChannelState:
	var enabled: bool = false
	var script_addr: int = 0
	var script_offset: int = 0
	var routine_addr: int = 0
	var instruction_offset: int = 0
	var instruction_offset_backup: int = 0
	var loop_counter: int = 0
	var note_duration_remaining: int = 1
	var note_duration: int = 1
	var current_note: int = 0
	var timer_period: int = 0
	var volume: float = 0.0
	var duty: int = 2
	var vol_control: int = 0
	var vol_base: int = 0
	var vol_frame_counter: int = 0
	var noise_period: float = 0.001
	var is_periodic_noise: bool = false
	var reset_phase: bool = false

var channels: Array[ChannelState] = []
var currently_playing_track: int = -1
var note_offset: int = 0
var duration_offset: int = 0

# Authentic 16-entry NES APU Noise Timer Period Table (CPU cycle counts)
const NOISE_PERIOD_TABLE: Array[int] = [
	4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068
]

# Authentic tables loaded from PRG-ROM
var prg_rom: PackedByteArray = PackedByteArray()
var note_to_wave_table: PackedByteArray = PackedByteArray()
var note_duration_table: PackedByteArray = PackedByteArray()
var music_data_table: PackedByteArray = PackedByteArray()
var music_vol_table: PackedByteArray = PackedByteArray()
var noises_table: PackedByteArray = PackedByteArray()

func _init() -> void:
	channels.clear()
	for i in range(4):
		channels.append(ChannelState.new())

## Ingests sound engine bytecode and tables from ROM extraction result.
func setup_tables(
	p_prg: PackedByteArray,
	p_wave: PackedByteArray,
	p_dur: PackedByteArray,
	p_data: PackedByteArray,
	p_vol: PackedByteArray,
	p_noises: PackedByteArray
) -> void:
	prg_rom = p_prg
	note_to_wave_table = p_wave
	note_duration_table = p_dur
	music_data_table = p_data
	music_vol_table = p_vol
	noises_table = p_noises

## Helper to safely read a byte from PRG-ROM via NES CPU address ($8000..$FFFF).
func read_prg(cpu_addr: int) -> int:
	var idx: int = cpu_addr - 0x8000
	if idx >= 0 and idx < prg_rom.size():
		return prg_rom[idx]
	return 0

## Helper to safely read a 16-bit little-endian word from PRG-ROM.
func read_prg_word(cpu_addr: int) -> int:
	var lo: int = read_prg(cpu_addr)
	var hi: int = read_prg(cpu_addr + 1)
	return lo | (hi << 8)

## Loads and starts one of the 10 authentic NES Tetris music tracks (0..9).
## Track IDs:
## 0: Title Screen
## 1: B-Type Goal Achieved
## 2: Music 1 (Korobeiniki)
## 3: Music 2 (Troika)
## 4: Music 3 (Kalinka)
## 5: Music 1 Fast
## 6: Music 2 Fast
## 7: Music 3 Fast
## 8: Congratulations (Level Complete)
## 9: Ending Theme (Rocket)
func load_track(track_id: int) -> void:
	stop_music()
	if track_id < 0 or track_id >= 10:
		return
	if music_data_table.size() < (track_id * 10 + 10):
		return

	currently_playing_track = track_id
	var base_idx: int = track_id * 10
	note_offset = music_data_table[base_idx]
	duration_offset = music_data_table[base_idx + 1]

	var script_addrs: Array[int] = [
		music_data_table[base_idx + 2] | (music_data_table[base_idx + 3] << 8),
		music_data_table[base_idx + 4] | (music_data_table[base_idx + 5] << 8),
		music_data_table[base_idx + 6] | (music_data_table[base_idx + 7] << 8),
		music_data_table[base_idx + 8] | (music_data_table[base_idx + 9] << 8),
	]

	for ch_idx in range(4):
		var ch: ChannelState = channels[ch_idx]
		var s_addr: int = script_addrs[ch_idx]
		if s_addr == 0xFFFF or s_addr == 0:
			ch.enabled = false
			ch.routine_addr = 0
			continue

		ch.enabled = true
		ch.script_addr = s_addr
		ch.script_offset = 0
		ch.instruction_offset = 0
		ch.instruction_offset_backup = 0
		ch.loop_counter = 0
		ch.note_duration_remaining = 1
		ch.note_duration = 1
		ch.vol_control = 0
		ch.vol_base = 0
		ch.vol_frame_counter = 0
		ch.volume = 0.0

		_load_routine(ch_idx)

func _load_routine(ch_idx: int) -> void:
	var ch: ChannelState = channels[ch_idx]
	while ch.enabled:
		var routine_word: int = read_prg_word(ch.script_addr + ch.script_offset)
		if routine_word == 0x0000:
			# End of channel playback
			ch.enabled = false
			ch.routine_addr = 0
			ch.volume = 0.0
			return
		elif routine_word == 0xFFFF:
			# Loop destination pointer follows $FFFF in script
			var loop_target: int = read_prg_word(ch.script_addr + ch.script_offset + 2)
			ch.script_addr = loop_target
			ch.script_offset = 0
			continue
		else:
			ch.routine_addr = routine_word
			ch.instruction_offset = 0
			ch.note_duration_remaining = 1
			return

## Advances the audio simulation by 1 frame (60 Hz).
func step_frame() -> void:
	if currently_playing_track < 0:
		return

	for ch_idx in range(4):
		var ch: ChannelState = channels[ch_idx]
		if not ch.enabled or ch.routine_addr == 0:
			continue

		ch.note_duration_remaining -= 1
		if ch.note_duration_remaining <= 0:
			ch.vol_frame_counter = 0
			_execute_channel_instructions(ch_idx)
		else:
			if ch_idx == 2 and ch.note_duration_remaining == 1:
				# Authentic 2A03 APU Triangle linear counter expiration on final frame of note
				ch.volume = 0.0
			_update_channel_envelope(ch_idx)

func _execute_channel_instructions(ch_idx: int) -> void:
	var ch: ChannelState = channels[ch_idx]
	while ch.enabled:
		var b: int = read_prg(ch.routine_addr + ch.instruction_offset)
		ch.instruction_offset += 1

		if b == 0x00:
			# Routine completed -> advance to next routine in script
			ch.script_offset += 2
			_load_routine(ch_idx)
			continue
		elif b == 0x9F:
			# Set instrument envelope control byte and base volume/duty
			ch.vol_control = read_prg(ch.routine_addr + ch.instruction_offset)
			ch.instruction_offset += 1
			ch.vol_base = read_prg(ch.routine_addr + ch.instruction_offset)
			ch.instruction_offset += 1
			continue
		elif b == 0x9E:
			# Set tempo duration table offset
			duration_offset = read_prg(ch.routine_addr + ch.instruction_offset)
			ch.instruction_offset += 1
			continue
		elif b == 0x9C:
			# Set note key transposition offset
			note_offset = read_prg(ch.routine_addr + ch.instruction_offset)
			ch.instruction_offset += 1
			continue
		elif b == 0xFF:
			# Loop terminator
			if ch.loop_counter > 0:
				ch.loop_counter -= 1
				ch.instruction_offset = ch.instruction_offset_backup
			continue
		elif (b & 0xC0) == 0xC0:
			# For-loop start: low 6 bits = loop count (1 = run once)
			var count: int = b & 0x3F
			ch.loop_counter = count - 1
			ch.instruction_offset_backup = ch.instruction_offset
			continue
		else:
			# Note or duration followed by note
			var note_byte: int = b
			if (b & 0xF0) == 0xB0: # Duration index prefix
				var dur_idx: int = (b & 0x0F) + duration_offset
				if dur_idx < note_duration_table.size():
					ch.note_duration = note_duration_table[dur_idx]
				note_byte = read_prg(ch.routine_addr + ch.instruction_offset)
				ch.instruction_offset += 1

			ch.note_duration_remaining = ch.note_duration
			ch.current_note = note_byte
			if ch_idx == 0 or ch_idx == 1:
				ch.reset_phase = true

			if ch_idx == 3: # Noise Channel
				# Authentic NES Tetris playNoise ($E9EB): y = (note_byte & 0x3F) directly indexes $E5AB
				var noise_idx: int = (note_byte & 0x3F)
				if noise_idx + 2 < noises_table.size():
					var n_vol: int = noises_table[noise_idx]
					var n_lo: int = noises_table[noise_idx + 1]
					var is_const_vol: bool = (n_vol & 0x10) != 0
					if is_const_vol:
						ch.volume = float(n_vol & 0x0F) / 15.0
					else:
						# Envelope decay mode: start at 0.8 and decay frame by frame
						ch.volume = 0.8
					ch.is_periodic_noise = (n_lo & 0x80) != 0
					var period_idx: int = n_lo & 0x0F
					var cpu_cycles: int = NOISE_PERIOD_TABLE[period_idx] if period_idx < NOISE_PERIOD_TABLE.size() else 4
					ch.noise_period = float(cpu_cycles) / Constants.NES_CPU_FREQ
				else:
					ch.volume = 0.0
			else:
				# Channels 0 (Pulse 1), 1 (Pulse 2), 2 (Triangle)
				if note_byte == 0x00 or note_byte == 0x02:
					# Rest / Mute
					ch.volume = 0.0
				else:
					var transposed: int = note_byte
					if (note_offset & 0x80) != 0:
						var sub_val: int = (note_offset & 0x7F)
						transposed = note_byte - sub_val - 1
					else:
						transposed = note_byte + note_offset

					if transposed >= 0 and (transposed + 1) < note_to_wave_table.size():
						var hi: int = note_to_wave_table[transposed]
						var lo: int = note_to_wave_table[transposed + 1]
						if hi == 0 and lo == 0:
							ch.volume = 0.0
						else:
							ch.timer_period = lo | ((hi & 0x07) << 8)
							if ch_idx == 2: # Triangle
								ch.volume = 0.4
							else: # Pulse 1 / Pulse 2
								ch.duty = (ch.vol_base >> 6) & 3
								ch.volume = float(ch.vol_base & 0x0F) / 15.0
			_update_channel_envelope(ch_idx)
			break

func _update_channel_envelope(ch_idx: int) -> void:
	if ch_idx == 3:
		# Authentic hardware envelope decay for noise channel percussion
		var ch_noise: ChannelState = channels[3]
		if ch_noise.volume > 0.0:
			ch_noise.volume = ch_noise.volume * 0.60
			if ch_noise.volume < 0.02:
				ch_noise.volume = 0.0
		return

	if ch_idx == 2:
		return # Triangle channel does not use volume envelopes

	var ch: ChannelState = channels[ch_idx]
	var env_idx: int = (ch.vol_control & 0x1F) - 1
	if env_idx < 0:
		return
	if (env_idx * 2 + 1) >= music_vol_table.size():
		return

	var env_ptr: int = music_vol_table[env_idx * 2] | (music_vol_table[env_idx * 2 + 1] << 8)
	var byte_idx: int = ch.vol_frame_counter >> 1
	var env_byte: int = read_prg(env_ptr + byte_idx)

	if env_byte == 0xFF:
		# Sustain last volume (hold without advancing frame counter)
		return
	elif env_byte == 0xF0:
		# Release / mute (hold mute without advancing frame counter)
		ch.volume = 0.0
		return
	else:
		var nibble: int = (env_byte >> 4) & 0x0F if (ch.vol_frame_counter & 1) == 0 else (env_byte & 0x0F)
		ch.duty = (ch.vol_base >> 6) & 3
		ch.volume = float(nibble) / 15.0
		ch.vol_frame_counter += 1

## Halts music playback and mutes all channels.
func stop_music() -> void:
	currently_playing_track = -1
	for ch in channels:
		ch.enabled = false
		ch.volume = 0.0
		ch.routine_addr = 0
