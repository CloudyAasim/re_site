extends Node

# 记录当前应用使用的是什么语言，默认是中文
var current_locale: String = "zh"

# 【新增】画布模式状态
var use_canvas_mode: bool = false

# 核心信号！当语言切换成功后，发出这个信号，所有监听了它的 UI 组件就会刷新文案
signal locale_changed()

# 【新增】画布模式切换信号
signal canvas_mode_changed(enabled: bool)

func _ready() -> void:
	# 直接同步初始化，ConfigManager 的安全锁会保证读取成功
	_init_settings()

# 统一加载所有已保存的配置
func _init_settings():
	print("SettingManager: 正在加载所有本地配置...")
	# 1. 加载语言配置
	var saved_locale = ConfigManager.get_value("locale", "zh")
	set_locale(saved_locale)
	
	# 2. 加载虚拟键盘配置，并同步给负责实际控制的 UiNavigator
	var vk_enabled = ConfigManager.get_value("virtual_keyboard", false)
	if UiNavigator: # 确保单例存在
		UiNavigator.virtual_keyboard_enabled = vk_enabled
		
	# 3. 【新增】加载画布模式配置
	var saved_canvas_mode = ConfigManager.get_value("use_canvas_mode", false)
	set_canvas_mode(saved_canvas_mode)

# 核心方法：切换语言
func set_locale(locale_code: String) -> void:
	if current_locale == locale_code:
		return
	current_locale = locale_code
	TranslationServer.set_locale(locale_code)
	ConfigManager.set_value("locale", locale_code)
	locale_changed.emit()

# 【新增】设置画布模式的方法
func set_canvas_mode(enabled: bool) -> void:
	if use_canvas_mode == enabled:
		return
	use_canvas_mode = enabled
	# 保存到本地配置
	ConfigManager.set_value("use_canvas_mode", enabled)
	# 发出信号，通知相关页面更新
	canvas_mode_changed.emit(enabled)
