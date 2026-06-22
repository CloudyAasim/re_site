extends HBoxContainer

# ⭐ 1. 拖拽绑定节点
@export var filter_group: VBoxContainer
@export var seat_map_view: VBoxContainer
@export var reservations_me: VBoxContainer

@export var btn_filter_group: Button
@export var btn_seat_map_view: Button
@export var btn_reservations_me: Button

@export var prev_button: Button
@export var next_button: Button

# ==========================================
# ⭐⭐⭐ 精细化焦点自定义接口 ⭐⭐⭐
# ==========================================
@export var focus_filter_from_bar: Control
@export var focus_seat_from_bar: Control
@export var focus_reservations_from_bar: Control

@export var focus_seat_from_prev: Control
@export var focus_reservations_from_prev: Control

@export var focus_filter_from_next: Control
@export var focus_seat_from_next: Control

# ==========================================

var current_index: int = -1
var current_active_btn: Button = null
var pages: Array[Control]
var btns: Array[Button]

# 记录上一次焦点所在的节点，用于判断是从外部进入还是内部移动
var _last_focus_owner: Control = null

func _ready():
	pages = [filter_group, seat_map_view, reservations_me]
	btns = [btn_filter_group, btn_seat_map_view, btn_reservations_me]
	
	btn_filter_group.pressed.connect(_on_nav_bar_pressed.bind(0))
	btn_seat_map_view.pressed.connect(_on_nav_bar_pressed.bind(1))
	btn_reservations_me.pressed.connect(_on_nav_bar_pressed.bind(2))
	
	if prev_button:
		prev_button.pressed.connect(_on_prev_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
		
	SettingManager.locale_changed.connect(_on_locale_changed)
	_update_ui_texts()
	
	# ⭐ 修复：初始化时统一将所有按钮设置为未选中状态的灰色，并锁定样式大小！
	for btn in btns:
		if btn:
			btn.add_theme_color_override("font_color", Color(0.017, 0.017, 0.002))
			
			# ⭐⭐ 新增：锁定各种状态下的样式，防止 Godot 默认主题在焦点/悬停/按下时改变按钮大小 ⭐⭐
			var normal_style = btn.get_theme_stylebox("normal")
			if normal_style:
				# 将 hover, pressed, focus 的样式强制设为和 normal 一样，杜绝大小抖动
				#btn.add_theme_stylebox_override("hover", normal_style)
				btn.add_theme_stylebox_override("pressed", normal_style)
				#btn.add_theme_stylebox_override("focus", normal_style)
				
			# ⭐⭐ 新增：锁定各种状态下的字体大小，防止主题切换时字体放大 ⭐⭐
			var normal_font_size = btn.get_theme_font_size("font_size")
			btn.add_theme_font_size_override("font_size", normal_font_size)
			btn.add_theme_font_size_override("hover_font_size", normal_font_size)
			btn.add_theme_font_size_override("pressed_font_size", normal_font_size)
			btn.add_theme_font_size_override("focus_font_size", normal_font_size)

	# 监听 Bar 内部按钮的焦点进入事件
	for btn in btns:
		if btn:
			btn.focus_entered.connect(_on_btn_focus_entered.bind(btn))
			
	# 切换到默认页面 (这会将目标按钮设为蓝色高亮)
	_switch_page(0, "bar")

func _process(_delta):
	var current_focus = get_viewport().gui_get_focus_owner()
	if current_focus != _last_focus_owner:
		_last_focus_owner = current_focus

func _on_locale_changed():
	_update_ui_texts()

func _update_ui_texts():
	if btn_filter_group: btn_filter_group.text = tr("TAB_FILTER")
	if btn_seat_map_view: btn_seat_map_view.text = tr("TAB_SEAT_MAP")
	if btn_reservations_me: btn_reservations_me.text = tr("LABEL_MY_RESERVATIONS")
	if prev_button: prev_button.text = tr("BTN_PREV")
	if next_button: next_button.text = tr("BTN_NEXT")

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel") and current_index > 0:
		_on_prev_pressed()
		get_viewport().set_input_as_handled()

func _on_nav_bar_pressed(index: int):
	_switch_page(index, "bar")

func _on_next_pressed():
	if current_index < pages.size() - 1:
		_switch_page(current_index + 1, "prev") 

func _on_prev_pressed():
	if current_index > 0:
		_switch_page(current_index - 1, "next") 

func _switch_page(target_index: int, entry_type: String):
	if target_index == current_index:
		return
		
	current_index = target_index
	
	for i in range(pages.size()):
		if is_instance_valid(pages[i]):
			pages[i].visible = (i == target_index)
			
	_set_active_btn(btns[target_index])
	
	if prev_button:
		prev_button.visible = (target_index > 0)
	if next_button:
		next_button.visible = (target_index < pages.size() - 1)
		
	var focus_target: Control = null
	
	# ⭐ 修改逻辑：根据入口类型决定焦点去向
	if entry_type == "bar":
		# 点击顶部导航按钮切换时，焦点保持在当前选中的导航按钮上
		if btns.size() > target_index and is_instance_valid(btns[target_index]):
			focus_target = btns[target_index]
	else:
		# 点击上一页/下一页切换时，走精细化焦点自定义接口
		focus_target = _get_focus_target_for_context(target_index, entry_type)
		
	await get_tree().process_frame
	
	if focus_target and is_instance_valid(focus_target):
		UiNavigator.focus_control(focus_target)
	else:
		# 兜底：如果精细化接口没找到目标，依然回到导航按钮
		if btns.size() > target_index and is_instance_valid(btns[target_index]):
			UiNavigator.focus_control(btns[target_index])


func _get_focus_target_for_context(target_index: int, entry_type: String) -> Control:
	match target_index:
		0: 
			if entry_type == "bar": return focus_filter_from_bar
			if entry_type == "next": return focus_filter_from_next
		1: 
			if entry_type == "bar": return focus_seat_from_bar
			if entry_type == "prev": return focus_seat_from_prev
			if entry_type == "next": return focus_seat_from_next
		2: 
			if entry_type == "bar": return focus_reservations_from_bar
			if entry_type == "prev": return focus_reservations_from_prev
			
	return null

func _set_active_btn(target_btn: Button):
	# 恢复旧按钮颜色 (统一恢复为初始化的灰色)
	if current_active_btn:
		current_active_btn.add_theme_color_override("font_color", Color(0.017, 0.017, 0.002))
	# 设置新按钮颜色 (选中蓝色)
	if target_btn:
		target_btn.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0))
	current_active_btn = target_btn

# 智能焦点拦截逻辑
func _on_btn_focus_entered(btn: Button):
	if btn == current_active_btn:
		return
		
	var is_internal_move = false
	if _last_focus_owner and is_instance_valid(_last_focus_owner) and _last_focus_owner is BaseButton:
		if _last_focus_owner.get_parent() == self:
			is_internal_move = true
			
	if is_internal_move:
		return
		
	if current_active_btn and is_instance_valid(current_active_btn):
		current_active_btn.grab_focus.call_deferred()
