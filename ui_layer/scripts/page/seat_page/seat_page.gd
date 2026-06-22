extends Node 

@export var seat_map_view: Node 
@export var seat_console_control: Node 
@export var main_reservation_list: Node 
@export var reservations_title_label: Label 
@export var initial_focus_button: OptionButton 

var _request_version: int = 0 

func _ready(): 
	DataContext.filter_changed.connect(_load_seat_map) 
	DataContext.basic_data_loaded.connect(_on_basic_data_loaded) 
	
	if SettingManager.locale_changed.is_connected(_on_locale_changed): 
		SettingManager.locale_changed.disconnect(_on_locale_changed) 
	SettingManager.locale_changed.connect(_on_locale_changed) 
	
	# 【新增】监听画布模式变化并初始化
	SettingManager.canvas_mode_changed.connect(_on_canvas_mode_changed)
	_sync_canvas_mode()
		
	if seat_map_view: 
		seat_map_view.seat_clicked.connect(_on_seat_clicked) 
		
	if main_reservation_list: 
		DataContext.filter_changed.connect(func(): main_reservation_list.fetch_data()) 
	if main_reservation_list.has_signal("reservation_selected"): 
		main_reservation_list.reservation_selected.connect(_on_main_reservation_selected) 
		
	DataContext.load_basic_data() 
	_update_ui_texts() 
	
	if initial_focus_button: 
		await get_tree().process_frame 
		initial_focus_button.grab_focus() 

# 【新增】画布模式切换回调
func _on_canvas_mode_changed(_enabled: bool):
	_sync_canvas_mode()
	# 如果数据已经加载，强制重新渲染一次以应用新的视图模式
	if DataContext.floors_data.size() > 0:
		_load_seat_map()

# 【新增】同步画布模式状态
func _sync_canvas_mode():
	if seat_map_view:
		seat_map_view.use_canvas_view = SettingManager.use_canvas_mode

func _unhandled_input(event: InputEvent): 
	if event.is_action_pressed("ui_cancel"): 
		UISignal.switch_page_requested.emit("res://ui_layer/scenes/page/home_page.tscn") 

func _on_basic_data_loaded(): 
	print("主页：基础数据就绪，开始加载默认座位图") 
	_load_seat_map() 

func _on_seat_clicked(seat_id: String, status: String, reservation_id: String): 
	if main_reservation_list and main_reservation_list.has_method("select_matching_item"): 
		main_reservation_list.select_matching_item(seat_id, DataContext.selected_date, DataContext.selected_slot_id) 
	if seat_console_control and seat_console_control.has_method("open_console"): 
		seat_console_control.open_console( 
			DataContext.selected_floor_id, 
			seat_id, 
			DataContext.selected_date, 
			DataContext.selected_slot_id, 
			status, 
			reservation_id 
		) 

func _on_main_reservation_selected(res_data: Dictionary): 
	if seat_console_control and seat_console_control.has_method("open_console"): 
		var seat_id = res_data.get("seat_id", "") 
		var date = res_data.get("date", "") 
		var slot_id = res_data.get("slot_id", "") 
		var status = res_data.get("status", "UNKNOWN") 
		var res_id = str(res_data.get("id", "")) 
		var floor_id = res_data.get("floor_id", "") 
		if floor_id == "" and seat_id != "": 
			var parts = seat_id.split("-") 
			if parts.size() > 0: 
				floor_id = parts[0] 
		DataContext.jump_to_reservation(res_data) 
		seat_console_control.open_console(floor_id, seat_id, date, slot_id, status, res_id) 

func _on_locale_changed(): 
	_update_ui_texts() 

func _update_ui_texts(): 
	if reservations_title_label: 
		reservations_title_label.text = tr("LABEL_MY_RESERVATIONS") 

func _load_seat_map(): 
	var floor_id = DataContext.selected_floor_id 
	var date = DataContext.selected_date 
	var slot_id = DataContext.selected_slot_id 
	if floor_id == "" or date == "" or slot_id == "": 
		return 
		
	_request_version += 1 
	var current_version = _request_version 
	
	var layout_res = await Network.get_floor_layout(floor_id) 
	if current_version != _request_version: 
		return 
	if not layout_res[0]: 
		print("主页：获取楼层布局失败") 
		return 
		
	var layout_data = layout_res[2] 
	var floor_info = layout_data.get("floor", {}) 
	var seats = layout_data.get("seats", []) 
	# 【新增】提取画布尺寸
	var canvas_size = layout_data.get("canvas_size", {})
	
	var avail_res = await Network.get_floor_availability(floor_id, date, true, slot_id) 
	if current_version != _request_version: 
		return 
		
	var avail_data = [] 
	if avail_res[0]: 
		if avail_res[2] is Array: 
			avail_data = avail_res[2] 
		elif avail_res[2] is Dictionary and avail_res[2].has("availability"): 
			avail_data = avail_res[2]["availability"] 
	else: 
		print("主页：获取座位占用状态失败") 
		
	if seat_map_view and seat_map_view.has_method("render_seats"): 
		# 【修改】传入 canvas_size 参数
		seat_map_view.render_seats(floor_info, seats, avail_data, canvas_size)
