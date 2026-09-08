# MusicPlayer.gd (set as autoload)
extends Node

@onready var player = AudioStreamPlayer.new()

func _ready():
	add_child(player)
	player.stream = preload("res://SE・BGM/BGM/audiostock_1086176.mp3")
	player.volume_db = -5
	player.play()

func play_track(stream: AudioStream, fade_in: bool = false):
	player.stream = stream
	player.play()

func stop():
	player.stop()
