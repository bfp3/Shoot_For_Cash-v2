extends Label3D

var damage_tween : Tween = null

func print_text(_display_pos : Vector3, money_yield : String) -> void:
	var new_money_label : Label3D = self #.duplicate()
	#if money_container:
	#get_tree().get_current_scene().add_child(new_money_label)
	new_money_label.top_level = true
	new_money_label.text = money_yield
	new_money_label.global_position = _display_pos

	new_money_label.tween_down()
	new_money_label.tween_fade(Color("45dec2ff"), 1.5)

func money_is_money(_display_pos : Vector3, money_yield : int) -> void:	
	var new_money_label : Label3D = self #.duplicate()
	#if money_container:
	#get_tree().get_current_scene().add_child(new_money_label)
	new_money_label.top_level = true
	new_money_label.text = "$" + str(money_yield) #.pad_zeros(2)
	new_money_label.global_position = _display_pos
	#new_money_label.text = "+$" + str(2) +".00"
	#money_container.update_money()
	
	new_money_label.tween_up()
	
	if money_yield >= 0:
		new_money_label.tween_fade(Color('42d100'), 1.5)
		
	else:
		new_money_label.tween_fade(Color('d10000'), 2.5)

func money_rock(_display_pos : Vector3, money_yield : int) -> void:
	
	var new_money_label : Label3D = self #.duplicate()
	#get_tree().get_current_scene().add_child(new_money_label)
	new_money_label.text = "$" + str(money_yield) #.pad_zeros(2)
	new_money_label.global_position = _display_pos
	#new_money_label.text = "+$" + str(2) +".00"
	#money_container.update_money()
	
	new_money_label.tween_up()
	
	if money_yield >= 0:
		new_money_label.tween_fade(Color('42d100'), 0.5)
		
	else:
		new_money_label.tween_fade(Color('d10000'), 1.5)

func gold_is_money(_display_pos : Vector3, money_yield : int) -> void:	
	var new_money_label : Label3D = self.duplicate()
	#if money_container:
	get_tree().get_current_scene().add_child(new_money_label)
	new_money_label.top_level = true
	new_money_label.text = "$" + str(money_yield) #.pad_zeros(2)
	new_money_label.global_position = _display_pos
	#new_money_label.text = "+$" + str(2) +".00"
	#money_container.update_money()
	await get_tree().create_timer(0.1).timeout
	$Gold_sfx.play()
	new_money_label.tween_up_gold()
	new_money_label.tween_fade_gold()
		
		
func damage_is_damage(_display_pos : Vector3, _damage_number : int) -> void:
	var new_damage_label : Label3D = self #duplicate()
	#get_tree().get_current_scene().add_child(new_damage_label)
	
	new_damage_label.global_position = _display_pos + Vector3(-0.5,0.5,0)
	new_damage_label.text = str(_damage_number)
	#new_damage_label.show()
	new_damage_label.tween_up_damage(0.0)
	new_damage_label.damage_tween_fade()
	
	
func health_is_health(pos : Vector3, _health : int) -> void:
	if _health <= 0:
		return
	self.text =  str(_health)
	self.show()
	self.global_position = pos + Vector3(0.5,-0.5,0)
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, 'modulate:a', 1.0, 0.01)
	#tween.tween_interval(1.0)
	tween.tween_property(self, 'modulate:a', 0.0, 1.0)
	await tween.finished
	self.hide()

func tween_up(_height_start_point : float = 0.5) -> void:
	var _rand_height : float = randf_range(0.8,1.0)
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, 'global_position:y', _height_start_point, 0.01).as_relative()
	#tween.tween_interval(0.25)
	tween.tween_property(self, 'global_position:y', 0.5, _rand_height).as_relative()
	await tween.finished
	
func tween_down(_height_start_point : float = 0.5) -> void:
	var _rand_height : float = -2.0
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, 'global_position:y', _height_start_point, 0.01).as_relative()
	tween.tween_interval(0.75)
	#tween.tween_interval(0.25)
	tween.tween_property(self, 'global_position:y', 0.5, _rand_height).as_relative()
	await tween.finished

func tween_up_gold(_height_start_point : float = 0.5) -> void:
	var _rand_height : float = randf_range(1.5,2.0)
	self.scale *= 1.15
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, 'global_position:y', _height_start_point + _rand_height, 0.01).as_relative()
	#tween.tween_interval(0.25)
	tween.tween_property(self, 'global_position:y', 0.5, _rand_height).as_relative()
	await tween.finished

func tween_up_damage(_height_start_point : float = 0.5) -> void:
	#var _rand_height : float = randf_range(1.5,2.0)
	#self.scale *= 1.15
	var tween = create_tween().set_ease(Tween.EASE_IN)
	#tween.tween_property(self, 'global_position', _height_start_point + _rand_height, 0.01).as_relative()
	#tween.tween_interval(0.25)
	tween.tween_property(self, 'global_position:y', 1.5, 1.0).as_relative()
	tween.parallel().tween_property(self, 'global_position:x', -1.5, 1.0).as_relative()
	#await tween.finished

func tween_fade(_start_colour : Color, fade_dur : float = 0.5, ) -> void:
	var _base_colour : Color = _start_colour
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, 'modulate', Color.WHITE, 0.01)
	tween.parallel().tween_property(self, 'outline_modulate', Color('262626'), 0.01)
	tween.tween_callback(self.show)
	tween.tween_property(self, 'modulate', _base_colour, 0.25)
	tween.tween_interval(1.5)
	tween.tween_property(self, 'modulate:a', 0.0, fade_dur)
	tween.parallel().tween_property(self, 'outline_modulate:a', 0.0, fade_dur)
	await tween.finished
	hide()
	#self.queue_free()

func damage_tween_fade(fade_dur : float = 0.25) -> void:
	if damage_tween:
		damage_tween.kill()
	self.modulate = Color('858585')
	self.outline_modulate = Color('262626')
	damage_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	damage_tween.tween_callback(self.show)
	damage_tween.tween_interval(0.2)
	damage_tween.tween_property(self, 'modulate', Color.TRANSPARENT, fade_dur)
	damage_tween.parallel().tween_property(self, 'outline_modulate', Color.TRANSPARENT, fade_dur)
	await damage_tween.finished
	#hide()
	
func tween_fade_gold() -> void:
	var _base_colour : Color = Color(4.416, 3.485, 0.0) #Color('ffc700')
	
	var fade_dur := 5.0
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, 'modulate', Color.WHITE, 0.01)
	tween.parallel().tween_property(self, 'outline_modulate', Color('262626'), 0.01)
	tween.tween_callback(self.show)
	tween.tween_property(self, 'modulate', _base_colour, 0.25)
	tween.tween_interval(1.5)
	tween.tween_property(self, 'modulate', Color.TRANSPARENT, fade_dur)
	tween.parallel().tween_property(self, 'outline_modulate', Color.TRANSPARENT, fade_dur)
	await tween.finished
	self.queue_free()


func pineapple_is_pineapple() -> void:
	gl_PlayerState.add_bonus(30)
	var new_money_label: Label3D = self.duplicate()

	get_tree().get_current_scene().add_child(new_money_label)
	new_money_label.font_size *= 3
	new_money_label.top_level = true
	new_money_label.text = "$30"
	new_money_label.global_position = Vector3(0, 5, 23)

	new_money_label.modulate = Color("42d100")
	new_money_label.outline_modulate = Color("262626")
	new_money_label.show()

	var tween := new_money_label.create_tween() \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_LINEAR)

	tween.tween_interval(3.0)
	tween.tween_property(new_money_label, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(new_money_label, "outline_modulate:a", 0.0, 0.5)

	await tween.finished
	new_money_label.queue_free()
