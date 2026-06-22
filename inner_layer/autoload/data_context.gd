extends Node

# 缓存数据
var floors_data: Array = []
var slots_data: Array = []
var my_reservations: Array = []

# 当前选中状态
var selected_date: String = ""
var selected_slot_id: String = ""
var selected_floor_id: String = ""
var selected_seat_id: String = ""

# 核心信号
signal filter_changed()
signal seat_focused(seat_id)
signal basic_data_loaded() # 基础数据加载完成信号

func _ready():
	# 将监听目标更新为 SettingManager
	SettingManager.locale_changed.connect(_on_locale_changed)
	
	# 初始化默认日期为今天
	var current_time = Time.get_datetime_dict_from_system()
	selected_date = _normalized_date(current_time["year"], current_time["month"], current_time["day"])
	
	# 移除硬编码的假数据，等待网络请求回来后自动赋值

func _on_locale_changed():
	filter_changed.emit()

# ================= 新增：核心数据加载方法 =================
func load_basic_data():
	# 防止重复请求
	if floors_data.size() > 0 and slots_data.size() > 0:
		basic_data_loaded.emit()
		return
		
	print("DataContext：开始从后端加载基础数据...")
	
	# 调用 Network 单例并发请求
	var floors_res = await Network.get_floors()
	var slots_res = await Network.get_slots()
	
	# 解析楼层数据 (根据你的 Network 返回格式: [成功与否, 状态码, 数据])
	if floors_res[0] == true:
		if floors_res[2] is Array:
			floors_data = floors_res[2]
		elif floors_res[2] is Dictionary and floors_res[2].has("floors"):
			floors_data = floors_res[2]["floors"]
			
	# 解析时段数据
	if slots_res[0] == true:
		if slots_res[2] is Array:
			slots_data = slots_res[2]
		elif slots_res[2] is Dictionary and slots_res[2].has("slots"):
			slots_data = slots_res[2]["slots"]
			
	# 数据到了，设置默认选中第一项
	if floors_data.size() > 0:
		selected_floor_id = str(floors_data[0].get("id", ""))
	if slots_data.size() > 0:
		selected_slot_id = str(slots_data[0].get("id", ""))
		
	print("DataContext：基础数据加载完成！")
	# 关键：通知 FilterGroup 可以渲染下拉框了
	basic_data_loaded.emit()

func change_filter(date, slot_id, floor_id) -> void:
	selected_date = date
	selected_slot_id = slot_id
	selected_floor_id = floor_id
	filter_changed.emit()

func jump_to_reservation(res_data: Dictionary) -> void:
	selected_date = res_data.get("date", selected_date)
	selected_slot_id = res_data.get("slot_id", selected_slot_id)
	selected_floor_id = res_data.get("floor_id", selected_floor_id)
	
	change_filter(selected_date, selected_slot_id, selected_floor_id)
	await get_tree().process_frame
	seat_focused.emit(res_data.get("seat_id", ""))

# ================= 辅助方法 =================
func _normalized_date(year: int, month: int, day: int) -> String:
	var date: String = str(year) + "-"
	if month < 10:
		date += "0" + str(month) + "-"
	else:
		date += str(month) + "-"
	if day < 10:
		date += "0" + str(day)
	else:
		date += str(day)
	return date
