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

extends Node

export var map_name = "test"

var n_map
var n_players
var n_map_line_left
var n_map_line_right
var n_map_starting_blocs
var n_map_path
var n_map_instance

var ui_countdown
var ui_pressstart

var start_your_engine_delay = 5.0


func _ready(): #{
	n_map = get_node("3d/circuit/map")
	n_players = get_node("3d/circuit/players")
	ui_countdown = get_node("ui/CountDown")
	ui_pressstart = get_node("ui/PressStart")
	play(true)
#}
	
func play(as_human): #{
	start_your_engine_delay = 5.0
	n_map_instance = load_map(map_name) ; #print(n_map_instance)
	n_players.get_child(0).is_computer = not as_human
	ui_countdown.show()
	set_fixed_process(true)
#}
	
func _fixed_process(delta): #{
	if start_your_engine_delay > 0.0 : #{
		start_your_engine_delay -= delta
		ui_countdown.set_text(str(int(start_your_engine_delay)))
	#}
	else: #{
		ui_countdown.hide()
		set_fixed_process(false)
	#}
		
	#if Input.is_action_pressed("game_play"): #{
	#	ui_pressstart.hide()
	#	set_fixed_process(false)
	#	play(true)
	##}
#}

func load_map(name): #{
	for c in n_map.get_children(): #{
		n_map.remove_child(c)
	#}
	
	var path = "res://maps/"+str(name)+".scn"
	var pack = load(path)
	if pack == null :
		print("Could not load map ",path)
		return null
	
	var map = pack.instance()
	n_map.add_child(map)
	
	n_map_line_left = map.get_node("line_left")
	n_map_line_right = map.get_node("line_right")
	n_map_starting_blocs = map.get_node("starting_blocs")
	n_map_path = map.get_node("Path/PathFollow")
	
	map.n_players = n_players
	
	for i in range( n_players.get_child_count() ): #{
		var c = n_players.get_child(i)
		var s = n_map_starting_blocs.get_child(i)
		
		c.player_number = i
		
		c.set_global_transform( s.get_global_transform() )
		#c.set_translation(n_map_start_0.get_translation())
		
		var a = c.get_global_transform().basis.get_euler() ;
		a.x = rad2deg(a.x) ; a.y = rad2deg(a.y) ; a.z = rad2deg(a.z)
		
		c.current_angle = a.y
		
		# WORKAROUND rotation bug (voir issue https://github.com/godotengine/godot/issues/2153)
		if a.x == -180 and a.z == -180 : #{
			if a.y < 0.0 :
				c.current_angle = -180 - a.y
			else:
				c.current_angle = 180 - a.y
		#}
		
		c.n_map = map
		c.n_path = n_map_path
		c.n_line_left = n_map_line_left
		c.n_line_right = n_map_line_right
	#}
	
	
	return map
#}
	


