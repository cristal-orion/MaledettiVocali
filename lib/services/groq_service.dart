import 'package:dio/dio.dart';

class GroqService {
  final Dio _dio = Dio();
  final String _apiKey = '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'; // Replace with your Groq API key

  Future<String?> transcribe(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'model': 'whisper-large-v3',
        'language': 'it', // Added language parameter for better accuracy
      });

      final response = await _dio.post(
        'https://api.groq.com/openai/v1/audio/transcriptions',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['text'];
      } else {
        return null;
      }
    } catch (e) {
      print('Error transcribing audio: $e');
      return null;
    }
  }
}
