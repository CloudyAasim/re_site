extends CanvasLayer

var target_line_edit: LineEdit = null
var main_container: PanelContainer
var vbox: VBoxContainer

# 键盘状态枚举: 0=小写, 1=大写, 2=符号, 3=数字
var _mode: int = 3
var is_dark_mode: bool = false

# 缓存关闭按钮，用于默认聚焦
var hide_btn: Button = null

# ==============================================================
# 精细化调控参数 (可在编辑器右侧检查器中直接配置)
# ==============================================================
## [基础设置] 键盘所在的渲染层级。数字越大显示在越上层，如果被其他UI遮挡，请调大此值。
@export_range(0, 200) var canvas_layer: int = 100
## [基础设置] 面板内边距(像素)。控制按键与屏幕边缘、以及按键组与背景边缘之间的留白距离。
@export_range(0, 50) var panel_padding: int = 5
## [尺寸与字体] 键盘整体高度占屏幕高度的比例。0.35 代表占屏幕底部 35% 的高度。
@export_range(0.1, 0.9) var keyboard_height_ratio: float = 0.35
## [尺寸与字体] 单个按键的最小高度(像素)。防止在低分辨率下按键被挤压成扁条。
@export_range(20, 150) var key_min_height: int = 8
## [尺寸与字体] 按键之间以及行与行之间的间距(像素)。
@export_range(0, 20) var key_separation: int = 3
## [尺寸与字体] 按键文字的字号大小。
@export_range(10, 48) var key_font_size: int = 16
## [尺寸与字体] 空格键的宽度倍数。设为 3.0 表示空格键宽度是普通字母键的 3 倍。
@export_range(1.0, 6.0, 0.1) var space_key_stretch_ratio: float = 3.0

## [布局配置] 默认小写字母布局。数组中每个字符串代表一行按键。
@export var layout_lower: Array[String] = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
## [布局配置] 大写字母布局 (按 Shift 后显示)。
@export var layout_upper: Array[String] = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
## [布局配置] 标点符号布局 (按 123!# 后默认显示)。
@export var layout_symbols: Array[String] = [
	"1234567890",
	"-_+={}[]|\\:;",
	"'<,>.?/!@#$%",
	"^&*()`~"
]
## [布局配置] 纯数字布局 (在符号模式下按 123/!# 切换显示，方便输入纯数字)。
@export var layout_numbers: Array[String] = [
	"+123*",
	"-456/",
	".7890"
]

## [功能键文本] 隐藏键盘的按钮文本，"v" 可改成 "▼" 或 "隐藏"。
@export var text_hide: String = "▼"
## [功能键文本] 大小写切换按钮文本。
@export var text_shift: String = "Shift"
## [功能键文本] 从字母切到符号的按钮文本。
@export var text_symbol: String = "123!#"
## [功能键文本] 在符号面板下，用于切换"数字"和"标点"的按钮文本。
@export var text_number_toggle: String = "123/!#"
## [功能键文本] 空格键文本。
@export var text_space: String = "Space"
## [功能键文本] 退格删除键文本，"Del" 可改成 "⌫"。
@export var text_backspace: String = "Del"
## [功能键文本] 确认/回车键文本，"Enter" 可改成 "↵"。
@export var text_enter: String = "Enter"

## [颜色主题 - 亮色] 亮色模式下的背景颜色
@export_group("Light Theme")
@export var light_bg_color: Color = Color(0.902, 0.902, 0.902, 0.686)
## [颜色主题 - 亮色] 按键默认颜色
@export var light_key_color: Color = Color(1.0, 1.0, 1.0, 0.196)
## [颜色主题 - 亮色] 鼠标悬停时的按键颜色
@export var light_key_hover_color: Color = Color(0.627, 0.898, 0.976, 1.0)
## [颜色主题 - 亮色] 按下时的按键颜色
@export var light_key_pressed_color: Color = Color(0.627, 0.898, 0.976, 1.0)
## [颜色主题 - 亮色] 聚焦(手柄/键盘选中)时的按键颜色
@export var light_key_focus_color: Color = Color(0.627, 0.898, 0.976, 1.0)
## [颜色主题 - 亮色] 按键上的文字颜色
@export var light_font_color: Color = Color(0.09, 0.09, 0.02, 1.0)

## [颜色主题 - 暗色] 暗色模式下的背景颜色
@export_group("Dark Theme")
@export var dark_bg_color: Color = Color(0.15, 0.15, 0.15, 1)
## [颜色主题 - 暗色] 按键默认颜色
@export var dark_key_color: Color = Color(0.3, 0.3, 0.3, 1)
## [颜色主题 - 暗色] 鼠标悬停时的按键颜色
@export var dark_key_hover_color: Color = Color(0.4, 0.4, 0.4, 1)
## [颜色主题 - 暗色] 按下时的按键颜色
@export var dark_key_pressed_color: Color = Color(0.5, 0.5, 0.5, 1)
## [颜色主题 - 暗色] 聚焦(手柄/键盘选中)时的按键颜色
@export var dark_key_focus_color: Color = Color(0.5, 0.5, 0.5, 1)
## [颜色主题 - 暗色] 按键上的文字颜色
@export var dark_font_color: Color = Color(0.9, 0.9, 0.9, 1)
# ==============================================================

func _ready():
	layer = canvas_layer
	_build_main_ui()
	_apply_theme()
	refresh_layout()
	visible = false

# ==========================================================
# 主题与样式管理
# ==========================================================
## 切换暗色/亮色模式的对外接口
func set_dark_mode(enabled: bool):
	is_dark_mode = enabled
	_apply_theme()
	refresh_layout()

func _apply_theme():
	var bg_color = dark_bg_color if is_dark_mode else light_bg_color
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = bg_color
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	main_container.add_theme_stylebox_override("panel", panel_style)

# 根据传入的状态获取对应的按键样式盒
func _get_key_stylebox(state: String = "normal") -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	if is_dark_mode:
		match state:
			"hover":
				style.bg_color = dark_key_hover_color
			"pressed":
				style.bg_color = dark_key_pressed_color
			"focus":
				style.bg_color = dark_key_focus_color
			_:
				style.bg_color = dark_key_color # normal
	else:
		match state:
			"hover":
				style.bg_color = light_key_hover_color
			"pressed":
				style.bg_color = light_key_pressed_color
			"focus":
				style.bg_color = light_key_focus_color
			_:
				style.bg_color = light_key_color # normal
	return style

func _get_font_color() -> Color:
	return dark_font_color if is_dark_mode else light_font_color

# ==========================================================
# UI 构建
# ==========================================================
func _build_main_ui():
	main_container = PanelContainer.new()
	main_container.anchor_left = 0.0
	main_container.anchor_right = 1.0
	main_container.anchor_top = 1.0 - keyboard_height_ratio
	main_container.anchor_bottom = 1.0
	main_container.offset_left = 0
	main_container.offset_top = 0
	main_container.offset_right = 0
	main_container.offset_bottom = 0
	main_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(main_container)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", panel_padding)
	margin.add_theme_constant_override("margin_right", panel_padding)
	margin.add_theme_constant_override("margin_top", panel_padding)
	margin.add_theme_constant_override("margin_bottom", panel_padding)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(margin)

	vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", key_separation)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

func refresh_layout():
	# 记录重建前拥有焦点的按钮文本（转小写统一匹配，解决大小写切换问题）
	var focus_text: String = ""
	var current_focus = get_viewport().gui_get_focus_owner()
	if current_focus is Button and is_focus_inside(current_focus):
		focus_text = current_focus.text.to_lower()
		
	for child in vbox.get_children():
		child.queue_free()
		
	vbox.add_theme_constant_override("separation", key_separation)

	var layout = layout_lower
	match _mode:
		1:
			layout = layout_upper
		2:
			layout = layout_symbols
		3:
			layout = layout_numbers

	for row_str in layout:
		var row_container = HBoxContainer.new()
		row_container.alignment = BoxContainer.ALIGNMENT_CENTER
		row_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row_container.add_theme_constant_override("separation", key_separation)
		vbox.add_child(row_container)

		for char in row_str:
			var btn = Button.new()
			btn.text = char
			# 分别设置 normal, hover, pressed, focus 状态的样式盒
			btn.add_theme_stylebox_override("normal", _get_key_stylebox("normal"))
			btn.add_theme_stylebox_override("hover", _get_key_stylebox("hover"))
			btn.add_theme_stylebox_override("pressed", _get_key_stylebox("pressed"))
			btn.add_theme_stylebox_override("focus", _get_key_stylebox("focus"))

			var font_col = _get_font_color()
			btn.add_theme_color_override("font_color", font_col)
			btn.add_theme_color_override("font_hover_color", font_col)
			btn.add_theme_color_override("font_pressed_color", font_col)
			btn.add_theme_color_override("font_focus_color", font_col)

			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", key_font_size)
			# 开启焦点模式，允许手柄/键盘导航
			btn.focus_mode = Control.FOCUS_ALL
			btn.custom_minimum_size = Vector2(0, key_min_height)
			btn.pressed.connect(_on_char_pressed.bind(char))
			
			# 如果这个按钮和刚才聚焦的按钮文本匹配，立刻让它获取焦点
			if btn.text.to_lower() == focus_text:
				btn.grab_focus()
				focus_text = "" # 找到了就清空，避免重复匹配
				
			row_container.add_child(btn)

	# 功能键行
	var func_row = HBoxContainer.new()
	func_row.alignment = BoxContainer.ALIGNMENT_CENTER
	func_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	func_row.add_theme_constant_override("separation", key_separation)
	vbox.add_child(func_row)

	# 隐藏按钮
	hide_btn = _create_func_btn(text_hide)
	if hide_btn.text.to_lower() == focus_text:
		hide_btn.grab_focus()
		focus_text = ""
	hide_btn.pressed.connect(close)
	func_row.add_child(hide_btn)

	# Shift 或 数字/符号切换按钮
	if _mode == 0 or _mode == 1:
		var shift_btn = _create_func_btn(text_shift)
		if shift_btn.text.to_lower() == focus_text:
			shift_btn.grab_focus()
			focus_text = ""
		shift_btn.toggle_mode = true
		shift_btn.set_pressed_no_signal(_mode == 1)
		shift_btn.pressed.connect(_on_shift_pressed)
		func_row.add_child(shift_btn)
	elif _mode == 2 or _mode == 3:
		var toggle_btn = _create_func_btn(text_number_toggle)
		if toggle_btn.text.to_lower() == focus_text:
			toggle_btn.grab_focus()
			focus_text = ""
		toggle_btn.pressed.connect(_on_number_sym_toggle_pressed)
		func_row.add_child(toggle_btn)

	# 切换到符号/数字模式的按钮 (当处于字母模式时)
	if _mode == 0 or _mode == 1:
		var sym_btn = _create_func_btn(text_symbol)
		if sym_btn.text.to_lower() == focus_text:
			sym_btn.grab_focus()
			focus_text = ""
		sym_btn.pressed.connect(_on_sym_pressed)
		func_row.add_child(sym_btn)
	# 切换回字母模式的按钮 (当处于符号/数字模式时)
	else:
		var abc_btn = _create_func_btn("ABC")
		if abc_btn.text.to_lower() == focus_text:
			abc_btn.grab_focus()
			focus_text = ""
		abc_btn.pressed.connect(_on_abc_pressed)
		func_row.add_child(abc_btn)

	var space_btn = _create_func_btn(text_space, space_key_stretch_ratio)
	if space_btn.text.to_lower() == focus_text:
		space_btn.grab_focus()
		focus_text = ""
	space_btn.pressed.connect(_on_char_pressed.bind(" "))
	func_row.add_child(space_btn)

	var bs_btn = _create_func_btn(text_backspace)
	if bs_btn.text.to_lower() == focus_text:
		bs_btn.grab_focus()
		focus_text = ""
	bs_btn.pressed.connect(_on_backspace_pressed)
	func_row.add_child(bs_btn)

	var enter_btn = _create_func_btn(text_enter)
	if enter_btn.text.to_lower() == focus_text:
		enter_btn.grab_focus()
		focus_text = ""
	enter_btn.pressed.connect(_on_enter_pressed)
	func_row.add_child(enter_btn)

func _create_func_btn(text: String, stretch_ratio: float = 1.0) -> Button:
	var btn = Button.new()
	btn.text = text
	# 分别设置 normal, hover, pressed, focus 状态的样式盒
	btn.add_theme_stylebox_override("normal", _get_key_stylebox("normal"))
	btn.add_theme_stylebox_override("hover", _get_key_stylebox("hover"))
	btn.add_theme_stylebox_override("pressed", _get_key_stylebox("pressed"))
	btn.add_theme_stylebox_override("focus", _get_key_stylebox("focus"))
	
	# 设置文字颜色 (包含默认、悬停、按下、聚焦状态)
	var font_col = _get_font_color()
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", font_col)
	btn.add_theme_color_override("font_pressed_color", font_col)
	btn.add_theme_color_override("font_focus_color", font_col)
	
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.size_flags_stretch_ratio = stretch_ratio
	btn.add_theme_font_size_override("font_size", key_font_size)
	# 开启焦点模式
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size = Vector2(0, key_min_height)
	return btn

# ==========================================================
# 焦点管理接口
# ==========================================================
## 判断当前焦点是否在键盘内部
func is_focus_inside(control: Control) -> bool:
	return is_instance_valid(control) and is_instance_valid(main_container) and main_container.is_ancestor_of(control)

## 强制让键盘获取默认焦点
func grab_default_focus():
	if is_instance_valid(hide_btn):
		hide_btn.grab_focus()

# ==========================================================
# 按键事件处理
# ==========================================================
func open(line_edit: LineEdit):
	target_line_edit = line_edit
	visible = true
	# 等待一帧让 UI 完成布局，然后聚焦关闭键
	await get_tree().process_frame
	grab_default_focus()

func close():
	visible = false
	if target_line_edit and is_instance_valid(target_line_edit):
		# 关闭时把焦点还给输入框
		target_line_edit.grab_focus()
		target_line_edit = null

func _on_char_pressed(char_str: String):
	if not target_line_edit or not is_instance_valid(target_line_edit):
		return
	# 移除了 grab_focus，不需要让输入框抢走焦点
	var pos = target_line_edit.caret_column
	target_line_edit.text = target_line_edit.text.insert(pos, char_str)
	target_line_edit.caret_column = pos + char_str.length()
	target_line_edit.text_changed.emit()
	if _mode == 1: # 大写状态下输入后自动切回小写
		_mode = 0
		# 重建会自动恢复当前焦点
		refresh_layout()

func _on_backspace_pressed():
	if not target_line_edit or not is_instance_valid(target_line_edit):
		return
	# 移除了 grab_focus
	var pos = target_line_edit.caret_column
	if pos > 0:
		target_line_edit.text = target_line_edit.text.erase(pos - 1, 1)
		target_line_edit.caret_column = pos - 1
		target_line_edit.text_changed.emit()

func _on_shift_pressed():
	_mode = 1 if _mode == 0 else 0
	refresh_layout()

func _on_sym_pressed():
	_mode = 2 # 默认进入符号布局
	refresh_layout()

func _on_abc_pressed():
	_mode = 0 # 回到小写字母
	refresh_layout()

func _on_number_sym_toggle_pressed():
	# 在符号(2)和数字(3)布局间切换
	_mode = 3 if _mode == 2 else 2
	refresh_layout()

func _on_enter_pressed():
	if not target_line_edit or not is_instance_valid(target_line_edit):
		return
	target_line_edit.text_submitted.emit(target_line_edit.text)
	close()
