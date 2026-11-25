# Empaquetado y distribución

Guía para generar los artefactos que se entregan al usuario. Todo se compila
desde este repositorio; no hay binarios de terceros versionados salvo el código
C de `libserialport` dentro de `third_party/`.

| Plataforma | Comando | Salida |
| :--- | :--- | :--- |
| Windows | `flutter build windows --release` | `build/windows/x64/runner/Release/` |
| Android | `flutter build apk --release --split-per-abi` | `build/app/outputs/flutter-apk/app-<abi>-release.apk` |

## 1. Android

### 1.1 Requisitos

| Pieza | Versión | Nota |
| :--- | :--- | :--- |
| Flutter | 3.50.1 o superior | Fija Gradle 9.5.0, AGP 9.3.1 y Kotlin 2.4.20 |
| Android SDK Platform | 36 (`platforms;android-36`) | Flutter lo exige desde 3.50 |
| Build-Tools | 36.0.0 | Lo usa AGP 9 |
| NDK | 28.2.13676358 | Compila `libserialport.so` |
| JDK | 17 | El JBR de Android Studio sirve |

Instalación de lo que falte (PowerShell):

```powershell
$sdk = "$env:LOCALAPPDATA\Android\sdk"
& "$sdk\cmdline-tools\latest\bin\sdkmanager.bat" "platforms;android-36" "ndk;28.2.13676358"
```

### 1.2 Compilar

```powershell
flutter pub get
flutter build apk --release --split-per-abi   # recomendado: ~19-22 MB por ABI
flutter build apk --release                    # universal: ~62 MB, 3 ABIs
```

ABIs generadas: `arm64-v8a` (móviles modernos), `armeabi-v7a` (equipos antiguos)
y `x86_64` (emulador). Dentro de cada APK quedan `libflutter.so`, `libapp.so`,
`libsqlite3.so`, `libdartjni.so` y `libserialport.so`; si falta alguna, la app
arranca pero falla al primer uso de esa capacidad.

Atributos del paquete (`aapt2 dump badging`):

- `package: com.panda.cnc.grbl_app`, etiqueta visible **GRBL CNC**.
- `minSdk 24`, `targetSdk 36` (Android 16), `compileSdk 36`.
- `uses-feature android.hardware.usb.host` **no requerida**: se instala también
  en equipos sin OTG.

### 1.3 Firma

`flutter build apk --release` firma con la **clave de depuración** mientras no
exista `android/key.properties` (que está en `.gitignore` junto con `*.jks`). Es
válido para probar e instalar por `adb`, no para publicar.

Para firmar de verdad, crea el keystore una sola vez:

```powershell
keytool -genkey -v -keystore "$HOME\upload-keystore.jks" -keyalg RSA `
  -keysize 2048 -validity 10000 -alias upload
```

y `android/key.properties` (fuera del repositorio):

```properties
storePassword=********
keyPassword=********
keyAlias=upload
storeFile=C:/Users/<usuario>/upload-keystore.jks
```

`android/app/build.gradle.kts` detecta el fichero y usa esa configuración; si no
existe, cae en la de depuración. En CI se pueden inyectar los cuatro valores
como *secrets* y escribir el fichero antes de compilar.

### 1.4 Instalar en el móvil

```powershell
adb install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

Si aparece `INSTALL_FAILED_USER_RESTRICTED`, el móvil (HyperOS/MIUI) tiene
desactivada la instalación por USB: activa *Opciones de desarrollador →
Instalar por USB* y acepta el aviso que aparece en pantalla.

### 1.5 Qué funciona y qué no en Android

| Capacidad | Estado |
| :--- | :--- |
| CAM láser, contornos, relieve, plóter | ✅ Compila y genera G-code en el isolate |
| Visor 3D, previsualizaciones, proyecto guardado | ✅ |
| Calibración y consola | ✅ (sin máquina conectada no envían nada) |
| **Conexión serie al GRBL** | ❌ Bloqueada con aviso (ADR-047) |

El motivo es que `libserialport` en Android enumera `/dev/bus/usb/...`, pero
abrir el dispositivo requiere que la app pida permiso al `UsbManager` y reciba
el descriptor; el plugin publicado no implementa ese flujo y `open()` falla con
«permiso denegado». La app lo detecta (`PlatformCapabilities.serialSupported`),
deshabilita «Conectar» y explica que el trabajo se prepara aquí y se envía
desde el escritorio. Habilitarlo es trabajo futuro: petición de permiso en
Kotlin + apertura por `fd` (ver R-02).

### 1.6 Parche local de `flutter_libserialport`

`flutter_libserialport` 0.6.0 es la última versión publicada y su
`android/build.gradle` (Gradle 8 + `jcenter()` + AGP 8.7) no se evalúa en
Gradle 9, que Flutter 3.50 impone. Por eso el paquete está vendorizado en
`third_party/flutter_libserialport` y se activa con `dependency_overrides` en
`pubspec.yaml`:

- **Único cambio de fondo:** `android/build.gradle` → `android/build.gradle.kts`
  con `plugins { id("com.android.library") }`, `compileSdk 36`, Java 17 y
  `externalNativeBuild` apuntando al mismo `CMakeLists.txt`.
- El manifiesto del módulo pierde el atributo `package=` (prohibido desde AGP 8).
- El código Dart, el Kotlin del plugin y todas las compilaciones nativas de
  escritorio son idénticos a los publicados.

Al actualizar el plugin hay que comprobar si la versión nueva ya trae un build
compatible; si es así, basta con borrar el override y el directorio.

## 2. Windows

```powershell
flutter build windows --release
```

Salida en `build\windows\x64\runner\Release\`: `grbl_app.exe` más
`flutter_windows.dll`, `serialport.dll` (compilada desde
`third_party/flutter_libserialport/windows`), `sqlite3.dll`,
`dartjni.dll` y los plugins. Para entregar, comprime **toda la carpeta**; el
`.exe` no funciona suelto.

## 3. Verificación antes de entregar

```powershell
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build windows --debug
flutter build apk --release --split-per-abi
aapt2 dump badging build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

Comprobaciones manuales mínimas en el móvil: arranque, abrir un proyecto
guardado (SQLite), cargar una imagen y generar un grabado, y que «Conectar»
aparezca deshabilitado con el aviso de Android.
