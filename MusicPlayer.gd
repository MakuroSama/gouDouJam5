# MusicPlayer.gd (set as autoload)
extends Node

@onready var player = AudioStreamPlayer.new()

func _ready():
	add_child(player)
	var bgm = preload("res://SE・BGM/BGM/audiostock_1086176.mp3")
	if bgm is AudioStreamMP3:
		bgm.loop = true
	player.stream = bgm
	# 元の音量 -5.0 dB をリニア値で1/3に調整 (-5.0 - 9.54 dB ≈ -14.5 dB)
	player.volume_db = -14.5
	player.finished.connect(func(): player.play())
	player.play()

func play_track(stream: AudioStream, fade_in: bool = false):
	if stream is AudioStreamMP3:
		stream.loop = true
	player.stream = stream
	player.play()

func stop():
	player.stop()
