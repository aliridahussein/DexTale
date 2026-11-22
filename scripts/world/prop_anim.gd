extends Sprite2D
## Cycles the horizontal frames of a prop sheet (flames, coals, mushrooms).

@export var fps := 6.0
@export var shuffle := true

var _t := 0.0
var _last := -1


func _ready() -> void:
	_t = randf() * 10.0


func _process(delta: float) -> void:
	if hframes <= 1 or fps <= 0.0:
		return
	_t += delta
	var step := int(_t * fps)
	if step == _last:
		return
	_last = step
	# shuffled order looks more like a living flame than a strict loop
	frame = (step * 7 + step / 3) % hframes if shuffle else step % hframes
