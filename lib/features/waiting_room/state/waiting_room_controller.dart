import 'package:get/get.dart';
import 'package:flutter/material.dart';
// TODO: Đổi tên package tương ứng
import 'package:werewolf/features/auth/state/auth_controller.dart';

class WaitingRoomController extends GetxController {
  // Lấy dữ liệu từ màn 1 (Tên và Mã phòng)
  final AuthController _authController = Get.find<AuthController>();

  // 1. CÁC BIẾN TRẠNG THÁI (State)
  var roomCode = ''.obs;
  var players = <String>[].obs; // Danh sách tên người chơi
  var isHost = false.obs; // Xác định xem người dùng hiện tại có phải chủ phòng không
  var maxPlayers = 11.obs; // Số lượng tối đa

  @override
  void onInit() {
    super.onInit();
    
    // Khởi tạo dữ liệu ban đầu khi vừa vào phòng
    roomCode.value = _authController.currentRoomCode.value;
    
    // Tạm thời đưa chính mình vào danh sách trước
    players.add(_authController.currentPlayerName.value);

    // Mặc định người tạo phòng đầu tiên sẽ là Host (Tạm thời gán bằng true để test nút bấm)
    isHost.value = true; 

    // Bắt đầu lắng nghe sự kiện người chơi khác gia nhập
    _listenToNewPlayers();
  }

  // 2. HÀM LẮNG NGHE REAL-TIME (Hiện tại giả lập, sau này dùng Socket)
  void _listenToNewPlayers() {
    // TODO: Khi có Socket, thay thế đoạn code giả lập này bằng:
    // socket.on('player-joined', (data) => players.add(data['nickname']));
    
    // GIẢ LẬP: Cứ sau vài giây lại có người mới join phòng để bạn test UI
    Future.delayed(const Duration(seconds: 2), () {
      if (players.length < maxPlayers.value) players.add('Vinh');
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (players.length < maxPlayers.value) players.add('Hùng');
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (players.length < maxPlayers.value) players.add('Quân');
    });
  }

  // 3. HÀM BẮT ĐẦU GAME
  void startGame() {
    // Luật cơ bản: Ma sói cần ít nhất 5 người để chơi
    if (players.length < 5) {
      Get.snackbar(
        'Chưa đủ người!',
        'Game cần tối thiểu 5 người chơi để bắt đầu.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    print("🚀 Đang phát tín hiệu bắt đầu game tới Server...");
    // TODO: Gửi tín hiệu qua Socket để báo tất cả các máy khác chuyển màn hình
    // socket.emit('start-game', {'roomId': roomCode.value});
    
    // Chuyển thẳng sang Màn 3.1 (Pha Ban Đêm của Quân)
    // Get.offAllNamed('/night-phase');
  }

  // 4. HÀM RỜI PHÒNG
  void leaveRoom() {
    print("👋 Rời phòng: ${roomCode.value}");
    // TODO: Báo cho Server biết mình đã thoát
    // socket.emit('leave-room', ...);
    
    players.clear();
    Get.offAllNamed('/login'); // Quay lại màn hình đăng nhập
  }
}