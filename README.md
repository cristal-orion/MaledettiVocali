# 🎙️ Maledetti Vocali

<p align="center">
  <img src="LogoMaledettivocali.png" width="200" alt="Maledetti Vocali Logo">
</p>

<p align="center">
  <b>Transcribe voice messages from WhatsApp, Telegram, and other apps instantly!</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.38-blue?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.10-blue?logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/Platform-Android-green?logo=android" alt="Android">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License">
</p>

---

## 📖 About

**Maledetti Vocali** (Italian for "Damn Voice Messages") is a Flutter app that transcribes audio messages shared from messaging apps like WhatsApp, Telegram, and others. 

Tired of listening to long voice messages? Just share them with Maledetti Vocali and get instant text transcriptions!

## ✨ Features

- 🎯 **Easy Sharing** - Share audio directly from WhatsApp, Telegram, or any app
- 🔊 **Multiple Format Support** - Works with OGG, OPUS, MP3, M4A, WAV, and more
- 🤖 **AI-Powered** - Uses Whisper models for accurate transcriptions
- 🌐 **Multi-Provider** - Choose between Groq (free) or OpenAI
- 📝 **History** - Keep track of all your transcriptions with sender names
- 🌙 **Dark Theme** - Beautiful modern dark UI
- 📤 **Share Results** - Easily share transcriptions with others
- 🔒 **Privacy First** - API keys stored locally on device only

## 📱 Screenshots

| Home | Settings | History |
|:---:|:---:|:---:|
| Transcription screen | API configuration | Past transcriptions |

## 🚀 Getting Started

### Prerequisites

- Flutter 3.x or higher
- Android SDK
- A free API key from [Groq](https://console.groq.com/keys) or [OpenAI](https://platform.openai.com/api-keys)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/cristal-orion/MaledettiVocali.git
   cd MaledettiVocali
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Build APK

```bash
# Debug build
flutter build apk --debug

# Release build (single ABI, smaller size)
flutter build apk --release --target-platform android-arm64

# Release build (all ABIs)
flutter build apk --release
```

## 📥 Download

Download the latest APK from the [Releases](https://github.com/cristal-orion/MaledettiVocali/releases) page.

## 🔑 API Key Setup

1. Open the app and go to **Settings** (gear icon)
2. Select your provider:
   - **Groq (Free)** - Recommended for most users
   - **OpenAI (Paid)** - Higher quality, but costs money
3. Click "How to get API Key?" for step-by-step instructions
4. Paste your API key and save

### Getting a Free Groq API Key

1. Go to [console.groq.com/keys](https://console.groq.com/keys)
2. Sign in or create an account (Google login available)
3. Click "Create API Key"
4. Copy the key and paste it in the app

## 🛠️ Tech Stack

- **Framework**: Flutter 3.38 / Dart 3.10
- **AI Models**: Whisper (via Groq or OpenAI)
- **HTTP Client**: Dio
- **Storage**: SharedPreferences
- **Analytics**: Firebase Analytics & Crashlytics

## 📂 Project Structure

```
lib/
├── main.dart                 # App entry point & main screen
├── firebase_options.dart     # Firebase configuration
├── screens/
│   ├── history_screen.dart   # Transcription history
│   └── settings_screen.dart  # Provider & API key settings
└── services/
    └── groq_service.dart     # Transcription service
```

## 🤝 Contributing

Contributions are welcome! Feel free to:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Cristal Orion**

- GitHub: [@cristal-orion](https://github.com/cristal-orion)

## 🙏 Acknowledgments

- [Groq](https://groq.com/) for providing free Whisper API access
- [OpenAI](https://openai.com/) for the Whisper model
- Flutter team for the amazing framework

---

<p align="center">
  Made with ❤️ in Italy 🇮🇹
</p>
