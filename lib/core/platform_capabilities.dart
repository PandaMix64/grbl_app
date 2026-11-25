import 'dart:io';

/// Capacidades que dependen de la plataforma de destino.
///
/// Se aíslan aquí para que la UI y los controladores consulten una sola fuente
/// y las pruebas puedan sustituirlas con un provider.
abstract final class PlatformCapabilities {
  /// `true` cuando la app puede enumerar y abrir puertos serie reales.
  ///
  /// En Android el APK incluye `libserialport` (compilado con NDK) y la
  /// enumeración devuelve rutas de `/dev/bus/usb/...`, pero abrir el
  /// dispositivo exige que Android conceda el permiso USB a la app
  /// (`UsbManager.requestPermission` y apertura desde el descriptor), un flujo
  /// que el plugin publicado no implementa. Sin él, cualquier `open()` falla
  /// con «permiso denegado». Por eso en Android la app se limita a preparar
  /// trabajo (CAM, plóter y visor) y la conexión serie se bloquea con un aviso
  /// en lugar de mostrar un error críptico.
  static bool get serialSupported => !Platform.isAndroid;
}
