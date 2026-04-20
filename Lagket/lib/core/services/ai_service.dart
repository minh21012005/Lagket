import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aiServiceProvider = Provider((ref) => AIService());

class AIService {
  late final GenerativeModel _model;

  AIService() {
    const String apiKey = 'AIzaSyC0bypkQw3FdmOnJBXQE34r-mP-0Gaeym4';

    _model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: apiKey,
    );
  }

  List<String> getDefaultCaptions() {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    
    return [
      "Tận hưởng khoảnh khắc này ✨",
      "$timeStr 📸",
      "Kỷ niệm đáng nhớ ngày hôm nay 🌟"
    ];
  }

  Future<List<String>> generateCaptions(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      final content = [
        Content.multi([
          TextPart("Hãy gợi ý 3 câu caption ngắn gọn, bắt trend cho ảnh này bằng tiếng Việt. "
              "Mỗi câu bắt buộc kết thúc bằng 1-2 emoji phù hợp. "
              "Chỉ trả về đúng 3 dòng, không đánh số. Ví dụ format mẫu: Cà phê sáng chill chill ☕✨"),
          DataPart('image/jpeg', bytes),
        ])
      ];

      final response = await _model.generateContent(content);
      final text = response.text;

      if (text == null || text.isEmpty) {
        return ["Tuyệt vời! 🌟", "Khoảnh khắc đáng nhớ", "Yêu đời quá! ❤️"];
      }

      return text
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .take(3)
          .map((line) => line.replaceAll(RegExp(r'^[-\*\d+\.]\s*'), '').trim())
          .toList();

    } catch (e) {
      print('AI Caption Generation Error: $e');
      throw Exception('Mạng chậm hoặc AI đang bận. Vui lòng thử lại!');
    }
  }
}