import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:werewolf/core/constants/app_colors.dart';
import 'package:werewolf/features/waiting_room/state/waiting_room_controller.dart';

class WaitingRoomScreen extends StatelessWidget {
  const WaitingRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Khởi tạo Controller của Phòng Chờ
    final WaitingRoomController roomController = Get.put(WaitingRoomController());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'PHÒNG CHỜ',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        // Thêm nút Thoát để người dùng có thể rời phòng
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => roomController.leaveRoom(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Khu vực hiển thị Mã Phòng
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  const Text(
                    'MÃ PHÒNG',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  // Lấy mã phòng trực tiếp từ Controller
                  Obx(() => Text(
                    roomController.roomCode.value.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  )),
                ],
              ),
            ),

            // 2. Tiêu đề danh sách người chơi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Người chơi đã tham gia',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  // Cập nhật số lượng động khi có người mới vào
                  Obx(() => Text(
                    '${roomController.players.length}/${roomController.maxPlayers.value}',
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                  )),
                ],
              ),
            ),

            // 3. Danh sách Avatar người chơi (Bọc trong Obx để lắng nghe thay đổi)
            Expanded(
              child: Obx(() => GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, 
                  childAspectRatio: 0.8, 
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: roomController.players.length,
                itemBuilder: (context, index) {
                  // Lấy tên người chơi từ Controller
                  String playerName = roomController.players[index];
                  // Highlight người chơi đầu tiên (Giả định là Chủ phòng)
                  bool isMe = index == 0; 

                  return Column(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.surface,
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: isMe ? AppColors.accent : Colors.grey, 
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Tên người chơi
                      Text(
                        playerName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isMe ? AppColors.accent : Colors.white,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                },
              )),
            ),

            // 4. Nút Bắt đầu Game (Chỉ hiện nếu là Chủ phòng)
            Obx(() {
              // Ẩn nút nếu không phải Host
              if (!roomController.isHost.value) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Đang chờ chủ phòng bắt đầu...',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                );
              }

              // Hiện nút nếu là Host
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // Gọi hàm startGame từ Controller
                    onPressed: () => roomController.startGame(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      // Làm mờ nút nếu chưa đủ 5 người
                      disabledBackgroundColor: AppColors.surface, 
                    ),
                    child: const Text(
                      'BẮT ĐẦU GAME',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}