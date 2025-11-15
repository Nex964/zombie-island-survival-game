extends Node3D

const ADS_LERP: float = 20

@export var camera_path : NodePath
var camera : Camera3D

@export var default_position : Vector3
@export var ads_position : Vector3
var fview := { "Default": 70, "ADS": 50}

func _ready():
	camera = get_node(camera_path)
	
func _process(delta: float) -> void:
	if Input.is_action_pressed("fire2"):
		#position = ads_position
		#print(ads_position)
		position = position.lerp(ads_position, ADS_LERP * delta)
		camera.fov = lerp(camera.fov, float(fview["ADS"]), ADS_LERP * delta)
	else:
		#position = default_position
		#print(default_position)
		position = position.lerp(default_position, ADS_LERP * delta)
		camera.fov = lerp(camera.fov, float(fview["Default"]), ADS_LERP * delta)
