import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

class TranscriptionEntry {
  final String text;
  final String sender;
  final DateTime timestamp;

  TranscriptionEntry({
    required this.text,
    required this.sender,
    required this.timestamp,
  });

  factory TranscriptionEntry.fromJson(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr);
      return TranscriptionEntry(
        text: map['text'] ?? jsonStr,
        sender: map['sender'] ?? 'Sconosciuto',
        timestamp: map['timestamp'] != null 
            ? DateTime.parse(map['timestamp']) 
            : DateTime.now(),
      );
    } catch (e) {
      // Fallback for old format (plain text)
      return TranscriptionEntry(
        text: jsonStr,
        sender: 'Sconosciuto',
        timestamp: DateTime.now(),
      );
    }
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'Adesso';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
    if (diff.inHours < 24) return '${diff.inHours} ore fa';
    if (diff.inDays == 1) return 'Ieri';
    if (diff.inDays < 7) return '${diff.inDays} giorni fa';
    
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TranscriptionEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getStringList('transcription_history') ?? [];
    setState(() {
      _history = rawHistory.map((e) => TranscriptionEntry.fromJson(e)).toList();
    });
  }

  Future<void> _deleteEntry(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getStringList('transcription_history') ?? [];
    rawHistory.removeAt(index);
    await prefs.setStringList('transcription_history', rawHistory);
    _loadHistory();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancella tutto?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Questa azione non può essere annullata.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancella', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('transcription_history');
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00D9FF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cronologia',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white54),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nessuna trascrizione',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final entry = _history[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00D9FF).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with sender and time
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D9FF).withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D9FF).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                entry.sender[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF00D9FF),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.sender,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    entry.formattedDate,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white38),
                              color: const Color(0xFF1A1A2E),
                              onSelected: (value) {
                                if (value == 'share') {
                                  Share.share('${entry.sender}:\n${entry.text}');
                                } else if (value == 'delete') {
                                  _deleteEntry(index);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'share',
                                  child: Row(
                                    children: [
                                      Icon(Icons.share, color: Color(0xFF00D9FF), size: 20),
                                      SizedBox(width: 12),
                                      Text('Condividi', style: TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                      SizedBox(width: 12),
                                      Text('Elimina', style: TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Text content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          entry.text,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.5,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
