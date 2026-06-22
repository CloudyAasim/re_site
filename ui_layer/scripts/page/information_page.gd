extends Node

# ⭐ 绑定标题 Label，用于多语言刷新
@export var username_title_label: Label
@export var score_title_label: Label
# ⭐ 绑定数值 Label，用于显示后端返回的数据
@export var username_value_label: Label
@export var score_value_label: Label

@export var slot_title_label: Label
# ⭐ 新增：绑定展示时段的 ItemList
@export var slots_item_list: ItemList

# ⭐ 可选：绑定初始焦点（可以绑定到你那个独立的返回按钮上）
@export var initial_focus_control: Control

func _ready() -> void:
	# 监听语言切换
	SettingManager.locale_changed.connect(_on_locale_changed)
	
	# ⭐ 新增：监听基础数据加载完成信号
	if not DataContext.basic_data_loaded.is_connected(_update_slots_ui):
		DataContext.basic_data_loaded.connect(_update_slots_ui)
	
	# 初始化 UI 文本
	_on_locale_changed()
	
	# ⭐ 新增：配置 ItemList 不可选逻辑
	if slots_item_list:
		slots_item_list.focus_mode = Control.FOCUS_NONE
		if not slots_item_list.item_selected.is_connected(_on_item_selected):
			slots_item_list.item_selected.connect(_on_item_selected)
	
	# 刷新一次时段列表 (防止进入页面时数据已经加载完毕)
	_update_slots_ui()
	
	# 请求数据
	_fetch_user_profile()
	
	# 设置初始焦点
	UiNavigator.focus_control(initial_focus_control)

# ⭐⭐ 新增：监听全局返回键输入 ⭐⭐
func _unhandled_input(event: InputEvent):
	# ui_cancel 对应键盘的 Escape 键和安卓的返回键
	if event.is_action_pressed("ui_cancel"):
		UISignal.switch_page_requested.emit("res://ui_layer/scenes/page/home_page.tscn")

# ================= 网络请求 =================
func _fetch_user_profile():
	# 显示加载中提示
	if username_value_label:
		username_value_label.text = "..."
	if score_value_label:
		score_value_label.text = "..."
		
	var result = await Network.get_user_profile()
	
	# 防止在等待网络请求期间场景被切换导致报错
	if not is_inside_tree():
		return
		
	if result[0]: # 请求成功，解析数据 result[2] 是 Dictionary
		var profile_data = result[2]
		var username = str(profile_data.get("username", "N/A"))
		var score = str(profile_data.get("score", 0))
		if username_value_label:
			username_value_label.text = username
		if score_value_label:
			score_value_label.text = score
	else: # 请求失败
		print("个人资料页：获取用户信息失败")
		if username_value_label:
			username_value_label.text = tr("MSG_LOAD_FAILED")
		if score_value_label:
			score_value_label.text = "-"

# ================= 时段列表展示 =================
func _update_slots_ui():
	if not slots_item_list:
		return
		
	# 清空旧数据
	slots_item_list.clear()
	
	var slots = DataContext.slots_data
	if slots.is_empty():
		slots_item_list.add_item(tr("MSG_LOAD_FAILED"))
		return
		
	# 遍历时段数据并填充
	for slot in slots:
		var slot_name = slot.get("name", "未知时段")
		var start = slot.get("start", "00:00")
		var end = slot.get("end", "00:00")
		
		# 拼接格式："上午时段: 08:00 - 12:00"
		var display_text = "%s: %s - %s" % [slot_name, start, end]
		slots_item_list.add_item(display_text)

# 拦截 ItemList 的选中事件，保持纯展示不可选
func _on_item_selected(_index: int):
	if slots_item_list:
		slots_item_list.deselect_all()

# ================= 多语言支持 =================
func _on_locale_changed():
	username_title_label.text = tr("LABEL_USERNAME") + ":"
	score_title_label.text = tr("LABEL_SCORE") + ":"
	slot_title_label.text = tr("LABEL_SLOT")
