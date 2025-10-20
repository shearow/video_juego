extends CharacterBody3D

# ------------------------------------
## CONFIGURATION
# ------------------------------------

@export var walk_speed := 5.0
@export var run_speed := 7.5
@export var jump_force := 8.0
@export var double_jump_force := 7.0
@export var gravity := 20.0
@export var max_jumps := 2
@export var max_health := 100
@export var max_mana := 100

# ------------------------------------
## INTERNAL VARIABLES
# ------------------------------------

var health := max_health
var mana := max_mana
var jump_count := 0
var current_state := "idle"
var is_jumping := false
var is_dead := false  # 👉 Nueva variable para controlar la muerte

# ------------------------------------
## NODES
# ------------------------------------

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var camera_ctrl = $Camera_Controller
@onready var health_bar = $CanvasLayer/Health_Bar
@onready var mana_bar = $CanvasLayer/Mana_Bar
var state_machine

# ------------------------------------
## _READY
# ------------------------------------

func _ready():
	anim_tree.active = true
	state_machine = anim_tree["parameters/playback"]
	state_machine.travel("idle")
	update_bars()

# ------------------------------------
## _PROCESS (TESTEO)
# ------------------------------------

func _process(delta):
	if Input.is_action_just_pressed("ui_accept"):
		take_damage(10)
	if Input.is_action_just_pressed("ui_cancel"):
		heal(10)

# ------------------------------------
## _PHYSICS_PROCESS
# ------------------------------------

func _physics_process(delta: float) -> void:
	if is_dead:  # 👉 Si está muerto, no procesa nada
		return
	
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

# Player Life and Mana logic and UI BAR
func update_bars():
	health_bar.value = health
	health_bar.max_value = max_health
	mana_bar.value = mana
	mana_bar.max_value = max_mana

func take_damage(amount: float):
	if is_dead:  # 👉 Evita daño si ya está muerto
		return
	health = clamp(health - amount, 0, max_health)
	update_bars()
	
	if health <= 0:
		die()

func use_mana(amount: float):
	if is_dead:
		return
	mana = clamp(mana - amount, 0, max_mana)
	update_bars()

func heal(amount: float):
	if is_dead:
		return
	health = clamp(health + amount, 0, max_health)
	update_bars()

func recover_mana(amount: float):
	if is_dead:
		return
	mana = clamp(mana + amount, 0, max_mana)
	update_bars()

# ------------------------------------
## NUEVA FUNCIÓN DE MUERTE
# ------------------------------------

func die():
	is_dead = true
	state_machine.travel("death")
	velocity = Vector3.ZERO
	print("🪦 Player ha muerto")

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
	if is_dead:  # 👉 No moverse si está muerto
		return
	
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
		is_jumping = false

# ------------------------------------

func handle_jump() -> void:
	if is_dead:  # 👉 No puede saltar muerto
		return
	
	if Input.is_action_just_pressed("ui_accept") and jump_count < max_jumps:
		velocity.y = jump_force if jump_count == 0 else double_jump_force
		jump_count += 1
		is_jumping = true

# ------------------------------------

func update_animation(input_dir: Vector3) -> void:
	var new_state = ""

	if health <= 0:
		new_state = "death"
	elif is_jumping:
		new_state = "jump_in_place" if input_dir == Vector3.ZERO else "jump_in_movement"
	elif not is_on_floor():
		new_state = "jump_in_place"
	else:
		if input_dir == Vector3.ZERO:
			new_state = "idle"
		else:
			new_state = "run" if Input.is_action_pressed("ui_run") else "walk"

	if new_state != current_state and new_state != "":
		state_machine.travel(new_state)
		current_state = new_state
