import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:maledetti_vocali/screens/history_screen.dart';
import 'package:maledetti_vocali/screens/settings_screen.dart';
import 'package:maledetti_vocali/services/groq_service.dart';
import 'package:maledetti_vocali/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
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
      theme: AppTheme.dark,
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
  final List<String> _transcriptions = [];
  String _statusText = "Condividi un file audio per iniziare...";
  String _currentSender = '';
  bool _isLoading = false;
  String _summary = '';
  bool _isSummarizing = false;

  // Modalita' batch: accumula i vocali condivisi uno alla volta e li
  // trascrive tutti insieme al comando dell'utente.
  bool _batchMode = false;
  final List<String> _queuedFiles = [];

  static const String _kBatchMode = 'batch_mode';
  static const String _kBatchQueue = 'batch_queue';

  final GroqService _groqService = GroqService();

  bool get _hasResult => _transcriptions.isNotEmpty;

  /// Testo unico (per condivisione e riassunto), numerato se piu' vocali.
  String get _combinedText {
    if (_transcriptions.length == 1) return _transcriptions.first;
    return _transcriptions
        .asMap()
        .entries
        .map((e) => 'Vocale ${e.key + 1}\n${e.value}')
        .join('\n\n');
  }

  @override
  void initState() {
    super.initState();
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    }, onError: (err) {
      print("getMediaStream error: $err");
    });

    // Carica lo stato batch PRIMA di processare la condivisione iniziale,
    // cosi' un eventuale audio condiviso a freddo finisce in coda se serve.
    _restoreThenHandleInitial();
  }

  Future<void> _restoreThenHandleInitial() async {
    await _loadBatchState();
    final value = await ReceiveSharingIntent.instance.getInitialMedia();
    if (value.isNotEmpty) {
      _handleSharedFiles(value);
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Modalita' batch
  // ---------------------------------------------------------------------------

  Future<void> _loadBatchState() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getBool(_kBatchMode) ?? false;
    final queue = prefs.getStringList(_kBatchQueue) ?? [];
    // Tieni solo i file ancora presenti su disco.
    final existing = queue.where((p) => File(p).existsSync()).toList();
    if (!mounted) return;
    setState(() {
      _batchMode = mode;
      _queuedFiles
        ..clear()
        ..addAll(existing);
    });
  }

  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kBatchQueue, _queuedFiles);
  }

  Future<void> _setBatchMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBatchMode, value);
    if (mounted) setState(() => _batchMode = value);
  }

  void _toggleBatchMode() {
    if (_batchMode) {
      _clearQueue();
      _setBatchMode(false);
    } else {
      // Entrando in batch nascondo un eventuale risultato precedente.
      setState(() {
        _transcriptions.clear();
        _summary = '';
      });
      _setBatchMode(true);
    }
  }

  /// Copia un file condiviso in una cartella stabile dell'app, cosi' resta
  /// disponibile anche se Android pulisce la cache mentre sei su WhatsApp.
  Future<String> _persistFile(String srcPath) async {
    final docs = await getApplicationDocumentsDirectory();
    final batchDir = Directory('${docs.path}/batch');
    if (!batchDir.existsSync()) {
      batchDir.createSync(recursive: true);
    }
    final dot = srcPath.lastIndexOf('.');
    final ext = dot >= 0 ? srcPath.substring(dot) : '';
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final dest = '${batchDir.path}/voc_${stamp}_${_queuedFiles.length}$ext';
    await File(srcPath).copy(dest);
    return dest;
  }

  Future<void> _addToQueue(List<SharedMediaFile> files) async {
    for (final f in files) {
      try {
        if (!File(f.path).existsSync()) continue;
        final saved = await _persistFile(f.path);
        _queuedFiles.add(saved);
      } catch (e) {
        print('Errore copia in coda: $e');
      }
    }
    await _saveQueue();
    if (mounted) setState(() {});
  }

  Future<void> _removeFromQueue(int index) async {
    try {
      final f = File(_queuedFiles[index]);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    _queuedFiles.removeAt(index);
    await _saveQueue();
    if (mounted) setState(() {});
  }

  Future<void> _clearQueue() async {
    for (final p in _queuedFiles) {
      try {
        final f = File(p);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    _queuedFiles.clear();
    await _saveQueue();
    if (mounted) setState(() {});
  }

  Future<void> _transcribeBatch() async {
    if (_queuedFiles.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key') ?? '';
    if (apiKey.isEmpty) {
      _showApiKeyMissingDialog();
      return;
    }
    final paths = List<String>.from(_queuedFiles);
    await _runTranscription(paths);
    // Pulisci ed esci dal batch solo se la trascrizione e' andata a buon fine.
    if (_hasResult) {
      await _clearQueue();
      await _setBatchMode(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Ricezione condivisioni + trascrizione
  // ---------------------------------------------------------------------------

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    // In modalita' batch i vocali si accumulano senza trascrivere subito.
    if (_batchMode) {
      await _addToQueue(files);
      return;
    }

    // Modalita' classica: serve la API key e si trascrive subito.
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key') ?? '';
    if (apiKey.isEmpty) {
      _showApiKeyMissingDialog();
      return;
    }

    await _runTranscription(files.map((f) => f.path).toList());
  }

  /// Trascrive in sequenza una lista di percorsi e popola il risultato.
  Future<void> _runTranscription(List<String> paths) async {
    setState(() {
      _isLoading = true;
      _summary = '';
      _transcriptions.clear();
      _statusText = "Trascrizione in corso...";
    });

    final List<String> results = [];

    for (int i = 0; i < paths.length; i++) {
      final filePath = paths[i];

      if (paths.length > 1) {
        setState(() {
          _statusText = "Trascrizione ${i + 1}/${paths.length}...";
        });
      }

      if (!File(filePath).existsSync()) {
        print("File does not exist at path: $filePath");
        continue;
      }

      // Send the file directly to the API without conversion
      // Whisper model supports many formats including opus/ogg
      final transcription = await _groqService.transcribe(filePath);

      if (transcription != null && transcription.trim().isNotEmpty) {
        final text = transcription.trim();
        results.add(text);
        // Save immediately without popup
        _saveTranscription(text, 'Sconosciuto');
      }
    }

    if (results.isEmpty) {
      setState(() {
        _statusText = "Errore durante la trascrizione.";
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _transcriptions
        ..clear()
        ..addAll(results);
      _currentSender = 'Sconosciuto';
      _isLoading = false;
    });
  }

  Future<void> _summarize() async {
    if (_isSummarizing) return;

    setState(() => _isSummarizing = true);

    final summary = await _groqService.summarize(_combinedText);

    setState(() {
      _isSummarizing = false;
      if (summary != null && summary.trim().isNotEmpty) {
        _summary = summary.trim();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante il riassunto. Riprova.'),
            backgroundColor: Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  static const Color _violetText = Color(0xFFB9A8FF);

  Widget _buildSummarizeButton() {
    return InkWell(
      onTap: _isSummarizing ? null : _summarize,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent2.withOpacity(0.30),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSummarizing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.bg,
                ),
              )
            else
              const Icon(Icons.auto_awesome, color: AppColors.bg, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _isSummarizing ? 'Riassumo...' : 'Riassumi',
              style: AppText.button.copyWith(color: AppColors.bg),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accent2.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.accent2.withOpacity(0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.accent2, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('RIASSUNTO', style: AppText.label.copyWith(color: _violetText)),
              const Spacer(),
              InkWell(
                onTap: () => Share.share(_summary),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: Icon(Icons.ios_share, color: _violetText, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableText(_summary, style: AppText.body),
        ],
      ),
    );
  }

  // Intestazione card: icona + etichetta + conteggio vocali.
  Widget _buildCardHeader() {
    final count = _transcriptions.length;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.16),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: const Icon(Icons.graphic_eq, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(count > 1 ? 'TRASCRIZIONI' : 'TRASCRIZIONE', style: AppText.label),
        const Spacer(),
        if (count > 1)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              '$count vocali',
              style: AppText.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // Un blocco per ogni vocale; con badge numerato se piu' di uno.
  List<Widget> _buildVocaleBlocks() {
    final multiple = _transcriptions.length > 1;
    final widgets = <Widget>[];
    for (int i = 0; i < _transcriptions.length; i++) {
      if (i > 0) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Divider(color: AppColors.hairline, height: 1),
        ));
      }
      if (multiple) {
        widgets.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _numberBadge(i + 1),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SelectableText(
                _transcriptions[i],
                style: AppText.body.copyWith(letterSpacing: 0.2),
              ),
            ),
          ],
        ));
      } else {
        widgets.add(SelectableText(
          _transcriptions[i],
          style: AppText.body.copyWith(fontSize: 17, letterSpacing: 0.2),
        ));
      }
    }
    return widgets;
  }

  Widget _numberBadge(int n) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.14),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent.withOpacity(0.35)),
      ),
      child: Text(
        '$n',
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildSenderButton() {
    final hasSender = _currentSender.isNotEmpty && _currentSender != 'Sconosciuto';
    return InkWell(
      onTap: _showEditSenderDialog,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSender ? Icons.person : Icons.person_add_outlined,
              color: AppColors.textFaint,
              size: 16,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(hasSender ? _currentSender : 'Aggiungi mittente', style: AppText.caption),
            if (hasSender)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.edit, color: Color(0x3DFFFFFF), size: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 72),
          Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.18),
                  blurRadius: 40,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: const Icon(Icons.graphic_eq, size: 56, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Condividi un vocale', style: AppText.display.copyWith(fontSize: 24)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Apri WhatsApp o Telegram, seleziona un vocale\ne condividilo qui',
            textAlign: TextAlign.center,
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.xxxl),
          // Entrata in modalita' batch
          OutlinedButton.icon(
            onPressed: _toggleBatchMode,
            icon: const Icon(Icons.layers_outlined, size: 20, color: AppColors.accent),
            label: Text(
              'Attiva modalità batch',
              style: AppText.button.copyWith(color: AppColors.accent, fontSize: 15),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'Per passare più vocali insieme: li condividi uno alla volta e li trascrivi tutti in una volta.',
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Vista modalita' batch
  // ---------------------------------------------------------------------------

  Widget _buildBatchView() {
    final count = _queuedFiles.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner stato batch
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.accent.withOpacity(0.30)),
          ),
          child: Row(
            children: [
              const Icon(Icons.layers, color: AppColors.accent, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MODALITÀ BATCH', style: AppText.label),
                    const SizedBox(height: 2),
                    Text(
                      count == 0 ? 'In attesa di vocali…' : '$count in coda',
                      style: AppText.caption.copyWith(color: AppColors.textMd),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _toggleBatchMode,
                child: Text(
                  'Esci',
                  style: AppText.caption.copyWith(
                    color: AppColors.textLo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        if (count == 0)
          _buildBatchEmptyHint()
        else
          ..._buildQueueItems(),

        const SizedBox(height: AppSpacing.xxl),

        // Pulsante trascrivi
        _buildTranscribeButton(count),
        if (count > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: _clearQueue,
              child: Text(
                'Svuota la coda',
                style: AppText.caption.copyWith(color: AppColors.textLo),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBatchEmptyHint() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          const Icon(Icons.swipe_up_alt_outlined, color: AppColors.accent, size: 40),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Torna su WhatsApp',
            style: AppText.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Condividi i vocali uno alla volta su Maledetti Vocali: '
            'si accumuleranno qui. Quando hai finito, premi Trascrivi.',
            textAlign: TextAlign.center,
            style: AppText.bodyMuted,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQueueItems() {
    final items = <Widget>[];
    for (int i = 0; i < _queuedFiles.length; i++) {
      items.add(Container(
        margin: EdgeInsets.only(bottom: i == _queuedFiles.length - 1 ? 0 : AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            _numberBadge(i + 1),
            const SizedBox(width: AppSpacing.md),
            const Icon(Icons.graphic_eq, color: AppColors.accent, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('Vocale ${i + 1}', style: AppText.body.copyWith(fontSize: 15)),
            ),
            InkWell(
              onTap: () => _removeFromQueue(i),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.xs),
                child: Icon(Icons.close, color: AppColors.textFaint, size: 18),
              ),
            ),
          ],
        ),
      ));
    }
    return items;
  }

  Widget _buildTranscribeButton(int count) {
    final enabled = count > 0;
    return InkWell(
      onTap: enabled ? _transcribeBatch : null,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_motion, color: AppColors.bg, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                count > 0 ? 'Trascrivi ($count)' : 'Trascrivi',
                style: AppText.button.copyWith(color: AppColors.bg),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.accent.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(),
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.hairline, height: 1),
          const SizedBox(height: AppSpacing.lg),
          ..._buildVocaleBlocks(),
          const SizedBox(height: AppSpacing.xl),
          _buildSummarizeButton(),
          if (_summary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildSummaryBox(),
          ],
          const SizedBox(height: AppSpacing.xl),
          _buildSenderButton(),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(_statusText, style: AppText.bodyMuted, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Icon(Icons.mic, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            const Text('Maledetti Vocali', style: AppText.title),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.accent),
            tooltip: 'Cronologia',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textLo),
            tooltip: 'Impostazioni',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: _isLoading
            ? _buildLoading()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: _batchMode
                    ? _buildBatchView()
                    : (_hasResult ? _buildResultCard() : _buildEmptyState()),
              ),
      ),
      floatingActionButton: _hasResult
          ? FloatingActionButton.extended(
              onPressed: () => Share.share(_combinedText),
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bg,
              icon: const Icon(Icons.ios_share, color: AppColors.bg),
              label: Text('Condividi', style: AppText.button.copyWith(color: AppColors.bg)),
            )
          : null,
    );
  }
}
