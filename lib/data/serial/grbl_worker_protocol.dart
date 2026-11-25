/// Protocolo de mensajes entre la UI (cliente) y el isolate que posee el puerto.
///
/// Los mensajes son mapas con claves de texto para poder cruzar la frontera del
/// isolate sin compartir memoria ni objetos nativos.
library;

/// Comandos cliente → worker.
abstract final class GrblWorkerCommand {
  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String listPorts = 'listPorts';
  static const String startPolling = 'startPolling';
  static const String stopPolling = 'stopPolling';
  static const String requestStatus = 'requestStatus';
  static const String stream = 'stream';
  static const String pause = 'pause';
  static const String resume = 'resume';
  static const String stop = 'stop';
  static const String persistDone = 'persistDone';
  static const String jogCancel = 'jogCancel';
  static const String unlock = 'unlock';
  static const String home = 'home';
  static const String readSettings = 'readSettings';
  static const String readParserState = 'readParserState';
  static const String readOffsets = 'readOffsets';
  static const String dispose = 'dispose';
  static const String jog = 'jog';
  static const String writeSettings = 'writeSettings';
  static const String setWorkZero = 'setWorkZero';
}

/// Eventos worker → cliente.
abstract final class GrblWorkerEvent {
  static const String status = 'status';
  static const String message = 'message';
  static const String result = 'result';
  static const String error = 'error';

  /// El worker pausó la máquina y **exige** que el cliente guarde el progreso
  /// antes de continuar con el soft reset (SEG-03).
  static const String persistRequest = 'persistRequest';
}

/// Claves de los mapas de mensaje.
abstract final class GrblWorkerKey {
  static const String command = 'cmd';
  static const String event = 'evt';
  static const String id = 'id';
  static const String data = 'data';
  static const String line = 'line';
  static const String message = 'message';
  static const String portName = 'portName';
  static const String baudRate = 'baudRate';
  static const String intervalMs = 'intervalMs';
  static const String blocks = 'blocks';
  static const String toolOnLine = 'toolOnLine';
  static const String settleMs = 'settleMs';
  static const String ports = 'ports';
  static const String parserState = 'parserState';
  static const String values = 'values';
  static const String feedMmMin = 'feedMmMin';
  static const String absolute = 'absolute';
  static const String changes = 'changes';
  static const String written = 'written';
  static const String axes = 'axes';
}
