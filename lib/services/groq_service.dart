import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TranscriptionProvider {
  groq,
  openai,
}

class ProviderConfig {
  final String baseUrl;
  final String model;

  const ProviderConfig({required this.baseUrl, required this.model});
}

class GroqService {
  final Dio _dio = Dio();
  
  static const Map<TranscriptionProvider, ProviderConfig> _providers = {
    TranscriptionProvider.groq: ProviderConfig(
      baseUrl: 'https://api.groq.com/openai/v1/audio/transcriptions',
      model: 'whisper-large-v3',
    ),
    TranscriptionProvider.openai: ProviderConfig(
      baseUrl: 'https://api.openai.com/v1/audio/transcriptions',
      model: 'whisper-1',
    ),
  };

  Future<Map<String, dynamic>> _getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final providerIndex = prefs.getInt('transcription_provider') ?? 0;
    final apiKey = prefs.getString('api_key') ?? '';
    
    final provider = TranscriptionProvider.values[providerIndex];
    final config = _providers[provider]!;
    
    return {
      'apiKey': apiKey,
      'baseUrl': config.baseUrl,
      'model': config.model,
    };
  }

  Future<String?> transcribe(String filePath) async {
    try {
      final settings = await _getSettings();
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'model': settings['model'],
        'language': 'it',
      });

      final response = await _dio.post(
        settings['baseUrl'],
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${settings['apiKey']}',
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
