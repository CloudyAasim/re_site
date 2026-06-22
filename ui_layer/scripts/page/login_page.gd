extends Node # 引入场景 # LoginPageUI

@export var tip_label : Label
@export var username_input : LineEdit # UsernameInput
@export var password_input : LineEdit # PasswordInput
@export var sign_in_button : Button # SignInButton
# 在编辑器右侧的 Inspector 面板中，把你的第一个按钮拖到这里
@export var initial_focus_button: LineEdit
@export var unlogin_setting_button: Button
@export var quit_button : Button # QuitButton
# ⭐ 新增：绑定用于显示错误提示的 Label
@export var error_label: Label 
@export var server_line_edit : LineEdit
@export var server_button : Button

var _error_seq: int = 0 # ⭐ 用于防抖的序列号，确保只有最后一次定时的清除生效

# 当节点首次进入场景树时调用。
func _ready() -> void:
	SettingManager.locale_changed.connect(_on_locale_changed)
	_on_locale_changed()
	
	# 初始化时隐藏错误提示
	if error_label:
		error_label.modulate.a = 0.0
		error_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	server_line_edit.text = Network.BASE_URL
	
	# 延迟一帧确保界面完全就绪，然后让第一个按钮获取焦点
	if initial_focus_button:
		await get_tree().process_frame
		initial_focus_button.grab_focus()

# 更新语言
func _on_locale_changed():
	tip_label.text = tr("LABEL_TIP")
	username_input.placeholder_text = tr("LINEEDIT_USERNAME")
	password_input.placeholder_text = tr("LINEEDIT_PASSWD")
	sign_in_button.text = tr("BTN_SIGN_IN")
	unlogin_setting_button.text = tr("BTN_HOME_SETTING")
	quit_button.text = tr("BTN_HOME_QUIT")
	server_line_edit.placeholder_text = tr("LINEEDIT_SERVER")
	server_button.text = tr("BTU_SERVER")
	
	# 刷新错误提示的语言（如果正在显示错误）
	if error_label and error_label.visible and error_label.has_meta("error_key"):
		error_label.text = tr(error_label.get_meta("error_key"))

# 当 SignInButton 停止按下时
func _on_sign_in_button_button_up() -> void:
	_clear_error() # 点击登录时，先清除之前的错误
	
	_show_error("ERROR_LEADING")
	
	var result = await Network.user_login(username_input.text, password_input.text)
	if not is_inside_tree(): return
	
	if result[0]:
		# 登录成功
		_clear_error() # 确保清除错误
		print("登陆界面：登录成功")
		UISignal.switch_page_requested.emit("res://ui_layer/scenes/page/home_page.tscn")
	else:
		# 登录失败
		print("登陆界面：登录失败")
		var status_code = result[1]
		
		# ⭐ 核心判断：401 代表账密错误，其他一律提示网络问题
		if status_code == 401:
			_show_error("ERROR_LOGIN_FAILED")
		else:
			_show_error("ERROR_NETWORK_OR_NOT_FOUND")

# 按下（未登录界面）设置按钮时
func _on_unlogin_setting_button_pressed() -> void:
	UISignal.switch_page_requested.emit("res://ui_layer/scenes/page/unlogin_setting_page.tscn")

# 按下退出按钮
func _on_quit_button_pressed() -> void:
	get_tree().quit()

# 账号栏按下确认键聚焦于密码栏
func _on_username_input_text_submitted(new_text: String) -> void:
	UiNavigator.focus_control(password_input)

# 密码栏按下确认键调用按下登陆按钮
func _on_password_input_text_submitted(new_text: String) -> void:
	_on_sign_in_button_button_up()

# 更换服务器地址时
func _on_server_button_pressed() -> void:
	Network.BASE_URL = server_line_edit.text

# ================= 错误提示辅助方法 =================
func _show_error(error_key: String):
	error_label.text = tr(error_key)
	# 存储当前的 key，方便切换语言时刷新
	error_label.set_meta("error_key", error_key) 
	
	error_label.modulate.a = 1.0
	error_label.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# ⭐ 核心防抖逻辑：递增序列号，使之前的定时器失效
	_error_seq += 1
	var current_seq = _error_seq
	
	# 等待 5 秒
	await get_tree().create_timer(5.0).timeout
	
	# 只有当序列号没变（即这5秒内没有新的错误触发），才清除
	if _error_seq == current_seq:
		_clear_error()

# 立即清除错误
func _clear_error():
	if not error_label:
		return
	_error_seq += 1 # ⭐ 取消正在排队的定时器
	error_label.text = ""
	
	error_label.modulate.a = 0.0
	error_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if error_label.has_meta("error_key"):
		error_label.remove_meta("error_key")
