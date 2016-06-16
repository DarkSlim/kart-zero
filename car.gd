
extends Position3D

export var collision_ray = 0.2


var n_anim_turn
var n_anim_engine
var n_anim_shield
var n_emit
var n_dust
var n_shadow


func _ready():
	n_anim_turn = get_node("AnimTurn") ; n_anim_turn.set_current_animation("turn")
	n_anim_engine = get_node("AnimEngine")
	n_anim_shield = get_node("AnimShield")
	n_emit = get_node("car/caisse").get_material_override()
	n_dust = get_node("car/dust")
	n_shadow = get_node("shadow")
	
func anim_turn_angle(angle): #{
	if angle > 45 :
		angle = 45
	if angle < -45 :
		angle = -45
	angle = 1.0 - angle/45.0
	n_anim_turn.seek(angle, true)
#}

func anim_engine_speed(speed): #{
	n_anim_engine.set_speed(speed * 10.0)
#}

func set_brake(level): #{
	n_emit.set_parameter( FixedMaterial.PARAM_EMISSION, Color( level,level,level) )
#}

func set_dust(state): #{
	if not state :
		n_dust.set_emitting(false)
	elif not n_dust.is_emitting() :
		n_dust.set_emitting(true)
#}

func set_shadow_offset(offset_y): #{
	n_shadow.set_translation( Vector3( 0, offset_y, 0 ) / get_scale() )
#}

func show_shield(): #{
	if n_anim_shield :
		n_anim_shield.play("show")
#}
