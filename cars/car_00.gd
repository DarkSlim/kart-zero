# ------- BEGINNING OF LICENSE CONTENT ------------------
#
# Anti-Evil open source license <3 <3 <3 <3 <3 <3
# 
# By "source-code", we mean all the scripts, assets, resources, documentation,
# files and love available in this project.
# 
# You are allowed to make direct and indirect use of this "source-code" and of
# this love as long as you follow these rules :
# 
# 1 - you shall not detach this license nor this love from this "source-code".
# 2 - you shall not modify this license nor reduce this love.
# 3 - you shall share your modifications of this "source-code" and this love
#  in the same conditions.
# 4 - you shall torture or torment no animal, no human, no sentient being, no
#  being sensitive to love.
# 5 - you shall kill no human being and no being sensitive to love EXCEPT if
#  this being begs you to do so and that you and this being are lucid and that
#  the law of your both countries authorize you to help this being this way
#  and that there is no better alternate solution and that this death is given
#  with respect, with dignity and with the least pain possible for this being,
#  or EXCEPT in certain cases of self-defence where there is absolutely no
#  other alternative, or EXCEPT accidentally, ALL OF THESE EXCEPTIONS at the
#  condition that you are not drunk or under the effect of drugs or under the
#  effect of anger or of hatred.
# 6 - you must not be possessed by any demon, except if all of your demons are
#  nice persons and that they are compatible with love.
# 
# <3 <3 <3 <3 <3 <3
# 
# ------- END OF LICENSE CONTENT ------------------

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
