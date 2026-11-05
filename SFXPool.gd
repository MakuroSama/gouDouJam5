# SFXPool.gd — autoload singleton
extends Node

const POOL_SIZE = 16
var players: Array[AudioStreamPlayer] = []
var priority_player: AudioStreamPlayer
var steal_idx: int = 0

func _ready():
	for i in POOL_SIZE:
		var p = AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	
	# 専用の優先再生プレイヤー（袋破れなど、絶対に途中で途切れてはいけない重要SE用）
	priority_player = AudioStreamPlayer.new()
	add_child(priority_player)

# 指定されたストリームの再生をすべて停止する
func stop_stream(stream: AudioStream) -> void:
	for p in players:
		if p.playing and p.stream == stream:
			p.stop()
	if priority_player and priority_player.playing and priority_player.stream == stream:
		priority_player.stop()

# 優先再生（他のSEに奪われない専用チャンネル）
func play_priority_sfx(stream: AudioStream, volume_db: float = -2.0) -> void:
	if priority_player:
		priority_player.stream = stream
		priority_player.volume_db = volume_db
		priority_player.play()
	else:
		play_sfx(stream, volume_db)

# 通常SE再生
func play_sfx(stream: AudioStream, volume_db: float = -8.5) -> void:
	for p in players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			return
	# 空きがない場合はラウンドロビンで上書き
	players[steal_idx].stream = stream
	players[steal_idx].volume_db = volume_db
	players[steal_idx].play()
	steal_idx = (steal_idx + 1) % POOL_SIZE
