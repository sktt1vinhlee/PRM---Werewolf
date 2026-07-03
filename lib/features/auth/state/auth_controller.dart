import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
//import 'package:werewolf/core/network/api_service.dart'; 

class AuthController extends GetxController {
  //final ApiService _apiService = ApiService();

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

      // 1. Giả lập thời gian chờ mạng 1.5 giây để nhìn thấy vòng xoay Loading
      await Future.delayed(const Duration(milliseconds: 1500));

      // 2. TẠM THỜI ĐÓNG GỌI API THẬT ĐỂ TEST UI (cần máy chủ máy chủ Backend (Spring Boot/NodeJS))
      /*
      final responseData = await _apiService.joinRoom(
        nickname: nickname,
        roomCode: roomCode,
      );
      */

      // 3. GIẢ LẬP ĐĂNG NHẬP THÀNH CÔNG LUÔN
      print("🎉 [MOCK] VÀO LÀNG THÀNH CÔNG: Chào mừng $nickname đến phòng $roomCode!");
      currentPlayerName.value = nickname;
      currentRoomCode.value = roomCode;

      return true;

    } catch (e) {
      Get.snackbar(
        "Lỗi kết nối",
        "Có lỗi xảy ra: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}