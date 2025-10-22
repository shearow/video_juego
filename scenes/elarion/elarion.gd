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
@export var damage_attack_1 := 33

# ------------------------------------
## INTERNAL VARIABLES
# ------------------------------------
var health := max_health
var mana := max_mana
var jump_count := 0
var current_state := "idle"
var is_jumping := false
var is_dead := false

# Ataque
var is_attacking := false
var enemies_hit_attack_1 := []

# Referencias a nodos
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_player: AnimationPlayer = $Elarion_Model/AnimationPlayer
@onready var camera_ctrl = $Camera_Controller
@onready var health_bar = $HUD_UI/Health_Bar
@onready var mana_bar = $HUD_UI/Mana_Bar
@onready var hitbox = $"Elarion_Model/Skeleton3D/Bone-RightHand/sword-1/Hitbox"
var state_machine

# ------------------------------------
## _READY
# ------------------------------------
func _ready():
	anim_tree.active = true
	state_machine = anim_tree["parameters/playback"]
	state_machine.travel("idle")
	anim_player.animation_finished.connect(_on_animation_finished)
	update_bars()

# ------------------------------------
## _PHYSICS_PROCESS
# ------------------------------------
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	var input_dir = get_input_direction()
	handle_movement(input_dir, delta)
	handle_jump()
	handle_attack()
	update_animation(input_dir)
	move_and_slide()
	
	# Cámara suavemente detrás del personaje
	camera_ctrl.position = camera_ctrl.position.lerp(position, 0.15)

# ------------------------------------
## AUXILIAR FUNCTIONS
# ------------------------------------
func update_bars():
	health_bar.value = health
	health_bar.max_value = max_health
	mana_bar.value = mana
	mana_bar.max_value = max_mana	
	print("Vida actual de Elarion: %d" % health)

func take_damage(amount: float):
	if is_dead:
		return
	health = clamp(health - amount, 0, max_health)
	update_bars()
	
	if health <= 0:
		die()
	else:
		# Interrumpe ataque si te pegan
		if is_attacking:
			is_attacking = false
			hitbox.monitoring = false
			anim_player.stop()
			state_machine.travel("idle")
			current_state = "idle"

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
## MUERTE
# ------------------------------------
func die():
	is_dead = true
	if is_attacking:
		anim_player.stop()
	state_machine.travel("death")
	current_state = "death"
	velocity = Vector3.ZERO
	print("Player ha muerto")

# ------------------------------------
## INPUTS
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
## MOVIMIENTO
# ------------------------------------
func handle_movement(input_dir: Vector3, delta: float) -> void:
	if is_dead or is_attacking:
		velocity.x = 0
		velocity.z = 0
		return
	
	var speed = walk_speed
	if Input.is_action_pressed("ui_run"):
		speed = run_speed
	
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed
	
	if input_dir != Vector3.ZERO:
		var target_rotation = Vector3(0, atan2(-input_dir.x, -input_dir.z), 0)
		rotation.y = lerp_angle(rotation.y, target_rotation.y, 0.15)
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
		jump_count = 0
		is_jumping = false


func handle_jump() -> void:
	if is_dead or is_attacking:
		return
	
	if Input.is_action_just_pressed("ui_accept") and jump_count < max_jumps:
		velocity.y = jump_force if jump_count == 0 else double_jump_force
		jump_count += 1
		is_jumping = true

# ------------------------------------
## ATAQUE
# ------------------------------------
func handle_attack():
	if is_dead or is_attacking or not is_on_floor():
		return
		
	if Input.is_action_just_pressed("ui_attack"):
		start_attack()


func start_attack():
	is_attacking = true
	hitbox.monitoring = true
	current_state = "attack_1"
	state_machine.travel("attack_1")
	anim_player.play("attack_1")


func _on_animation_finished(anim_name: String):
	if anim_name == "attack_1" and is_attacking:
		is_attacking = false
		hitbox.monitoring = false
		enemies_hit_attack_1.clear()
		state_machine.travel("idle")
		current_state = "idle"

# ------------------------------------
## ANIMACIÓN
# ------------------------------------
func update_animation(input_dir: Vector3) -> void:
	if is_dead or is_attacking:
		return
	
	var new_state = ""

	if health <= 0:
		new_state = "death"
	elif not is_on_floor():  # Salto o caída
		new_state = "jump_in_place" if input_dir == Vector3.ZERO else "jump_in_movement"
		is_jumping = true
	else:
		is_jumping = false
		if input_dir == Vector3.ZERO:
			new_state = "idle"
		else:
			new_state = "run" if Input.is_action_pressed("ui_run") else "walk"
	
	if new_state != current_state and new_state != "":
		state_machine.travel(new_state)
		current_state = new_state

# ------------------------------------
## SEÑALES
# ------------------------------------
func _on_hitbox_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies") and not body in enemies_hit_attack_1:
		print("Enemigo golpeado por %d " % damage_attack_1)
		body.take_damage(damage_attack_1)
		enemies_hit_attack_1.append(body)
