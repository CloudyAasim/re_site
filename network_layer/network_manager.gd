extends Node 

# ================= 认证信息 ================= 
var auth_token: String = "" 

# ================= 配置 ================= 
# 【修改】将 BASE_URL 改为带 setter/getter 的属性，以实现自动保存
var _base_url: String = ""
var BASE_URL: String:
	get:
		return _base_url
	set(value):
		if _base_url != value and value != "":
			_base_url = value
			# 自动保存到本地配置文件中
			ConfigManager.set_value("base_url", value)

const MAX_POOL_SIZE: int = 5 # 允许同时并发的最大请求数 

# ================= 核心数据结构 ================= 
# 内部类：请求任务，用于承载唤醒协程的信号 
class RequestTask: 
	extends RefCounted 
	signal completed(result_array) 
	var request_key: String = "" 

# 空闲的 HTTP 节点池 
var _idle_pool: Array[HTTPRequest] = [] 
# 正在飞行的任务字典 { "请求指纹": RequestTask实例 } 
var _flying_tasks: Dictionary = {} 

func _ready() -> void: 
	# 【新增】启动时从本地配置加载服务器地址
	var saved_url = ConfigManager.get_value("base_url", "")
	if saved_url != "":
		_base_url = saved_url # 直接赋值给内部变量，避免触发重复保存
		
	# 初始化节点池 
	for i in MAX_POOL_SIZE: 
		var http = HTTPRequest.new() 
		http.timeout = 15.0 # 设置超时，避免协程永远挂起 
		add_child(http) 
		_idle_pool.append(http) 

# ================================================== 
# 核心引擎：发送请求、去重、协程调度 
# ================================================== 
func _send_request(url_path: String, params: Dictionary, method: int, body: Dictionary = {}, require_auth: bool = true) -> Array: 
	# 1. 拼接完整 URL (处理 GET 请求的 Query 参数) 
	var full_url = BASE_URL + url_path 
	if method == HTTPClient.METHOD_GET and not params.is_empty(): 
		var query_parts = [] 
		for key in params.keys(): 
			query_parts.append(str(key) + "=" + str(params[key]).uri_encode()) 
		full_url += "?" + "&".join(query_parts) 
		
	# 2. 生成请求指纹 
	var key = _make_request_key(url_path, params, body) 
	
	# 3. 去重拦截 
	if _flying_tasks.has(key): 
		return await _flying_tasks[key].completed 
		
	# 4. 没有重复，从池子取节点 
	if _idle_pool.is_empty(): 
		push_error("网络请求池已满，丢弃请求: " + url_path) 
		return [false, 0, {}] 
		
	var http_node: HTTPRequest = _idle_pool.pop_front() 
	
	# 5. 创建任务 
	var task = RequestTask.new() 
	task.request_key = key 
	_flying_tasks[key] = task 
	
	# 6. 准备请求头和请求体 
	var headers = ["Content-Type: application/json"] 
	if require_auth and auth_token != "": 
		headers.append("Authorization: Bearer " + auth_token) 
		
	var json_body = "" 
	if method != HTTPClient.METHOD_GET and not body.is_empty(): 
		json_body = JSON.stringify(body) 
		
	print("⚡ 网络请求发出: URL=", full_url, " | Body: ", json_body) 
	
	# 7. 绑定信号 
	if http_node.request_completed.is_connected(_on_request_completed): 
		http_node.request_completed.disconnect(_on_request_completed) 
	http_node.request_completed.connect(_on_request_completed.bind(task, http_node)) 
	
	# 8. 发起真实请求 
	var err = http_node.request(full_url, headers, method, json_body) 
	if err != OK: 
		_cleanup_task(task, http_node) 
		return [false, 0, {}] 
		
	# 9. 挂起协程，等待网络回调唤醒 
	return await task.completed 

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, task: RequestTask, http_node: HTTPRequest) -> void: 
	_cleanup_task(task, http_node) 
	if result != HTTPRequest.RESULT_SUCCESS: 
		task.completed.emit([false, response_code, {}]) 
		return 
		
	var body_str = body.get_string_from_utf8() 
	var json_data = null 
	if body_str != "": 
		var json = JSON.new() 
		if json.parse(body_str) == OK: 
			json_data = json.data 
			
	var is_success = (response_code == 200 or response_code == 201) 
	if not is_success: 
		print("❌ 请求失败: 状态码=", response_code, " | 后端返回内容: ", body_str) 
		task.completed.emit([false, response_code, json_data if json_data != null else {}]) 
		return 
		
	# ========= 专门处理 201 Created，极度详细的调试 ========= 
	if response_code == 201: 
		print("\n========== 🔍 调试 201 响应 🔍 ==========") 
		print("1. 原始 Headers (共 ", _headers.size(), " 个):") 
		for h in _headers: 
			print(" -> ", h) 
		print("\n2. 原始 Body 文本 (长度 ", body_str.length(), "):") 
		print(" [", body_str, "]") 
		print("\n3. JSON 解析结果:") 
		if json_data != null: 
			print(" 成功解析: ", json_data) 
		else: 
			print(" ❌ 解析失败！后端可能返回的不是标准 JSON。") 
		print("=========================================\n") 
		
	if json_data == null: 
		json_data = {} 
		
	if json_data is Dictionary: 
		var location_id = "" 
		# 1. 尝试从 Location 头取 ID 
		for h in _headers: 
			var lower_h = h.to_lower() 
			if lower_h.begins_with("location:"): 
				var location_value = h.substr(h.find(":") + 1).strip_edges() 
				var parts = location_value.split("/") 
				if not parts.is_empty(): 
					location_id = parts[-1] 
				break 
				
		# 2. 如果 Location 没拿到，再从 body 里找 "id" 或 "reservation_id" 
		if location_id == "": 
			if json_data.has("id"): 
				location_id = str(json_data["id"]) 
			elif json_data.has("reservation_id"): 
				location_id = str(json_data["reservation_id"]) 
				
		# 3. 把 ID 统一塞进 json_data["id"] 
		if location_id != "": 
			json_data["id"] = location_id 
			print("📌 成功提取到预约ID: ", location_id) 
		else: 
			print("⚠️ 未能提取到预约ID，请查看上方的 [原始 Headers] 和 [原始 Body 文本]！") 
			
	task.completed.emit([true, response_code, json_data if json_data != null else {}]) 

# 辅助清理函数 
func _cleanup_task(task: RequestTask, http_node: HTTPRequest) -> void: 
	_flying_tasks.erase(task.request_key) 
	if http_node.request_completed.is_connected(_on_request_completed): 
		http_node.request_completed.disconnect(_on_request_completed) 
	_idle_pool.append(http_node) 

# 生成请求指纹 
func _make_request_key(url_path: String, params: Dictionary, body: Dictionary) -> String: 
	var keys = params.keys() 
	keys.sort() 
	var p_str = "" 
	for k in keys: 
		p_str += str(k) + "=" + str(params[k]) + "&" 
		
	var b_keys = body.keys() 
	b_keys.sort() 
	var b_str = "" 
	for k in b_keys: 
		b_str += str(k) + "=" + str(body[k]) + "&" 
		
	return url_path + "?" + p_str + "#" + b_str 

# ================================================== 
# 业务 API 封装 
# ================================================== 

## 用户登录 
func user_login(username: String, password: String) -> Array: 
	var body = { "username": username, "password": password } 
	var res = await _send_request("/auth/login", {}, HTTPClient.METHOD_POST, body, false) 
	if res[0] == true and res[2] is Dictionary and res[2].has("token"): 
		auth_token = res[2]["token"] 
	return res 

## 获取楼层列表 
func get_floors() -> Array: 
	return await _send_request("/floors", {}, HTTPClient.METHOD_GET) 

## 获取楼层布局 
func get_floor_layout(floor_id: String) -> Array: 
	var path = "/floors/" + floor_id + "/layout" 
	return await _send_request(path, {}, HTTPClient.METHOD_GET) 

## 获取时段定义 
func get_slots() -> Array: 
	return await _send_request("/slots", {}, HTTPClient.METHOD_GET) 

## 查询楼层座位占用总览 
func get_floor_availability(floor_id: String, date: String, have_slot_id: bool, slot_id: String) -> Array: 
	var path = "/floors/" + floor_id + "/availability" 
	var params = {} 
	if date != "": 
		params["date"] = date 
	if have_slot_id and slot_id != "": 
		params["slot_id"] = slot_id 
	return await _send_request(path, params, HTTPClient.METHOD_GET) 

## 查询单个座位占用详情 
func get_seat_availability(seat_id: String, date: String) -> Array: 
	var path = "/seats/" + seat_id + "/availability" 
	var params = {} 
	if date != "": 
		params["date"] = date 
	return await _send_request(path, params, HTTPClient.METHOD_GET) 

## 发起预约 
func post_reservations(seat_id: String, date: String, slot_id: String) -> Array: 
	var body = { "seat_id": seat_id, "date": date, "slot_id": slot_id } 
	return await _send_request("/reservations", {}, HTTPClient.METHOD_POST, body) 

## 我的预约列表 
func get_reservations_me(have_status: bool = false, status: String = "") -> Array: 
	var params = {} 
	if have_status and status != "": 
		params["status"] = status 
	return await _send_request("/reservations/me", params, HTTPClient.METHOD_GET) 

## 状态流转操作 (签到/暂离/返回/结束/取消) 
func state_transition(transition_id: int, id: String, certificate: String = "") -> Array: 
	var path = "" 
	var body = {} 
	match transition_id: 
		1: # 签到 
			path = "/reservations/" + id + "/check-in" 
			body = { "certificate": certificate if certificate != "" else "placeholder" } 
		2: # 暂离 
			path = "/reservations/" + id + "/suspend" 
		3: # 暂离返回 (重新签到) 
			path = "/reservations/" + id + "/check-in" 
			body = { "certificate": certificate if certificate != "" else "placeholder" } 
		4: # 结束使用 
			path = "/reservations/" + id + "/finish" 
		5: # 取消预约 
			path = "/reservations/" + id + "/cancel" 
		_: 
			return [false, 0, {}] 
	return await _send_request(path, {}, HTTPClient.METHOD_POST, body) 

## 获取个人资料 
func get_user_profile() -> Array: 
	return await _send_request("/user/profile", {}, HTTPClient.METHOD_GET)
