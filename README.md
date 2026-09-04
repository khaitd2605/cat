# Domino Focus — Godot Web Prototype

Prototype game về việc **làm một công việc tỉ mỉ (xếp domino) trong khi phải để mắt tới
môi trường xung quanh** (gió lùa qua cửa sổ, mèo nhảy lên bàn). Mọi sự cố đều có
chuỗi tín hiệu cảnh báo trước để người chơi kịp phản ứng.

- Engine: **Godot 4.7.1** (GL Compatibility renderer, Jolt Physics 3D, chạy tốt trên Web/WebGL2)
- Scene chính: **`scenes/main_3d.tscn`** — bàn và domino là 3D vật lý thật. `scenes/main.tscn` là bản 2D cũ, giữ để tham chiếu.
- Target: **Web/HTML5** (preset `Web` đã cấu hình, không dùng thread → host tĩnh nào cũng chạy)
- Input: chuột (click). Phím `R` để chơi lại khi kết thúc.

## Chạy trong Godot

```bash
godot --path . --editor        # mở editor
godot --path .                 # chạy game trực tiếp
```

Scene chính: `scenes/main_3d.tscn` (bản 2D cũ: `scenes/main.tscn`, chạy bằng `godot --path . scenes/main.tscn`).

## Export Web

Export template Web cho 4.7.1 đã được cài vào
`~/Library/Application Support/Godot/export_templates/4.7.1.stable/` (chỉ các file `web_*.zip`).

```bash
godot --headless --path . --export-release Web build/web/index.html
cd build/web && python3 -m http.server 8080
# mở http://localhost:8080/index.html
```

Preset nằm trong `export_presets.cfg` (`variant/thread_support=false`, không cần COOP/COEP header).
`build/` và `.godot/` đã được gitignore.

## Core mechanic: Focus vs Awareness

Hai chế độ **cạnh tranh** nhau, thời gian không bao giờ dừng:

| | FOCUS (đang cầm domino) | AWARENESS (buông tay) |
|---|---|---|
| Màn hình | viền tối lại, rìa khó nhận ra chuyển động | sáng đều, thấy rõ cả phòng |
| Làm được gì | căn vị trí, canh hết lắc rồi thả | hover đồ vật để đọc trạng thái, click để xử lý |
| Cái giá | dễ bỏ lỡ mèo/cửa sổ ở rìa | không xếp được |

Camera **không tự di chuyển** (zoom tự động ra/vào liên tục gây khó chịu). Muốn nhìn gần thì tự
giữ **Shift** hoặc lăn chuột.

### Build (3D, vật lý thật)
1. Đường dẫn là một **domino run** hình rắn lượn (3 hàng lượn sóng nối bằng cua chữ U) từ BẮT ĐẦU tới ĐÍCH, ~50 quân.
   Mỗi quân là một `RigidBody3D` (Jolt). Quân đã đặt được **freeze** (kinematic) nên không rung; quân đang đổ chạm
   vào quân freeze thì đánh thức nó → dây chuyền lan bằng va chạm thật, qua cả khúc cua. `gravity_scale = 10` để
   domino 1m cao đổ nhanh như domino 5cm thật.
2. Cầm domino từ **khay** (góc dưới trái) hoặc bấm vào vòng sáng. Tay cầm ở **đầu trên**, đầu dưới đung đưa như con lắc:
   di tay nhanh thì lắc mạnh, giữ yên thì tắt dần (~1.5s). Gió làm lắc thêm. Góc quân tự đúng, không cần xoay.
3. Đưa đầu dưới (vòng nhỏ dưới quân: xanh = thẳng, vàng = hơi nghiêng, đỏ = lắc mạnh) vào vòng sáng rồi thả.
   Thẳng (lắc ≤0.05) → đặt thẳng và freeze; lắc hơn → giao cho vật lý với đúng độ nghiêng đó: nghiêng ít thì
   lắc rồi đứng lại, nghiêng nhiều thì ngã đè quân trước/sau. Lệch chỗ >0.22 vẫn nằm đó nhưng **không tính**;
   ra ngoài đường >0.7 thì về khay. Không đặt được lên chỗ còn quân đổ chưa dọn.
4. Gió = impulse đẩy mọi quân phía cửa sổ về phía người chơi; mèo = impulse tỏa quanh điểm rơi. Che chắn (Space/chuột phải) chặn gió.
5. Quân đổ mờ dần rồi biến mất → xếp lại (recovery). Một đợt đổ ≥50% khi đang có ≥8 quân → thua.

### Environmental events (lifecycle IDLE → WARNING → ESCALATING → DANGER → TRIGGERED / RESOLVED)
- **Mèo**: nhìn lên bàn → đi lại → ngồi sát mép nhìn chằm chằm → thu mình → NHẢY (đè bẹp quanh điểm rơi, phần còn lại đổ dây chuyền). Xử lý: click mèo.
- **Gió**: rèm động + cửa hé → gió nhẹ, lá bay → **tờ giấy trên bàn bay** → domino rung → GIÓ LỚN (mọi quân phía cửa sổ đổ về phía người chơi). Xử lý: click cửa sổ, hoặc giữ **Space / chuột phải** che tay đúng lúc.
- Không có banner. Hover vào mèo/cửa sổ trong lúc AWARENESS để đọc trạng thái hiện tại. Màn thua ghi rõ **dấu hiệu đã bỏ lỡ**.
- Chế độ trợ giúp (banner + nút hành động) vẫn có: bật `assist_banner` trên node `HUD`.

## Kiến trúc

```
scripts/
  3d/                       # scene 3D (main_3d.tscn)
    domino_body.gd          # RigidBody3D một quân: freeze/wake, va chạm đánh thức láng giềng
    domino_task_3d.gd       # BUILD 3D: đường dẫn, khay, cầm-lắc-thả, gust/smash, collapse bookkeeping (API giống 2D)
    focus_system_3d.gd      # Camera3D zoom vào ô đang xếp + vignette
    interactable_object_3d.gd, cat_3d.gd, window_3d.gd, curtain_3d.gd, paper_3d.gd, room_3d.gd
    main_3d.gd, auto_tester_3d.gd
  autoload/
    event_bus.gd          # hub signal toàn cục — các hệ thống không tham chiếu chéo nhau
    game_manager.gd       # state PLAYING / FAILING / FAILED / WON, restart, đồng hồ
    sfx.gd                # âm placeholder tổng hợp bằng code (AudioStreamWAV)
  events/
    environmental_event.gd  # BASE: chuỗi stage cảnh báo → impact; hook _on_*; get_actions()
    wind_event.gd           # gió: cửa sổ + rèm + particles + rung + che chắn
    cat_event.gd            # mèo: LOOK → WALK → CROUCH → JUMP
    event_scheduler.gd      # chọn event kế tiếp, nhịp độ theo tiến độ (WarningSystem timing)
  task/
    domino_task.gd        # BUILD: khay, kéo/xoay/thả, đường dẫn, va chạm + chain reaction theo khoảng cách, recovery
    domino.gd             # data + vẽ 1 quân (RefCounted, state STANDING/FALLING/FALLEN)
  interactables/
    interactable_object.gd  # Area2D base: hitbox, hover, signal `interacted`
  environment/
    window_object.gd, cat.gd, curtain.gd, paper.gd, room_background.gd   # visual + state, không có luật chơi
  systems/
    focus_system.gd       # FOCUS vs AWARENESS: Camera2D zoom + vignette, emit focus_changed
    player_controls.gd    # thao tác không-click: giữ Space / chuột phải = che chắn
    warning_system.gd     # (assist mode, tắt mặc định) banner + nút hành động từ event.get_actions()
    failure_system.gd     # collapse_finished → đổ ít: recovery, đổ nhiều: GameManager.fail()
  ui/
    hud.gd, ui_theme.gd, warning_icon.gd
  debug/
    auto_tester.gd        # bot chơi tự động + chụp screenshot (chỉ chạy khi có cờ dòng lệnh)
```

**Thêm một event mới** = tạo script kế thừa `EnvironmentalEvent`, override `_build_stages()`
(mỗi stage có `phase`, `text`, `duration`), `_on_stage_entered()` (bật tín hiệu trong cảnh),
`_on_resolved()`, `_on_impact()` (gọi `task.gust()` / `task.smash_at()` hoặc API mới), `get_actions()`,
rồi thả node đó vào `Scheduler` trong `main.tscn` và điền `task_path`, `event_id`, `failure_text`,
`missed_signals_text`. Không cần sửa FocusSystem / FailureSystem / HUD.

## Test tự động

```bash
# bot 3D: thả thẳng, thả lệch (đổ), probe dây chuyền 3 quân, rồi bỏ qua cảnh báo → phải thua
godot --path . -- --autotest
# bot xử lý cảnh báo và xếp hết 50 quân → phải thắng
godot --path . -- --autotest --autotest-win
```

Ảnh lưu tại `~/Library/Application Support/Godot/app_userdata/Domino Focus/` (`autotest3d_*.png`).

## Placeholder

- Toàn bộ visual 3D dựng từ primitive (Box/Sphere/Capsule/Cylinder) và StandardMaterial3D — chưa có model thật.
- Âm thanh là tone tổng hợp bằng code; chưa có nhạc nền.
- Icon cảnh báo vẽ bằng code (Web không có emoji font).
- Font mặc định của Godot (hỗ trợ tiếng Việt).

## Nên làm tiếp (phase sau)

- Thêm event: vật rung trên bàn, điện thoại reo, em bé, người gõ cửa… (chỉ cần 1 script + 1 node).
- Cho phép 2 event chồng nhau và cân bằng độ khó theo thời gian thay vì chỉ theo tiến độ.
- Cơ chế "tỉ mỉ" sâu hơn: giữ chuột để đặt, quân lệch thì nghiêng, độ ổn định.
- Che chắn có giới hạn (stamina), cửa sổ tự mở lại ngẫu nhiên.
- Asset 2D thật theo mood ảnh reference, animation mèo, particles bụi/lá đẹp hơn.
- Hỗ trợ touch (đã bật `emulate_mouse_from_touch`) và kiểm tra trên mobile browser.
- Lưu điểm cao / thống kê (localStorage qua `user://` trên Web hoạt động sẵn).
