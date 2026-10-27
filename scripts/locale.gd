extends Node

const DropdownStyle := preload("res://scripts/dropdown_style.gd")

signal locale_changed(locale: String)

const LOCALE_FILE := "user://locale.cfg"
var locale: String = "en"

const EN_TO_VI := {
	"SHOP": "CỬA HÀNG TÀU",
	"STORE": "CỬA HÀNG",
	"CREDITS": "TIỀN",
	"LOADOUT CATEGORIES": "DANH MỤC TRANG BỊ",
	"OVERVIEW": "TỔNG QUAN",
	"DRONES": "DRONE",
	"WEAPONS": "VŨ KHÍ",
	"NO COMPATIBLE EQUIPMENT FOUND": "KHÔNG CÓ TRANG BỊ TƯƠNG THÍCH",
	"SELECT A SLOT OR BROWSE YOUR EQUIPMENT": "Chọn một ô hoặc duyệt kho trang bị",
	"SELECT AN ITEM TO EQUIP IN THE %s SLOT": "Chọn vật phẩm để lắp vào ô %s",
	"%d ITEMS  /  %d OWNED": "%d VẬT PHẨM  /  %d ĐÃ SỞ HỮU",
	"NOT OWNED": "CHƯA SỞ HỮU",
	"EQUIPPED ITEMS / Select a slot to choose from equipment you own.": "TRANG BỊ ĐANG DÙNG / Chọn một ô để chọn vật phẩm bạn sở hữu.",
	"EQUIPMENT SLOTS": "Ô TRANG BỊ",
	"ARMOR SLOT": "Ô GIÁP",
	"DRONE SLOT": "Ô DRONE",
	"SUPPORT SLOT": "Ô HỖ TRỢ",
	"SUPPORT SYSTEM": "HỆ THỐNG HỖ TRỢ",
	"EMPTY": "TRỐNG",
	"SELECT ITEM": "CHỌN VẬT PHẨM",
	"NO OWNED ITEMS FOR THIS SLOT. VISIT STORE TO BUY EQUIPMENT.": "Bạn chưa sở hữu vật phẩm phù hợp. Hãy đến Cửa hàng để mua.",
	"CHANGE PILOT NAME": "ĐỔI TÊN PHI CÔNG",
	"your name is saved for future sessions": "Tên sẽ được lưu cho những lần chơi sau",
	"SAVE NAME": "LƯU TÊN",
	"OPEN PILOT PROFILE": "MỞ HỒ SƠ PHI CÔNG",
	"PILOT COMBAT PROFILE": "HỒ SƠ CHIẾN ĐẤU",
	"PILOT LEVEL": "CẤP PHI CÔNG",
	"BEST-RUN KILLS": "QUÁI HẠ GỤC (LƯỢT TỐT NHẤT)",
	"BOSSES DEFEATED": "BOSS ĐÃ HẠ",
	"DAMAGE DEALT": "SÁT THƯƠNG GÂY RA",
	"LATEST RUN": "LƯỢT GẦN NHẤT",
	"SHIP & ENGINE COLORS": "MÀU TÀU & ĐỘNG CƠ",
	"SHIP COLOR  /  ONE PLAYER PER COLOR": "MÀU TÀU  /  MỖI NGƯỜI MỘT MÀU",
	"ENGINE FLAME  /  SHARED COLORS ALLOWED": "LỬA ĐỘNG CƠ  /  ĐƯỢC DÙNG CHUNG MÀU",
	"UNEQUIP SLOT": "THÁO TRANG BỊ",
	"CATEGORIES": "DANH MỤC",
	"ALL ITEMS": "TẤT CẢ VẬT PHẨM",
	"ARMOR": "GIÁP",
	"ATTACK DRONES": "DRONE TẤN CÔNG",
	"REPAIR": "HỒI PHỤC",
	"DEFENSE": "PHÒNG THỦ",
	"SUPPORT": "HỖ TRỢ",
	"SEARCH EQUIPMENT": "TÌM TRANG BỊ",
	"BUY EQUIPMENT WITH CREDITS / Owned items can be equipped from Equipment.": "MUA TRANG BỊ BẰNG TIỀN / Vật phẩm đã mua có thể lắp từ Kho trang bị.",
	"NO MATCHING EQUIPMENT": "KHÔNG CÓ TRANG BỊ PHÙ HỢP",
	"REPLACE EQUIPMENT": "THAY TRANG BỊ",
	"BUY": "MUA",
	"EQUIP": "TRANG BỊ",
	"UNEQUIP": "THÁO",
	"REINFORCED ARMOR": "GIÁP GIA CỐ",
	"STRIKE DRONE": "DRONE TẤN CÔNG",
	"REPAIR DRONE": "DRONE SỬA CHỮA",
	"HEX GUARD DRONE": "DRONE KHIÊN LỤC GIÁC",
	"REACTOR TUNER": "BỘ ĐIỀU CHỈNH LÒ PHẢN ỨNG",
	"TARGETING SERVO": "BỘ NGẮM MỤC TIÊU",
	"+3 maximum hull points while equipped.": "Tăng 3 máu tối đa khi trang bị.",
	"Autonomously fires at nearby enemies.": "Tự động bắn kẻ địch ở gần.",
	"Repairs one hull point during combat.": "Sửa một điểm máu trong khi chiến đấu.",
	"Generates a segmented hex shield around the ship.": "Tạo khiên lục giác nhiều mảnh quanh phi thuyền.",
	"Optimizes the ship's firing cycle.": "Tối ưu chu kỳ khai hỏa của phi thuyền.",
	"Improves weapon targeting efficiency.": "Tăng hiệu quả ngắm bắn.",
	"Adds 3 maximum HP.": "Tăng 3 máu tối đa.",
	"Fires a support shot about every 1.4 seconds.": "Bắn hỗ trợ khoảng mỗi 1,4 giây.",
	"Restores 1 HP every 6 seconds.": "Hồi 1 HP mỗi 6 giây.",
	"Blocks 3 hits; one charge returns every 8 seconds.": "Chặn 3 đòn; hồi một mảnh khiên mỗi 8 giây.",
	"+8% firing rate while equipped.": "Tăng 8% tốc độ bắn khi trang bị.",
	"+10% weapon damage while equipped.": "Tăng 10% sát thương vũ khí khi trang bị.",
	"SEARCH FIGHTERS": "TÌM PHI THUYỀN",
	"FIGHTER DETAILS": "CHI TIẾT PHI THUYỀN",
	"ENGINE": "ĐỘNG CƠ",
	"WEAPON": "VŨ KHÍ",
	"VECTOR DRIVE": "ĐỘNG CƠ VECTOR",
	"NEEDLE CANNON": "PHÁO KIM",
	"OVERCLOCK": "TĂNG XUNG",
	"ACE OPTICS": "ỐNG NGẮM ACE",
	"VECTOR THRUSTERS": "ĐỘNG CƠ VECTOR",
	"PULSE FOCUS": "TẬP TRUNG XUNG",
	"CAPACITOR": "TỤ ĐIỆN",
	"PHASE PIERCING": "ĐẠN XUYÊN PHA",
	"AFTERBURNER": "ĐỘNG CƠ ĐỐT SAU",
	"PLASMA CORE": "LÕI PLASMA",
	"IGNITION ARRAY": "MẢNG ĐÁNH LỬA",
	"EMBER MATRIX": "MA TRẬN THAN HỒNG",
	"HEAVY THRUSTERS": "ĐỘNG CƠ HẠNG NẶNG",
	"SIEGE CANNON": "PHÁO CÔNG PHÁ",
	"POWER CELL": "PIN NĂNG LƯỢNG",
	"BULWARK PLATING": "GIÁP PHÁO ĐÀI",
	"INTERCEPTOR DRIVE": "ĐỘNG CƠ ĐÁNH CHẶN",
	"TARGETING ARRAY": "MẢNG NGẮM",
	"REACTOR LOOP": "VÒNG LÒ PHẢN ỨNG",
	"HYPERCOIL": "CUỘN SIÊU TỐC",
	"+3.5% critical chance per level": "Tăng 3,5% tỉ lệ chí mạng mỗi cấp",
	"+1 projectile pierce per level": "Tăng 1 lần xuyên đạn mỗi cấp",
	"+1 burn stack per level": "Tăng 1 cộng dồn thiêu đốt mỗi cấp",
	"+6% projectile speed per level": "Tăng 6% tốc độ đạn mỗi cấp",
	"FIRE RATE": "TỐC ĐỘ BẮN",
	"RATE": "TỐC ĐỘ BẮN",
	"HULL": "THÂN TÀU",
	"SPEED": "TỐC ĐỘ",
	"DMG": "SÁT THƯƠNG",
	"CRIT": "CHÍ MẠNG",
	"PIERCE": "XUYÊN GIÁP",
	"BURN": "THIÊU ĐỐT",
	"BULLET SPEED": "TỐC ĐỘ ĐẠN",
	"UPGRADE": "NÂNG CẤP",
	"MAX": "TỐI ĐA",
	"CURRENT": "HIỆN TẠI",
	"NEXT": "TIẾP THEO",
	"LEVEL": "CẤP",
	"NOT ENOUGH GEMS": "KHÔNG ĐỦ NGỌC",
	"ACTIVE SHIP": "TÀU ĐANG DÙNG",
	"UNLOCK BY REACHING WAVE": "MỞ KHÓA KHI ĐẠT ĐỢT",
	"OR PURCHASE FOR": "HOẶC MUA VỚI",
	"PERMANENT SHIP SYSTEMS / Upgrade levels apply to the pilot's ship in future runs.": "HỆ THỐNG TÀU VĨNH VIỄN / Cấp nâng cấp được áp dụng cho tàu trong các lượt chơi tiếp theo.",
	"ACTIVE FIGHTER / Changes here persist and apply to your next run.": "PHI THUYỀN HIỆN TẠI / Thay đổi được lưu và áp dụng cho lượt chơi tiếp theo.",
	"SHIP UNLOCKS / Unlock fighters with gems or earn them by reaching their best-wave requirement.": "MỞ KHÓA TÀU / Dùng ngọc mở khóa hoặc đạt mốc wave yêu cầu.",
	"DAILY MISSIONS / Progress and rewards are saved with your pilot profile.": "NHIỆM VỤ HẰNG NGÀY / Tiến trình và phần thưởng được lưu trong hồ sơ phi công.",
	"+5% ship movement speed per level": "Tăng 5% tốc độ di chuyển mỗi cấp",
	"+8% weapon damage per level": "Tăng 8% sát thương vũ khí mỗi cấp",
	"+6% firing rate per level": "Tăng 6% tốc độ bắn mỗi cấp",
	"+1 maximum hull point per level": "Tăng 1 máu tối đa mỗi cấp",
	"Finish one normal run to earn pilot gems.": "Hoàn thành một lượt chơi thường để nhận ngọc.",
	"Survive until wave five in a normal run.": "Sống sót đến wave 5 trong một lượt chơi thường.",
	"Defeat a boss during a normal run.": "Đánh bại boss trong một lượt chơi thường.",
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
	"MASTER VOLUME": "ÂM LƯỢNG CHÍNH",
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
	"TOTAL EARNED": "TỔNG NHẬN ĐƯỢC",
	"TOTAL EXPERIENCE": "TỔNG KINH NGHIỆM",
	"CASH SAVE FAILED": "Không lưu được tiền thưởng vào hồ sơ",
	"REWARD SAVE FAILED": "Không lưu được phần thưởng vào hồ sơ",
	"WAVE REACHED": "MÀN ĐẠT ĐƯỢC",
	"ENEMIES DEFEATED": "QUÁI ĐÃ TIÊU DIỆT",
	"NO REWARDS EARNED": "CHƯA NHẬN ĐƯỢC THƯỞNG",
	"CASH EACH": "TIỀN MỖI CON",
	"SHAPE 3": "QUÁI HÌNH 3 CẠNH",
	"SHAPE 4": "QUÁI HÌNH 4 CẠNH",
	"SHAPE 5": "QUÁI HÌNH 5 CẠNH",
	"SHAPE 6": "QUÁI HÌNH 6 CẠNH",
	"SHOOTER": "QUÁI BẮN ĐẠN",
	"DOUBLE": "QUÁI ĐÔI",
	"RAILGUN": "QUÁI RAILGUN",
	"CHARGER": "QUÁI LAO TỚI",
	"ORB": "QUÁI ORB",
	"BEAM": "QUÁI TIA BEAM",
	"BOSS DRONE": "DRONE BOSS",
	"BOSS": "BOSS",
	"BOSS 2": "BOSS 2",
	"WAVES": "SỐ MÀN",
	"RUN RECORD": "THÀNH TÍCH",
	"NO RUNS RECORDED": "CHƯA CÓ THÀNH TÍCH",
	"MT SPACE": "MT SPACE",
	"PILOT": "PHI CÔNG",
	"STARFIGHTER COMMAND": "BỘ CHỈ HUY PHI CƠ",
	"BEST WAVE": "ĐỢT CAO NHẤT",
	"TOKENS": "ĐỒNG",
	"SET": "CÀI ĐẶT",
	"MENU": "MENU",
	"HOME": "TRANG CHỦ",
	"SHIPS": "PHI ĐỘI",
	"UPGRADES": "NÂNG CẤP",
	"EQUIPMENT": "KHO TRANG BỊ",
	"MISSIONS": "NHIỆM VỤ",
	"ACHIEVEMENTS": "THÀNH TÍCH",
	"EVENTS": "SỰ KIỆN",
	"ACTIVE STARFIGHTER": "PHI THUYỀN ĐANG DÙNG",
	"HANGAR / ACTIVE FIGHTER": "HANGAR / PHI THUYỀN ĐANG DÙNG",
	"PILOT PROFILE": "HỒ SƠ PHI CÔNG",
	"FRAME SYSTEMS": "THÔNG SỐ KHUNG TÀU",
	"HP": "HP",
	"CASH": "TIỀN MẶT",
	"GEM": "NGỌC",
	"GEMS": "NGỌC",
	"STOCK": "MẶC ĐỊNH",
	"ION": "ION",
	"NEBULA": "TINH VÂN",
	"SOLAR": "MẶT TRỜI",
	"JADE": "NGỌC BÍCH",
	"CORAL": "SAN HÔ",
	"EQUIPPED": "ĐANG DÙNG",
	"OWNED": "ĐÃ SỞ HỮU",
	"CURRENTLY EQUIPPED": "ĐANG TRANG BỊ",
	"BEST WAVE %d OR %d GEMS": "ĐẠT ĐỢT %d HOẶC DÙNG %d NGỌC",
	"CHOOSE MODE": "CHỌN CHẾ ĐỘ",
	"SELECT A FLIGHT MODE": "CHỌN CHẾ ĐỘ BAY",
	"Choose what Play Now will launch.": "Chọn chế độ mà nút Chơi ngay sẽ bắt đầu.",
	"SINGLE PLAYER": "CHƠI ĐƠN",
	"Start a solo wave-survival run immediately.": "Bắt đầu lượt sinh tồn theo đợt ngay lập tức.",
	"Open the room browser to host or join a multiplayer run.": "Mở danh sách phòng để tạo hoặc tham gia lượt chơi nhiều người.",
	"SELECT MODE": "CHỌN CHẾ ĐỘ",
	"CURRENT MODE": "CHẾ ĐỘ HIỆN TẠI",
	"SOLO  /  WAVE SURVIVAL": "CHƠI ĐƠN  /  SINH TỒN THEO ĐỢT",
	"ONLINE CO-OP  /  ROOM BROWSER": "CHƠI PHỐI HỢP  /  DANH SÁCH PHÒNG",
	"TEST MODE": "CHẾ ĐỘ KIỂM THỬ",
	"TEST MODE  /  SANDBOX": "CHẾ ĐỘ KIỂM THỬ  /  MÔI TRƯỜNG THỬ",
	"Start a sandbox with no normal waves and manual enemy controls.": "Bắt đầu môi trường thử nghiệm không có đợt quái tự động, cho phép gọi quái thủ công.",
	"VIEW ALL MISSIONS": "XEM TẤT CẢ NHIỆM VỤ",
	"AVAILABLE": "CÓ THỂ CHỌN",
	"SELECT PAINT": "CHỌN MÀU SƠN",
	"OPEN STORE": "MỞ CỬA HÀNG",
	"Distinct fighter frames with different combat stats. Choose one that matches your play style.": "Mỗi phi thuyền có bộ chỉ số chiến đấu riêng. Hãy chọn tàu phù hợp với lối chơi của bạn.",
	"Gems come from daily mission rewards. Spend them to unlock fighters early; reaching the listed best wave also unlocks a fighter for free.": "Ngọc nhận từ nhiệm vụ hằng ngày. Dùng ngọc để mở sớm phi thuyền; đạt mốc đợt cao nhất cũng mở tàu miễn phí.",
	"COSMETIC SHIP SKINS": "PHI ĐỘI PHI THUYỀN",
	"RECON FIGHTER  /  COSMETIC": "PHI THUYỀN CHIẾN ĐẤU",
	"Each fighter has its own speed, hull, weapon damage, and projectile velocity.": "Mỗi tàu có tốc độ, giáp, sát thương và tốc độ đạn riêng.",
	"BROWSE FLEET": "XEM HANGAR",
	"FLIGHT RECORD": "HỒ SƠ CHIẾN ĐẤU",
	"YOUR RECENT PERFORMANCE": "THÀNH TÍCH CỦA BẠN",
	"OPERATIONS": "NHIỆM VỤ",
	"CHOOSE YOUR NEXT FLIGHT": "CHỌN CHUYẾN BAY TIẾP THEO",
	"PLAY NOW": "CHƠI NGAY",
	"ONLINE CO-OP": "CHƠI PHỐI HỢP",
	"Solo starts immediately. Co-op opens the room browser.": "Chơi đơn bắt đầu ngay. Chơi phối hợp mở danh sách phòng.",
	"PILOT SERVICES": "DỊCH VỤ PHI CÔNG",
	"QUICK ACCESS": "TRUY CẬP NHANH",
	"DAILY MISSIONS": "NHIỆM VỤ HẰNG NGÀY",
	"REWARDS RESET EACH DAY": "PHẦN THƯỞNG ĐẶT LẠI MỖI NGÀY",
	"STARFIGHTER HANGAR": "HANGAR PHI THUYỀN",
	"PAINT SCHEMES UNLOCK FROM BEST WAVE": "MỞ MÀU SƠN THEO ĐỢT CAO NHẤT",
	"Complete a run": "Hoàn thành một lượt",
	"Reach wave 5": "Đạt đợt 5",
	"Defeat a boss": "Đánh bại một boss",
	"SELECTED": "ĐANG CHỌN",
	"UNLOCKED": "ĐÃ MỞ",
	"LOCKED": "ĐÃ KHÓA",
	"UNLOCK": "MỞ KHÓA",
	"REWARD": "PHẦN THƯỞNG",
	"COST": "CHI PHÍ",
	"FREE AT WAVE": "MỞ MIỄN PHÍ Ở ĐỢT",
	"CLAIM": "NHẬN",
	"CLAIMED": "ĐÃ NHẬN",
	"Every fighter has distinct combat stats. Unlock ships by reaching the listed best wave or using gems.": "Mỗi phi thuyền có chỉ số chiến đấu riêng. Đạt mốc đợt cao nhất hoặc dùng ngọc để mở khóa.",
	"Complete objectives during regular runs. Progress is saved locally and resets each day.": "Hoàn thành mục tiêu trong các lượt chơi thường. Tiến độ được lưu trên thiết bị và đặt lại mỗi ngày.",
	"These are in-run cards; choose them when leveling up during a run.": "Đây là thẻ nâng cấp trong trận; hãy chọn khi lên cấp.",
	"Your weapon and passive upgrades are selected during a run. Last recorded weapon: %s.": "Vũ khí và nâng cấp bị động được chọn trong trận. Vũ khí ghi nhận gần nhất: %s.",
	"Use the Upgrades section to review the available cards.": "Mở mục Nâng cấp để xem các thẻ hiện có.",
	"Pilot tokens: %d": "Đồng phi công: %d",
	"Tokens come from daily mission rewards. Spend them to unlock fighters early; reaching the listed best wave also unlocks one for free.": "Đồng nhận từ phần thưởng nhiệm vụ hằng ngày. Dùng đồng để mở sớm phi thuyền; đạt mốc đợt cao nhất cũng mở miễn phí.",
	"No active limited-time event is running. Daily missions are available in Pilot Services.": "Hiện không có sự kiện giới hạn thời gian. Nhiệm vụ hằng ngày nằm trong mục Dịch vụ phi công.",
	"MASTER VOLUME  %d%%": "ÂM LƯỢNG CHÍNH  %d%%",
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
	"RETURN TO LOBBY": "VỀ SẢNH",
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
	"CẦN CẤP QUYỀN": "PERMISSION REQUIRED",
	"Android yêu cầu cho phép MT Space cài ứng dụng trước khi tải bản cập nhật. Bật quyền này trong Cài đặt, quay lại game rồi bấm cập nhật lần nữa.": "Android requires permission for MT Space to install apps before downloading the update. Enable it in Settings, return to the game, then tap Update again.",
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
	var item_count_separator := " ITEMS  /  "
	var item_count_position := value.find(item_count_separator)
	if item_count_position >= 0 and value.ends_with(" OWNED"):
		var item_count := value.substr(0, item_count_position)
		var owned_count := value.substr(
			item_count_position + item_count_separator.length()
		).trim_suffix(" OWNED")
		if item_count.is_valid_int() and owned_count.is_valid_int():
			return "%s VẬT PHẨM  /  %s ĐÃ SỞ HỮU" % [
				item_count, owned_count,
			]
	var slot_hint_prefix := "SELECT AN ITEM TO EQUIP IN THE "
	if value.begins_with(slot_hint_prefix) and value.ends_with(" SLOT"):
		var slot_name := value.trim_prefix(slot_hint_prefix).trim_suffix(" SLOT")
		var translated_slot: String = {
			"ARMOR": "GIÁP",
			"DRONE": "DRONE",
			"SUPPORT": "HỖ TRỢ",
		}.get(slot_name, slot_name)
		return "Chọn vật phẩm để lắp vào ô %s" % translated_slot
	if value.begins_with("BUY  ") and value.ends_with(" CREDITS"):
		var amount := value.trim_prefix("BUY  ").trim_suffix(" CREDITS")
		if amount.is_valid_int():
			return "MUA  %s $" % amount
	if value.begins_with("UPGRADE STACKS: "):
		return "SỐ LẦN NÂNG CẤP: " + value.trim_prefix("UPGRADE STACKS: ")
	if value.ends_with(" XP") and value.contains(" / "):
		return value.trim_suffix(" XP") + " KN"
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
	if value.begins_with("MUA  ") and value.ends_with(" $"):
		var amount := value.trim_prefix("MUA  ").trim_suffix(" $")
		if amount.is_valid_int():
			return "BUY  %s CREDITS" % amount
	if value.begins_with("Không thể mở cổng "):
		return "could not open port " + value.trim_prefix("Không thể mở cổng ")
	if value.begins_with("Không thể kết nối tới "):
		return "cannot reach " + value.trim_prefix("Không thể kết nối tới ")
	if value.begins_with("SỐ LẦN NÂNG CẤP: "):
		return "UPGRADE STACKS: " + value.trim_prefix("SỐ LẦN NÂNG CẤP: ")
	if value.ends_with(" KN") and value.contains(" / "):
		return value.trim_suffix(" KN") + " XP"
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
	call_deferred("_translate_added_node", node.get_instance_id())


func _translate_added_node(instance_id: int) -> void:
	var added_object := instance_from_id(instance_id)
	if added_object is Node:
		_translate_node(added_object)


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
		DropdownStyle.apply(node)
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
