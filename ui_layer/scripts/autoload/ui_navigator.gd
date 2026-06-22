extends Node

## 按住方向键/摇杆时，每次移动的间隔时间（秒）
@export_range(0.05, 0.5) var navigation_delay: float = 0.15

## 接口：是否允许弹出自制虚拟键盘。外部修改此变量时会自动同步状态。
var virtual_keyboard_enabled: bool = false:
	set(value):
		if virtual_keyboard_enabled == value:
			return
		virtual_keyboard_enabled = value
		# 状态改变时，更新所有已存在的 LineEdit
		_apply_vkb_state_to_all_line_edits()

var _nav_timer: float = 0.0
var _last_nav_action: String = ""

## 当前打开的模态弹窗引用
var current_modal: Control = null
## 打开弹窗前拥有焦点的节点
var previous_focus: Control = null
## 当前弹窗绑定的返回键动作
var _current_modal_back_action: Callable = Callable()

## 焦点丢失时缓存的可聚焦节点
var _auto_focus_candidate: Control = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 监听节点添加，解决场景切换后新 LineEdit 无法弹键盘的问题
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_setup_focus_modes")

# ==========================================================
# 初始化与动态绑定：强制修复焦点模式
# ==========================================================
func _on_node_added(node: Node):
	if node is LineEdit:
		_setup_line_edit(node)
	if node is ItemList or node is OptionButton or node is BaseButton:
		node.focus_mode = Control.FOCUS_ALL

func _setup_focus_modes():
	_setup_focus_mode_recursive(get_tree().root)

func _setup_focus_mode_recursive(node: Node):
	if node is ItemList or node is OptionButton or node is BaseButton:
		node.focus_mode = Control.FOCUS_ALL
	if node is LineEdit:
		_setup_line_edit(node)
	for child in node.get_children():
		_setup_focus_mode_recursive(child)

func _setup_line_edit(line_edit: LineEdit):
	line_edit.focus_mode = Control.FOCUS_ALL
	# 不再强制设为 false，而是根据当前全局设置来决定
	_update_line_edit_vkb_state(line_edit)
	if not line_edit.gui_input.is_connected(_on_line_edit_gui_input):
		line_edit.gui_input.connect(_on_line_edit_gui_input.bind(line_edit))

# 新增：更新单个 LineEdit 的原生键盘状态
func _update_line_edit_vkb_state(line_edit: LineEdit):
	# 如果开启自制键盘，就关闭系统键盘；如果关闭自制键盘，就允许系统键盘
	line_edit.virtual_keyboard_enabled = not virtual_keyboard_enabled

# 新增：遍历更新所有 LineEdit 的状态
func _apply_vkb_state_to_all_line_edits():
	_apply_vkb_state_recursive(get_tree().root)

func _apply_vkb_state_recursive(node: Node):
	if node is LineEdit:
		_update_line_edit_vkb_state(node)
	for child in node.get_children():
		_apply_vkb_state_recursive(child)

# ==========================================================
# 弹窗管理
# ==========================================================
func _is_modal_active() -> bool:
	return current_modal != null and current_modal.visible

func show_modal(popup: Control, on_back: Callable = Callable()):
	previous_focus = get_viewport().gui_get_focus_owner()
	current_modal = popup
	_current_modal_back_action = on_back
	popup.visible = true
	_grab_focus_in_modal()

func hide_modal(popup: Control):
	if popup == current_modal:
		popup.visible = false
		current_modal = null
		_current_modal_back_action = Callable()
		if previous_focus and is_instance_valid(previous_focus) and previous_focus.visible:
			previous_focus.grab_focus()
		previous_focus = null

func _grab_focus_in_modal():
	if not current_modal or not current_modal.visible:
		return
	var focus_owner = get_viewport().gui_get_focus_owner()
	if not focus_owner or not current_modal.is_ancestor_of(focus_owner):
		var target = _find_first_focusable(current_modal)
		if target:
			target.grab_focus()

# ==========================================================
# 焦点丢失自动恢复
# ==========================================================
func _find_first_focusable(node: Node) -> Control:
	if node is Control:
		if node.focus_mode == Control.FOCUS_ALL and node.visible:
			return node
	for child in node.get_children():
		var result = _find_first_focusable(child)
		if result:
			return result
	return null

func _handle_focus_lost():
	if _is_modal_active() and current_modal:
		_grab_focus_in_modal()
		return
		
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down") or Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right") or Input.is_action_pressed("ui_accept"):
		if not _auto_focus_candidate or not is_instance_valid(_auto_focus_candidate) or not _auto_focus_candidate.visible:
			_auto_focus_candidate = _find_first_focusable(get_tree().root)
		if _auto_focus_candidate:
			_auto_focus_candidate.grab_focus()

# ==========================================================
# 输入拦截核心逻辑
# ==========================================================
func _input(event: InputEvent):
	var focus_owner = get_viewport().gui_get_focus_owner()
	if not focus_owner:
		return

	# ================= 虚拟键盘焦点处理 =================
	if VirtualKeyboard.visible and VirtualKeyboard.is_focus_inside(focus_owner):
		# 如果是鼠标/触摸事件，直接放行，交给 Godot GUI 系统处理按钮点击
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			return
			
		# 处理关闭键盘
		if event.is_action("ui_cancel") and event.is_pressed() and not event.is_echo():
			VirtualKeyboard.close()
			get_viewport().set_input_as_handled()
			return

		# 拦截方向键，交由 _process 中的节流导航处理
		if event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("ui_left") or event.is_action("ui_right"):
			get_viewport().set_input_as_handled()
			return

		# ui_accept 不拦截，让 Godot 自动触发按钮的 pressed 信号
		return

	# ================= 处理返回键 =================
	if event.is_action("ui_cancel") and event.is_pressed() and not event.is_echo():
		if VirtualKeyboard.visible:
			VirtualKeyboard.close()
			get_viewport().set_input_as_handled()
			return
		if focus_owner is OptionButton:
			var popup = focus_owner.get_popup()
			if popup and popup.visible:
				return
		if _is_modal_active() and current_modal:
			get_viewport().set_input_as_handled()
			if _current_modal_back_action.is_valid():
				_current_modal_back_action.call()
			else:
				hide_modal(current_modal)
			return

	# ================= 1. OptionButton 下拉菜单特殊处理 =================
	if focus_owner is OptionButton:
		var popup = focus_owner.get_popup()
		if popup and popup.visible:
			if event.is_action("ui_up") or event.is_action("ui_down"):
				get_viewport().set_input_as_handled()
				if event.is_pressed() and not event.is_echo():
					var dir = -1 if event.is_action("ui_up") else 1
					_navigate_option_popup(popup, dir)
				return
			if event.is_action("ui_left") or event.is_action("ui_right"):
				get_viewport().set_input_as_handled()
				return
		else:
			if event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("ui_left") or event.is_action("ui_right"):
				get_viewport().set_input_as_handled()
				return

	# ================= 2. LineEdit 处理 =================
	elif focus_owner is LineEdit:
		if event.is_action("ui_left") or event.is_action("ui_right"):
			return
		if event.is_action("ui_up") or event.is_action("ui_down"):
			get_viewport().set_input_as_handled()
			return
		# 如果是回车键
		if event.is_action("ui_accept") and event.is_pressed() and not event.is_echo():
			# 如果开启了自制虚拟键盘，并且键盘当前未显示
			if virtual_keyboard_enabled and not VirtualKeyboard.visible:
				# 拦截按键，阻止 LineEdit 的 text_submitted 信号
				get_viewport().set_input_as_handled()
				# 弹出自制虚拟键盘
				VirtualKeyboard.open(focus_owner)
				return
			# 如果没开启自制键盘，或者键盘已经显示了，不拦截，继续走原来的流程
			return

	# ================= 3. 常规控件拦截 =================
	elif event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("ui_left") or event.is_action("ui_right"):
		get_viewport().set_input_as_handled()
		return

	# 处理通用确认键
	if event.is_action("ui_accept") and event.is_pressed() and not event.is_echo():
		if focus_owner is ItemList:
			get_viewport().set_input_as_handled()
			var selected = focus_owner.get_selected_items()
			if selected.size() > 0:
				focus_owner.item_activated.emit(selected[0])
			return

# ==========================================================
# LineEdit 点击拦截
# ==========================================================
func _on_line_edit_gui_input(event: InputEvent, line_edit: LineEdit):
	# 如果全局禁用了自制虚拟键盘，直接返回，让安卓系统输入法接管
	if not virtual_keyboard_enabled:
		return
		
	var is_tap = false
	if event is InputEventMouseButton and event.pressed:
		is_tap = true
	elif event is InputEventScreenTouch and event.pressed:
		is_tap = true
		
	if is_tap:
		if not line_edit.has_focus():
			line_edit.grab_focus()
		VirtualKeyboard.open(line_edit)

# ==========================================================
# 焦点轮询与节流移动
# ==========================================================
func _process(delta):
	var focus_owner = get_viewport().gui_get_focus_owner()
	
	# ================= 虚拟键盘焦点保护 =================
	if VirtualKeyboard.visible:
		# 获取当前鼠标是否按下，如果按下则不抢夺焦点，避免打断按钮的点击操作
		var is_mouse_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		
		# 如果焦点不在键盘内，且没有正在用鼠标点击，才强行拉回
		if not VirtualKeyboard.is_focus_inside(focus_owner) and not is_mouse_pressed:
			VirtualKeyboard.grab_default_focus()
			focus_owner = VirtualKeyboard.hide_btn # 更新当前焦点引用以便下方逻辑运行

	# ==============================================================
	if not focus_owner:
		if not VirtualKeyboard.visible:
			_handle_focus_lost()
		_last_nav_action = ""
		_nav_timer = 0.0
		return

	# 如果键盘可见，跳过底层的弹窗焦点越界拦截
	if not VirtualKeyboard.visible:
		if _is_modal_active() and current_modal and not current_modal.is_ancestor_of(focus_owner):
			_grab_focus_in_modal()
			_last_nav_action = ""
			_nav_timer = 0.0
			return

	if focus_owner is OptionButton:
		var popup = focus_owner.get_popup()
		if popup and popup.visible:
			_last_nav_action = ""
			_nav_timer = 0.0
			return

	if focus_owner is ItemList:
		if focus_owner.get_selected_items().is_empty() and focus_owner.item_count > 0:
			focus_owner.select(0, true)

	var current_action = ""
	var nav_actions = ["ui_up", "ui_down", "ui_left", "ui_right"]
	for action in nav_actions:
		if Input.is_action_pressed(action):
			current_action = action
			break

	if current_action == "":
		_last_nav_action = ""
		_nav_timer = 0.0
		return

	if current_action != _last_nav_action:
		_last_nav_action = current_action
		_nav_timer = 0.0
		_execute_navigation(focus_owner, current_action)
	else:
		_nav_timer += delta
		if _nav_timer >= navigation_delay:
			_nav_timer -= navigation_delay
			_execute_navigation(focus_owner, current_action)

# ==========================================================
# 导航执行逻辑
# ==========================================================
func _execute_navigation(focus_owner: Control, action: String):
	if focus_owner is LineEdit:
		if action == "ui_left" or action == "ui_right":
			return

	# 虚拟键盘内部的左右导航特殊处理，强制在同一行(兄弟节点)移动，防止焦点跨行跳跃
	if VirtualKeyboard.visible and VirtualKeyboard.is_focus_inside(focus_owner):
		if action == "ui_left" or action == "ui_right":
			if _navigate_keyboard_row(focus_owner, action):
				return

	if focus_owner is ItemList:
		if _navigate_item_list(focus_owner, action):
			return

	if focus_owner is Tree:
		if _navigate_tree(focus_owner, action):
			return

	var neighbor = _find_neighbor(focus_owner, action)
	if neighbor:
		# 如果在键盘内移动，且目标在键盘外，拒绝移动 (防越界)
		if VirtualKeyboard.visible and VirtualKeyboard.is_focus_inside(focus_owner) and not VirtualKeyboard.is_focus_inside(neighbor):
			return
		# 模态弹窗防越界
		if _is_modal_active() and current_modal and not current_modal.is_ancestor_of(neighbor):
			return
		neighbor.grab_focus()

# 新增：虚拟键盘同一行内的导航控制
func _navigate_keyboard_row(control: Control, action: String) -> bool:
	var parent = control.get_parent()
	if not parent is HBoxContainer:
		return false

	var dir = -1 if action == "ui_left" else 1
	var idx = control.get_index()
	var new_idx = idx + dir

	# 到达行首或行尾，拦截移动并停住，不允许跑到上一行或下一行
	if new_idx < 0 or new_idx >= parent.get_child_count():
		return true

	var next_control = parent.get_child(new_idx)
	if next_control is Control and next_control.focus_mode != Control.FOCUS_NONE:
		next_control.grab_focus()
		return true
		
	return false


# ==========================================================
# 辅助导航函数
# ==========================================================
func _navigate_option_popup(popup: PopupMenu, dir: int):
	var current = popup.current_selected
	var new_idx = current + dir
	if new_idx < 0:
		new_idx = 0
	if new_idx >= popup.item_count:
		new_idx = popup.item_count - 1
	if new_idx != current:
		popup.select(new_idx)

func _navigate_item_list(list: ItemList, action: String) -> bool:
	if action == "ui_left" or action == "ui_right":
		return false
	var dir = 0
	if action == "ui_up":
		dir = -1
	elif action == "ui_down":
		dir = 1
	else:
		return false

	var current = list.get_selected_items()
	var current_idx = -1
	if current.size() > 0:
		current_idx = current[0]
	else:
		if list.item_count > 0:
			list.select(0, true)
			list.ensure_current_is_visible()
			return true

	var new_idx = current_idx + dir
	if new_idx < 0 or new_idx >= list.item_count:
		return false

	list.deselect_all()
	list.select(new_idx, true)
	list.ensure_current_is_visible()
	return true

func _navigate_tree(tree: Tree, action: String) -> bool:
	var dir = 0
	if action == "ui_up":
		dir = -1
	elif action == "ui_down":
		dir = 1
	else:
		return false

	var selected = tree.get_selected()
	if not selected:
		var root = tree.get_root()
		if root and root.get_child_count() > 0:
			root.get_child(0).select(0)
			tree.ensure_cursor_is_visible()
			return true
		return false

	var parent = selected.get_parent()
	if not parent:
		return false
	var idx = selected.get_index()
	var new_idx = idx + dir
	if new_idx < 0 or new_idx >= parent.get_child_count():
		return false
	parent.get_child(new_idx).select(0)
	tree.ensure_cursor_is_visible()
	return true

func _find_neighbor(control: Control, action: String) -> Control:
	match action:
		"ui_up":
			return control.find_valid_focus_neighbor(SIDE_TOP)
		"ui_down":
			return control.find_valid_focus_neighbor(SIDE_BOTTOM)
		"ui_left":
			return control.find_valid_focus_neighbor(SIDE_LEFT)
		"ui_right":
			return control.find_valid_focus_neighbor(SIDE_RIGHT)
	return null

## 外部调用：安全地聚焦一个控件
func focus_control(control: Control):
	if not control:
		return
	control.grab_focus()
