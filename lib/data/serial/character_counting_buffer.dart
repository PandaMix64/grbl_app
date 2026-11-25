import 'dart:collection';

import '../../core/grbl/grbl_constants.dart';

/// Error de uso del presupuesto de caracteres (línea imposible de enviar).
class CharacterBudgetException implements Exception {
  const CharacterBudgetException(this.message);

  final String message;

  @override
  String toString() => 'CharacterBudgetException: $message';
}

class _InFlightLine {
  const _InFlightLine(this.line, this.bytes);

  final String line;
  final int bytes;
}

/// Control de flujo por conteo de caracteres para GRBL v1.1.
///
/// GRBL tiene un búfer de recepción pequeño (128 B por defecto) y responde `ok`
/// cuando **parsea y encola** cada bloque, no cuando lo ejecuta. Este control
/// mantiene un presupuesto de bytes en vuelo:
///
/// * cada línea enviada consume `longitud + 1` (el `\r`),
/// * cada `ok` **o `error:`** libera el espacio de la línea más antigua,
/// * los comandos en tiempo real **no** pasan por aquí: los consume la ISR antes
///   de entrar al búfer, por lo que no consumen presupuesto.
///
/// Es lógica pura, sin I/O, para poder probarla con miles de líneas sin
/// hardware (ver `docs/revision_tecnica_ruta_de_accion.md`, P1-4).
class CharacterCountingBuffer {
  CharacterCountingBuffer({
    this.bufferSize = kDefaultRxBufferSize,
    this.reserve = kRxBufferReserve,
  }) : assert(bufferSize > 0, 'El búfer debe ser positivo'),
       assert(reserve >= 0 && reserve < bufferSize, 'Reserva inválida');

  /// Tamaño del búfer de recepción de GRBL (`RX_BUFFER_SIZE`).
  final int bufferSize;

  /// Bytes que nunca se ofrecen, como margen de seguridad.
  final int reserve;

  final Queue<String> _pending = Queue<String>();
  final Queue<_InFlightLine> _inFlight = Queue<_InFlightLine>();
  int _bytesInFlight = 0;

  /// Presupuesto útil de bytes.
  int get budget => bufferSize - reserve;

  /// Bytes enviados y todavía no confirmados.
  int get bytesInFlight => _bytesInFlight;

  /// Bytes que aún caben en el búfer del controlador.
  int get available => budget - _bytesInFlight;

  /// Líneas en espera de ser enviadas.
  int get pendingCount => _pending.length;

  /// Líneas enviadas pendientes de `ok`/`error`.
  int get inFlightCount => _inFlight.length;

  /// Indica si queda trabajo por enviar (pendiente o en vuelo).
  bool get isBusy => _pending.isNotEmpty || _inFlight.isNotEmpty;

  /// Encola una línea de G-code o un comando `$`.
  ///
  /// Se normaliza quitando los terminadores para que el conteo sea exacto.
  void enqueue(String line) {
    final String normalized = _normalize(line);
    if (normalized.isEmpty) {
      throw const CharacterBudgetException(
        'No se encolan líneas vacías: GRBL respondería ok sin ejecutar nada.',
      );
    }
    final int bytes = normalized.length + 1;
    if (bytes > budget) {
      throw CharacterBudgetException(
        'La línea ocupa $bytes B y el presupuesto es de $budget B. '
        'Divide el bloque antes de enviarlo.',
      );
    }
    _pending.add(normalized);
  }

  /// Encola varias líneas en orden.
  void enqueueAll(Iterable<String> lines) {
    for (final String line in lines) {
      enqueue(line);
    }
  }

  /// Extrae las líneas que caben ahora y las marca como en vuelo.
  List<String> drainSendable() {
    final List<String> sendable = <String>[];
    while (_pending.isNotEmpty) {
      final String line = _pending.first;
      final int bytes = line.length + 1;
      if (bytes > available) {
        break;
      }
      _pending.removeFirst();
      _inFlight.add(_InFlightLine(line, bytes));
      _bytesInFlight += bytes;
      sendable.add(line);
    }
    return sendable;
  }

  /// Confirma un `ok`: libera la línea más antigua.
  void acknowledgeOk() => _releaseOldest();

  /// Confirma un `error:`: también libera la línea más antigua.
  ///
  /// Si no se liberara en el error, el contador se congelaría y el streaming se
  /// detendría indefinidamente.
  void acknowledgeError() => _releaseOldest();

  /// Línea más antigua sin confirmar, para diagnóstico.
  String? get oldestInFlight => _inFlight.isEmpty ? null : _inFlight.first.line;

  /// Descarta lo pendiente pero conserva lo que está en vuelo.
  void clearPending() => _pending.clear();

  /// Reinicia el control (tras un soft reset o una reconexión).
  void reset() {
    _pending.clear();
    _inFlight.clear();
    _bytesInFlight = 0;
  }

  void _releaseOldest() {
    if (_inFlight.isEmpty) {
      // Respuesta no solicitada (por ejemplo, el `ok` de un comando `$`):
      // se ignora en lugar de arrastrar un contador negativo.
      return;
    }
    final _InFlightLine released = _inFlight.removeFirst();
    _bytesInFlight -= released.bytes;
    if (_bytesInFlight < 0) {
      _bytesInFlight = 0;
    }
  }

  static String _normalize(String line) {
    String normalized = line;
    while (normalized.endsWith('\r') || normalized.endsWith('\n')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
