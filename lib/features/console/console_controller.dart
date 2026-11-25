import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/serial/grbl_worker_client.dart';

/// Estado de la consola de comandos.
@immutable
class ConsoleUiState {
  const ConsoleUiState({
    this.entries = const <String>[],
    this.sent = const <String>[],
    this.error,
  });

  /// Líneas de tráfico (`→` enviado, `←` recibido) y avisos.
  final List<String> entries;

  /// Historial de comandos enviados (para reenviarlos con las flechas).
  final List<String> sent;

  final String? error;

  ConsoleUiState copyWith({
    List<String>? entries,
    List<String>? sent,
    String? error,
    bool clearError = false,
  }) {
    return ConsoleUiState(
      entries: entries ?? this.entries,
      sent: sent ?? this.sent,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Consola: captura el tráfico del puerto y envía comandos sueltos.
///
/// Mantiene un búfer circular para que la telemetría no borre lo importante: el
/// streaming y los status reports se filtran en el servicio.
class ConsoleController extends Notifier<ConsoleUiState> {
  static const int _maxEntries = 400;
  static const int _maxHistory = 30;

  StreamSubscription<String>? _trafficSub;

  @override
  ConsoleUiState build() {
    final GrblWorkerClient? client = ref.read(grblWorkerProvider).value;
    if (client != null) {
      _attach(client);
    } else {
      ref.listen(grblWorkerProvider, (_, AsyncValue<GrblWorkerClient> next) {
        final GrblWorkerClient? ready = next.value;
        if (ready != null) {
          _attach(ready);
        }
      });
    }
    ref.onDispose(() => unawaited(_trafficSub?.cancel()));
    return const ConsoleUiState();
  }

  void _attach(GrblWorkerClient client) {
    if (_trafficSub != null) {
      return;
    }
    _trafficSub = client.consoleLines.listen(_append);
  }

  void _append(String line) {
    final List<String> entries = List<String>.of(state.entries)..add(line);
    if (entries.length > _maxEntries) {
      entries.removeRange(0, entries.length - _maxEntries);
    }
    state = state.copyWith(entries: entries);
  }

  /// Envía una línea al controlador.
  Future<void> send(String command) async {
    final String trimmed = command.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final GrblWorkerClient? client = ref.read(grblWorkerProvider).value;
    if (client == null) {
      state = state.copyWith(error: 'El puerto serial no está disponible.');
      return;
    }
    try {
      await client.sendConsoleCommand(trimmed);
      final List<String> sent = List<String>.of(state.sent);
      if (sent.isEmpty || sent.first != trimmed) {
        sent.insert(0, trimmed);
        if (sent.length > _maxHistory) {
          sent.removeRange(_maxHistory, sent.length);
        }
      }
      state = state.copyWith(sent: sent, clearError: true);
    } on Object catch (error) {
      state = state.copyWith(error: '$error');
    }
  }

  void clear() => state = state.copyWith(entries: const <String>[]);
}

/// Consola observable por la UI.
final NotifierProvider<ConsoleController, ConsoleUiState>
consoleControllerProvider = NotifierProvider<ConsoleController, ConsoleUiState>(
  ConsoleController.new,
);
