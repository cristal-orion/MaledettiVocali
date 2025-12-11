# Maledetti Vocali - Blueprint

## Overview
"Maledetti Vocali" is a Flutter application designed to transcribe voice messages received via WhatsApp and Telegram. It allows users to share audio files from these apps directly to "Maledetti Vocali", which then converts the audio to a compatible format and uses the Groq API (Whisper model) for speech-to-text transcription.

## Project Structure
- `lib/main.dart`: Main entry point, handles file sharing intents, audio conversion, and displays transcription.
- `lib/services/groq_service.dart`: Handles communication with the Groq API.
- `lib/screens/history_screen.dart`: Displays conversion history.
- `android/`: Android native configuration (Kotlin/Gradle).

## Current Status
- **Audio Conversion**: Migrated from a broken native implementation to `ffmpeg_kit_flutter_audio` for robust handling of various audio formats (Opus, OGG, etc.).
- **Transcription**: Uses Groq API (`whisper-large-v3` model).
- **Sharing**: Uses `receive_sharing_intent` to accept audio files from other apps.
- **State**: The app is currently being updated to ensure the conversion pipeline works correctly.

## Recent Changes
- Replaced custom native Android audio conversion code with `ffmpeg_kit_flutter_audio` package.
- Updated `minSdk` to 24 in `android/app/build.gradle.kts` to support `ffmpeg_kit`.
- Cleaned up `MainActivity.kt`.

## Plan
1.  **Test Conversion**: Verify that `ffmpeg_kit` correctly converts WhatsApp voice notes (typically Opus/OGG) to WAV.
2.  **Test API**: Ensure Groq API receives the WAV file and returns the transcription.
3.  **Refinement**: Improve error handling and UI feedback.
