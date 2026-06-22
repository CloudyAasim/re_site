extends Button

func _ready() -> void:
	SettingManager.locale_changed.connect(_on_locale_changed)
	_on_locale_changed()
	
	# 读取 UiNavigator 的状态（它已经在 SettingManager 初始化时被赋过值了）
	button_pressed = UiNavigator.virtual_keyboard_enabled
	
	# 连接点击信号
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func _on_locale_changed():
	text = tr("CHECK_BTN_VIRTUAL_KEYBROAD")

func _on_pressed() -> void:
	# 1. 更新实际控制键盘开关的全局状态
	UiNavigator.virtual_keyboard_enabled = button_pressed
	
	# 2. 持久化保存到本地配置文件
	ConfigManager.set_value("virtual_keyboard", button_pressed)
