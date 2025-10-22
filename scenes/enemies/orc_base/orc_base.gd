extends CharacterBody3D

# ------------------------------------
# CONFIGURACIÓN
# ------------------------------------
@export var walk_speed := 3.0
@export var run_speed := 5.0
@export var gravity := 20.0
@export var health := 100
@export var attack_1_damage := 15
@export var attack_range := 0.9
@export var attack_cooldown := 1.0

# ------------------------------------
# VARIABLES INTERNAS
# ------------------------------------
var velocity_y := 0.0
var can_attack := true
var is_dead := false
var is_moving := false
var is_taking_damage := false
var current_state := "idle"

# Ataque
var is_attacking := false

# Referencias a nodos
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var state_machine = anim_tree["parameters/playback"]
@onready var hitbox_attack_1 = $"Hitbox-Attack_1"
@onready var player_detected = false
@onready var player_ref: Node3D = null

# ------------------------------------
# _READY
# ------------------------------------
func _ready():
	anim_tree.active = true
	state_machine = anim_tree["parameters/playback"]
	state_machine.travel("idle")
	hitbox_attack_1.connect("body_entered", Callable(self, "_on_attack_area_body_entered"))
	hitbox_attack_1.monitoring = false
	anim_player.animation_finished.connect(_on_animation_finished)

# ------------------------------------
# CICLO PRINCIPAL
# ------------------------------------
func _physics_process(delta):
	if is_dead or is_taking_damage:
		return
	
	var dir = Vector3.ZERO
	
	if player_detected and player_ref:
		dir = (player_ref.global_position - global_position).normalized()
		var distance = global_position.distance_to(player_ref.global_position)
		
		# Movimiento según distancia
		if distance > attack_range:
			var target_speed = run_speed if distance > 6.0 else walk_speed
			velocity.x = lerp(velocity.x, dir.x * target_speed, 0.1)
			velocity.z = lerp(velocity.z, dir.z * target_speed, 0.1)
			
			# Cambiar animación solo si cambió el estado
			if distance > 6.0 and current_state != "run":
				state_machine.travel("run")
				current_state = "run"
			elif distance <= 6.0 and current_state != "walk":
				state_machine.travel("walk")
				current_state = "walk"
			
			is_moving = true
		else:
			# En rango de ataque, dejar de moverse
			velocity.x = 0
			velocity.z = 0
			is_moving = false
			# Intentar atacar si puede hacerlo
			if can_attack and not is_attacking:
				print("ENTRA EN EL ELSE PARA MANDAR ATAQUE")
				_attack()
			elif current_state != "idle" and not is_attacking:
				state_machine.travel("idle")
				current_state = "idle"
	else:
		# No hay jugador detectado
		velocity.x = 0
		velocity.z = 0
		is_moving = false
		if current_state != "idle":
			state_machine.travel("idle")
			current_state = "idle"
	
	# Rotación suave
	if dir.length() > 0.1:
		var target_rot_y = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, 0.1)
	
	_apply_gravity(delta)
	move_and_slide()


# ------------------------------------
# COMPORTAMIENTO GENERAL
# ------------------------------------
func _idle():
	if not is_attacking and not is_taking_damage:
		is_moving = false
		state_machine.travel("idle")

# ------------------------------------
# ATAQUE
# ------------------------------------
func _attack():
	if not can_attack or is_dead or is_taking_damage:
		return
	
	print("ENTRA EN LA PARTE DE LA ANIMACION DEL ATAQUE")
	is_attacking = true
	can_attack = false
	state_machine.travel("attack_1")
	anim_player.play("attack_1")
	
	var impact_time := 1.0      # momento donde el arma “golpea”
	var impact_duration := 0.12  # cuánto tiempo dura el hitbox
	
	await get_tree().create_timer(impact_time).timeout
	if not is_attacking or is_dead or is_taking_damage:
		_disable_hitbox_attack_1()
		return
	
	# activar hitbox durante el momento de impacto
	hitbox_attack_1.monitoring = true
	await get_tree().create_timer(impact_duration).timeout
	_disable_hitbox_attack_1()
	
	# esperar el resto de la animación antes del cooldown
	var anim_length := 2.6333  # duración total de la animación (ajustá según corresponda)
	var remaining := anim_length - (impact_time + impact_duration)
	if remaining > 0:
		await get_tree().create_timer(remaining).timeout
	
	is_attacking = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func _disable_hitbox_attack_1():
	if hitbox_attack_1:
		hitbox_attack_1.monitoring = false


func _on_animation_finished(anim_name: String):
	if anim_name == "attack_1" and is_attacking:
		is_attacking = false
		hitbox_attack_1.monitoring = false
		state_machine.travel("idle")
		current_state = "idle"

# ------------------------------------
# DAÑO Y MUERTE
# ------------------------------------
func take_damage(amount: int):
	if is_dead:
		return
	
	health -= amount
	print("Enemy received %d damage! Health left: %d" % [amount, health])
	
	# Interrumpe cualquier acción
	if is_attacking:
		is_attacking = false
		_disable_hitbox_attack_1()
	
	is_taking_damage = true
	#velocity = Vector3.ZERO
	state_machine.travel("take_damage_1")
	await get_tree().create_timer(1.43333).timeout
	is_taking_damage = false
	can_attack = true
	
	if health <= 0:
		die()

func die():
	_disable_hitbox_attack_1()
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

# ------------------------------------
# SEÑALES
# ------------------------------------
func _on_detection_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_detected = true
		player_ref = body
		print("Jugador detectado!")


func _on_detection_area_body_exited(body: Node3D) -> void:
	if body == player_ref:
		player_detected = false
		player_ref = null
		print("Jugador fuera de rango.")


func _on_attack_1_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.take_damage(attack_1_damage)
