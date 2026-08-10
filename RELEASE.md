# Come pubblicare una nuova APK

Due regole da rispettare sempre, altrimenti chi ha già l'app installata **non
riesce ad aggiornarla**: Android rifiuta un'APK con versionCode uguale o più
basso di quella installata, e rifiuta un'APK firmata con una chiave diversa.

## 1. Incrementa la versione

In `pubspec.yaml`:

```yaml
version: 1.3.0+4
#        ^^^^^  ^
#        nome   versionCode: DEVE crescere a ogni APK distribuita
```

Il numero dopo il `+` diventa il `versionCode` Android. Se non cambia,
l'installazione sopra la versione precedente fallisce con "App non installata".

Storico (le prime tre release sono state distribuite tutte con versionCode 1,
per questo non erano aggiornabili):

| APK    | versionCode |
| ------ | ----------- |
| v1.0.0 | 1           |
| v1.1.0 | 1 ⚠️        |
| v1.2.0 | 1 ⚠️        |
| v1.3.0 | 4           |

## 2. Usa sempre la stessa keystore

La build cade sulla keystore di debug (`~/.android/debug.keystore`) se non
trova `android/key.properties`. Quel file è locale alla macchina e viene
rigenerato se cancellato: da quel momento le nuove APK hanno una firma diversa
e non si installano sopra quelle già distribuite (l'utente deve disinstallare,
perdendo la cronologia).

Genera la keystore una volta sola:

```bash
keytool -genkey -v -keystore ~/maledetti-vocali-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias maledetti
```

Poi crea `android/key.properties` (già in `.gitignore`):

```properties
storeFile=/home/michele/maledetti-vocali-release.jks
storePassword=la-password-scelta
keyAlias=maledetti
keyPassword=la-password-scelta
```

**Conserva il file `.jks` e le password in un posto sicuro e fuori dal repo.**
Se si perdono, l'unico modo per distribuire un aggiornamento è far
disinstallare e reinstallare l'app a tutti gli utenti.

## 3. Build

```bash
flutter build apk --release --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-release.apk releases/maledetti-vocali-v1.3.0.apk
```

Verifica che la firma sia quella giusta (non deve dire `CN=Android Debug`):

```bash
keytool -printcert -jarfile releases/maledetti-vocali-v1.3.0.apk
```
