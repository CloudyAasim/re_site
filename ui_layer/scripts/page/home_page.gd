extends Node

# ⭐ 用枚举表示“要聚焦哪个按钮”，比字符串更安全
enum FocusTarget {
	SEAT,      # 座位
	INFORMATION,   # 个人信息
	SETTING,   # 设置
	SIGNOUT,   # 退出登录
	QUIT,      # 退出
}

# ⭐ 静态变量：跨场景记住“回去后要聚焦哪个按钮”
static var next_focus_target: FocusTarget = FocusTarget.SEAT

@export var seat_button : Button
@export var information_button : Button
@export var setting_button : Button
@export var signout_button : Button
@export var quit_button : Button

func _ready() -> void:
	prints("[HomePage _ready] next_focus_target:", next_focus_target)

	# 恢复焦点（根据枚举选择 @export 按钮）
	_restore_focus()

	# 多语言等原有逻辑
	SettingManager.locale_changed.connect(_refresh_text)
	_refresh_text()
	
	DataContext.load_basic_data()

# ⭐ 根据静态变量选择聚焦哪个 @export 按钮
func _restore_focus() -> void:
	prints("[HomePage _restore_focus] next_focus_target:", next_focus_target)

	var target_node: Control = null

	match next_focus_target:
		FocusTarget.SEAT:
			target_node = seat_button
		FocusTarget.INFORMATION:
			target_node = information_button
		FocusTarget.SETTING:
			target_node = setting_button
		FocusTarget.SIGNOUT:
			target_node = signout_button
		FocusTarget.QUIT:
			target_node = quit_button

	# 用完即清，避免下次正常启动时焦点错乱
	next_focus_target = FocusTarget.SEAT

	if target_node:
		prints("[HomePage _restore_focus] 聚焦节点:", target_node.name)
		UiNavigator.focus_control(target_node)
	else:
		# 兜底：如果没匹配到，就聚焦 seat_button
		if seat_button:
			prints("[HomePage _restore_focus] 兜底聚焦 seat_button")
			UiNavigator.focus_control(seat_button)

func _refresh_text():
	seat_button.text = tr("BTN_HOME_SEAT")
	information_button.text = tr("BTN_HOME_INFORMATION")
	setting_button.text = tr("BTN_HOME_SETTING")
	signout_button.text = tr("BTN_HOME_SIGNOUT")
	quit_button.text = tr("BTN_HOME_QUIT")

# ⭐ 每个按钮的 pressed 回调里，顺便设置“回去后要聚焦谁”
func _on_seat_button_pressed() -> void:
	# 记住：下次回到 HomePage 时，聚焦“座位”按钮
	next_focus_target = FocusTarget.SEAT
	prints("[HomePage] _on_seat_button_pressed, 设置 next_focus_target =", next_focus_target)
	UISignal.switch_page_requested.emit("res://ui_layer/scenes/page/seat_page/seat_page.tscn")

func _on_information_button_pressed() -> void:
	next_focus_target = FocusTarget.INFORMATION
	prints("[HomePage] _on_information_button_pressed, 设置 next_focus_target =", next_focus_target)
	UISignal.switch_page_requested.emit("res://ui_layer/scenes/page/information_page.tscn")

func _on_setting_button_pressed() -> void:
	next_focus_target = FocusTarget.SETTING
	prints("[HomePage] _on_setting_button_pressed, 设置 next_focus_target =", next_focus_target)
	UISignal.switch_page_requested.emit("res://ui_layer/scenes/page/setting_page.tscn")

func _on_signout_button_pressed() -> void:
	next_focus_target = FocusTarget.SEAT # 重新聚焦到“座位”按钮
	prints("[HomePage] _on_signout_button_pressed, 设置 next_focus_target =", next_focus_target)
	# 清除登录凭证
	Network.auth_token = ""
	# ⭐ 在这里补充你的退出登录逻辑，比如清除 Token 或跳转场景
	UISignal.switch_page_requested.emit("res://ui_layer/scenes/page/login_page.tscn")

func _on_quit_button_pressed() -> void:
	next_focus_target = FocusTarget.SEAT # 重新聚焦到“座位”按钮
	prints("[HomePage] _on_quit_button_pressed, 设置 next_focus_target =", next_focus_target)
	get_tree().quit()
