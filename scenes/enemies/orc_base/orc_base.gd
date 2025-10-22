extends CharacterBody3D

# ------------------------------------
# CONFIGURACIÓN
# ------------------------------------
@export var walk_speed := 3.0
@export var run_speed := 5.0
@export var gravity := 20.0
@export var health := 100
@export var attack_damage := 10
@export var attack_range := 2.0
@export var attack_cooldown := 1.5

# ------------------------------------
# VARIABLES INTERNAS
# ------------------------------------
var velocity_y := 0.0
var can_attack := true
var is_dead := false
var is_moving := false
var is_attacking := false
var is_taking_damage := false

# Referencias a nodos
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var state_machine = anim_tree["parameters/playback"]

# ------------------------------------
# _READY
# ------------------------------------
func _ready():
	anim_tree.active = true
	state_machine = anim_tree["parameters/playback"]
	state_machine.travel("idle")

# ------------------------------------
# CICLO PRINCIPAL
# ------------------------------------
func _physics_process(delta):
	if is_dead or is_taking_damage:
		return
	
	_idle()
	_apply_gravity(delta)
	move_and_slide()

# ------------------------------------
# COMPORTAMIENTO GENERAL
# ------------------------------------
func _idle():
	is_moving = false
	if not is_attacking:
		state_machine.travel("idle")

# ------------------------------------
# ATAQUE
# ------------------------------------
func _attack():
	if not can_attack or is_dead or is_taking_damage:
		return
	can_attack = false
	is_attacking = true
	state_machine.travel("attack_1")
	await get_tree().create_timer(0.5).timeout
	print("Enemy attacks for %d damage" % attack_damage)
	await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false
	can_attack = true

# ------------------------------------
# DAÑO Y MUERTE
# ------------------------------------
func take_damage(amount: int):
	if is_dead:
		return
	health -= amount
	
	print("Enemy received %d damage! Health left: %d" % [amount, health])
	
	# Interrumpe cualquier acción
	is_attacking = false
	can_attack = false
	is_taking_damage = true
	velocity = Vector3.ZERO
	
	# Reproducir animación de daño
	state_machine.travel("take_damage_1")
	# Duración breve de la animación de daño
	await get_tree().create_timer(0.3).timeout
	is_taking_damage = false
	can_attack = true
	
	if health <= 0:
		die()

func die():
	is_dead = true
	velocity = Vector3.ZERO
	state_machine.travel("death")
	await get_tree().create_timer(2.0).timeout
	queue_free()

# ------------------------------------
# GRAVEDAD
# ------------------------------------
func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
