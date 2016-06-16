
extends Position3D

const METRIC_SCALE = 5 # 1 unité de distance = 5 mètres

var player_number = 0 # sera redéfini par load_map dans le gameboard

# TODO : mettre tous les paramètres caractéristiques du véhicule comme exported dans le script du véhicule
var param_acceleration = 3.0
var param_speed_max = 15.0
var param_reverse_speed_max = -1.0
var param_resistance_rate = 0.1
var param_boost_decceleration = 1.0
var param_rotate_speed = 90.0
var param_brake_force = 7.0

# impulsion de rebond contre les obstacles
var param_bounce_factor = 0.1 # proportionnel à la vitesse
var param_bounce_factor_min = 0.1 # valeur minimale que doit avoir le produit du facteur et de la vitesse
var param_bounce_speed_factor = 0.75 # modulation de la vitesse après impact
var param_bounce_resistance_rate = 1.0 # facteur de réduction du vecteur de rebond
var param_bounce_min_len = 0.1 # longueur minimale des composantes xz que doit avoir le vecteur bounce, en deça de quoi il est nullifié
var param_bounce_rotation_factor = 360.0 # facteur de rotation à chaque impacte pour aligner le véhicule avec l'obstacle

var param_gravity = -20.0 # acceleration gravitaionnelle # TODO : specifique à la carte ou à une zone de la carte ?

var param_glide_rescale_factor = 1.5 # réglage de l'adhérence de la map # TODO : specifique à la carte ?

var param_jump_rescale_factor = 10.0 # réglage des saut de la map
var param_jump_bounce_factor = 0.5 # réglage des rebonds sur le sol après un saut

var param_can_turn_while_flying = false # indique si le véhicule peut tourner pendant un saut



var current_speed = 0.0
var current_speed_max
var current_angle = 0.0
var current_gtrans = Vector3()
var previous_gtrans = Vector3()
var last_gtrans_without_collision = null
var y_correction = 0.0

var bounce_vector = Vector3(0,0,0)

var map_info = null
var collisions = null

var is_braking = false ; var was_braking = null
var is_colliding = false 

var is_close_ennough_for_details = true

var wants_to_accelerate = false
var wants_to_turn_left = false
var wants_to_turn_right = false
var wants_to_brake = false
var wants_to_reverse = false

var ui_speed
var ui_angle
var ui_terrain_r
var ui_terrain_g
var ui_terrain_b
var ui_bounce
var ui_coords
var ui_fps
var ui_ghost

var n_gameboard

var n_camera
var n_car
var n_map 
var n_path
var n_line_left
var n_line_right
var n_testcube

var car_target_angle = 0.0
var car_current_angle = 0.0
var param_car_angle_max = 20.0
var param_car_angle_speed = 10.0

export var is_computer = false
var computer_path_target_dist = 0.0
var computer_path_target_point = Vector3()

func _ready(): #{
	
	if not is_visible() :
		return
	
	
	n_gameboard = get_node("/root/gameboard")
	n_camera = get_node("camera_pivot")
	n_car = get_node("car").get_child(0)
	n_testcube = n_car.get_node("car/TestCube")
	
	ui_speed = get_node("/root/gameboard/ui/Debug/Speed/Value")
	ui_angle = get_node("/root/gameboard/ui/Debug/Angle/Value")
	ui_terrain_r = get_node("/root/gameboard/ui/Debug/R/Value")
	ui_terrain_g = get_node("/root/gameboard/ui/Debug/G/Value")
	ui_terrain_b = get_node("/root/gameboard/ui/Debug/B/Value")
	ui_bounce = get_node("/root/gameboard/ui/Debug/Bounce/Value")
	ui_coords = get_node("/root/gameboard/ui/Debug/Coords/Value")
	ui_fps = get_node("/root/gameboard/ui/Debug/FPS")

	current_angle = get_rotation_deg().y # FIXME WARNING : il y a un soucis avec les rotations. l'angle retourné n'est valide qu'entre -90 et 90 degrés.
	
	set_process(true)
	set_fixed_process(false)
	
	if not is_computer :
		set_process_input(true)
	else :
		param_acceleration = param_acceleration * 0.75 + randf()*0.5
		print(player_number, " : ", param_acceleration )

#} end of _ready()
	
var animation_timer = 0.0

#func _fixed_process(delta): #{ # WARNING TODO FIXME : Bottleneck CPU + Gdscript à partir d'un certain nombre de véhicules
func _process(delta): #{ # UGLYHACK FIXME TODO

	current_gtrans = get_global_transform()
	
	#is_close_ennough_for_details = false
	is_close_ennough_for_details = current_gtrans.origin.distance_to( get_viewport().get_camera().get_global_transform().origin ) < 10.0
	#n_testcube.set_hidden(is_close_ennough_for_details)
		
	
	if is_computer :
		computer_logic(delta)
		#pass
		
	update_physics(delta)
	
	if player_number == 0 or not is_computer :
		update_camera_animation(delta)
		
	if player_number == 0 or not is_computer :
		 debug_ui(delta)
	
	update_car_animations(delta)
#}

func debug_ui(delta): #{
	ui_speed.set_text( str(current_speed)+" / "+str(current_speed_max) )
	ui_angle.set_text( str(current_angle) )
	ui_terrain_r.set_text( str(map_info.relief_8)+" / "+str(map_info.relief_y) )
	ui_terrain_g.set_text( str(map_info.type)+":"+str(map_info.effect>>4)+":"+str(map_info.force_4) )
	#ui_terrain_b.set_text( str(map_info.bonus)+" / "+str(map_info.bonus_f) )
	ui_bounce.set_text( str(bounce_vector) + " ( " + str(Vector2(bounce_vector.x, bounce_vector.z).length()) + " )" )
	ui_coords.set_text( str(current_gtrans.origin ) )
	ui_fps.set_text( str(OS.get_frames_per_second()) )
#}


func update_physics(delta): #{

		
	if last_gtrans_without_collision == null :
		last_gtrans_without_collision = current_gtrans
				
# nature du terrain 
	
	if map_info == null :
		map_info = n_map.MapInfo.new()
	n_map.get_info_at( current_gtrans.origin.x, current_gtrans.origin.z, map_info ) 
	
	# facteur R : relief : 0 = layer inférieur < enfoncement < 127 = layer < élévation < 255 = layer supérieur
	
	# - gravité et inertie (saut par changement de niveau de terrain)
	
	var is_touching_ground = true	
	var dy = map_info.relief_y - current_gtrans.origin.y # distance entre le sol et le véhicule : 0.0 < dy = sous le sol ; dy < 0.0 = dans les airs

	y_correction = 0 # par defaut, pas de remise à niveau

	if dy < 0.0 : # le vehicule se trouve dans les airs
		bounce_vector.y += param_gravity * delta ; # on applique la gravité
		is_touching_ground = false
		
	
	if dy > 0.0 : # le véhicule se trouve sous le sol
		y_correction = dy ; # on le remet au niveau du sol
		if bounce_vector.y < -1.0 : # si'il tombait, on le fait rebondir
			bounce_vector.y *= -param_jump_bounce_factor
		else: # stabilisation
			bounce_vector.y = 0 
		
	
	# facteur G : Effets du terrain
		
	# - obstacles et vecteur de rebondissement
	if collisions == null :
		collisions = n_map.Collisions.new()
	n_map.get_collisions_around_player( self, collisions )
	
	# attenuation du vecteur de rebondissement lateral 
	if Vector2( bounce_vector.x, bounce_vector.z ).length() > param_bounce_min_len :
		bounce_vector.x *= 1.0 - param_bounce_resistance_rate * delta
		bounce_vector.z *= 1.0 - param_bounce_resistance_rate * delta
	else :
		bounce_vector.x = 0.0
		bounce_vector.z = 0.0
	
	# comportement vis à vis des collisions
	if collisions.count > 0 :
		is_colliding = true
		var norm = Vector3( collisions.normal.x,0, collisions.normal.y )
		var dotx = current_gtrans.basis.x.dot( norm )
		var dotz = current_gtrans.basis.z.dot( norm )
		
		# alignement du véhicule en fonction de l'angle
		var da = 0.0
		if abs(dotz) <= 0.5 :
			da = param_bounce_rotation_factor * sign(dotz) * sign(-dotx) * delta
		else:
			da = param_bounce_rotation_factor * sign(dotx) * sign(-dotz) * delta
		
		current_angle += da
		
		# annulation de la pénétration dans l'obstacle
		set_global_transform( last_gtrans_without_collision )
		
		# application impulsion de rebond 
		bounce_vector.x += collisions.normal.x * max( param_bounce_factor * current_speed, param_bounce_factor_min )
		bounce_vector.z += collisions.normal.y * max( param_bounce_factor * current_speed, param_bounce_factor_min )
		
		# modulation de la vitesse actuelle
		current_speed *= param_bounce_speed_factor
	else :
		last_gtrans_without_collision = current_gtrans
		is_colliding = false
		
	# - Boost de vitesse
	
	current_speed_max = param_speed_max
	
	if is_touching_ground :
		if map_info.effect == n_map.TE_BOOST :
			current_speed = current_speed_max + current_speed_max * map_info.force_rate
	
	# - Adherence
	
	if is_touching_ground :
		if map_info.effect == n_map.TE_GLIDE and map_info.force_rate < 1.0 : # terrain graveleux : réduction de la vitesse max
			current_speed_max *= map_info.force_rate * param_glide_rescale_factor + 1.0
		
		# TODO : glicement et dérappages
	
	# - Projection vers le haut
	
	if is_touching_ground :
		if map_info.effect == n_map.TE_JUMP :
			var f = map_info.force_rate * param_jump_rescale_factor # * current_speed 
			bounce_vector.y += f

		
	# facteur B : (réservé)
	# TODO
		
		
			
# gestion de la poussière  (à améliorer TODO)
	if is_touching_ground :
		# TODO : changer l'aspect de la poussière en fonction du type de terrain
		if current_speed > (0.1*current_speed_max) and n_map.TT_SAND <= map_info.type and map_info.type <= n_map.TT_GRAVIER_MIN :
			n_car.set_dust( true )
		else:
			n_car.set_dust( false )

	
# resistance et frottements de l'air
	current_speed -= current_speed * param_resistance_rate * delta
	
# controles
	
	is_braking = false
	car_target_angle = 0.0
	
	
	if is_touching_ground and wants_to_accelerate : #{
		current_speed += param_acceleration * delta
		if current_speed > current_speed_max : #{
			current_speed -= current_speed * param_boost_decceleration * delta
		#}
	#}
	if wants_to_brake : #{
		if is_touching_ground :
			current_speed -= param_brake_force * delta
			if current_speed < 0 : #{
				current_speed = 0
			#}
		#}
		is_braking = true
	#}
	if wants_to_reverse : #{
		if is_touching_ground : #{
			current_speed -= param_acceleration * delta
			if current_speed < param_reverse_speed_max : #{
				current_speed = param_reverse_speed_max
			#}
		#}
		if current_speed >= 0 :
			is_braking = true
	#}
	if ( is_touching_ground or param_can_turn_while_flying ) and wants_to_turn_left : #{
		current_angle += param_rotate_speed * delta
		car_target_angle = param_car_angle_max
	#}
	if ( is_touching_ground or param_can_turn_while_flying ) and wants_to_turn_right : #{
		current_angle -= param_rotate_speed * delta
		car_target_angle =-param_car_angle_max
	#}
	
	
# transformations
	
	previous_gtrans = current_gtrans
	var dpos = Vector3(0,0,0)	
	
	# altitude
	dpos += Vector3(0,y_correction,0)
	
	# déplacement
	dpos += Vector3(0,0,1).rotated( Vector3(0,1,0), -deg2rad( current_angle) ) * ( current_speed * delta  ) + bounce_vector * delta
	
	# màj transform
	current_gtrans.origin += dpos
	set_global_transform( current_gtrans )
	
	# orientation
	set_rotation_deg( Vector3(0,current_angle,0) )
	
	
	# inclinaison
	if is_touching_ground and is_close_ennough_for_details :
		n_car.get_parent().set_rotation( n_gameboard.n_map_instance.get_car_inclinaison_at( current_gtrans.origin.x, current_gtrans.origin.z, current_angle, n_car.collision_ray ) )
	

#} end of apply_physics()

func update_camera_animation(delta): #{
	# animation pivot camera
	if car_target_angle == 0.0 : 
		if car_current_angle > 0.0 :
			car_current_angle -= param_car_angle_speed * delta
		elif car_current_angle < 0.0 :
			car_current_angle += param_car_angle_speed * delta
			
	if car_current_angle < car_target_angle :
		car_current_angle += param_car_angle_speed * delta
		
	if car_current_angle > car_target_angle :
		car_current_angle -= param_car_angle_speed * delta
		
	n_camera.set_rotation_deg(Vector3(0,-car_current_angle,0)) # TODO : fluidifier la rotation de la caméra en déplaçant dans _process()
#}


func update_car_animations(delta): #{
	# animations

	n_car.anim_engine_speed( current_speed / 20.0 ) # TODO : définir constante en tant que param
	
	n_car.anim_turn_angle( car_target_angle )

	if is_braking != was_braking : #{
		was_braking = is_braking
		if is_braking == true :
			n_car.set_brake(1)
		else:
			n_car.set_brake(0)
	#}
		
	n_car.set_shadow_offset( -current_gtrans.origin.y )
	
	if is_colliding : 
		n_car.show_shield()
#}

	
func _input(event): #{
	if n_gameboard.start_your_engine_delay > 0.0 :
		return
		
	if event.is_action("game_accelerate"):
		wants_to_accelerate = event.is_pressed()
		return
	if event.is_action("game_brake"):
		wants_to_brake = event.is_pressed()
		return
	if event.is_action("game_reverse"):
		wants_to_reverse = event.is_pressed()
		return
	if event.is_action("game_turn_left"):
		wants_to_turn_left = event.is_pressed()
		return
	if event.is_action("game_turn_right"):
		wants_to_turn_right = event.is_pressed()
		return
#}

	
func computer_logic(delta): #{
	if n_gameboard.start_your_engine_delay > 0.0 :
		return
		
	wants_to_accelerate = false
	wants_to_brake = false
	wants_to_reverse = false
	wants_to_turn_left = false
	wants_to_turn_right = false
	
	# le vehicule doit suivre le path de la map
	
	# on choisit un point du path devant le véhicule
	n_path.set_offset( computer_path_target_dist )
	computer_path_target_point = n_path.get_global_transform().origin

	
	# le vehicule cherche à s'orienter et à avancer vers ce point
	var dir = (computer_path_target_point - current_gtrans.origin).normalized()
	var o = current_gtrans.basis.x.dot( dir )
	if abs(o) > 0.2 : # TODO : définir en param
		if o > 0 :
			wants_to_turn_left = true
		if o < 0 :
			wants_to_turn_right = true
	
	if abs(o) < 0.6 : # TODO : définir en param
		wants_to_accelerate = true	
		
	if abs(o) > 0.5 : # TODO : définir en param
		wants_to_brake = true
	
	# lorsqu'une distance minimale est atteinte, on selectionne un autre point plus loin
	# si le véhicule s'éloigne du point choisi, on recherche un point plus proche

	var dist = computer_path_target_point.distance_to( current_gtrans.origin )
	if dist < 3 : #{
		computer_path_target_dist += current_speed * delta
		n_path.set_offset( computer_path_target_dist ) 
		computer_path_target_point = n_path.get_global_transform().origin
		dist = computer_path_target_point.distance_to( current_gtrans.origin )
		#print( dist, " : ", computer_path_target_dist, " : ", current_speed )
	#}
	
	pass
#}
	
