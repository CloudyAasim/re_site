extends OptionButton

func _ready():
	# 1. 连接选项切换信号
	item_selected.connect(_on_item_selected)
	
	# 2. 监听语言变化信号（处理从其他地方触发语言改变的情况，保持状态同步）
	SettingManager.locale_changed.connect(_on_locale_changed)
	
	# 3. 动态生成下拉选项
	_populate_options()
	
	# 4. 初始化当前选中项
	_select_current_locale()

# 生成语言选项
func _populate_options():
	clear()
	
	# 获取软件当前支持的所有语言代码（如 ["zh", "en"]）
	var supported_locales = TranslationServer.get_loaded_locales()
	
	for locale_code in supported_locales:
		# 将语言代码转换为友好的显示名称
		var display_name = _get_display_name(locale_code)
		
		# 添加选项到下拉框
		add_item(display_name)
		
		# 关键：将真实的语言代码存入元数据，方便点击时直接获取
		set_item_metadata(item_count - 1, locale_code)


# 根据语言代码返回友好的显示文本
func _get_display_name(locale_code: String) -> String:
	match locale_code:
		"zh": return "中文"
		"en": return "English"
		# 如果有其他语言可以在这里扩展
		_: return locale_code # 未知语言直接显示代码


# 当用户点击下拉框选中某个选项时触发
func _on_item_selected(index: int):
	# 取出存入的语言代码元数据
	var selected_locale = get_item_metadata(index)
	if selected_locale:
		# 调用 LocaleManager 切换语言
		SettingManager.set_locale(selected_locale)


# 当语言发生变化时（比如代码其他地方调用了 set_locale），同步更新下拉框的选中状态
func _on_locale_changed():
	_select_current_locale()


# 将下拉框的选中项与当前语言状态同步
func _select_current_locale():
	var current = SettingManager.current_locale
	for i in range(item_count):
		if get_item_metadata(i) == current:
			selected = i
			return
			
	# 如果遍历完没找到（可能是不支持的语言），默认选第一项
	if item_count > 0:
		selected = 0
