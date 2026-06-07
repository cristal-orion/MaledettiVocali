import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TranscriptionProvider {
  groq,
  openai,
}

class ProviderConfig {
  final String baseUrl;
  final String model;
  final String chatBaseUrl;
  final String chatModel;

  const ProviderConfig({
    required this.baseUrl,
    required this.model,
    required this.chatBaseUrl,
    required this.chatModel,
  });
}

class GroqService {
  final Dio _dio = Dio();

  static const Map<TranscriptionProvider, ProviderConfig> _providers = {
    TranscriptionProvider.groq: ProviderConfig(
      baseUrl: 'https://api.groq.com/openai/v1/audio/transcriptions',
      model: 'whisper-large-v3',
      chatBaseUrl: 'https://api.groq.com/openai/v1/chat/completions',
      chatModel: 'llama-3.3-70b-versatile',
    ),
    TranscriptionProvider.openai: ProviderConfig(
      baseUrl: 'https://api.openai.com/v1/audio/transcriptions',
      model: 'whisper-1',
      chatBaseUrl: 'https://api.openai.com/v1/chat/completions',
      chatModel: 'gpt-4o-mini',
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
      'chatBaseUrl': config.chatBaseUrl,
      'chatModel': config.chatModel,
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

  /// Genera un riassunto del testo trascritto usando l'endpoint chat del provider.
  Future<String?> summarize(String text) async {
    try {
      final settings = await _getSettings();

      final response = await _dio.post(
        settings['chatBaseUrl'],
        data: {
          'model': settings['chatModel'],
          'temperature': 0.3,
          'messages': [
            {
              'role': 'system',
              'content':
                  'Sei un assistente che riassume in italiano messaggi vocali trascritti. '
                      'Scrivi un riassunto chiaro e conciso, mantenendo tutte le informazioni '
                      'importanti (date, nomi, richieste, appuntamenti). Usa un elenco puntato '
                      'quando ci sono piu\' punti distinti.',
            },
            {
              'role': 'user',
              'content': 'Riassumi questi messaggi vocali:\n\n$text',
            },
          ],
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${settings['apiKey']}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['choices'][0]['message']['content'];
      } else {
        return null;
      }
    } catch (e) {
      print('Error summarizing text: $e');
      return null;
    }
  }
}
