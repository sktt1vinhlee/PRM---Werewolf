import 'package:dio/dio.dart';

class ApiService {
  // 1. CẤU HÌNH TRỎ VÀO SERVER GAME (Tạm thời giữ cổng 8080 nếu Hùng vẫn dùng Spring Boot)
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://10.0.2.2:8080',
      connectTimeout: const Duration(seconds: 10), 
      receiveTimeout: const Duration(seconds: 10), // Game không cần chờ lâu như AI
    ),
  );

  // 2. HÀM TẠO PHÒNG MỚI (Dành cho Chủ phòng)
  Future<Map<String, dynamic>?> createRoom({
    required String hostName,
    required int maxPlayers, // Số lượng người chơi dự kiến (Thường là 5-11 người)
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        "hostName": hostName,
        "maxPlayers": maxPlayers,
      };

      print("🏠 Đang yêu cầu tạo phòng mới cho: $hostName...");
      final response = await _dio.post('/api/game/create', data: requestData);

      if (response.statusCode == 200) {
        return response.data; // Server nên trả về RoomCode (VD: AXYZ)
      }
    } catch (e) {
      print("❌ Lỗi gọi API Tạo phòng: $e");
    }
    return null;
  }

  // 3. HÀM XIN VÀO PHÒNG (Cho người chơi khác - Màn 1)
  Future<Map<String, dynamic>?> joinRoom({
    required String nickname,
    required String roomCode,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        "nickname": nickname,
        "roomCode": roomCode,
      };

      print("✈️ Đang gửi yêu cầu vào làng (phòng $roomCode) cho: $nickname...");
      final response = await _dio.post('/api/game/join', data: requestData);

      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      if (e is DioException) {
        print("MÃ LỖI SERVER GAME: ${e.response?.statusCode}");
      }
      print("❌ Lỗi gọi API Vào phòng: $e");
    }
    return null;
  }

  // 4. LẤY HỒ SƠ/LỊCH SỬ NGƯỜI CHƠI (Tùy chọn cho Màn hình cá nhân)
  Future<Map<String, dynamic>?> getPlayerProfile({required String nickname}) async {
    try {
      print("🔍 Đang lấy thông tin hồ sơ cho: $nickname");
      final response = await _dio.get(
        '/api/player/profile', 
        queryParameters: {"nickname": nickname}, 
      );

      if (response.statusCode == 200) {
        return response.data; 
      }
    } catch (e) {
      print("❌ Lỗi lấy hồ sơ: $e");
    }
    return null;
  }
}