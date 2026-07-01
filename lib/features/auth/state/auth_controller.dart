import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
// TODO: Tương lai đổi ApiService thành SocketService để xử lý realtime
import 'package:werewolf/core/network/api_service.dart'; 

class AuthController extends GetxController {
  final ApiService _apiService = ApiService();

  var isLoading = false.obs;
  
  // Lưu thông tin người chơi hiện tại để truyền sang Màn 4 (Phòng chờ) và Màn 3
  var currentPlayerName = ''.obs;
  var currentRoomCode = ''.obs;

  Future<bool> joinRoom({
    required String nickname,
    required String roomCode,
  }) async {
    try {
      isLoading.value = true;

      // TODO: Sau này thay đoạn này bằng SocketIO để join room
      // Ví dụ: _socketService.emit('join-room', {'name': nickname, 'room': roomCode});
      
      // Tạm thời vẫn dùng API HTTP cũ để giữ khung (Cần Hùng cung cấp API Check Room hợp lệ)
      final responseData = await _apiService.joinRoom( 
        nickname: nickname,
        roomCode: roomCode,
      );

      // Giả định response trả về thành công nếu phòng tồn tại và chưa bắt đầu
      if (responseData != null && responseData['status'] == 'success') {
        print("🎉 VÀO LÀNG THÀNH CÔNG: Chào mừng $nickname đến phòng $roomCode!");

        // Ghi nhớ dữ liệu vào State để mang sang Màn 4 (Waiting Room)
        currentPlayerName.value = nickname;
        currentRoomCode.value = roomCode;

        return true;
      } else {
        print("❌ VÀO LÀNG THẤT BẠI: Phòng không tồn tại hoặc đã đầy!");

        Get.snackbar(
          "Lỗi tham gia",
          responseData?['message'] ?? "Không thể vào phòng. Có thể phòng đã đầy hoặc đang chơi!",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );

        return false;
      }
    } catch (e) {
      print("Lỗi kết nối Server Game: $e");
      Get.snackbar(
        "Lỗi kết nối",
        "Không thể kết nối đến máy chủ làng sói. Vui lòng kiểm tra lại mạng!",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}