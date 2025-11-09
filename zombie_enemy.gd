extends CharacterBody3D

@onready var nav = $NavigationAgent3D
@onready var score_label: Label = $"../../Hud/Hud/MarginContainer/VBoxContainer/ScoreLabel"
@onready var animation_player: AnimationPlayer = $Zombie/AnimationPlayer

var speed = 1
var gravity = 9.8
var isWalking = true
var isAttacking = false

var health = 3
var attack_range = 2.0  # distance within which zombie attacks
var attack_cooldown = 1.5  # seconds between attacks
var last_attack_time = 0.0

const Enemy = preload("res://zombie_enemy.tscn")

var targetPlayer;

@export var spawns: PackedVector3Array = [
	Vector3(-18, 1.2, 0),
	Vector3(18, 1.2, 0),
	Vector3(-2.8, 1.2, -6),
	Vector3(-17, 1.2, 17),
	Vector3(17, 1.2, 17),
	Vector3(17, 1.2, -17),
]

func _process(delta):
	if health <= 0:
		return
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y -= 2
	
	var current_location = global_transform.origin
	var player_pos = nav.target_position
	var distance_to_player = current_location.distance_to(player_pos)
	
	# Attack if close enough and cooldown done
	if distance_to_player < attack_range and not isAttacking and (Time.get_ticks_msec() - last_attack_time) > attack_cooldown * 1000:
		start_attack()
		return
	
	# Follow player if not attacking
	if isWalking and not isAttacking:
		var next_location = nav.get_next_path_position()
		var direction = (next_location - current_location)
		direction.y = 0
		if direction.length() > 0.1:
			var new_velocity = direction.normalized() * speed
			velocity = velocity.move_toward(new_velocity, 0.25)
			look_at(current_location + direction, Vector3.UP)
		move_and_slide()

func start_attack():
	isAttacking = true
	isWalking = false
	velocity = Vector3.ZERO
	animation_player.play("zombie_attack")
	animation_player.connect("animation_finished", Callable(self, "on_attack_finished"), ConnectFlags.CONNECT_ONE_SHOT)

func on_attack_finished(anim_name):
	if anim_name != "zombie_attack":
		return
	
	print("Calling damage")
	if targetPlayer and global_transform.origin.distance_to(targetPlayer.global_transform.origin) < attack_range:
		print("Sending damage")
		targetPlayer.recieve_damage.rpc_id(targetPlayer.get_multiplayer_authority())
		#targetPlayer.rpc("recieve_damage", 1)  # ✅ Damage player if still nearby
	
	last_attack_time = Time.get_ticks_msec()
	isAttacking = false
	isWalking = true
	animation_player.play("walk")

func target_position(target):
	targetPlayer = target
	nav.target_position = target.global_transform.origin

func on_die(anim_name):
	queue_free()

func on_hit_complete(anim_name):
	print("walking on")
	isWalking = true
	animation_player.play("walk")

@rpc("any_peer", "call_local")
func recieve_damage(damage := 1) -> void:
	health -= damage
	if health <= 0:
		animation_player.play("Zombie Dying")
		animation_player.connect("animation_finished", Callable(self, "on_die"))
		var kills = int(score_label.text.split(" ")[1])
		score_label.text = "Kills: " + str(kills + 1)
		add_zombie.rpc_id(multiplayer.get_unique_id())
		#add_zombie.rpc_id(multiplayer.get_unique_id())
	else:
		isWalking = false
		animation_player.play("zombie_hit")
		animation_player.connect("animation_finished", Callable(self, "on_hit_complete"), ConnectFlags.CONNECT_ONE_SHOT)

@rpc("authority", "call_local")
func add_zombie() -> void:
	print("Zombie Spawned")
	var zombie: Node = Enemy.instantiate()
	zombie.name = "Zombie" + str(randi_range(0, 1000))
	zombie.set_multiplayer_authority(1)
	$"..".add_child(zombie)
	zombie.position = Vector3(0, 1, 0)
