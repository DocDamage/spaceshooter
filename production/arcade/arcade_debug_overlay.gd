class_name ArcadeDebugOverlay
extends CanvasLayer

var player: ProductionPlayer
var tracker: MissionScoreTracker
var pool: ProjectilePoolManager
var readout: Label

func configure(player_actor: ProductionPlayer, score: MissionScoreTracker, projectile_pool: ProjectilePoolManager) -> void:
	player = player_actor; tracker = score; pool = projectile_pool

func _ready() -> void:
	layer = 80
	readout = Label.new(); readout.position = Vector2(12, 108); readout.add_theme_font_size_override("font_size", 12); readout.modulate = Color("a8eaff"); add_child(readout)

func _process(_delta: float) -> void:
	if readout == null or player == null or tracker == null: return
	var cancelable := 0
	if pool != null:
		for category in [&"enemy_bullet", &"missile", &"mine"]:
			for projectile in pool.get_active_objects(category):
				if projectile is ProductionProjectile and projectile.can_convert(): cancelable += 1
	readout.text = "ARCADE DEBUG\nCORE %.1f  GRAZE %.1f  CANCEL %d\nCHAIN %.0f%% via %s  RANK %s" % [player.hurtbox_component.radius, player.ship_definition.graze_radius, cancelable, tracker.chain_fill * 100.0, tracker.last_chain_source, "●".repeat(tracker.rank_pips())]
