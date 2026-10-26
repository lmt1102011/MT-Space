extends Node

signal locale_changed(locale: String)

const LOCALE_FILE := "user://locale.cfg"
var locale: String = "en"

const EN_TO_VI := {
	"PLAY": "CHƠI",
	"SETTINGS": "CÀI ĐẶT",
	"the other players will see this under your ship": "Tên này sẽ hiện bên dưới tàu của bạn",
	"your name": "tên của bạn",
	"NAME ALREADY IN USE": "TÊN ĐÃ ĐƯỢC SỬ DỤNG",
	"choose a different name to join this room": "hãy chọn tên khác để vào phòng",
	"CHANGE NAME": "ĐỔI TÊN",
	"QUIT": "THOÁT",
	"CHECK FOR UPDATE": "KIỂM TRA CẬP NHẬT",
	"NEW VERSION - UPDATE": "CÓ PHIÊN BẢN MỚI - CẬP NHẬT",
	"VOLUME": "ÂM LƯỢNG",
	"LANGUAGE": "NGÔN NGỮ",
	"CLOSE": "ĐÓNG",
	"LOBBY": "SẢNH CHỜ",
	"select a room, or start your own": "chọn phòng hoặc tự tạo phòng",
	"BACK": "QUAY LẠI",
	"+ NEW ROOM": "+ PHÒNG MỚI",
	"JOIN BY HOST": "VÀO ĐỊA CHỈ",
	"JOIN BY ADDRESS": "VÀO BẰNG ĐỊA CHỈ",
	"PLAY SOLO": "CHƠI ĐƠN",
	"JOIN": "VÀO PHÒNG",
	"CREATE ROOM": "TẠO PHÒNG",
	"CREATE": "TẠO",
	"CANCEL": "HỦY",
	"ROOM": "PHÒNG",
	"open slot": "chỗ trống",
	"START GAME": "BẮT ĐẦU",
	"ADD PLAYER": "THÊM NGƯỜI CHƠI",
	"LEAVE ROOM": "RỜI PHÒNG",
	"TO LOBBY": "VỀ SẢNH CHỜ",
	"TEST MENU": "MENU KIỂM THỬ",
	"TEST CONTROLS": "ĐIỀU KHIỂN KIỂM THỬ",
	"SET WAVE": "ĐẶT ĐỢT",
	"PLAYER LEVEL": "CẤP ĐỘ",
	"SPAWN ENEMY": "GỌI QUÁI",
	"SPAWN BOSS": "GỌI BOSS",
	"GIVE CARD": "NHẬN THẺ",
	"GIVE WEAPON": "NHẬN VŨ KHÍ",
	"JUMP TO WAVE": "ĐẾN ĐỢT",
	"SET LEVEL": "ĐẶT CẤP",
	"CLEAR ALL": "DỌN TẤT CẢ",
	"SPECTATING": "ĐANG QUAN SÁT",
	"LEVEL UP — CHOOSE A CARD": "LÊN CẤP — CHỌN MỘT THẺ",
	"LEVEL 5 — CHOOSE YOUR WEAPON": "CẤP 5 — CHỌN VŨ KHÍ",
	"CANNOT HOST HERE": "KHÔNG THỂ TẠO PHÒNG Ở ĐÂY",
	"a browser can only join a desktop host - use JOIN BY HOST": "trình duyệt chỉ vào được phòng máy tính - chọn VÀO ĐỊA CHỈ",
	"CONNECTION: FAST (LAN)": "KẾT NỐI: NHANH (LAN)",
	"CONNECTION: BROWSER FRIENDLY": "KẾT NỐI: TƯƠNG THÍCH TRÌNH DUYỆT",
	"up to 4 players - you are the host": "tối đa 4 người chơi - bạn là chủ phòng",
	"host address": "địa chỉ máy chủ",
	"host address - use wss:// when this page is https": "địa chỉ máy chủ - dùng wss:// nếu trang này dùng https",
	"host address, e.g. 192.168.1.5": "địa chỉ máy chủ, ví dụ 192.168.1.5",
	"room name": "tên phòng",
	"Refresh rooms": "Làm mới danh sách phòng",
	"no rooms found - create one, or use JOIN BY HOST\nauto-discovery needs the same Wi-Fi/LAN; otherwise enter the host IP": "Chưa tìm thấy phòng - hãy tạo phòng hoặc chọn VÀO ĐỊA CHỈ.\nTự tìm phòng cần cùng Wi-Fi/LAN; nếu không, hãy nhập IP máy chủ.",
	"a browser cannot find rooms - use JOIN BY HOST": "Trình duyệt không thể tìm phòng - hãy chọn VÀO ĐỊA CHỈ",
	"this page is https - type a secure wss:// host address": "Trang này dùng HTTPS - hãy nhập địa chỉ máy chủ wss:// bảo mật",
	"no rooms yet - create one": "Chưa có phòng - hãy tạo phòng mới",
	"REFRESH ROOMS": "LÀM MỚI DANH SÁCH PHÒNG",
	"WAVE CLEAR": "ĐÃ DỌN SẠCH ĐỢT",
	"GAME OVER": "TRÒ CHƠI KẾT THÚC",
	"RUN RECORD": "THÀNH TÍCH",
	"NO RUNS RECORDED": "CHƯA CÓ THÀNH TÍCH",
	"LAST RUN": "LƯỢT GẦN NHẤT",
	"BEST RUN": "LƯỢT TỐT NHẤT",
	"MOST PICKED": "THẺ ĐƯỢC CHỌN NHIỀU NHẤT",
	"WAVE": "ĐỢT",
	"BOSSES": "BOSS",
	"DAMAGE": "SÁT THƯƠNG",
	"SURVIVED": "SỐNG SÓT",
	"TIME": "THỜI GIAN",
	"BOSS TTK": "THỜI GIAN HẠ BOSS",
	"BUILD": "BỘ THẺ",
	"PLAY AGAIN": "CHƠI LẠI",
	"MAIN MENU": "MENU CHÍNH",
	"WHAT IS YOUR NAME?": "BẠN TÊN GÌ?",
	"SURVIVE  THE  SWARM": "SỐNG SÓT TRƯỚC BẦY ĐỊCH",
	"UPDATE": "CẬP NHẬT",
	"DISCARD CARD": "VỨT THẺ",
	"BACKPACK": "BA LÔ",
	"waiting for the host to start...": "đang chờ chủ phòng bắt đầu...",
	"COMMON": "THƯỜNG",
	"RARE": "HIẾM",
	"EPIC": "SỬ THI",
	"Rapid Fire": "Bắn Nhanh",
	"+18% fire rate": "+18% tốc độ bắn",
	"Hot Rounds": "Đạn Nóng",
	"+20% bullet speed": "+20% tốc độ đạn",
	"Turbo Thrusters": "Động Cơ Tăng Tốc",
	"+14% move speed": "+14% tốc độ di chuyển",
	"Heavy Slugs": "Đạn Hạng Nặng",
	"+20% bullet damage": "+20% sát thương đạn",
	"Incendiary": "Đạn Cháy",
	"Shots set enemies on fire": "Đạn khiến kẻ địch bốc cháy",
	"Cryo Rounds": "Đạn Đóng Băng",
	"Shots slow enemies": "Đạn làm chậm kẻ địch",
	"Vampiric Core": "Lõi Hút Máu",
	"Kills restore 1 HP": "Tiêu diệt địch hồi 1 HP",
	"Precision": "Chính Xác",
	"+12% crit chance (x2 dmg)": "+12% tỉ lệ chí mạng (x2 sát thương)",
	"Graviton": "Từ Trường",
	"+40% XP pickup range": "+40% tầm hút kinh nghiệm",
	"Reinforced Hull": "Thân Tàu Gia Cố",
	"+2 max HP and heal 2": "+2 HP tối đa và hồi 2 HP",
	"Nano Repair": "Sửa Chữa Nano",
	"Regenerate 1 HP / 8s": "Hồi 1 HP mỗi 8 giây",
	"Piercing Tips": "Đầu Đạn Xuyên",
	"Bullets pierce +1 enemy": "Đạn xuyên thêm 1 kẻ địch",
	"Homing Rounds": "Đạn Tầm Nhiệt",
	"Bullets curve toward the nearest foe": "Đạn tự hướng về kẻ địch gần nhất",
	"Shatter": "Phân Mảnh",
	"Crit hits burst, hurting nearby foes": "Chí mạng phát nổ, gây sát thương địch gần đó",
	"Elite Hunter": "Thợ Săn Tinh Anh",
	"+50% damage to elite enemies": "+50% sát thương lên địch tinh anh",
	"Bloodthirst": "Khát Máu",
	"Kills may restore 1 HP": "Tiêu diệt địch có thể hồi 1 HP",
	"Hull Plating": "Giáp Thân Tàu",
	"Take 1 less contact damage": "Giảm 1 sát thương khi va chạm",
	"Second Wind": "Hồi Sức",
	"Restore 1 HP on every level up": "Hồi 1 HP mỗi lần lên cấp",
	"Greed": "Tham Lam",
	"+20% XP from orbs": "+20% kinh nghiệm từ quả cầu",
	"Inferno": "Hỏa Ngục",
	"Burn damage +40%": "+40% sát thương thiêu đốt",
	"Brittle": "Giòn Yếu",
	"Frozen enemies take +35% damage": "Địch bị đóng băng nhận thêm 35% sát thương",
	"Thorns": "Gai Nhọn",
	"Taking a hit hurts nearby foes": "Bị đánh gây sát thương lên kẻ địch gần đó",
	"Piercing Focus": "Xuyên Phá Tập Trung",
	"Rounds gain damage as they pierce": "Đạn tăng sát thương sau mỗi lần xuyên",
	"Explosive Rounds": "Đạn Nổ",
	"Rounds burst when they expire": "Đạn phát nổ khi hết tầm bay",
	"Scavenger": "Lượm Lặt",
	"Kills drop +40% XP": "Kẻ địch bị hạ rơi thêm 40% kinh nghiệm",
	"Rushed": "Vội Vàng",
	"+25% fire rate, -15% bullet speed": "+25% tốc độ bắn, -15% tốc độ đạn",
	"Heavy Caliber": "Cỡ Nòng Lớn",
	"+30% damage, -15% fire rate": "+30% sát thương, -15% tốc độ bắn",
	"Second Chance": "Cơ Hội Thứ Hai",
	"Revive once with half HP": "Hồi sinh một lần với nửa lượng HP",
	"Cold Blood": "Máu Lạnh",
	"Crit chance rises as HP drops": "Tỉ lệ chí mạng tăng khi HP giảm",
	"Longshot": "Tầm Xa",
	"+15% bullet range per stack": "Mỗi cấp tăng 15% tầm bay của đạn",
	"Momentum": "Động Năng",
	"+15% damage while moving fast": "Tăng 15% sát thương khi di chuyển nhanh",
	"Point Blank": "Cận Chiến",
	"+15% damage to nearby enemies": "Tăng 15% sát thương lên địch ở gần",
	"Machine Gun": "Súng Máy",
	"Fast fire rate, lower damage, wide spread.": "Bắn nhanh, sát thương thấp, tỏa đạn rộng.",
	"+25% fire rate": "+25% tốc độ bắn",
	"-40% damage, inaccurate": "-40% sát thương, độ chính xác thấp",
	"Twin Cannon": "Pháo Nòng Đôi",
	"Fires two parallel rounds each shot.": "Bắn hai viên đạn song song mỗi phát.",
	"2 bullets / shot": "2 viên đạn mỗi phát",
	"+25% cooldown": "+25% thời gian hồi",
	"Shotgun": "Súng Bắn Tỏa",
	"Huge burst up close, weak at range, slow reload.": "Cực mạnh ở gần, yếu ở xa, nạp đạn chậm.",
	"7 pellets up close": "7 viên đạn ở cự ly gần",
	"slow, short range": "chậm, tầm bắn ngắn",
	"Railgun": "Súng Điện Từ",
	"One fast piercing round, big damage, slow cadence.": "Đạn xuyên cực nhanh, sát thương lớn, nhịp bắn chậm.",
	"pierce + big damage": "xuyên giáp + sát thương lớn",
	"+120% cooldown": "+120% thời gian hồi",
	"Burst Rifle": "Súng Trường Loạt",
	"Fires a 3-round burst, then a short pause.": "Bắn loạt 3 viên rồi nghỉ ngắn.",
	"3-round burst": "loạt bắn 3 viên",
	"+30% cooldown": "+30% thời gian hồi",
	"a browser cannot host a room": "Trình duyệt không thể tạo phòng",
	"multiplayer is not available here": "Chế độ nhiều người chơi hiện không khả dụng",
	"the host did not answer": "Chủ phòng không phản hồi",
	"the host kicked you out": "Chủ phòng đã đưa bạn ra khỏi phòng",
	"could not open port %d": "Không thể mở cổng %d",
	"cannot reach %s": "Không thể kết nối tới %s",
	"cannot reach %s:%d": "Không thể kết nối tới %s:%d",
	"ĐANG CẬP NHẬT": "UPDATING",
	"Đang chuẩn bị...": "Preparing...",
	"Đang kiểm tra bản cập nhật...": "Checking for updates...",
	"Đang tải bản cập nhật...": "Downloading update...",
	"Đang tải bản cập nhật: %.1f MB": "Downloading update: %.1f MB",
	"Đang tải bản cập nhật: %.1f / %.1f MB": "Downloading update: %.1f / %.1f MB",
	"Không thể kiểm tra bản cập nhật. Hãy kiểm tra kết nối mạng rồi thử lại.": "Could not check for updates. Check your internet connection and try again.",
	"Không thể tải bản cập nhật. Hãy kiểm tra kết nối mạng rồi thử lại.": "Could not download the update. Check your internet connection and try again.",
	"Thông tin bản cập nhật không hợp lệ.": "The update information is invalid.",
	"Không thể lưu bản cập nhật trên thiết bị.": "Could not save the update on this device.",
	"Không thể lưu thông tin xác minh bản cập nhật.": "Could not save update verification information.",
	"Bản tải về bị thiếu hoặc không hợp lệ. Hãy thử tải lại.": "The downloaded file is incomplete or invalid. Try downloading again.",
	"Không thể hoàn tất lưu bản cập nhật trên thiết bị.": "Could not finish saving the update on this device.",
	"Không thể khởi chạy trình cập nhật. Bạn có thể tải bản Windows trực tiếp từ trang web.": "Could not start the updater. You can download the Windows version directly from the website.",
	"Đã tải và xác minh APK. Android sẽ yêu cầu bạn xác nhận cài đặt.": "The APK was downloaded and verified. Android will ask you to confirm installation.",
	"Không thể mở trình cài đặt Android. Hãy tải bản cập nhật từ trang web.": "Could not open the Android installer. Download the update from the website.",
	"Android yêu cầu cho phép MT Space cài ứng dụng. Bật quyền này trong Cài đặt, quay lại game rồi bấm cập nhật lần nữa.": "Android requires permission for MT Space to install apps. Enable it in Settings, return to the game, then tap Update again.",
	"KHÔNG THỂ TẢI BẢN CẬP NHẬT": "UPDATE DOWNLOAD FAILED",
	"HỦY TẢI": "CANCEL DOWNLOAD",
	"ĐÓNG": "CLOSE",
	"CẬP NHẬT HOÀN TẤT": "UPDATE COMPLETE",
	"Bản cập nhật đã sẵn sàng.\nBạn có muốn khởi động game ngay bây giờ không?": "The update is ready.\nWould you like to restart the game now?",
	"KHỞI ĐỘNG NGAY": "RESTART NOW",
	"ĐỂ SAU": "LATER",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_locale()
	_apply_locale()
	get_tree().node_added.connect(_on_node_added)
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_translate_current_scene")


func _load_locale() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LOCALE_FILE) == OK:
		var saved := str(cfg.get_value("locale", "lang", ""))
		if saved == "vi" or saved == "en":
			locale = saved
			return
	if OS.get_locale().begins_with("vi"):
		locale = "vi"
	else:
		locale = "en"


func set_locale(l: String) -> void:
	if l != "vi" and l != "en":
		return
	locale = l
	var cfg := ConfigFile.new()
	cfg.set_value("locale", "lang", locale)
	cfg.save(LOCALE_FILE)
	_apply_locale()
	_translate_current_scene()
	call_deferred("_translate_current_scene")
	locale_changed.emit(locale)


func get_locale() -> String:
	return locale


func _apply_locale() -> void:
	TranslationServer.set_locale(locale)


func translate_text(value: String) -> String:
	if value.is_empty():
		return value
	if locale == "en":
		return _to_english(value)
	if value.begins_with("UPGRADE STACKS: "):
		return "SỐ LẦN NÂNG CẤP: " + value.trim_prefix("UPGRADE STACKS: ")
	if EN_TO_VI.has(value):
		return str(EN_TO_VI[value])
	if value.begins_with("could not open port "):
		return "Không thể mở cổng " + value.trim_prefix("could not open port ")
	if value.begins_with("cannot reach "):
		return "Không thể kết nối tới " + value.trim_prefix("cannot reach ")
	if value.begins_with("SPECTATING "):
		return "ĐANG QUAN SÁT " + value.trim_prefix("SPECTATING ")
	if value.begins_with("WAVE ") and value.substr(5).is_valid_int():
		return "ĐỢT " + value.substr(5)
	if value.begins_with("LV ") and value.substr(3).is_valid_int():
		return "CẤP " + value.substr(3)
	if value.begins_with("LEVEL ") and value.substr(6).is_valid_int():
		return "CẤP " + value.substr(6)
	if value.begins_with("Next wave in "):
		return "Đợt tiếp theo sau " + value.trim_prefix("Next wave in ")
	if value.begins_with("ready to start  -  "):
		return "sẵn sàng bắt đầu  -  " + value.trim_prefix("ready to start  -  ")
	if value.ends_with(" players - start whenever you like"):
		return value.trim_suffix(" players - start whenever you like") \
			+ " người chơi - có thể bắt đầu bất cứ lúc nào"
	if value.ends_with(" (browser)"):
		return value.trim_suffix(" (browser)") + " (trình duyệt)"
	return value


func _to_english(value: String) -> String:
	for english in EN_TO_VI:
		if EN_TO_VI[english] == value:
			return str(english)
	if value.begins_with("Không thể mở cổng "):
		return "could not open port " + value.trim_prefix("Không thể mở cổng ")
	if value.begins_with("Không thể kết nối tới "):
		return "cannot reach " + value.trim_prefix("Không thể kết nối tới ")
	if value.begins_with("SỐ LẦN NÂNG CẤP: "):
		return "UPGRADE STACKS: " + value.trim_prefix("SỐ LẦN NÂNG CẤP: ")
	if value.begins_with("ĐANG QUAN SÁT "):
		return "SPECTATING " + value.trim_prefix("ĐANG QUAN SÁT ")
	if value.begins_with("ĐỢT ") and value.substr(5).is_valid_int():
		return "WAVE " + value.substr(5)
	if value.begins_with("CẤP ") and value.substr(4).is_valid_int():
		return "LV " + value.substr(4)
	if value.begins_with("Đợt tiếp theo sau "):
		return "Next wave in " + value.trim_prefix("Đợt tiếp theo sau ")
	if value.begins_with("sẵn sàng bắt đầu  -  "):
		return "ready to start  -  " + value.trim_prefix("sẵn sàng bắt đầu  -  ")
	if value.ends_with(" người chơi - có thể bắt đầu bất cứ lúc nào"):
		return value.trim_suffix(" người chơi - có thể bắt đầu bất cứ lúc nào") \
			+ " players - start whenever you like"
	if value.ends_with(" (trình duyệt)"):
		return value.trim_suffix(" (trình duyệt)") + " (browser)"
	return value


func _translate_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		translate_tree(scene)


func _on_node_added(node: Node) -> void:
	call_deferred("_translate_node", node)


func _on_scene_changed() -> void:
	call_deferred("_translate_current_scene")


func translate_tree(node: Node) -> void:
	_translate_node(node)
	for child in node.get_children():
		translate_tree(child)


func _translate_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is OptionButton:
		var source_items: Array = node.get_meta("locale_source_items", [])
		if source_items.size() != node.item_count:
			source_items.clear()
			for index in node.item_count:
				source_items.append(_source_text(node.get_item_text(index)))
			node.set_meta("locale_source_items", source_items)
		for index in node.item_count:
			node.set_item_text(index, translate_text(str(source_items[index])))
	elif node is Button:
		var source_text := _control_source_text(node, "text", "locale_source_text")
		node.text = translate_text(source_text)
		_fit_button_text(node)
	elif node is Label:
		var source_text := _control_source_text(node, "text", "locale_source_text")
		node.text = translate_text(source_text)
	elif node is RichTextLabel:
		var source_text := _control_source_text(node, "text", "locale_source_text")
		node.text = translate_text(source_text)
	elif node is LineEdit:
		var source_text := _control_source_text(
			node, "placeholder_text", "locale_source_placeholder"
		)
		node.placeholder_text = translate_text(source_text)
	if node is Control and not node.tooltip_text.is_empty():
		var tooltip_source := str(node.get_meta(
			"locale_source_tooltip", _source_text(node.tooltip_text)
		))
		node.set_meta("locale_source_tooltip", tooltip_source)
		node.tooltip_text = translate_text(tooltip_source)


func localize_control(node: Control, source_text: String) -> void:
	node.set_meta("locale_source_text", source_text)
	set_control_text(node, source_text)


func _control_source_text(node: Control, property: String, metadata_key: String) -> String:
	if node.has_meta(metadata_key):
		return str(node.get_meta(metadata_key))
	var current := str(node.get(property))
	var source := _source_text(current)
	node.set_meta(metadata_key, source)
	return source


func _source_text(value: String) -> String:
	return _to_english(value)


func set_control_text(node: Control, source_text: String) -> void:
	node.set_meta("locale_source_text", source_text)
	if node is Button or node is Label or node is RichTextLabel:
		node.set("text", translate_text(source_text))
		if node is Button:
			_fit_button_text(node)


func set_control_placeholder(node: LineEdit, source_text: String) -> void:
	node.set_meta("locale_source_placeholder", source_text)
	node.placeholder_text = translate_text(source_text)


func _fit_button_text(button: Button) -> void:
	var resize_callback := Callable(self, "_fit_button_text").bind(button)
	if not button.resized.is_connected(resize_callback):
		button.resized.connect(resize_callback)
	if not button.has_meta("locale_base_font_size"):
		button.set_meta("locale_base_font_size", button.get_theme_font_size("font_size"))
	var base_size := int(button.get_meta("locale_base_font_size"))
	var available_width := button.size.x
	var style: StyleBox = button.get_theme_stylebox("normal")
	if style != null:
		available_width -= style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
	available_width = maxf(0.0, available_width - 16.0)
	var font: Font = button.get_theme_font("font")
	if button.text.is_empty() or available_width <= 0.0 or font == null:
		return
	var text_width := font.get_string_size(
		button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, base_size
	).x
	var target_size := base_size
	if text_width > available_width:
		target_size = maxi(10, floori(base_size * available_width / text_width))
	button.add_theme_font_size_override("font_size", target_size)
