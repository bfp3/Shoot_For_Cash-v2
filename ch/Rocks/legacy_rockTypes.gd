extends Node

func rock_types() -> void:
	pass
		# 1
		#RockSize.SMALL_2:
			#current_rock_type 	= "Pigeon"
			#rock_type_name 		= "rock_type_1"
			#ignores_x_out_of_bounds = true
			#gl_PlayerState.log_white_rock()
			#var base_health := int(gl_DataSet.get_value("rock_type_1", 1))
			#var base_cash   := 0 #int(gl_DataSet.get_value("rock_type_1", 0))
			#var base_scale  := Vector3.ONE * 0.35 * 2
#
			#var size_multiplier_float : float = 2.4 #randf_range (1.2, 1.35) * 2
			#var size_multiplier_int : int = 2
			#$Mesh.scale = Vector3.ONE
			#health = 1 #base_health * size_multiplier_int
			#cash_value = base_cash # * size_multiplier
			#max_health = health
			#small_rock.visible = true
			#main_col.scale = Vector3.ONE * 0.125  * size_multiplier_float
			#current_mesh = small_rock
			#assign_random_mesh(current_mesh)
			#current_mesh.scale = base_scale * size_multiplier_float
			#rock_type_gravity_scale = 0.1 # + (size_multiplier / 10)
			#linear_damp = 0.5
			#force_mult.clear()
			#force_mult = [3,4]
			#force_mult_index = 0
		
		# 2
		#RockSize.MEDIUM:
			#current_rock_type 	= "Coal"
			#rock_type_name 		= "rock_type_2"
			##health 				= int(gl_DataSet.get_value("rock_type_2", 1))
			#health 				= 2
			#cash_value 			= 1 #int(gl_DataSet.get_value("rock_type_2", 0))
			#medium_rock.visible = true
			#main_col.scale = Vector3.ONE * 0.225
			#current_mesh 		= medium_rock
			#assign_random_mesh(current_mesh)
			#current_mesh.scale  = Vector3.ONE * 0.625
			#max_health = health
			#rock_type_gravity_scale = 0.15
			#linear_damp = 0.5
			#force_mult.clear()
			#force_mult = [2,3]
			#force_mult_index = 0
			#
		## Rock Type 3
		#RockSize.LARGE:
			#var base_scale  := Vector3.ONE * 0.35
			#var size_multiplier_float : float = 1.2
			##var size_multiplier_int : int = 1
			#current_rock_type 	= "Gold"
			#rock_type_name 		= "rock_type_2"
			#health 				= 1
			#max_health = health
			#cash_value 			= 0
			#large_rock.visible 	= true
			#main_col.scale = Vector3.ONE * 0.11  * size_multiplier_float
			#current_mesh 		= large_rock
			#current_mesh.scale = base_scale * size_multiplier_float
			#assign_random_mesh(current_mesh)
			#rock_type_gravity_scale = 0.1 # + (size_multiplier / 10)
			#$Mesh.scale = Vector3.ONE
			#linear_damp = 0.5
			#force_mult.clear()
			#force_mult = [3,4]
			#force_mult_index = 0
	#
	
	
#
		#RockSize.LARGE:
			#current_rock_type 	= "Gold"
			#rock_type_name 		= "rock_type_3"
			#health 				= int(gl_DataSet.get_value("rock_type_3", 1))
			#cash_value 			= int(gl_DataSet.get_value("rock_type_3", 0))
			#large_rock.visible 	= true
			#main_col.scale 		= Vector3.ONE * 0.3
			#current_mesh 		= large_rock
			#assign_random_mesh(current_mesh)
			#current_mesh.scale  = Vector3.ONE * 0.7
			#max_health = health
			#rock_type_gravity_scale = 0.4
			#linear_damp = 0.5
			#force_mult.clear()
			#force_mult = [3,4]
			#force_mult_index = 0
			
		
