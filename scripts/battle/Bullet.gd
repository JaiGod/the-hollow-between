extends RefCounted
## One projectile. Kept as a plain object (not a Node) so hundreds can run
## cheaply on phones; BattleArena draws them all in one _draw pass.

var pos: Vector2
var vel: Vector2
var acc: Vector2 = Vector2.ZERO
var radius: float = 5.0
var color: Color = Color("fff6d6")
var kind: String = "orb"     # orb | shard | page | mine | spark | ring
var life: float = 8.0
var age: float = 0.0
var grazed: bool = false
var text: String = ""
var spin: float = 0.0
var rot: float = 0.0
var orbit_center: Vector2 = Vector2.ZERO
var orbit_radius: float = 0.0
var orbit_speed: float = 0.0
var orbit_shrink: float = 0.0
var homing: float = 0.0
var harmless_until: float = 0.0
var dead: bool = false
var reflected: bool = false


func update(dt: float, soul: Vector2) -> void:
	age += dt
	rot += spin * dt
	if orbit_radius > 0.0:
		var a := atan2(pos.y - orbit_center.y, pos.x - orbit_center.x) + orbit_speed * dt
		orbit_radius = maxf(0.0, orbit_radius - orbit_shrink * dt)
		pos = orbit_center + Vector2(cos(a), sin(a)) * orbit_radius
		if orbit_radius <= 2.0:
			dead = true
	else:
		if homing > 0.0:
			var want := (soul - pos).normalized() * vel.length()
			vel = vel.lerp(want, clampf(homing * dt, 0.0, 1.0))
		vel += acc * dt
		pos += vel * dt
	if age >= life:
		dead = true


func is_harmful() -> bool:
	return age >= harmless_until and not reflected
