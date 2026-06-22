extends VBoxContainer 

@export var floor_label: Label 
@export var seat_list: ItemList 
@export var canvas_scroll_container: ScrollContainer 
@export var canvas_container: Control 

const BASE_BUTTON_PATH = "res://ui_layer/scenes/components/base/BaseButton.tscn"
const BUTTON_SIZE: int = 70 # 按钮正方形边长
const GAP_PADDING: int = 20 # 画布边缘留白

var id_to_index_map: Dictionary = {} 
var seat_statuses: Dictionary = {} 
var seat_reservation_ids: Dictionary = {} 
var canvas_buttons: Dictionary = {} 

signal seat_clicked(seat_id: String, status: String, reservation_id: String)

var use_canvas_view: bool = false:
	set(value):
		use_canvas_view = value
		_update_view_visibility()

func _ready(): 
	seat_list.item_activated.connect(_on_seat_activated) 
	seat_list.item_selected.connect(_on_seat_activated) 
	DataContext.seat_focused.connect(_on_seat_focused) 
	DataContext.filter_changed.connect(_clear_view) 
	_update_view_visibility()

func _update_view_visibility():
	if seat_list:
		seat_list.visible = not use_canvas_view
	if canvas_scroll_container:
		canvas_scroll_container.visible = use_canvas_view

func render_seats(floor_info: Dictionary, layout_seats: Array, availability_data: Array, canvas_size: Dictionary = {}): 
	seat_list.clear() 
	id_to_index_map.clear() 
	seat_statuses.clear() 
	seat_reservation_ids.clear() 
	canvas_buttons.clear()
	
	if canvas_container:
		for child in canvas_container.get_children():
			child.queue_free()
	
	floor_label.text = str(floor_info.get("name", tr("LABEL_FLOOR"))) 
	
	# 1. 提取所有坐标
	var coords = []
	var has_valid_coords = false
	for seat in layout_seats:
		var x = int(seat.get("x", 0))
		var y = int(seat.get("y", 0))
		coords.append({x = x, y = y})
		if x != 0 or y != 0:
			has_valid_coords = true
			
	# 2. 计算最近的两个座位之间的距离
	var min_dist = INF
	if has_valid_coords:
		for i in range(coords.size()):
			for j in range(i + 1, coords.size()):
				var dx = coords[i].x - coords[j].x
				var dy = coords[i].y - coords[j].y
				var dist = sqrt(dx * dx + dy * dy)
				# 排除完全重叠的坐标点
				if dist > 0 and dist < min_dist:
					min_dist = dist
					
	# 3. 判断是否使用坐标模式
	var use_coordinate_mode = has_valid_coords and min_dist != INF and min_dist > 0
	
	# 4. 计算缩放比例
	var scale = 1.0
	if use_coordinate_mode:
		scale = (1.25 * BUTTON_SIZE) / min_dist
		
	var max_x = 0
	var max_y = 0
	# 用于无坐标时的网格排版
	var col_idx = 0
	var row_idx = 0
	var grid_cols = ceil(sqrt(layout_seats.size()))
	
	# 预加载 BaseButton 场景
	var btn_scene = load(BASE_BUTTON_PATH)
	
	for i in range(layout_seats.size()): 
		var seat = layout_seats[i]
		var seat_id = str(seat.get("id", "")) 
		var seat_name = str(seat.get("name", "未知座位")) 
		
		# 填充列表视图
		seat_list.add_item(seat_name, null, true) 
		var idx = seat_list.get_item_count() - 1 
		seat_list.set_item_metadata(idx, seat_id) 
		id_to_index_map[seat_id] = idx 
		
		# 填充画布视图
		if use_canvas_view and canvas_container and btn_scene:
			# 【修改】使用实例化 BaseButton 代替原生 Button
			var btn = btn_scene.instantiate()
			btn.text = seat_name
			btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
			btn.size = Vector2(BUTTON_SIZE, BUTTON_SIZE) # 强制尺寸
			btn.clip_text = true
			btn.add_theme_font_size_override("font_size", 12)
			btn.set_meta("seat_id", seat_id)
			btn.pressed.connect(_on_canvas_seat_pressed.bind(seat_id))
			
			var pos_x = 0
			var pos_y = 0
			if use_coordinate_mode:
				# 坐标模式：应用等比例缩放
				pos_x = int(coords[i].x * scale)
				pos_y = int(coords[i].y * scale)
			else:
				# 网格模式：自动排布
				pos_x = GAP_PADDING + col_idx * (BUTTON_SIZE + GAP_PADDING)
				pos_y = GAP_PADDING + row_idx * (BUTTON_SIZE + GAP_PADDING)
				col_idx += 1
				if col_idx >= grid_cols:
					col_idx = 0
					row_idx += 1
					
			btn.position = Vector2(pos_x, pos_y)
			canvas_container.add_child(btn)
			canvas_buttons[seat_id] = btn
			
			# 记录画布所需的最大尺寸
			if pos_x + BUTTON_SIZE > max_x: max_x = pos_x + BUTTON_SIZE
			if pos_y + BUTTON_SIZE > max_y: max_y = pos_y + BUTTON_SIZE
			
	for avail in availability_data: 
		var avail_seat_id = str(avail.get("seat_id", "")) 
		var status = str(avail.get("status", "UNKNOWN")) 
		if id_to_index_map.has(avail_seat_id): 
			var idx = id_to_index_map[avail_seat_id] 
			var base_name = seat_list.get_item_text(idx).split(" - ")[0] 
			seat_statuses[avail_seat_id] = status 
			seat_reservation_ids[avail_seat_id] = str(avail.get("reservation_id", "")) 
			
			match status: 
				"AVAILABLE": 
					seat_list.set_item_text(idx, base_name + " - 🟢" + tr("STATUS_AVAILABLE")) 
					_update_canvas_seat_color(avail_seat_id, Color(0.2, 0.8, 0.2))
				"OCCUPIED": 
					seat_list.set_item_text(idx, base_name + " - 🔴" + tr("STATUS_OCCUPIED")) 
					_update_canvas_seat_color(avail_seat_id, Color(0.9, 0.2, 0.2))
				"SUSPENDED": 
					seat_list.set_item_text(idx, base_name + " - 🟡" + tr("STATUS_SUSPENDED")) 
					_update_canvas_seat_color(avail_seat_id, Color(0.9, 0.7, 0.0))
					
	# 设置画布最终尺寸，加上边缘留白
	if canvas_container:
		canvas_container.custom_minimum_size = Vector2(max_x + GAP_PADDING, max_y + GAP_PADDING)
					
	if seat_list.item_count > 0: 
		seat_list.select(0) 
		DataContext.selected_seat_id = str(seat_list.get_item_metadata(0)) 

func _update_canvas_seat_color(seat_id: String, color: Color):
	if canvas_buttons.has(seat_id) and is_instance_valid(canvas_buttons[seat_id]):
		var btn = canvas_buttons[seat_id] as Button
		btn.add_theme_color_override("font_color", color)

func _on_canvas_seat_pressed(seat_id: String):
	var status = seat_statuses.get(seat_id, "UNKNOWN")
	var res_id = seat_reservation_ids.get(seat_id, "")
	seat_clicked.emit(seat_id, status, res_id)

func _on_seat_activated(index: int): 
	var seat_id = str(seat_list.get_item_metadata(index)) 
	DataContext.selected_seat_id = seat_id 
	var status = seat_statuses.get(seat_id, "UNKNOWN") 
	var res_id = seat_reservation_ids.get(seat_id, "") 
	seat_clicked.emit(seat_id, status, res_id) 

func _on_seat_focused(seat_id: String): 
	if id_to_index_map.has(seat_id): 
		var idx = id_to_index_map[seat_id] 
		seat_list.select(idx) 
		seat_list.ensure_current_is_visible() 

func _clear_view(): 
	seat_list.clear() 
	id_to_index_map.clear() 
	seat_statuses.clear() 
	seat_reservation_ids.clear() 
	if canvas_container:
		for child in canvas_container.get_children():
			child.queue_free()
	canvas_buttons.clear()
	floor_label.text = ""
