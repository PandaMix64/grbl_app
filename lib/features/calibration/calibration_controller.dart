import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/serial/grbl_worker_client.dart';
import '../../domain/entities/axis.dart';
import '../../domain/entities/grbl_settings.dart';
import '../../domain/entities/machine_profile.dart';
import '../../domain/services/backlash_estimate.dart';
import '../../domain/services/steps_per_mm_calibration.dart';
import '../connection/connection_controller.dart';

/// Estado de la pantalla de calibración.
@immutable
class CalibrationUiState {
  const CalibrationUiState({
    this.profiles = const <MachineProfile>[],
    this.selectedProfileId,
    this.settings,
    this.draft = const <int, String>{},
    this.pending = const <int, String>{},
    this.jogStepMm = 1,
    this.jogFeedMmMin = 500,
    this.isBusy = false,
    this.settingsRevision = 0,
    this.message,
    this.error,
  });

  final List<MachineProfile> profiles;
  final String? selectedProfileId;

  /// Parámetros leídos de la EEPROM (`$$`); `null` si aún no se leyeron.
  final GrblSettings? settings;

  /// Valores editables por código `$`.
  final Map<int, String> draft;

  /// Subconjunto de [draft] que difiere de la EEPROM y se escribiría al aplicar.
  final Map<int, String> pending;

  final double jogStepMm;
  final double jogFeedMmMin;
  final bool isBusy;

  /// Se incrementa al releer la EEPROM para forzar el refresco de los campos.
  final int settingsRevision;

  final String? message;
  final String? error;

  MachineProfile? get selectedProfile {
    for (final MachineProfile profile in profiles) {
      if (profile.id == selectedProfileId) {
        return profile;
      }
    }
    return null;
  }

  bool get hasPendingChanges => pending.isNotEmpty;

  CalibrationUiState copyWith({
    List<MachineProfile>? profiles,
    String? selectedProfileId,
    GrblSettings? settings,
    Map<int, String>? draft,
    Map<int, String>? pending,
    double? jogStepMm,
    double? jogFeedMmMin,
    bool? isBusy,
    int? settingsRevision,
    String? message,
    String? error,
    bool clearError = false,
    bool clearMessage = false,
    bool clearSettings = false,
    bool clearSelectedProfile = false,
  }) {
    return CalibrationUiState(
      profiles: profiles ?? this.profiles,
      selectedProfileId: clearSelectedProfile
          ? null
          : (selectedProfileId ?? this.selectedProfileId),
      settings: clearSettings ? null : (settings ?? this.settings),
      draft: draft ?? this.draft,
      pending: pending ?? this.pending,
      jogStepMm: jogStepMm ?? this.jogStepMm,
      jogFeedMmMin: jogFeedMmMin ?? this.jogFeedMmMin,
      isBusy: isBusy ?? this.isBusy,
      settingsRevision: settingsRevision ?? this.settingsRevision,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controlador de calibración: perfiles, jogging, parámetros `$` y pasos/mm.
///
/// Se apoya en el `GrblWorkerClient` (nunca escribe bytes) y en Drift para los
/// perfiles. Cualquier escritura en EEPROM pasa por `GrblSettings.diff`.
class CalibrationController extends Notifier<CalibrationUiState> {
  @override
  CalibrationUiState build() => const CalibrationUiState();

  GrblWorkerClient? get _clientOrNull {
    try {
      return ref.read(grblWorkerProvider).value;
    } on Object {
      return null;
    }
  }

  bool get _isConnected => ref.read(connectionControllerProvider).isConnected;

  /// Carga los perfiles y selecciona el más reciente si no hay ninguno activo.
  Future<void> loadProfiles() async {
    try {
      final List<MachineProfile> profiles = await ref
          .read(databaseProvider)
          .allProfiles();
      String? selected = state.selectedProfileId;
      if (selected == null && profiles.isNotEmpty) {
        selected = profiles.first.id;
      } else if (selected != null &&
          !profiles.any((MachineProfile p) => p.id == selected)) {
        selected = profiles.isEmpty ? null : profiles.first.id;
      }
      state = state.copyWith(
        profiles: profiles,
        selectedProfileId: selected,
        clearSelectedProfile: selected == null,
        clearError: true,
      );
      ref.read(activeProfileIdProvider.notifier).select(selected);
    } on Object catch (error) {
      state = state.copyWith(
        error: 'No se pudieron cargar los perfiles: $error',
      );
    }
  }

  void selectProfile(String? id) {
    state = state.copyWith(selectedProfileId: id, clearError: true);
    ref.read(activeProfileIdProvider.notifier).select(id);
  }

  /// Guarda (crea o actualiza) un perfil validándolo antes.
  Future<bool> saveProfile(MachineProfile profile) async {
    final List<String> errors = profile.validate();
    if (errors.isNotEmpty) {
      state = state.copyWith(error: errors.first);
      return false;
    }
    try {
      await ref.read(databaseProvider).upsertProfile(profile);
      await loadProfiles();
      state = state.copyWith(
        selectedProfileId: profile.id,
        message: 'Perfil "${profile.name}" guardado.',
      );
      return true;
    } on Object catch (error) {
      state = state.copyWith(error: 'No se pudo guardar el perfil: $error');
      return false;
    }
  }

  Future<void> deleteProfile(String id) async {
    try {
      await ref.read(databaseProvider).deleteProfile(id);
      if (state.selectedProfileId == id) {
        state = state.copyWith(clearSelectedProfile: true);
      }
      await loadProfiles();
      state = state.copyWith(message: 'Perfil eliminado.');
    } on Object catch (error) {
      state = state.copyWith(error: 'No se pudo eliminar el perfil: $error');
    }
  }

  void setJogStep(double stepMm) => state = state.copyWith(jogStepMm: stepMm);

  void setJogFeed(double feedMmMin) =>
      state = state.copyWith(jogFeedMmMin: feedMmMin);

  /// Desplaza un eje un paso con `$J=` y el avance configurado.
  Future<void> jog({required MachineAxis axis, required int direction}) async {
    if (direction == 0) {
      return;
    }
    final GrblWorkerClient? client = _clientOrNull;
    if (!_isConnected || client == null) {
      state = state.copyWith(error: 'Conecta la máquina para hacer jogging.');
      return;
    }
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await client.jog(
        values: <MachineAxis, double>{axis: state.jogStepMm * direction},
        feedMmPerMin: state.jogFeedMmMin,
      );
      state = state.copyWith(isBusy: false);
    } on Object catch (error) {
      state = state.copyWith(isBusy: false, error: 'Jog rechazado: $error');
    }
  }

  /// Cancela el jog en curso (`0x85`).
  Future<void> cancelJog() async {
    final GrblWorkerClient? client = _clientOrNull;
    if (!_isConnected || client == null) {
      return;
    }
    try {
      await client.cancelJog();
      state = state.copyWith(message: 'Jog cancelado.');
    } on Object catch (error) {
      state = state.copyWith(error: 'No se pudo cancelar el jog: $error');
    }
  }

  /// Lee la EEPROM (`$$`) y prepara el borrador editable.
  Future<void> refreshSettings() async {
    final GrblWorkerClient? client = _clientOrNull;
    if (!_isConnected || client == null) {
      state = state.copyWith(
        error: 'Conecta la máquina para leer los parámetros.',
      );
      return;
    }
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final GrblSettings settings = await client.readSettings();
      state = state.copyWith(
        isBusy: false,
        settings: settings,
        draft: _draftFrom(settings),
        pending: const <int, String>{},
        settingsRevision: state.settingsRevision + 1,
        message: 'Parámetros leídos: ${settings.codes.length}.',
      );
    } on Object catch (error) {
      state = state.copyWith(
        isBusy: false,
        error: 'No se pudo leer la EEPROM: $error',
      );
    }
  }

  /// Edita un parámetro del borrador y recalcula qué se escribiría.
  void setDraftValue(int code, String value) {
    final Map<int, String> draft = Map<int, String>.of(state.draft)
      ..[code] = value;
    state = state.copyWith(
      draft: draft,
      pending: _computePending(state.settings, draft),
      clearError: true,
    );
  }

  /// Aplica **solo** los parámetros que difieren de la EEPROM.
  Future<int> applyDraft() async {
    final GrblWorkerClient? client = _clientOrNull;
    final Map<int, String> changes = state.pending;
    if (!_isConnected || client == null) {
      state = state.copyWith(
        error: 'Conecta la máquina para escribir parámetros.',
      );
      return 0;
    }
    if (changes.isEmpty) {
      state = state.copyWith(message: 'No hay cambios que escribir.');
      return 0;
    }
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final int written = await client.writeSettings(changes);
      await refreshSettings();
      state = state.copyWith(
        isBusy: false,
        message: 'Parámetros escritos en la EEPROM: $written.',
      );
      return written;
    } on Object catch (error) {
      state = state.copyWith(
        isBusy: false,
        error: 'No se pudieron escribir los parámetros: $error',
      );
      return 0;
    }
  }

  /// Corrige los pasos/mm de un eje y deja el valor aplicado en la máquina.
  Future<double?> calibrateSteps({
    required MachineAxis axis,
    required double commandedMm,
    required double measuredMm,
  }) async {
    final GrblSettings? settings = state.settings;
    if (settings == null) {
      state = state.copyWith(
        error: 'Lee primero los parámetros de la máquina.',
      );
      return null;
    }
    final double? current = settings.stepsPerMm(axis);
    if (current == null) {
      state = state.copyWith(
        error: 'La EEPROM no tiene pasos/mm para el eje ${axis.letter}.',
      );
      return null;
    }
    final StepsPerMmCalibration calibration = StepsPerMmCalibration(
      currentStepsPerMm: current,
      commandedMm: commandedMm,
      measuredMm: measuredMm,
    );
    final List<String> errors = calibration.validate();
    if (errors.isNotEmpty) {
      state = state.copyWith(error: errors.first);
      return null;
    }
    final GrblWorkerClient? client = _clientOrNull;
    if (!_isConnected || client == null) {
      state = state.copyWith(
        error: 'Conecta la máquina para escribir la calibración.',
      );
      return null;
    }

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await client.writeSettings(<int, String>{
        axis.stepsPerMmCode: calibration.toGrblValue(),
      });
      await refreshSettings();
      state = state.copyWith(
        isBusy: false,
        message:
            'Pasos/mm del eje ${axis.letter}: ${current.toStringAsFixed(3)} → '
            '${calibration.toGrblValue()}.',
      );
      return calibration.newStepsPerMm;
    } on Object catch (error) {
      state = state.copyWith(
        isBusy: false,
        error: 'No se pudo escribir la calibración: $error',
      );
      return null;
    }
  }

  /// Estima la holgura de un eje y la guarda en el perfil activo.
  Future<double?> calibrateBacklash({
    required MachineAxis axis,
    required double commandedMm,
    required double measuredMm,
  }) async {
    if (axis == MachineAxis.z) {
      state = state.copyWith(
        error:
            'La holgura de Z no se compensa: la fuerza de la herramienta la '
            'hace impredecible.',
      );
      return null;
    }
    final MachineProfile? profile = state.selectedProfile;
    if (profile == null) {
      state = state.copyWith(
        error: 'Selecciona un perfil antes de guardar la holgura.',
      );
      return null;
    }
    final BacklashEstimate estimate = BacklashEstimate(
      commandedMm: commandedMm,
      measuredMm: measuredMm,
    );
    final List<String> errors = estimate.validate();
    if (errors.isNotEmpty) {
      state = state.copyWith(error: errors.first);
      return null;
    }
    final MachineProfile updated = axis == MachineAxis.x
        ? profile.copyWith(backlashXmm: estimate.backlashMm)
        : profile.copyWith(backlashYmm: estimate.backlashMm);
    if (!await saveProfile(updated)) {
      return null;
    }
    state = state.copyWith(
      message:
          'Holgura del eje ${axis.letter}: ${estimate.toProfileValue()} mm '
          'guardada en el perfil.',
    );
    return estimate.backlashMm;
  }

  /// Escribe en la EEPROM los parámetros que definen el perfil activo.
  ///
  /// Solo envía lo que difiere: `$32` (modo láser), `$30` (RPM máx.) y
  /// `$130-$132` (recorrido). El resto de parámetros no se toca.
  Future<int> applyProfileToSettings() async {
    final MachineProfile? profile = state.selectedProfile;
    final GrblSettings? settings = state.settings;
    final GrblWorkerClient? client = _clientOrNull;
    if (profile == null) {
      state = state.copyWith(error: 'Selecciona un perfil para aplicarlo.');
      return 0;
    }
    if (settings == null) {
      state = state.copyWith(
        error: 'Lee primero los parámetros de la máquina.',
      );
      return 0;
    }
    if (!_isConnected || client == null) {
      state = state.copyWith(
        error: 'Conecta la máquina para aplicar el perfil.',
      );
      return 0;
    }

    final Map<int, String> target = <int, String>{
      32: profile.usesLaserMode ? '1' : '0',
      30: profile.maxSpindleRpm.toStringAsFixed(0),
      130: profile.travelXmm.toStringAsFixed(3),
      131: profile.travelYmm.toStringAsFixed(3),
      132: profile.travelZmm.toStringAsFixed(3),
    };
    final Map<int, String> changes = <int, String>{
      for (final MapEntry<int, String> entry in target.entries)
        if (!_sameNumber(settings.rawValue(entry.key), entry.value))
          entry.key: entry.value,
    };
    if (changes.isEmpty) {
      state = state.copyWith(
        message: 'La máquina ya coincide con el perfil: nada que aplicar.',
      );
      return 0;
    }

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final int written = await client.writeSettings(changes);
      await refreshSettings();
      state = state.copyWith(
        isBusy: false,
        message: 'Perfil aplicado a la máquina: $written parámetros.',
      );
      return written;
    } on Object catch (error) {
      state = state.copyWith(
        isBusy: false,
        error: 'No se pudo aplicar el perfil: $error',
      );
      return 0;
    }
  }

  /// Lanza el ciclo de homing (`$H`).
  Future<void> home() async {
    final GrblWorkerClient? client = _clientOrNull;
    if (!_isConnected || client == null) {
      state = state.copyWith(error: 'Conecta la máquina para hacer homing.');
      return;
    }
    try {
      await client.home();
      state = state.copyWith(
        message: 'Homing lanzado. Espera a que termine antes de mover.',
      );
    } on Object catch (error) {
      state = state.copyWith(error: 'Homing fallido: $error');
    }
  }

  /// Fija el cero de trabajo actual en G54 (`G10 L20 P1`).
  Future<void> setWorkZero({
    bool x = true,
    bool y = true,
    bool z = true,
  }) async {
    final GrblWorkerClient? client = _clientOrNull;
    if (!_isConnected || client == null) {
      state = state.copyWith(error: 'Conecta la máquina para fijar el origen.');
      return;
    }
    try {
      await client.setWorkZero(x: x, y: y, z: z);
      state = state.copyWith(
        message: 'Origen de trabajo fijado en G54 (G10 L20 P1).',
      );
    } on Object catch (error) {
      state = state.copyWith(error: 'No se pudo fijar el origen: $error');
    }
  }

  static bool _sameNumber(String? current, String target) {
    final double? a = double.tryParse(current ?? '');
    final double? b = double.tryParse(target);
    if (a == null || b == null) {
      return false;
    }
    return (a - b).abs() < 1e-6;
  }

  static Map<int, String> _draftFrom(GrblSettings settings) {
    return <int, String>{
      for (final int code in settings.codes) code: settings.rawValue(code)!,
    };
  }

  static Map<int, String> _computePending(
    GrblSettings? settings,
    Map<int, String> draft,
  ) {
    if (settings == null) {
      return const <int, String>{};
    }
    final GrblSettings target = GrblSettings.fromJson(<String, Object?>{
      for (final MapEntry<int, String> entry in draft.entries)
        entry.key.toString(): entry.value,
    });
    return settings.diff(target);
  }
}

/// Estado de calibración observable por la UI.
final NotifierProvider<CalibrationController, CalibrationUiState>
calibrationControllerProvider =
    NotifierProvider<CalibrationController, CalibrationUiState>(
      CalibrationController.new,
    );
