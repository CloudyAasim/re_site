extends ItemList

@export var filter_statuses: PackedStringArray = ["PENDING", "ACTIVE", "SUSPENDED"]

var _cached_reservations: Array = []
var _pending_request_count: int = 0
var _is_fetching: bool = false # ⭐ 防并发锁
var _sticky_selection: Dictionary = {} # ⭐⭐ 新增：记录需要保持选中的条件

signal reservation_selected(reservation_data: Dictionary)
signal data_refreshed()

func _ready():
	item_clicked.connect(_on_item_clicked)
	item_activated.connect(_on_item_activated)
	DataContext.filter_changed.connect(fetch_data)

# ================= 核心数据加载 =================
func fetch_data():
	# ⭐ 核心修复：如果正在请求中，拒绝重复发起，直接等待上一次完成
	if _is_fetching: 
		return
	_is_fetching = true
	clear()
	_cached_reservations.clear()
	
	if filter_statuses.is_empty():
		data_refreshed.emit()
		_is_fetching = false
		return
		
	_pending_request_count = filter_statuses.size()
	for status in filter_statuses:
		_request_status(status)

func _request_status(status: String):
	var res = await Network.get_reservations_me(true, status)
	# ⭐ 核心修复：防御性处理返回数据类型
	if res[0]:
		var data = res[2]
		if data is Array:
			_cached_reservations.append_array(data)
		elif data == null or data == {}:
			pass # 空数据，正常跳过
		else:
			push_warning("预约列表返回数据格式异常，期望Array，收到: ", data)
			
	_pending_request_count -= 1
	# ⭐ 核心修复：用 <= 0 防御意外情况
	if _pending_request_count <= 0:
		_sort_and_refresh()
		data_refreshed.emit()
		_is_fetching = false # 解锁

# ================= 智能排序与UI刷新 =================
const STATUS_PRIORITY = {
	"PENDING": 1,
	"ACTIVE": 2,
	"SUSPENDED": 3,
	"COMPLETED": 4,
	"CANCELLED": 5
}

func _sort_and_refresh():
	_cached_reservations.sort_custom(func(a, b): 
		var prio_a = STATUS_PRIORITY.get(a.get("status", ""), 99)
		var prio_b = STATUS_PRIORITY.get(b.get("status", ""), 99)
		if prio_a != prio_b: return prio_a < prio_b
		
		var date_a = a.get("date", "")
		var date_b = b.get("date", "")
		if date_a != date_b: return date_a > date_b # 日期降序
		
		var mins_a = _get_slot_start_mins(a.get("slot_id", ""))
		var mins_b = _get_slot_start_mins(b.get("slot_id", ""))
		if mins_a != mins_b: return mins_a > mins_b # 时段降序
		
		return false # 保持原序
	)
	
	for res in _cached_reservations:
		var floor_name = _get_floor_name(res.get("floor_id", ""))
		var seat_name = res.get("seat_name", "未知座位")
		var status_text = _get_status_text(res.get("status", ""))
		var deadline = res.get("next_deadline", "")
		if " " in deadline:
			deadline = deadline.split(" ")[1] # 提取时分秒
			
		var display_text = "%s %s | %s | 截止: %s" % [floor_name, seat_name, status_text, deadline]
		add_item(display_text, null, true)
		set_item_metadata(get_item_count() - 1, res)
		
	# ================= 恢复粘性选中逻辑 =================
	if not _sticky_selection.is_empty():
		select_matching_item(
			_sticky_selection.get("seat_id", ""),
			_sticky_selection.get("date", ""),
			_sticky_selection.get("slot_id", "")
		)

# ================= 交互逻辑 =================
func _on_item_clicked(index: int, at_position: Vector2, mouse_button_index: int):
	_handle_selection(index)

func _on_item_activated(index: int):
	_handle_selection(index)

func _handle_selection(index: int):
	if index < 0: return
	var res_data = get_item_metadata(index)
	if res_data is Dictionary:
		reservation_selected.emit(res_data)

# ================= 提供给外部的查询接口 =================
# ⭐ 修改：严格限制只有这三种状态的预约才被认为是“有效匹配”
func find_reservation(seat_id: String, date: String, slot_id: String) -> Dictionary:
	for res in _cached_reservations:
		var r_status = res.get("status", "")
		if r_status != "PENDING" and r_status != "ACTIVE" and r_status != "SUSPENDED":
			continue
		if res.get("seat_id") == seat_id and res.get("date") == date and res.get("slot_id") == slot_id:
			return res
	return {}

# ⭐⭐ 新增：自动选中列表中与指定座位/日期/时段匹配的项目
func select_matching_item(p_seat_id: String, p_date: String, p_slot_id: String) -> void:
	deselect_all()
	var target_res = find_reservation(p_seat_id, p_date, p_slot_id)
	if target_res.is_empty():
		return
		
	for i in range(item_count):
		var item_data = get_item_metadata(i)
		if item_data == target_res:
			select(i)
			ensure_current_is_visible()
			return

# ⭐⭐ 新增：设置粘性选中（无论怎么刷新，都强制选中对应项）
func set_sticky_selection(p_seat_id: String, p_date: String, p_slot_id: String):
	_sticky_selection = {
		"seat_id": p_seat_id,
		"date": p_date,
		"slot_id": p_slot_id
	}

# ⭐⭐ 新增：清除粘性选中
func clear_sticky_selection():
	_sticky_selection = {}
	deselect_all()

# ================= 辅助方法 =================
func _get_floor_name(floor_id: String) -> String:
	for f in DataContext.floors_data:
		if str(f.get("id")) == str(floor_id):
			return str(f.get("name", ""))
	return floor_id

func _get_status_text(status: String) -> String:
	match status:
		"PENDING": return "待签到"
		"ACTIVE": return "使用中"
		"SUSPENDED": return "暂离中"
		"COMPLETED": return "已结束"
		"CANCELLED": return "已取消"
		_: return status

func _get_slot_start_mins(slot_id: String) -> int:
	for s in DataContext.slots_data:
		if str(s.get("id")) == slot_id:
			var start_str = str(s.get("start_time", s.get("startTime", "")))
			if " " in start_str:
				start_str = start_str.split(" ")[1]
			var parts = start_str.split(":")
			if parts.size() >= 2:
				return int(parts[0]) * 60 + int(parts[1])
	return 0
