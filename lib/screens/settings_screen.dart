import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum TranscriptionProvider {
  groq,
  openai,
}

class ProviderConfig {
  final String name;
  final String baseUrl;
  final String model;
  final String hint;

  const ProviderConfig({
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.hint,
  });
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Map<TranscriptionProvider, ProviderConfig> providers = {
    TranscriptionProvider.groq: ProviderConfig(
      name: 'Groq (Gratis)',
      baseUrl: 'https://api.groq.com/openai/v1/audio/transcriptions',
      model: 'whisper-large-v3',
      hint: 'Accedi a console.groq.com/keys e clicca "Create API Key"',
    ),
    TranscriptionProvider.openai: ProviderConfig(
      name: 'OpenAI (A pagamento)',
      baseUrl: 'https://api.openai.com/v1/audio/transcriptions',
      model: 'whisper-1',
      hint: 'Accedi a platform.openai.com/api-keys',
    ),
  };

  TranscriptionProvider _selectedProvider = TranscriptionProvider.groq;
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isApiKeyVisible = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final providerIndex = prefs.getInt('transcription_provider') ?? 0;
    final apiKey = prefs.getString('api_key') ?? '';

    setState(() {
      _selectedProvider = TranscriptionProvider.values[providerIndex];
      _apiKeyController.text = apiKey;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('transcription_provider', _selectedProvider.index);
    await prefs.setString('api_key', _apiKeyController.text.trim());

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Impostazioni salvate'),
            ],
          ),
          backgroundColor: const Color(0xFF00D9FF).withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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
          'Impostazioni',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Section
            const Text(
              'Provider AI',
              style: TextStyle(
                color: Color(0xFF00D9FF),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: TranscriptionProvider.values.map((provider) {
                  final config = providers[provider]!;
                  final isSelected = _selectedProvider == provider;

                  return InkWell(
                    onTap: () => setState(() => _selectedProvider = provider),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: provider != TranscriptionProvider.values.last
                            ? const Border(bottom: BorderSide(color: Colors.white12))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF00D9FF)
                                    : Colors.white38,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Center(
                                    child: Icon(
                                      Icons.circle,
                                      size: 12,
                                      color: Color(0xFF00D9FF),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  config.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Modello: ${config.model}',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            IconButton(
                              icon: const Icon(
                                Icons.help_outline,
                                color: Color(0xFF00D9FF),
                                size: 20,
                              ),
                              onPressed: () => _showApiGuide(provider),
                              tooltip: 'Come ottenere API Key',
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),

            // API Key Section
            const Text(
              'API Key',
              style: TextStyle(
                color: Color(0xFF00D9FF),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _apiKeyController,
                obscureText: !_isApiKeyVisible,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Inserisci la tua API key',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: const Icon(Icons.key, color: Colors.white38),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isApiKeyVisible ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white38,
                    ),
                    onPressed: () {
                      setState(() => _isApiKeyVisible = !_isApiKeyVisible);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _showApiGuide(_selectedProvider),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.help_outline,
                      color: Color(0xFF00D9FF),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Come ottenere la API Key?',
                      style: TextStyle(
                        color: const Color(0xFF00D9FF).withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: const Color(0xFF1A1A2E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1A1A2E),
                        ),
                      )
                    : const Text(
                        'Salva Impostazioni',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // Info Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E).withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white38, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Informazioni',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Groq offre trascrizioni veloci e gratuite (con limiti)\n'
                    '• OpenAI offre alta qualità ma è a pagamento\n'
                    '• La tua API key è salvata solo sul dispositivo',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showApiGuide(TranscriptionProvider provider) {
    final isGroq = provider == TranscriptionProvider.groq;
    final url = isGroq
        ? 'https://console.groq.com/keys'
        : 'https://platform.openai.com/api-keys';
    final providerName = isGroq ? 'Groq' : 'OpenAI';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.key, color: Color(0xFF00D9FF)),
                const SizedBox(width: 12),
                Text(
                  'Come ottenere la API Key $providerName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStep('1', isGroq
                ? 'Vai su console.groq.com/keys'
                : 'Vai su platform.openai.com/api-keys'),
            _buildStep('2', isGroq
                ? 'Accedi o crea un account (puoi usare Google)'
                : 'Accedi o crea un account OpenAI'),
            _buildStep('3', isGroq
                ? 'Clicca su "Create API Key"'
                : 'Clicca su "Create new secret key"'),
            _buildStep('4', 'Copia la chiave e incollala qui'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: Text('Apri $providerName'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: const Color(0xFF1A1A2E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF00D9FF).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFF00D9FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
