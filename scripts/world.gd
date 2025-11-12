extends Node

@onready var main_menu: PanelContainer = $Menu/MainMenu
@onready var options_menu: PanelContainer = $Menu/Options
@onready var pause_menu: PanelContainer = $Menu/PauseMenu
@onready var address_entry: LineEdit = %AddressEntry
@onready var menu_music: AudioStreamPlayer = %MenuMusic

const Player = preload("res://prefabs/player.tscn")
const Enemy = preload("res://prefabs/zombie_enemy.tscn")
const PORT = 5500
var enet_peer = NodeTunnelPeer.new()
var paused: bool = false
var options: bool = false
var controller: bool = false

var playerList = []

# Spawner Code Temp
@onready var terrain: Terrain3D = $NavMap/Terrain3D  # Adjust to your terrain node path

@export var spawn_interval: float = 10.0
@export var spawn_area_size: float = 20.0

func _ready() -> void:
	multiplayer.multiplayer_peer = enet_peer

	enet_peer.connect_to_relay("relay.nodetunnel.io", 9998)
	await enet_peer.relay_connected
	print("Connected! Your ID: ", enet_peer.online_id)

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_pressed("pause") and !main_menu.visible and !options_menu.visible:
		paused = !paused
	if event is InputEventJoypadMotion:
		controller = true
	elif event is InputEventMouseMotion:
		controller = false

func _process(_delta: float) -> void:
	
	if playerList.size() > 0:
		get_tree().call_group("enemy", "target_position", playerList[0])
	
	if paused:
		$Menu/Blur.show()
		pause_menu.show()
		if !controller:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_resume_pressed() -> void:
	if !options:
		$Menu/Blur.hide()
	$Menu/PauseMenu.hide()
	if !controller:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	paused = false
	
func _on_options_pressed() -> void:
	_on_resume_pressed()
	$Menu/Options.show()
	$Menu/Blur.show()
	%Fullscreen.grab_focus()
	if !controller:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	options = true

func _on_back_pressed() -> void:
	if options:
		$Menu/Blur.hide()
		if !controller:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		options = false

#func _ready() -> void:
func _on_host_button_pressed() -> void:
	main_menu.hide()
	$Menu/DollyCamera.hide()
	$Menu/Blur.hide()
	menu_music.stop()

	#enet_peer.create_server(PORT)
	#multiplayer.multiplayer_peer = enet_peer
	
	enet_peer.host()
	await enet_peer.hosting
	print("Share this ID: ", enet_peer.online_id)
	DisplayServer.clipboard_set(enet_peer.online_id)
	
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)

	if options_menu.visible:
		options_menu.hide()

	add_player(multiplayer.get_unique_id())
	
	if is_multiplayer_authority():
		print("Called RPC")
		spawn_enemy_loop.rpc_id(multiplayer.get_unique_id())
	#upnp_setup()

func _on_join_button_pressed() -> void:
	main_menu.hide()
	$Menu/Blur.hide()
	menu_music.stop()
	
	#enet_peer.create_client(address_entry.text, PORT)
	
	enet_peer.join(address_entry.text)
	await enet_peer.joined
	
	if options_menu.visible:
		options_menu.hide()
	multiplayer.multiplayer_peer = enet_peer

func _on_options_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		options_menu.show()
	else:
		options_menu.hide()
		
func _on_music_toggle_toggled(toggled_on: bool) -> void:
	if !toggled_on:
		menu_music.stop()
	else:
		menu_music.play()

func add_player(peer_id: int) -> void:
	var player: Node = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)
	playerList.append(player)

func remove_player(peer_id: int) -> void:
	var player: Node = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
		

@rpc("authority", "call_local")
func spawn_enemy_loop() -> void:
	add_zombie()
	# Repeat every 2 seconds
	await get_tree().create_timer(spawn_interval).timeout
	spawn_enemy_loop()
	
func add_zombie() -> void:
	print("Zombie Spawned")


	# Generate random XZ position within spawn area
	var x = randf_range(-spawn_area_size / 2, spawn_area_size / 2)
	var z = randf_range(-spawn_area_size / 2, spawn_area_size / 2)
	
	# Query the terrain height (this is the magic part)
	var y = terrain.data.get_height(Vector3(x, 0, z))
	#terrain.
	if is_nan(y):
		return
		
	var zombie: Node = Enemy.instantiate()
	zombie.name = "Zombie" + str(randi_range(0, 1000))
	zombie.set_multiplayer_authority(1)
	$ZombieList.add_child(zombie)
	zombie.position = Vector3(x, y + 1, z)

func upnp_setup() -> void:
	var upnp: UPNP = UPNP.new()

	upnp.discover()
	upnp.add_port_mapping(PORT)

	var ip: String = upnp.query_external_address()
	if ip == "":
		print("Failed to establish upnp connection!")
	else:
		print("Success! Join Address: %s" % upnp.query_external_address())
