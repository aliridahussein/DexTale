extends PointLight2D
## Gentle, irregular flicker for lanterns, candles and the forge.

@export var flicker_amount := 0.14
@export var flicker_speed := 6.0

var _base_energy := 1.0
var _base_scale := 1.0
var _t := 0.0


func _ready() -> void:
	_base_energy = energy
	_base_scale = texture_scale
	_t = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta * flicker_speed
	var n := sin(_t) * 0.5 + sin(_t * 2.31 + 1.7) * 0.3 + sin(_t * 5.17 + 0.4) * 0.2
	energy = _base_energy * (1.0 + n * flicker_amount)
	texture_scale = _base_scale * (1.0 + n * flicker_amount * 0.25)


## Lets story scripts brighten or dim a light without fighting the flicker.
func set_base_energy(value: float) -> void:
	_base_energy = value
