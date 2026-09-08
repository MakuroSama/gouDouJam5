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

func play_sfx(stream: AudioStream, volume_db: float = 1.0):
	for p in players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			return
	# optional: steal the oldest voice if pool is full
	players[0].stream = stream
	players[0].play()
