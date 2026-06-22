extends Control 

@export var close_button: Button 
@export var seat_info_container: Node 
@export var reservations_button: Button 
@export var check_in_button: Button 
@export var suspend_button: Button 
@export var finish_button: Button 
@export var delete_reservations_button: Button 
@export var reservation_list: Node 
@export var error_label: Label 

# 【新增】用于显示当前座位ID和状态的 Label
@export var current_seat_id_label: Label 
@export var current_seat_status_label: Label 

var seat_id: String = "" 
var date: String = "" 
var slot_id: String = "" 
var current_status: String = "UNKNOWN" 
var current_reservation_id: String = "" 
var current_reservation_data: Dictionary = {} 
var is_opening: bool = false 
var _current_error_key: String = "" 
var _current_error_detail: String = "" 
var _error_seq: int = 0 

func _ready(): 
	visible = false 
	# 连接按钮信号 
	if close_button: 
		close_button.pressed.connect(_on_close_button_pressed) 
	if reservations_button: 
		reservations_button.pressed.connect(_on_reservations_button_up) 
	if check_in_button: 
		check_in_button.pressed.connect(_on_check_in_button_up) 
	if suspend_button: 
		suspend_button.pressed.connect(_on_suspend_button_up) 
	if finish_button: 
		finish_button.pressed.connect(_on_finish_button_up) 
	if delete_reservations_button: 
		delete_reservations_button.pressed.connect(_on_delete_reservations_button_up) 
		
	# 初始化时隐藏错误提示 
	if error_label: 
		error_label.modulate.a = 0.0 
		error_label.mouse_filter = Control.MOUSE_FILTER_IGNORE 
		error_label.text = "" 
		
	# 监听预约列表的点击跳转信号 
	if reservation_list: 
		reservation_list.reservation_selected.connect(_on_reservation_selected) 
		
	# 让弹窗内的列表监听全局数据变更信号，自动刷新
	if reservation_list and reservation_list.has_method("fetch_data"):
		DataContext.filter_changed.connect(_on_global_data_changed)
		
	# 监听语言切换 
	SettingManager.locale_changed.connect(_on_locale_changed) 
	update_texts() 

# 全局数据变更后，重新拉取列表并刷新当前控制台状态
func _on_global_data_changed():
	if reservation_list and reservation_list.has_method("fetch_data"):
		reservation_list.fetch_data()
		if reservation_list.has_signal("data_refreshed"):
			await reservation_list.data_refreshed
			
	# 重新匹配当前座位，获取最新状态
	if reservation_list and reservation_list.has_method("select_matching_item"):
		reservation_list.select_matching_item(seat_id, date, slot_id)
		
	if reservation_list and reservation_list.has_method("find_reservation"):
		var exact_res = reservation_list.find_reservation(seat_id, date, slot_id)
		if not exact_res.is_empty():
			current_reservation_data = exact_res
			current_status = exact_res.get("status", current_status).to_upper()
			current_reservation_id = str(exact_res.get("id", current_reservation_id))
			update_buttons_visibility()
		# 更新信息标签
		_update_info_labels()

func open_console(floor_id: String, p_seat_id: String, p_date: String, p_slot_id: String, p_status: String, p_reservation_id: String): 
	if is_opening: 
		return 
	is_opening = true 
	_clear_error() # 打开时清除之前的错误提示 
	seat_id = p_seat_id 
	date = p_date 
	slot_id = p_slot_id 
	current_status = p_status.to_upper() 
	current_reservation_id = p_reservation_id 
	current_reservation_data = {} 
	
	# 核心整合：从预约列表获取精确状态 
	if reservation_list and reservation_list.has_method("fetch_data"): 
		reservation_list.fetch_data() 
		if reservation_list.has_signal("data_refreshed"): 
			await reservation_list.data_refreshed 
			
	# 刷新后首次选中，并设置粘性选中状态 
	if reservation_list.has_method("select_matching_item"): 
		reservation_list.select_matching_item(seat_id, date, slot_id) 
	if reservation_list.has_method("set_sticky_selection"): 
		reservation_list.set_sticky_selection(seat_id, date, slot_id) 
		
	if reservation_list.has_method("find_reservation"): 
		var exact_res = reservation_list.find_reservation(seat_id, date, slot_id) 
		if not exact_res.is_empty(): 
			current_reservation_data = exact_res 
			current_status = exact_res.get("status", current_status).to_upper() 
			current_reservation_id = str(exact_res.get("id", current_reservation_id)) 
			
	if seat_info_container and seat_info_container.has_method("init_seat_info"): 
		seat_info_container.init_seat_info(floor_id, seat_id, date, slot_id) 
		
	update_buttons_visibility() 
	# 更新信息标签
	_update_info_labels()
	
	UiNavigator.show_modal(self, _on_close_button_pressed) 
	is_opening = false 

func _on_reservation_selected(res_data: Dictionary): 
	DataContext.jump_to_reservation(res_data) 
	seat_id = res_data.get("seat_id", "") 
	date = res_data.get("date", "") 
	slot_id = res_data.get("slot_id", "") 
	current_status = res_data.get("status", "UNKNOWN").to_upper() 
	current_reservation_id = str(res_data.get("id", "")) 
	current_reservation_data = res_data 
	var floor_id = res_data.get("floor_id", "") 
	_clear_error() # 切换座位时清除错误提示 
	if seat_info_container and seat_info_container.has_method("init_seat_info"): 
		seat_info_container.init_seat_info(floor_id, seat_id, date, slot_id) 
	# 选中项切换时，也更新粘性选中 
	if reservation_list and reservation_list.has_method("set_sticky_selection"): 
		reservation_list.set_sticky_selection(seat_id, date, slot_id) 
	update_buttons_visibility() 
	# 更新信息标签
	_update_info_labels()

# 更新座位ID和状态标签的方法
func _update_info_labels():
	if current_seat_id_label:
		# 只显示纯 ID，没有任何前缀
		current_seat_id_label.text = seat_id
	if current_seat_status_label:
		var display_status = current_status
		# API 查询只有两种状态：AVAILABLE 和 OCCUPIED
		match current_status:
			"AVAILABLE": 
				display_status = "🟢" + tr("STATUS_AVAILABLE")
			"OCCUPIED": 
				display_status = "🔴" + tr("STATUS_OCCUPIED")
			_: 
				# 其他状态在总览层面统一显示为占用
				display_status = "🔴" + tr("STATUS_OCCUPIED")
		current_seat_status_label.text = display_status

func update_texts(): 
	if close_button: 
		close_button.text = tr("BTN_CLOSE") 
	if reservations_button: 
		reservations_button.text = tr("BTN_RESERVE") 
	if suspend_button: 
		suspend_button.text = tr("BTN_SUSPEND") 
	if finish_button: 
		finish_button.text = tr("BTN_FINISH") 
	if delete_reservations_button: 
		delete_reservations_button.text = tr("BTN_CANCEL") 
	if check_in_button: 
		if current_status == "SUSPENDED": 
			check_in_button.text = tr("BTN_BACK") 
		else: 
			check_in_button.text = tr("BTN_CHECK_IN") 
	# 刷新错误提示的语言（如果正在显示错误） 
	if error_label and _current_error_key != "": 
		_apply_error_text() 
	# 切换语言时也要刷新信息标签
	_update_info_labels()

func update_buttons_visibility(): 
	if reservations_button: 
		reservations_button.visible = false 
	if check_in_button: 
		check_in_button.visible = false 
	if suspend_button: 
		suspend_button.visible = false 
	if finish_button: 
		finish_button.visible = false 
	if delete_reservations_button: 
		delete_reservations_button.visible = false 
		
	match current_status: 
		"AVAILABLE": 
			if reservations_button: 
				reservations_button.visible = true 
		"PENDING", "RESERVED": 
			if check_in_button: 
				check_in_button.visible = true 
			if delete_reservations_button: 
				delete_reservations_button.visible = true 
		"OCCUPIED", "ACTIVE": 
			if suspend_button: 
				suspend_button.visible = true 
			if finish_button: 
				finish_button.visible = true 
		"SUSPENDED": 
			if check_in_button: 
				check_in_button.visible = true 
			if finish_button: 
				finish_button.visible = true 
	update_texts() 

func _on_locale_changed(): 
	update_texts() 

func _on_close_button_pressed(): 
	# 关闭弹窗时，解除强制选中锁定 
	if reservation_list and reservation_list.has_method("clear_sticky_selection"): 
		reservation_list.clear_sticky_selection() 
	UiNavigator.hide_modal(self) 

# ================= 错误提示辅助方法 ================= 
func _apply_error_text(): 
	var base_text = tr(_current_error_key) 
	if _current_error_detail != "": 
		error_label.text = base_text + "：" + _current_error_detail 
	else: 
		error_label.text = base_text 

func _show_error(error_key: String, error_detail: String = ""): 
	if not error_label: 
		push_error("❌❌❌ 严重错误：试图显示错误，但 error_label 未绑定！") 
		return 
	_current_error_key = error_key 
	_current_error_detail = error_detail 
	_apply_error_text() 
	error_label.modulate.a = 1.0 
	error_label.mouse_filter = Control.MOUSE_FILTER_STOP 
	_error_seq += 1 
	var current_seq = _error_seq 
	await get_tree().create_timer(5.0).timeout 
	if _error_seq == current_seq: 
		_clear_error() 

func _clear_error(): 
	if not error_label: 
		return 
	_error_seq += 1 
	_current_error_key = "" 
	_current_error_detail = "" 
	error_label.text = "" 
	error_label.modulate.a = 0.0 
	error_label.mouse_filter = Control.MOUSE_FILTER_IGNORE 

# ================= 网络请求逻辑 =================
func _on_reservations_button_up() -> void:
	_clear_error()
	var result = await Network.post_reservations(seat_id, date, slot_id)
	if result[0]:
		var data = result[2]
		if data is Dictionary and data.has("id"):
			current_reservation_id = str(data["id"])
			current_status = "PENDING"
			update_buttons_visibility()
		DataContext.filter_changed.emit()
	else:
		var status_code = result[1]
		if status_code == 403:
			_show_error("ERROR_DUPLICATE_RESERVATION")
		elif status_code == 404:
			_show_error("ERROR_NETWORK_OR_NOT_FOUND")
		else:
			_show_error("ERROR_RESERVATION_FAILED")

func _on_check_in_button_up() -> void:
	_clear_error()
	if current_reservation_id != "":
		var transition_id = 1
		if current_status == "SUSPENDED":
			transition_id = 3
		var result = await Network.state_transition(transition_id, current_reservation_id)
		if result[0]:
			current_status = "ACTIVE"
			update_buttons_visibility()
			DataContext.filter_changed.emit()
		else:
			var status_code = result[1]
			if status_code == 422:
				_show_error("ERROR_NOT_IN_CHECK_IN_TIME")
			elif status_code == 404:
				_show_error("ERROR_NETWORK_OR_NOT_FOUND")
			else:
				_show_error("ERROR_CHECK_IN_FAILED")
	else:
		_show_error("ERROR_NO_RESERVATION_ID")

func _on_suspend_button_up() -> void:
	_clear_error()
	if current_reservation_id != "":
		var result = await Network.state_transition(2, current_reservation_id)
		if result[0]:
			current_status = "SUSPENDED"
			update_buttons_visibility()
			DataContext.filter_changed.emit()
		else:
			var status_code = result[1]
			if status_code == 404:
				_show_error("ERROR_NETWORK_OR_NOT_FOUND")
			else:
				_show_error("ERROR_SUSPEND_FAILED")
	else:
		_show_error("ERROR_NO_RESERVATION_ID")

func _on_finish_button_up() -> void:
	_clear_error()
	if current_reservation_id != "":
		var result = await Network.state_transition(4, current_reservation_id)
		if result[0]:
			current_status = "AVAILABLE"
			current_reservation_id = ""
			update_buttons_visibility()
			DataContext.filter_changed.emit()
		else:
			var status_code = result[1]
			if status_code == 404:
				_show_error("ERROR_NETWORK_OR_NOT_FOUND")
			else:
				_show_error("ERROR_FINISH_FAILED")
	else:
		_show_error("ERROR_NO_RESERVATION_ID")

func _on_delete_reservations_button_up() -> void:
	_clear_error()
	if current_reservation_id != "":
		var result = await Network.state_transition(5, current_reservation_id)
		if result[0]:
			current_status = "AVAILABLE"
			current_reservation_id = ""
			update_buttons_visibility()
			DataContext.filter_changed.emit()
		else:
			var status_code = result[1]
			if status_code == 404:
				_show_error("ERROR_NETWORK_OR_NOT_FOUND")
			else:
				_show_error("ERROR_CANCEL_FAILED")
	else:
		_show_error("ERROR_NO_RESERVATION_ID")
