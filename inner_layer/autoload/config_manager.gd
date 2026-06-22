extends Node

# 常量：定义配置文件的保存路径。user:// 是 Godot 的虚拟路径，会自动映射到系统的 AppData 等安全目录
const SAVE_PATH = "user://app_settings.cfg"

# 实例化一个 ConfigFile 对象，它就像一个内存中的字典，用来暂存数据
var config = ConfigFile.new()
# 记录是否已经成功从硬盘加载过配置
var is_loaded: bool = false

func _ready():
	# 启动时尝试加载
	_load_config()

# 确保配置已加载（防止其他单例在 ConfigManager 之前调用）
func _load_config():
	if is_loaded:
		return
		
	if FileAccess.file_exists(SAVE_PATH):
		config.load(SAVE_PATH)
		
	is_loaded = true

# 获取配置的通用方法
# key: 比如叫 "locale" 或 "virtual_keyboard"
# default_value: 如果没找到这个 key，返回什么默认值
func get_value(key: String, default_value):
	_load_config() # 每次获取前确保已加载
	return config.get_value("settings", key, default_value)

# 保存配置的通用方法
func set_value(key: String, value):
	_load_config() # 设置前确保已加载
	# 把值写入内存的 config 对象中（分类为 "settings"）
	config.set_value("settings", key, value)
	# 将内存中的 config 数据真正写入硬盘
	config.save(SAVE_PATH)
