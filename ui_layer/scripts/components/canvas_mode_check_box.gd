extends CheckButton

func _ready() -> void:
	# 1. 监听全局设置变化（防止其他地方修改导致 UI 不同步）
	SettingManager.canvas_mode_changed.connect(_on_global_canvas_mode_changed)
	SettingManager.locale_changed.connect(_on_locale_changed)
	
	# 2. 初始化本地 UI 状态
	set_pressed_no_signal(SettingManager.use_canvas_mode)
	
	# 3. 连接自身的点击事件
	pressed.connect(_on_pressed)
	
	# 4. 初始化文本
	_update_text()

func _on_pressed() -> void:
	# 点击时，把当前按钮状态同步给全局管理器
	SettingManager.set_canvas_mode(button_pressed)

func _on_global_canvas_mode_changed(enabled: bool) -> void:
	# 全局状态改变时，更新 UI 状态（不触发 pressed 信号）
	set_pressed_no_signal(enabled)

func _on_locale_changed() -> void:
	_update_text()

func _update_text() -> void:
	# 你需要在翻译文件中添加 "SETTING_USE_CANVAS_MODE" 这个键
	text = tr("CHECK_BTN_CANVAS_MODE")
