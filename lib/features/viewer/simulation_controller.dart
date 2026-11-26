import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/gcode_program.dart';
import '../../domain/services/simulation_timeline.dart';
import 'viewer_controller.dart';

/// Estado del simulador de reproducción: posición, velocidad y si está en marcha.
@immutable
class SimulationUiState {
  const SimulationUiState({
    this.cursor,
    this.seconds = 0,
    this.totalSeconds = 0,
    this.playing = false,
    this.speed = 1,
  });

  /// Cabezal simulado en la posición actual; `null` sin programa.
  final SimulationCursor? cursor;

  /// Instante actual del programa (s).
  final double seconds;

  /// Duración total del programa (s).
  final double totalSeconds;

  final bool playing;

  /// Multiplicador de velocidad (0,25× … 8×).
  final double speed;

  bool get isReady => cursor != null && totalSeconds > 0;

  bool get atEnd => isReady && seconds >= totalSeconds - 1e-6;

  /// Avance 0..1 sobre el total, para la línea de tiempo.
  double get progress {
    if (totalSeconds <= 0) {
      return 0;
    }
    return (seconds / totalSeconds).clamp(0.0, 1.0);
  }

  /// Línea del archivo que corresponde al cabezal simulado (base 1).
  int get line => (cursor?.lineIndex ?? 0) + 1;

  SimulationUiState copyWith({
    SimulationCursor? cursor,
    double? seconds,
    double? totalSeconds,
    bool? playing,
    double? speed,
  }) {
    return SimulationUiState(
      cursor: cursor ?? this.cursor,
      seconds: seconds ?? this.seconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      playing: playing ?? this.playing,
      speed: speed ?? this.speed,
    );
  }
}

/// Reproduce el programa del visor sin tocar la máquina.
///
/// El reloj lo mueve el ticker de la barra (`advance`), así que el controlador es
/// puro estado: se puede probar sin vsync y el mismo código sirve en escritorio y
/// Android. La posición se reinicia sola cuando el visor carga otro programa.
class SimulationController extends Notifier<SimulationUiState> {
  /// Velocidades ofrecidas por la barra.
  static const List<double> speeds = <double>[0.25, 0.5, 1, 2, 4, 8];

  SimulationTimeline? _timeline;

  /// Se conserva entre programas: el operario no quiere reelegir velocidad.
  double _speed = 1;

  SimulationTimeline? get timeline => _timeline;

  @override
  SimulationUiState build() {
    final GcodeProgram? program = ref.watch(
      viewerControllerProvider.select((ViewerUiState state) => state.program),
    );
    _timeline = program == null || program.segments.isEmpty
        ? null
        : SimulationTimeline(program: program);
    final SimulationTimeline? timeline = _timeline;
    return SimulationUiState(
      cursor: timeline?.cursorAt(0),
      totalSeconds: timeline?.totalSeconds ?? 0,
      speed: _speed,
    );
  }

  /// Reproduce desde el principio si estaba al final.
  void play() {
    final SimulationTimeline? timeline = _timeline;
    if (timeline == null) {
      return;
    }
    if (state.atEnd) {
      _update(timeline: timeline, seconds: 0, playing: true);
      return;
    }
    state = state.copyWith(playing: true);
  }

  void pause() {
    if (state.playing) {
      state = state.copyWith(playing: false);
    }
  }

  void toggle() => state.playing ? pause() : play();

  /// Vuelve al principio y deja la reproducción en pausa.
  void restart() {
    final SimulationTimeline? timeline = _timeline;
    if (timeline == null) {
      return;
    }
    _update(timeline: timeline, seconds: 0, playing: false);
  }

  /// Salta a un instante concreto (0..`totalSeconds`).
  void seekTo(double seconds) {
    final SimulationTimeline? timeline = _timeline;
    if (timeline == null) {
      return;
    }
    final double clamped = seconds.clamp(0.0, timeline.totalSeconds);
    _update(
      timeline: timeline,
      seconds: clamped,
      playing: state.playing && clamped < timeline.totalSeconds,
    );
  }

  /// Salta a una fracción 0..1 del programa (línea de tiempo).
  void seekFraction(double fraction) =>
      seekTo(fraction.clamp(0.0, 1.0) * state.totalSeconds);

  /// Avanza hasta el final del bloque actual.
  void stepForward() {
    final SimulationTimeline? timeline = _timeline;
    final SimulationCursor? cursor = state.cursor;
    if (timeline == null || cursor == null) {
      return;
    }
    _update(
      timeline: timeline,
      seconds: timeline.endSeconds(cursor.segmentIndex),
      playing: false,
    );
  }

  /// Retrocede al inicio del bloque actual o, si ya está al principio, al
  /// anterior.
  void stepBack() {
    final SimulationTimeline? timeline = _timeline;
    final SimulationCursor? cursor = state.cursor;
    if (timeline == null || cursor == null) {
      return;
    }
    final double start = timeline.startSeconds(cursor.segmentIndex);
    final bool insideBlock = state.seconds - start > 0.001;
    final int target = insideBlock
        ? cursor.segmentIndex
        : (cursor.segmentIndex > 0 ? cursor.segmentIndex - 1 : 0);
    _update(
      timeline: timeline,
      seconds: timeline.startSeconds(target),
      playing: false,
    );
  }

  void setSpeed(double speed) {
    _speed = speed.clamp(0.1, 16);
    state = state.copyWith(speed: _speed);
  }

  /// Avanza el reloj [deltaSeconds] reales, multiplicados por la velocidad.
  ///
  /// Lo llama el ticker de la barra una vez por fotograma; al llegar al final se
  /// detiene solo.
  void advance(double deltaSeconds) {
    final SimulationTimeline? timeline = _timeline;
    if (timeline == null || !state.playing || deltaSeconds <= 0) {
      return;
    }
    final double next = state.seconds + deltaSeconds * state.speed;
    if (next >= timeline.totalSeconds) {
      _update(
        timeline: timeline,
        seconds: timeline.totalSeconds,
        playing: false,
      );
      return;
    }
    _update(timeline: timeline, seconds: next, playing: true);
  }

  void _update({
    required SimulationTimeline timeline,
    required double seconds,
    required bool playing,
  }) {
    state = SimulationUiState(
      cursor: timeline.cursorAt(seconds),
      seconds: seconds,
      totalSeconds: timeline.totalSeconds,
      playing: playing,
      speed: state.speed,
    );
  }
}

/// Estado del simulador observable por el visor.
final NotifierProvider<SimulationController, SimulationUiState>
simulationControllerProvider =
    NotifierProvider<SimulationController, SimulationUiState>(
      SimulationController.new,
    );
