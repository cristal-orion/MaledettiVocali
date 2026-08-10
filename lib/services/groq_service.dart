import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TranscriptionProvider {
  groq,
  openai,
}

/// Tipo di errore, cosi' la UI puo' proporre l'azione giusta
/// (es. aprire le impostazioni quando la chiave non e' valida).
enum AiErrorKind {
  missingKey,
  auth,
  rateLimit,
  tooLarge,
  format,
  network,
  server,
  empty,
  unknown,
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

/// Esito di una chiamata all'API: o il testo, o un messaggio d'errore
/// gia' pronto da mostrare all'utente.
class AiResult {
  final String? text;
  final String? error;
  final AiErrorKind? kind;

  const AiResult.success(String this.text)
      : error = null,
        kind = null;

  const AiResult.failure(String this.error, this.kind) : text = null;

  /// Richiesta annullata dall'utente: non c'e' nessun errore da mostrare.
  const AiResult.cancelled()
      : text = null,
        error = null,
        kind = null;

  bool get isSuccess => text != null;
  bool get isCancelled => text == null && error == null;
}

class _Settings {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String chatBaseUrl;
  final String chatModel;

  const _Settings({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.chatBaseUrl,
    required this.chatModel,
  });
}

class GroqService {
  GroqService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
          // Gli status 4xx/5xx li interpretiamo noi: niente eccezioni.
          validateStatus: (_) => true,
        ));

  final Dio _dio;

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

  Future<_Settings> _getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final providerIndex = prefs.getInt('transcription_provider') ?? 0;
    final apiKey = prefs.getString('api_key') ?? '';

    // Indice fuori range (prefs vecchie o corrotte): torna al default.
    final provider = providerIndex >= 0 &&
            providerIndex < TranscriptionProvider.values.length
        ? TranscriptionProvider.values[providerIndex]
        : TranscriptionProvider.groq;
    final config = _providers[provider]!;

    return _Settings(
      apiKey: apiKey,
      baseUrl: config.baseUrl,
      model: config.model,
      chatBaseUrl: config.chatBaseUrl,
      chatModel: config.chatModel,
    );
  }

  Future<AiResult> transcribe(
    String filePath, {
    CancelToken? cancelToken,
  }) async {
    final settings = await _getSettings();
    if (settings.apiKey.isEmpty) {
      return const AiResult.failure(
        'API key mancante: configurala nelle impostazioni.',
        AiErrorKind.missingKey,
      );
    }

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'model': settings.model,
        'language': 'it',
      });

      final response = await _dio.post(
        settings.baseUrl,
        data: formData,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${settings.apiKey}',
          },
        ),
      );

      if (response.statusCode == 200) {
        final text = (response.data['text'] as String?)?.trim() ?? '';
        if (text.isEmpty) {
          return const AiResult.failure(
            'Nessun parlato riconosciuto in questo vocale.',
            AiErrorKind.empty,
          );
        }
        return AiResult.success(text);
      }
      return _failureForStatus(response.statusCode, response.data, audio: true);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return const AiResult.cancelled();
      return _failureForException(e);
    } catch (e) {
      debugPrint('Errore trascrizione: $e');
      return const AiResult.failure(
        'Errore inatteso durante la trascrizione.',
        AiErrorKind.unknown,
      );
    }
  }

  /// Genera un riassunto del testo trascritto usando l'endpoint chat del provider.
  Future<AiResult> summarize(
    String text, {
    CancelToken? cancelToken,
  }) async {
    final settings = await _getSettings();
    if (settings.apiKey.isEmpty) {
      return const AiResult.failure(
        'API key mancante: configurala nelle impostazioni.',
        AiErrorKind.missingKey,
      );
    }

    try {
      final response = await _dio.post(
        settings.chatBaseUrl,
        cancelToken: cancelToken,
        data: {
          'model': settings.chatModel,
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
            'Authorization': 'Bearer ${settings.apiKey}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final content =
            (response.data['choices'][0]['message']['content'] as String?)
                    ?.trim() ??
                '';
        if (content.isEmpty) {
          return const AiResult.failure(
            'Il riassunto e\' arrivato vuoto. Riprova.',
            AiErrorKind.empty,
          );
        }
        return AiResult.success(content);
      }
      return _failureForStatus(response.statusCode, response.data, audio: false);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return const AiResult.cancelled();
      return _failureForException(e);
    } catch (e) {
      debugPrint('Errore riassunto: $e');
      return const AiResult.failure(
        'Errore inatteso durante il riassunto.',
        AiErrorKind.unknown,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Traduzione degli errori in messaggi leggibili
  // ---------------------------------------------------------------------------

  AiResult _failureForStatus(
    int? status,
    dynamic body, {
    required bool audio,
  }) {
    final detail = _apiMessage(body);

    switch (status) {
      case 400:
        return AiResult.failure(
          detail ??
              (audio
                  ? 'Il provider ha rifiutato il file audio: formato non supportato.'
                  : 'Richiesta non valida.'),
          AiErrorKind.format,
        );
      case 401:
      case 403:
        return const AiResult.failure(
          'API key non valida o senza permessi. Controllala nelle impostazioni.',
          AiErrorKind.auth,
        );
      case 413:
        return const AiResult.failure(
          'Vocale troppo grande: il limite del provider e\' 25 MB.',
          AiErrorKind.tooLarge,
        );
      case 429:
        return const AiResult.failure(
          'Limite di richieste del provider raggiunto. Riprova tra qualche minuto.',
          AiErrorKind.rateLimit,
        );
      default:
        if (status != null && status >= 500) {
          return const AiResult.failure(
            'Il servizio del provider non risponde. Riprova piu\' tardi.',
            AiErrorKind.server,
          );
        }
        debugPrint('Risposta inattesa dal provider: $status $body');
        return AiResult.failure(
          detail ?? 'Errore dal provider (codice ${status ?? '?'}).',
          AiErrorKind.unknown,
        );
    }
  }

  AiResult _failureForException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AiResult.failure(
          'Tempo scaduto: connessione lenta o vocale troppo lungo.',
          AiErrorKind.network,
        );
      case DioExceptionType.connectionError:
        return const AiResult.failure(
          'Nessuna connessione a internet.',
          AiErrorKind.network,
        );
      default:
        debugPrint('Errore di rete: $e');
        return const AiResult.failure(
          'Errore di rete durante la richiesta.',
          AiErrorKind.network,
        );
    }
  }

  /// Estrae il messaggio d'errore dal corpo JSON del provider, se c'e'.
  String? _apiMessage(dynamic body) {
    try {
      if (body is Map) {
        final error = body['error'];
        if (error is Map && error['message'] is String) {
          final message = (error['message'] as String).trim();
          if (message.isNotEmpty) return message;
        }
      }
    } catch (_) {}
    return null;
  }
}
