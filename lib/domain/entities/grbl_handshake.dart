import 'build_info.dart';
import 'grbl_settings.dart';
import 'parser_state.dart';
import 'work_offsets.dart';

/// Instantánea de la sesión GRBL obtenida justo después de conectar.
///
/// Agrupa lo que la app necesita para operar con conocimiento real del
/// controlador en lugar de suposiciones: tamaño de búfer, parámetros de EEPROM,
/// estado modal y offsets.
class GrblHandshake {
  const GrblHandshake({
    required this.rxBufferSize,
    required this.settings,
    required this.parserState,
    required this.offsets,
    this.buildInfo,
    this.bannerReceived = false,
  });

  /// Bytes del búfer RX reales del firmware (de `$I`, o 128 por defecto).
  final int rxBufferSize;

  final GrblSettings settings;
  final ParserState parserState;
  final WorkOffsets offsets;

  /// `null` si el firmware no respondió a `$I`.
  final BuildInfo? buildInfo;

  /// Si se recibió el banner `Grbl ...` al abrir el puerto.
  final bool bannerReceived;

  String get firmwareVersion => buildInfo?.version ?? 'desconocida';

  Map<String, Object?> toJson() => <String, Object?>{
    'rxBufferSize': rxBufferSize,
    'bannerReceived': bannerReceived,
    'buildInfo': buildInfo?.toJson(),
    'settings': settings.toJson(),
    'parserState': parserState.toJson(),
    'offsets': offsets.toJson(),
  };

  factory GrblHandshake.fromJson(Map<String, Object?> json) {
    final Object? build = json['buildInfo'];
    final Object? settings = json['settings'];
    final Object? parser = json['parserState'];
    final Object? offsets = json['offsets'];
    if (settings is! Map<String, Object?> ||
        parser is! Map<String, Object?> ||
        offsets is! Map<String, Object?>) {
      throw const FormatException(
        'Handshake incompleto: faltan settings, parserState u offsets.',
      );
    }
    return GrblHandshake(
      rxBufferSize: (json['rxBufferSize'] as num?)?.toInt() ?? 128,
      bannerReceived: json['bannerReceived'] == true,
      buildInfo: build is Map<String, Object?>
          ? BuildInfo.fromJson(build)
          : null,
      settings: GrblSettings.fromJson(settings),
      parserState: ParserState.fromJson(parser),
      offsets: WorkOffsets.fromJson(offsets),
    );
  }

  @override
  String toString() =>
      'GrblHandshake(v$firmwareVersion, ${rxBufferSize}B RX, '
      '${settings.codes.length} parámetros, $parserState)';
}
