@tool
extends MeshInstance3D

const size := 256.0

@export_range(4, 256, 4) var resolution := 32:
	set(new_resolution):
		resolution = new_resolution
		update_mesh()

@export var noise: FastNoiseLite:
	set(new_noise):
		noise = new_noise
		update_mesh()
		if noise:
			noise.changed.connect(update_mesh)
			
@export var noise_large: FastNoiseLite:
	set(new_noise):
		noise_large = new_noise
		update_mesh()
		if noise_large:
			noise_large.changed.connect(update_mesh)

@export_range(4.0, 128.0, 4.0) var height := 8.0:
	set(new_height):
		height = new_height
		if material_override != null:
			material_override.set_shader_parameter("height", height * 2.0)
		update_mesh()

func get_height(x: float, y: float) -> float:
	if noise == null || noise_large == null: return 0
	return noise.get_noise_2d(x, y) * height + (noise_large.get_noise_2d(x, y) * 10) 

func get_normal(x: float, y: float) -> Vector3:
	var epsilon := size / resolution
	var normal := Vector3(
		(get_height(x + epsilon, y) - get_height(x - epsilon, y)) / (2.0 * epsilon),
		1.0,
		(get_height(x, y + epsilon) - get_height(x, y - epsilon)) / (2.0 * epsilon),
	)
	return normal.normalized()

func update_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	plane.size = Vector2(size, size)
	
	var plane_arrays := plane.get_mesh_arrays()
	var vertex_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array: PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	
	for i:int in vertex_array.size():
		var vertex := vertex_array[i]
		var normal := Vector3.UP
		var tangent := Vector3.RIGHT
		if noise:
			vertex.y = get_height(vertex.x, vertex.z)
			normal = get_normal(vertex.x, vertex.z)
			tangent = normal.cross(Vector3.UP)
		vertex_array[i] = vertex
		normal_array[i] = normal
		tangent_array[4 * i] = tangent.x
		tangent_array[4 * i + 1] = tangent.y
		tangent_array[4 * i + 2] = tangent.z
	
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	mesh = array_mesh
	_add_collision(array_mesh)

func _add_collision(array_mesh: ArrayMesh) -> void:
	# Remove old collider
	var oldBodies: Array[Node] = get_children(false)
	for n in oldBodies:
		print("Found old node")
		n.queue_free()

	# Create StaticBody3D
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	add_child(body)

	# Create CollisionShape3D
	var col := CollisionShape3D.new()
	body.add_child(col)

	# Convert mesh → faces for concave collider
	var faces := array_mesh.get_faces()  # returns PackedVector3Array of triangles

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)

	col.shape = shape
