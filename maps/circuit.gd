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

export var data_image = Image()
export var layer0_height = 0.5
export var layer0_depth = 0.5

const PI_2 = PI / 2.0

var n_players

var n_layer0
var coords_rescale = 1.0
var coords_offset = Vector2(0,0)

# encodage des caractéristiques du terrain sur 8 bits

	# effet : 4 bits

const TE_NONE   = 0x00 # default
const TE_DAMAGE = 0x10
const TE_REPEAR = 0x20
const TE_3 = 0x30
const TE_4 = 0x40
const TE_JUMP   = 0x50
const TE_6 = 0x60
const TE_BOOST  = 0x70
const TE_8 = 0x80
const TE_GLIDE  = 0x90 # pourcentage
const TE_A = 0xA0
const TE_BOUNCE = 0xB0
const TE_C = 0xC0
const TE_D = 0xD0
const TE_E = 0xE0
const TE_F = 0xF0
	
	# force : 4 bits
		
		# entier positif : 0 < e < 15
		# pourcentage    : 0x00 = 0.0 < 0x0A = 1.0 < 0x0F = 1.5
		# entier relatif : r = v - 8 ; -8 < r < 7
		# ...
		
# types de terrains prédéfinis :

const TT_BITUME        = 0x9A
const TT_DUST          = 0x98
const TT_GRAVIER_MIN   = 0x97
const TT_GRAVIER_MAX   = 0x96
const TT_SAND          = 0x95
const TT_MUD           = 0x94

const TT_BARRIER_100   = 0xBA

const TT_ICE_160       = 0x6A

const TT_BOOST_200     = 0x7A # boost à 200%

class MapInfo : #{
	var relief_8 # 8 bits : 0 - 255
	var relief_y 
	var type
	var effect
	var force_4 # 4 bits : 0 - 15
	var force_rate
	var layer_depth
	var layer_height
#}
	

func _ready():
	n_layer0 = get_node("layer0")
	coords_rescale = (1.0 / n_layer0.get_pixel_size()) * data_image.get_width() / n_layer0.get_texture().get_width()
	coords_offset.x = data_image.get_width() * 0.5
	coords_offset.y = data_image.get_height() * 0.5
	pass
	
func get_info_at(x,y,result_reference=null): #{
	if result_reference == null :
		result_reference = MapInfo.new()
	
	x = max(0, min( int( coords_offset.x + x * coords_rescale ), data_image.get_width( )-1 ) )
	y = max(0, min( int( coords_offset.y + y * coords_rescale ), data_image.get_height()-1 ) )
	
	var p = data_image.get_pixel( x, y ) 
	
	# p.r8 = relief : 0 = layer_depth < 127 = niveau 0 < 255 = layer_height
	# p.g8 = terrain effect : 4bits TE + 4bits value
	# p.b8 = ?
	
	
	result_reference.relief_8   = int(p.r8)
	result_reference.relief_y   = relief_to_offset(2.0*p.r-1.0)
		
	result_reference.type       = int(p.g8)
	result_reference.effect     = int(p.g8) & 0xF0 # WORKAROUND : p.g8 est considéré comme un float bizarement, donc int(p.g8)
	result_reference.force_4    = int(p.g8) & 0x0F
	result_reference.force_rate = float(int(p.g8) & 0x0F) * 0.1
						
	result_reference.layer_depth  = layer0_depth
	result_reference.layer_height = layer0_height
	
	return result_reference
#}

func get_relief_y_at(x,y): #{
	x = max(0, min( int( coords_offset.x + x * coords_rescale ), data_image.get_width( )-1 ) )
	y = max(0, min( int( coords_offset.y + y * coords_rescale ), data_image.get_height()-1 ) )
	
	return data_image.get_pixel( x, y ).r * 2.0 - 1.0
#}

	
func relief_to_offset(r): #{
	if r < 0.0 :
		return r * layer0_depth
	if r > 0.0 :
		return r * layer0_height
	return 0.0
#}

func get_car_inclinaison_at(x,y,angle,ray): #{
	angle = deg2rad(angle)
	var hN = get_relief_y_at( x + ray * sin(angle   ), y + ray * cos(angle   ) )
	var hS = get_relief_y_at( x + ray * sin(angle+PI), y + ray * cos(angle+PI) )
	var aX = atan2( hS - hN, ray*2.0 ) ;
	
	var hL = get_relief_y_at( x + ray * sin(angle-PI_2), y + ray * cos(angle-PI_2) )
	var hR = get_relief_y_at( x + ray * sin(angle+PI_2), y + ray * cos(angle+PI_2) )
	var aZ = atan2( hR - hL, ray*2.0 ) ;
	
	return Vector3(aX,0,aZ)
#}

class Collisions: #{
	var count = 0
	var coord = Vector2()
	var coords = Vector2Array()
	var normal = Vector2()
	var normals = Vector2Array()
	
	func _init():
		coords.resize(100) # TODO FIXME : empecher tout risque de débordement
		normals.resize(100) # TODO FIXME : idem
		
	func reset():
		count = 0 ; coord = Vector2(0,0) ; normal = Vector2(0,0)
#}

var get_collisions_around_player_mapinfo = MapInfo.new()

func get_collisions_around_player(player, collisions_ref=null, ray=null, asteps=16): #{
	if collisions_ref == null :
		collisions_ref = Collisions.new()

	if ray == null :
		ray = player.n_car.collision_ray
	var gpos = player.get_global_transform().origin


	var r = Vector2()
	var p = Vector2()
	var n

	collisions_ref.reset()

	for a in range(0,360,int(360/asteps)): #{
		r.x = ray*sin(deg2rad(a))
		r.y = ray*cos(deg2rad(a))
		p.x = gpos.x + r.x
		p.y = gpos.z + r.y # /!\ : gpos.Z et pas Y car 3d -> 2d
		get_info_at( p.x, p.y, get_collisions_around_player_mapinfo )
		
		if get_collisions_around_player_mapinfo.effect == TE_BOUNCE :
			collisions_ref.coords[ collisions_ref.count ] = p
			collisions_ref.coord += p
			#n = r.normalized() * -1.0
			n = r.normalized() * -( get_collisions_around_player_mapinfo.force_rate )
			collisions_ref.normals[collisions_ref.count ] = n
			collisions_ref.normal += n
			collisions_ref.count += 1
		#}
	#}
	
	var t = Vector3()
	for car in n_players.get_children(): #{
		if car.player_number == player.player_number or not car.is_visible(): # ignorer self-collision
			continue
		var diff = player.get_translation() - car.get_translation()
		n = diff.normalized()
		if diff.length() < ( ray + car.n_car.collision_ray ) :
			
			t = car.get_translation() - n * ( car.n_car.collision_ray / (ray + car.n_car.collision_ray) )
			p.x = t.x
			p.y = t.z
			collisions_ref.coords[collisions_ref.count] = p
			collisions_ref.coord += p
			n = Vector2( n.x, n.z )
			collisions_ref.normals[collisions_ref.count] = n
			collisions_ref.normal += n
			collisions_ref.count += 1
	#}
			
	
	if collisions_ref.count > 0 :
		collisions_ref.coord /= collisions_ref.count
		collisions_ref.normal /= collisions_ref.count

	return collisions_ref
#}

func print_map_coords(x,y):
	x = int( coords_offset.x + x * coords_rescale )
	y = int( coords_offset.y + y * coords_rescale )
	print("(",x,", ",y,")")

