# Maledetti Vocali - Blueprint

## Overview

Maledetti Vocali is a Flutter application designed to transcribe voice messages shared from other apps like WhatsApp or Telegram. It leverages the Groq API for fast speech-to-text conversion and provides a simple interface for users to read, copy, and share the transcriptions.

## Features

- **Android Share Integration**: The app will appear in the Android share menu for audio files.
- **Audio Conversion**: It will convert `.opus` files to `.mp3` locally.
- **Transcription**: It will use the Groq API for speech-to-text.
- **Transcription Display**: It will show the transcription in a clean and readable format.
- **History**: It will save transcriptions for later viewing.
- **Firebase Integration**: It will use Firebase for analytics and crashlytics.

## Current Plan

1.  **Project Setup**: Configure `pubspec.yaml` with all necessary dependencies.
2.  **Android Configuration**: Set up `AndroidManifest.xml` to receive share intents.
3.  **UI/UX**: Create the main screen, transcription display, and history screen.
4.  **Services**: Implement services for file handling, API calls, and history management.
5.  **Firebase**: Integrate Firebase for analytics and crash reporting.
