extends Node2D
## Overworld player. Position is at the feet; collision is a small foot box
## checked against the map by the Overworld (no physics engine needed, which
## keeps movement crisp and identical on every platform).

const SpriteLib = preload("res://scripts/art/SpriteLib.gd")

const SPEED := 112.0
const RUN_MULT := 1.65

var overworld
var facing: Vector2 = Vector2.DOWN
var sprite: Sprite2D
var anim_t: float = 0.0
var moving: bool = false
var trail: Array = []  # recent positions, used by following companions
var step_accum: float = 0.0


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.scale = Vector2(2, 2)
	sprite.offset = Vector2(0, -8)
	add_child(sprite)
	_update_sprite()


func foot_rect(at: Vector2) -> Rect2:
	return Rect2(at + Vector2(-9, -8), Vector2(18, 9))


func _physics_process(delta: float) -> void:
	if overworld == null or overworld.is_busy():
		moving = false
		_update_sprite()
		return
	var dir: Vector2 = InputConfig.move_vector()
	if dir.length() > 1.0:
		dir = dir.normalized()
	moving = dir.length() > 0.2
	if moving:
		if absf(dir.x) > absf(dir.y):
			facing = Vector2(signf(dir.x), 0)
		else:
			facing = Vector2(0, signf(dir.y))
		var speed := SPEED * (RUN_MULT if Input.is_action_pressed("cancel") else 1.0)
		var motion := dir * speed * delta
		# Axis-separated so you slide along walls instead of sticking.
		var nx := position + Vector2(motion.x, 0)
		if overworld.can_stand(foot_rect(nx)):
			position = nx
		var ny := position + Vector2(0, motion.y)
		if overworld.can_stand(foot_rect(ny)):
			position = ny
		anim_t += delta * (speed / SPEED)
		step_accum += motion.length()
		if step_accum > 32.0:
			step_accum = 0.0
			GameState.add_stat("steps")
		if trail.is_empty() or trail[0].distance_to(position) > 2.0:
			trail.push_front(position)
			if trail.size() > 80:
				trail.pop_back()
		overworld.on_player_moved()
	_update_sprite()


func _update_sprite() -> void:
	if facing == Vector2.UP:
		sprite.texture = SpriteLib.texture("player_up")
	elif facing == Vector2.DOWN:
		sprite.texture = SpriteLib.texture("player_down")
	else:
		sprite.texture = SpriteLib.texture("player_side")
		sprite.flip_h = facing.x < 0
	if facing.y != 0:
		sprite.flip_h = false
	var bob := 0.0
	if moving:
		bob = -1.0 if int(anim_t * 8.0) % 2 == 0 else 0.0
		sprite.rotation = 0.06 * sin(anim_t * 12.0) if facing.y != 0 else 0.0
	else:
		sprite.rotation = 0.0
	sprite.offset.y = -8 + bob
