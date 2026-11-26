import 'dart:io';

/// Capacidades que dependen de la plataforma de destino.
///
/// Se aíslan aquí para que la UI y los controladores consulten una sola fuente
/// y las pruebas puedan sustituirlas con un provider.
abstract final class PlatformCapabilities {
  /// `true` cuando la app puede enumerar y abrir puertos serie reales.
  ///
  /// - **Escritorio** (Windows/Linux/macOS): `libserialport` por FFI dentro del
  ///   isolate worker; los chips USB-serie los expone el sistema como `COMx` o
  ///   `/dev/ttyUSB*`.
  /// - **Android**: se usa `usb_serial`, que pide permiso al `UsbManager`
  ///   (`UsbManager.requestPermission`) y habla con el chip por *bulk
  ///   transfers*. Requiere USB-OTG y que el móvil alimente al Arduino; el
  ///   sistema muestra un diálogo de permiso la primera vez.
  ///
  /// `false` en plataformas sin host USB (iOS, web), donde la app se limita a
  /// preparar trabajo (CAM, plóter y visor).
  static bool get serialSupported =>
      Platform.isAndroid ||
      Platform.isWindows ||
      Platform.isLinux ||
      Platform.isMacOS;
}
