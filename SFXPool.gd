# SFXPool.gd — autoload singleton
extends Node

const POOL_SIZE = 16
var players: Array[AudioStreamPlayer] = []

func _ready():
	for i in POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)

# 元の音量 1.0 dB をリニア値で1/3に調整 (1.0 - 9.54 dB ≈ -8.5 dB)
func play_sfx(stream: AudioStream, volume_db: float = -8.5):
	for p in players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			return
	# optional: steal the oldest voice if pool is full
	players[0].stream = stream
	players[0].volume_db = volume_db
	players[0].play()
