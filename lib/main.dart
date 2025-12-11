import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:maledetti_vocali/screens/history_screen.dart';
import 'package:maledetti_vocali/screens/settings_screen.dart';
import 'package:maledetti_vocali/services/groq_service.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maledetti Vocali',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        primaryColor: const Color(0xFF00D9FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D9FF),
          surface: Color(0xFF16213E),
          background: Color(0xFF1A1A2E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16213E),
          elevation: 0,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
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
  String _currentSender = '';
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
    
    // Check if API key is configured
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key') ?? '';
    
    if (apiKey.isEmpty) {
      _showApiKeyMissingDialog();
      return;
    }
    
    setState(() {
      _isLoading = true;
      _transcription = "Trascrizione in corso...";
    });

    // Check if file exists
    if (!File(filePath).existsSync()) {
      print("File does not exist at path: $filePath");
      setState(() {
        _transcription = "Errore: file non trovato.";
        _isLoading = false;
      });
      return;
    }

    // Send the file directly to Groq API without conversion
    // Whisper model supports many formats including opus/ogg
    final transcription = await _groqService.transcribe(filePath);
    
    if (transcription != null) {
      setState(() {
        _transcription = transcription;
        _currentSender = 'Sconosciuto';
      });
      // Save immediately without popup
      _saveTranscription(transcription, 'Sconosciuto');
    } else {
      setState(() {
        _transcription = "Errore durante la trascrizione.";
      });
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveTranscription(String transcription, String senderName) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('transcription_history') ?? [];
    
    // Save as JSON with metadata
    final entry = jsonEncode({
      'text': transcription,
      'sender': senderName.isEmpty ? 'Sconosciuto' : senderName,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    history.insert(0, entry);
    await prefs.setStringList('transcription_history', history);
  }

  Future<void> _updateLastTranscriptionSender(String senderName) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('transcription_history') ?? [];
    
    if (history.isNotEmpty) {
      try {
        final lastEntry = jsonDecode(history[0]);
        lastEntry['sender'] = senderName.isEmpty ? 'Sconosciuto' : senderName;
        history[0] = jsonEncode(lastEntry);
        await prefs.setStringList('transcription_history', history);
        setState(() {
          _currentSender = senderName.isEmpty ? 'Sconosciuto' : senderName;
        });
      } catch (e) {
        print('Error updating sender: $e');
      }
    }
  }

  void _showApiKeyMissingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.key_off, color: Color(0xFFFF6B6B)),
            SizedBox(width: 12),
            Text(
              'API Key mancante',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'Per trascrivere i vocali devi prima configurare la tua API Key nelle impostazioni.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Annulla',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Vai alle Impostazioni'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSenderDialog() async {
    final TextEditingController controller = TextEditingController(
      text: _currentSender == 'Sconosciuto' ? '' : _currentSender,
    );
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Color(0xFF00D9FF), size: 22),
            SizedBox(width: 10),
            Text(
              'Aggiungi mittente',
              style: TextStyle(color: Colors.white, fontSize: 17),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nome o chat',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.person, color: Color(0xFF00D9FF)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Annulla',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              _updateLastTranscriptionSender(controller.text);
              Navigator.pop(context);
            },
            child: const Text(
              'Salva',
              style: TextStyle(color: Color(0xFF00D9FF), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasTranscription = _transcription != "Condividi un file audio per iniziare..." && 
                                   !_transcription.startsWith("Errore") &&
                                   !_transcription.contains("in corso");
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.mic, color: Color(0xFF00D9FF)),
            SizedBox(width: 8),
            Text(
              'Maledetti Vocali',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF00D9FF)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white54),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF00D9FF),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _transcription,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasTranscription)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16213E),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00D9FF).withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.share,
                              size: 60,
                              color: Color(0xFF00D9FF),
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Condividi un vocale',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Apri WhatsApp o Telegram,\nseleziona un vocale e condividilo qui',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF00D9FF).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D9FF).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.text_snippet,
                                  color: Color(0xFF00D9FF),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Trascrizione',
                                style: TextStyle(
                                  color: Color(0xFF00D9FF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 16),
                          SelectableText(
                            _transcription,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              height: 1.6,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Add sender button
                          InkWell(
                            onTap: _showEditSenderDialog,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A2E),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _currentSender.isEmpty || _currentSender == 'Sconosciuto'
                                        ? Icons.person_add_outlined
                                        : Icons.person,
                                    color: Colors.white38,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currentSender.isEmpty || _currentSender == 'Sconosciuto'
                                        ? 'Aggiungi mittente'
                                        : _currentSender,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (_currentSender.isNotEmpty && _currentSender != 'Sconosciuto')
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Icons.edit,
                                        color: Colors.white24,
                                        size: 14,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: hasTranscription
          ? FloatingActionButton.extended(
              onPressed: () {
                Share.share(_transcription);
              },
              backgroundColor: const Color(0xFF00D9FF),
              icon: const Icon(Icons.share, color: Color(0xFF1A1A2E)),
              label: const Text(
                'Condividi',
                style: TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
}
