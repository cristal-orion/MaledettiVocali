import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maledetti_vocali/screens/history_screen.dart';
import 'package:maledetti_vocali/services/groq_service.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

// MethodChannel for native communication
const platform = MethodChannel('com.maledettivocali/converter');

Future<String?> convertFileNatively(String path) async {
  try {
    final String? resultPath = await platform.invokeMethod('convertOpusToWav', {'path': path});
    return resultPath;
  } on PlatformException catch (e) {
    print("Failed to convert file: '${e.message}'.");
    return null;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maledetti Vocali',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TranscriptionScreen(),
    );
  }
}

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  late StreamSubscription _intentDataStreamSubscription;
  String _transcription = "Condividi un file audio per iniziare...";
  bool _isLoading = false;

  final GroqService _groqService = GroqService();

  @override
  void initState() {
    super.initState();
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFile(value.first.path);
      }
    }, onError: (err) {
      print("getMediaStream error: $err");
    });

    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFile(value.first.path);
      }
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  Future<void> _handleSharedFile(String? filePath) async {
    if (filePath == null) return;
    setState(() {
      _isLoading = true;
      _transcription = "Conversione in corso...";
    });

    final convertedFilePath = await convertFileNatively(filePath);

    if (convertedFilePath != null) {
      setState(() {
        _transcription = "Trascrizione in corso...";
      });
      final transcription = await _groqService.transcribe(convertedFilePath);
      if (transcription != null) {
        setState(() {
          _transcription = transcription;
        });
        _saveTranscription(transcription);
      } else {
        setState(() {
          _transcription = "Errore durante la trascrizione.";
        });
      }
    } else {
      setState(() {
        _transcription = "Errore durante la conversione del file.";
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveTranscription(String transcription) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('transcription_history') ?? [];
    history.insert(0, transcription);
    await prefs.setStringList('transcription_history', history);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maledetti Vocali'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Text(_transcription),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_transcription.isNotEmpty && !_isLoading) {
            Share.share(_transcription);
          }
        },
        tooltip: 'Copia o Condividi',
        child: const Icon(Icons.share),
      ),
    );
  }
}
