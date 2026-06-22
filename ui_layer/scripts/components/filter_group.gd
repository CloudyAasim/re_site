extends VBoxContainer

@export var floor_option: OptionButton
@export var slot_option: OptionButton
@export var year_option: OptionButton
@export var month_option: OptionButton
@export var day_option: OptionButton

var is_syncing: bool = false # 防止同步数据时触发循环信号

func _ready():
	# 连接 OptionButton 的选中信号
	if floor_option: floor_option.item_selected.connect(_on_option_selected)
	if slot_option: slot_option.item_selected.connect(_on_option_selected)
	if year_option: year_option.item_selected.connect(_on_year_or_month_selected)
	if month_option: month_option.item_selected.connect(_on_year_or_month_selected)
	if day_option: day_option.item_selected.connect(_on_option_selected)
	
	# 监听 DataContext 信号
	DataContext.basic_data_loaded.connect(_populate_options)
	DataContext.filter_changed.connect(_sync_selection)
	
	# 初始化日期 UI
	_init_date_options()
	
	# 兜底：如果组件加载时数据已经好了，直接填充
	if DataContext.floors_data.size() > 0 and DataContext.slots_data.size() > 0:
		_populate_options()


# ================= 日期相关逻辑 =================

func _init_date_options():
	var current_time = Time.get_datetime_dict_from_system()
	
	year_option.get_popup().max_size.y = 120
	month_option.get_popup().max_size.y = 120
	day_option.get_popup().max_size.y = 120
	
	year_option.add_item(str(current_time["year"]), current_time["year"])
	year_option.add_item(str(current_time["year"]+1), current_time["year"]+1)
	year_option.select(year_option.get_item_index(current_time["year"]))
	
	for m in range(1, 13):
		month_option.add_item(str(m), m)
	month_option.select(month_option.get_item_index(current_time["month"]))
	
	update_days()
	if day_option.get_item_index(current_time["day"]) != -1:
		day_option.select(day_option.get_item_index(current_time["day"]))

func update_days():
	var selected_day_id = 1
	if day_option.item_count > 0 and day_option.selected >= 0:
		selected_day_id = day_option.get_selected_id()
		
	day_option.clear()
	var days_in_month = get_days_in_month(year_option.get_selected_id(), month_option.get_selected_id())
	for d in range(1, days_in_month + 1):
		day_option.add_item(str(d), d)
	
	if selected_day_id <= days_in_month:
		day_option.select(day_option.get_item_index(selected_day_id))
	else:
		day_option.select(day_option.get_item_index(days_in_month))

func get_days_in_month(year: int, month: int) -> int:
	if month in [1, 3, 5, 7, 8, 10, 12]: return 31
	elif month in [4, 6, 9, 11]: return 30
	else:
		if (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0): return 29
		else: return 28

func normalized_date(year: int, month: int, day: int) -> String:
	var date: String = str(year) + "-"
	if month < 10: date += "0" + str(month) + "-"
	else: date += str(month) + "-"
	if day < 10: date += "0" + str(day)
	else: date += str(day)
	return date

func _submit_date_to_context():
	var date_str = normalized_date(year_option.get_selected_id(), month_option.get_selected_id(), day_option.get_selected_id())
	DataContext.change_filter(date_str, DataContext.selected_slot_id, DataContext.selected_floor_id)


# ================= 数据填充与智能初始化逻辑 =================

func _populate_options():
	_populate_floors()
	_populate_slots()
	
	var defaults = get_smart_default_filter()
	DataContext.selected_date = defaults["date"]
	DataContext.selected_slot_id = defaults["slot_id"]
	
	if DataContext.floors_data.size() > 0 and DataContext.selected_floor_id == "":
		DataContext.selected_floor_id = str(DataContext.floors_data[0].get("id", ""))
		
	_sync_selection()
	
	DataContext.change_filter(DataContext.selected_date, DataContext.selected_slot_id, DataContext.selected_floor_id)

func _populate_floors():
	if not floor_option: return
	floor_option.clear()
	for floor_info in DataContext.floors_data:
		var f_id: String = str(floor_info.get("id", ""))
		var f_name: String = str(floor_info.get("name", "未知楼层"))
		floor_option.add_item(f_name)
		floor_option.set_item_metadata(floor_option.item_count - 1, f_id)

func _populate_slots():
	if not slot_option: return
	slot_option.clear()
	for slot_info in DataContext.slots_data:
		var s_id: String = str(slot_info.get("id", ""))
		var s_name: String = str(slot_info.get("name", "未知时段"))
		slot_option.add_item(s_name)
		slot_option.set_item_metadata(slot_option.item_count - 1, s_id)


# ================= 状态同步逻辑 =================

func _sync_selection():
	is_syncing = true
	
	_select_by_id(floor_option, DataContext.selected_floor_id)
	_select_by_id(slot_option, DataContext.selected_slot_id)
	
	if DataContext.selected_date != "":
		var date_parts = DataContext.selected_date.split("-")
		var year = int(date_parts[0])
		var month = int(date_parts[1])
		var day = int(date_parts[2])
		
		if year_option.get_item_index(year) != -1:
			year_option.select(year_option.get_item_index(year))
		if month_option.get_item_index(month) != -1:
			month_option.select(month_option.get_item_index(month))
		
		update_days()
		
		if day_option.get_item_index(day) != -1:
			day_option.select(day_option.get_item_index(day))
			
	is_syncing = false

func _select_by_id(option_btn: OptionButton, target_id: String):
	if not option_btn: return
	for i in range(option_btn.item_count):
		var meta = option_btn.get_item_metadata(i)
		if meta != null and str(meta) == target_id:
			option_btn.selected = i
			return
	if option_btn.item_count > 0:
		option_btn.selected = 0


# ================= 用户交互逻辑 =================

func _on_year_or_month_selected(index: int):
	update_days()
	if not is_syncing:
		_submit_date_to_context()

func _on_option_selected(index: int):
	if is_syncing: return
		
	var floor_id: String = ""
	var slot_id: String = ""
	
	if floor_option and floor_option.item_count > 0 and floor_option.selected >= 0:
		var meta = floor_option.get_item_metadata(floor_option.selected)
		if meta != null:
			floor_id = str(meta)
			
	if slot_option and slot_option.item_count > 0 and slot_option.selected >= 0:
		var meta = slot_option.get_item_metadata(slot_option.selected)
		if meta != null:
			slot_id = str(meta)
			
	var date_str = normalized_date(year_option.get_selected_id(), month_option.get_selected_id(), day_option.get_selected_id())
	
	DataContext.change_filter(date_str, slot_id, floor_id)


# ================= 智能默认时段核心算法 =================

func get_smart_default_filter() -> Dictionary:
	if DataContext.slots_data.is_empty():
		return {"date": Time.get_date_string_from_system(), "slot_id": ""}

	# 获取本地当前时间（默认取系统本地时间，如果是北京时间就无需转换）
	var now_dict = Time.get_datetime_dict_from_system()
	var current_minutes = now_dict["hour"] * 60 + now_dict["minute"]
	var today_str = "%04d-%02d-%02d" % [now_dict["year"], now_dict["month"], now_dict["day"]]
	
	print("\n========== 🕒 智能默认时段判断 ==========")
	print("当前系统时间: ", now_dict["hour"], ":", now_dict["minute"], " (总分钟:", current_minutes, ")")

	var sorted_slots = DataContext.slots_data.duplicate()
	sorted_slots.sort_custom(func(a, b): return _get_slot_time_mins(a, ["start_time", "startTime", "begin_time", "beginTime", "start"]) < _get_slot_time_mins(b, ["start_time", "startTime", "begin_time", "beginTime", "start"]))

	var current_slot_id = ""
	var next_slot_id = ""
	var first_slot_id = sorted_slots[0].get("id", "")
	var latest_end_mins = -1

	# 遍历计算最晚结束时间
	for slot in sorted_slots:
		var start_mins = _get_slot_time_mins(slot, ["start_time", "startTime", "begin_time", "beginTime", "start"])
		var end_mins = _get_slot_time_mins(slot, ["end_time", "endTime", "close_time", "closeTime", "end"])
		
		var effective_end = end_mins
		if end_mins != -1 and start_mins != -1 and end_mins < start_mins:
			effective_end = end_mins + 24 * 60 # 跨天时段处理

		if effective_end > latest_end_mins:
			latest_end_mins = effective_end

	# 规则3：如果当前时间已经过了今天所有时段的最晚结束时间，直接跳到明天
	if latest_end_mins >= 0 and current_minutes >= latest_end_mins:
		var tomorrow_str = _get_tomorrow_date_str(now_dict)
		print("👉 判定结果：今日时段已全部结束 (最晚结束分钟:", latest_end_mins, ")，默认切换至明天: ", tomorrow_str)
		print("=========================================\n")
		return {"date": tomorrow_str, "slot_id": first_slot_id}

	# 规则1和2：寻找当前时段或下一个时段
	for slot in sorted_slots:
		var slot_id = str(slot.get("id", ""))
		var start_mins = _get_slot_time_mins(slot, ["start_time", "startTime", "begin_time", "beginTime", "start"])
		var end_mins = _get_slot_time_mins(slot, ["end_time", "endTime", "close_time", "closeTime", "end"])
		
		if start_mins == -1 or end_mins == -1:
			continue

		# 判断是否在时段内
		var is_in_slot = false
		if start_mins <= end_mins:
			is_in_slot = (current_minutes >= start_mins and current_minutes < end_mins)
		else:
			# 跨天时段 (如 22:00 - 次日06:00)
			is_in_slot = (current_minutes >= start_mins or current_minutes < end_mins)
			
		if is_in_slot:
			current_slot_id = slot_id
			print("👉 判定结果：当前正处于时段 [", slot_id, "] 内 (", start_mins, "-", end_mins, " 分钟)")
			break
		elif current_minutes < start_mins:
			if next_slot_id == "":
				next_slot_id = slot_id
				print("👉 判定结果：当前不在任何时段内，下一时段为 [", slot_id, "] (", start_mins, " 分钟)")
				break # 找到最近的下一个就跳出

	if current_slot_id != "":
		print("=========================================\n")
		return {"date": today_str, "slot_id": current_slot_id}
	elif next_slot_id != "":
		print("=========================================\n")
		return {"date": today_str, "slot_id": next_slot_id}
	else:
		var tomorrow_str = _get_tomorrow_date_str(now_dict)
		print("👉 判定结果：兜底逻辑，默认切换至明天: ", tomorrow_str)
		print("=========================================\n")
		return {"date": tomorrow_str, "slot_id": first_slot_id}

# 辅助函数：智能提取时段的分钟数（兼容各种键名和格式）
func _get_slot_time_mins(slot: Dictionary, possible_keys: Array) -> int:
	for key in possible_keys:
		if slot.has(key):
			return _time_to_minutes(str(slot[key]))
	return -1

# 辅助函数：将各种格式的时间转换为当天的总分钟数
func _time_to_minutes(time_str: String) -> int:
	if time_str == null or time_str == "": return -1
	time_str = time_str.strip_edges()
	
	# 兼容 "2024-05-20 08:00:00" 这种带日期的格式，提取空格后面的部分
	if " " in time_str:
		time_str = time_str.split(" ")[1]
		
	var parts = time_str.split(":")
	if parts.size() >= 2:
		var h = int(parts[0])
		var m = int(parts[1])
		if h >= 0 and h < 24 and m >= 0 and m < 60:
			return h * 60 + m
			
	return -1

func _get_tomorrow_date_str(date_dict: Dictionary) -> String:
	var now_unix = Time.get_unix_time_from_datetime_dict(date_dict)
	var tomorrow_unix = now_unix + 86400
	var tomorrow_dict = Time.get_datetime_dict_from_unix_time(tomorrow_unix)
	return "%04d-%02d-%02d" % [tomorrow_dict["year"], tomorrow_dict["month"], tomorrow_dict["day"]]
