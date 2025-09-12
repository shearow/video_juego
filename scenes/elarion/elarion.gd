extends CharacterBody3D

# ------------------------------------
## CONFIGURATION
# ------------------------------------

@export var walk_speed := 5.0
@export var run_speed := 7.5
@export var jump_force := 8.0
@export var double_jump_force := 7.0
@export var gravity := 20.0
var max_jumps := 2

# ------------------------------------
## INTERNAL VARIABLES
# ------------------------------------

var health := 100
var jump_count := 0
var current_state := "idle"

# ------------------------------------
## NODES
# ------------------------------------

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var camera_ctrl = $Camera_Controller
var state_machine

# ------------------------------------
## _READY
# ------------------------------------

func _ready():
	anim_tree.active = true
	state_machine = anim_tree["parameters/playback"]

# ------------------------------------
## _PHYSICS_PROCESS
# ------------------------------------

func _physics_process(delta: float) -> void:
	var input_dir = get_input_direction()
	
	handle_movement(input_dir, delta)
	handle_jump()
	update_animation(input_dir)

	move_and_slide()

	# Cámara suavemente detrás del personaje
	camera_ctrl.position = camera_ctrl.position.lerp(position, 0.15)

# ------------------------------------
## AUXILIAR FUNCTIONS
# ------------------------------------

func get_input_direction() -> Vector3:
	var dir = Vector3.ZERO
	
	if Input.is_action_pressed("ui_up"):
		dir.z -= 1
	if Input.is_action_pressed("ui_down"):
		dir.z += 1
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_action_pressed("ui_right"):
		dir.x += 1
	
	return dir.normalized()

# ------------------------------------

func handle_movement(input_dir: Vector3, delta: float) -> void:
	# Velocidad
	var speed = walk_speed
	
	if Input.is_action_pressed("ui_run"):
		speed = run_speed
	
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed
	
	# Rotación suave hacia dirección de movimiento
	if input_dir != Vector3.ZERO:
		var target_rotation = Vector3(0, atan2(-input_dir.x, -input_dir.z), 0)
		rotation.y = lerp_angle(rotation.y, target_rotation.y, 0.15)
	
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
		jump_count = 0

# ------------------------------------

func handle_jump() -> void:
	if Input.is_action_just_pressed("ui_accept") and jump_count < max_jumps:
		velocity.y = jump_force if jump_count == 0 else double_jump_force
		jump_count += 1

# ------------------------------------

func update_animation(input_dir: Vector3) -> void:
	var new_state = ""
	
	# Comprobar si está muerto?
	if health <= 0:
		new_state = "death"
	
	# En el aire
	if not is_on_floor():
		new_state = "jump_in_place" if input_dir == Vector3.ZERO else "jump_in_movement"
	else:
		# Movimiento horizontal		
		if input_dir == Vector3.ZERO:
			new_state = "idle"
		else:
			#Distinguimos walk/run según tecla ui_run
			new_state = "run" if Input.is_action_pressed("ui_run") else "walk"
	
	# Cambiar estado solo si hay diferencia
	if new_state != current_state:
		state_machine.travel(new_state);
		current_state = new_state

# ------------------------------------
