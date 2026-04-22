import 'dart:io';
import 'dart:math';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final aiServiceProvider = Provider((ref) => AIService());

class AIService {
  GenerativeModel? _model;

  Future<void> _initModel() async {
    if (_model != null) return;

    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      print("Cảnh báo: Không tìm thấy file .env, đang thử dùng biến môi trường hệ thống.");
    }

    final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      throw Exception('Chưa cấu hình API Key trong file .env');
    }

    _model = GenerativeModel(
      model: 'gemini-flash-lite-latest',
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
      await _initModel();

      final bytes = await imageFile.readAsBytes();

      final content = [
        Content.multi([
          TextPart("Hãy gợi ý 3 câu caption ngắn gọn, bắt trend cho ảnh này bằng tiếng Việt. "
              "Mỗi câu bắt buộc kết thúc bằng 1-2 emoji phù hợp. "
              "Chỉ trả về đúng 3 dòng, không đánh số. Ví dụ format mẫu: Cà phê sáng chill chill ☕✨"),
          DataPart('image/jpeg', bytes),
        ])
      ];

      final response = await _model!.generateContent(content);
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

  /// Phân tích ảnh và trả về mô tả chi tiết để dùng cho việc gen ảnh
  Future<String> describeImage(File imageFile) async {
    try {
      await _initModel();
      final bytes = await imageFile.readAsBytes();

      final content = [
        Content.multi([
          TextPart("Describe this image in detail but concisely in English. "
              "Focus on the main subjects, colors, and lighting. "
              "Output only the description."),
          DataPart('image/jpeg', bytes),
        ])
      ];

      final response = await _model!.generateContent(content);
      return response.text ?? "A beautiful scene";
    } catch (e) {
      print('AI Image Description Error: $e');
      return "A beautiful photo";
    }
  }

  /// Trả về 3 URL ảnh đã được "làm đẹp" bằng AI của Cloudinary.
  /// Giữ nguyên nội dung gốc, chỉ chỉnh màu sắc, ánh sáng, độ nét.
  List<String> getEnhancedImageUrls(String originalUrl, {int seed = 0}) {
    if (!originalUrl.contains('res.cloudinary.com')) {
      return [originalUrl, originalUrl, originalUrl];
    }

    // Tách URL Cloudinary để chèn tham số biến đổi (transformations)
    // Format: https://res.cloudinary.com/demo/image/upload/v1/sample.jpg
    final parts = originalUrl.split('/upload/');
    if (parts.length != 2) return [originalUrl, originalUrl, originalUrl];

    final baseUrl = parts[0];
    final imagePath = parts[1];

    // Danh sách 10 phong cách làm đẹp
    final variations = [
      // 1. "Hyper Color" - Nổ tung màu sắc (Saturation & Vibrance kịch kim)
      'c_fill,f_auto,q_auto,e_vibrance:100,e_saturation:80,e_contrast:30',

      // 2. "Inferno" - Đỏ rực như lửa (Can thiệp sâu vào kênh Đỏ/Xanh lá)
      'c_fill,f_auto,q_auto,e_red:50,e_green:20,e_contrast:80',

      // 3. "Razor Sharp" - Sắc nét gai góc (Sharpen cực độ)
      'c_fill,f_auto,q_auto,e_sharpen:800,e_contrast:50',

      // 4. "Shadow Realm" - Tối tăm và bí ẩn (Ép độ sáng xuống thấp, đẩy tương phản)
      'c_fill,f_auto,q_auto,e_brightness:-40,e_contrast:100,e_saturation:-50',

      // 5. "1920s Ruined" - Phim cũ hỏng nặng (Sepia + Nhiễu hạt + Viền đen)
      'c_fill,f_auto,q_auto,e_sepia:100,e_noise:40,e_vignette:70',

      // 6. "Ghost White" - Sáng loá, nhợt nhạt (Phá vỡ Gamma và Contrast)
      'c_fill,f_auto,q_auto,e_brightness:40,e_contrast:-60,e_gamma:150',

      // 7. "Sin City" - Đen trắng kịch tính (Trắng đen + Tương phản tuyệt đối)
      'c_fill,f_auto,q_auto,e_grayscale,e_contrast:150',

      // 8. "Glacier Icy" - Lạnh lẽo đóng băng (Kích kênh Xanh dương, gọt kênh Đỏ)
      'c_fill,f_auto,q_auto,e_blue:70,e_red:-40,e_contrast:30',

      // 9. "Acid Trip" - Đảo lộn dải màu quang phổ (Xoay Hue)
      'c_fill,f_auto,q_auto,e_hue:120,e_saturation:100',

      // 10. "Paper Flat" - Bạc màu, phẳng lì (Giảm tương phản và độ bão hòa chạm đáy)
      'c_fill,f_auto,q_auto,e_contrast:-70,e_saturation:-80,e_brightness:30',
    ];

    // Lấy ngẫu nhiên 3 phần tử dựa trên seed
    final random = Random(seed);
    final selectedVariations = (List.of(variations)..shuffle(random)).take(3).toList();

    return selectedVariations.map((transform) => '$baseUrl/upload/$transform/$imagePath').toList();
  }
}