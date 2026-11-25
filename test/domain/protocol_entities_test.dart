import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/entities/build_info.dart';
import 'package:grbl_app/domain/entities/parser_state.dart';
import 'package:grbl_app/domain/entities/work_offsets.dart';

void main() {
  group('BuildInfo', () {
    test('parsea version, fecha y opciones', () {
      final BuildInfo info = BuildInfo.fromLines(<String>[
        '[VER:1.1h.20190825:]',
        '[OPT:V,15,128]',
      ]);

      expect(info.version, '1.1h');
      expect(info.buildDate, '20190825');
      expect(info.optionFlags, 'V');
      expect(info.plannerBlocks, 15);
      expect(info.rxBufferSize, 128);
      expect(info.hasVariableSpindle, isTrue);
      expect(info.hasLineNumbers, isFalse);
    });

    test('admite firmware sin fecha de compilación', () {
      final BuildInfo info = BuildInfo.fromLines(<String>[
        '[VER:1.1f:]',
        '[OPT:VN,16,256]',
      ]);

      expect(info.version, '1.1f');
      expect(info.buildDate, isNull);
      expect(info.plannerBlocks, 16);
      expect(info.rxBufferSize, 256);
      expect(info.hasLineNumbers, isTrue);
    });

    test('admite flags vacías', () {
      final BuildInfo info = BuildInfo.fromLines(<String>[
        '[VER:1.1h.20190825:]',
        '[OPT:,15,128]',
      ]);

      expect(info.optionFlags, '');
      expect(info.rxBufferSize, 128);
    });

    test('rechaza una respuesta incompleta', () {
      expect(
        () => BuildInfo.fromLines(<String>['[VER:1.1h.20190825:]']),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BuildInfo.fromLines(<String>['[OPT:V]']),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ParserState', () {
    test('interpreta el bloque GC de GRBL', () {
      final ParserState state = ParserState.parse(
        r'[GC:G0 G54 G17 G21 G90 G94 M5 M9 T0 F0 S0]',
      );

      expect(state.isMetric, isTrue);
      expect(state.isInches, isFalse);
      expect(state.isAbsolute, isTrue);
      expect(state.motionMode, 'G0');
      expect(state.workCoordinateSystem, 'G54');
      expect(state.spindleMode, 'M5');
      expect(state.feed, 0);
      expect(state.spindle, 0);
      expect(state.usesDynamicLaserPower, isFalse);
    });

    test('detecta láser dinámico con M4', () {
      final ParserState state = ParserState.parse(
        r'[GC:G1 G54 G17 G21 G90 G94 M4 M9 T0 F500 S800]',
      );

      expect(state.spindleMode, 'M4');
      expect(state.usesDynamicLaserPower, isTrue);
      expect(state.feed, 500);
      expect(state.spindle, 800);
    });

    test('compara el estado modal relevante, no el avance', () {
      final ParserState a = ParserState.parse(
        r'[GC:G1 G54 G17 G21 G90 G94 M4 M9 T0 F500 S800]',
      );
      final ParserState b = ParserState.parse(
        r'[GC:G1 G54 G17 G21 G90 G94 M4 M9 T1 F900 S300]',
      );
      final ParserState incremental = ParserState.parse(
        r'[GC:G1 G54 G17 G21 G91 G94 M4 M9 T0 F900 S300]',
      );
      final ParserState otherWcs = ParserState.parse(
        r'[GC:G1 G55 G17 G21 G90 G94 M4 M9 T0 F900 S300]',
      );

      expect(a.isCompatibleWith(b), isTrue);
      expect(a.isCompatibleWith(incremental), isFalse);
      expect(a.isCompatibleWith(otherWcs), isFalse);
    });

    test('rechaza líneas que no son del parser', () {
      expect(() => ParserState.parse('[OPT:V,15,128]'), throwsFormatException);
      expect(() => ParserState.parse('[GC:]'), throwsFormatException);
    });
  });

  group('WorkOffsets', () {
    test('parsea offsets y descarta el sufijo de PRB', () {
      final WorkOffsets offsets = WorkOffsets.parse(<String>[
        '[G54:1.000,2.000,3.000]',
        '[G92:0.000,0.000,-1.500]',
        '[TLO:0.000]',
        '[PRB:1.000,2.000,3.000:1]',
      ]);

      expect(offsets['G54'], <double>[1, 2, 3]);
      expect(offsets['G92'], <double>[0, 0, -1.5]);
      expect(offsets['TLO'], <double>[0]);
      expect(offsets['PRB'], <double>[1, 2, 3]);
    });

    test('compara con tolerancia', () {
      final WorkOffsets a = WorkOffsets.parse(<String>[
        '[G54:1.000,2.000,3.000]',
      ]);
      final WorkOffsets almost = WorkOffsets.parse(<String>[
        '[G54:1.0004,2.000,3.000]',
      ]);
      final WorkOffsets different = WorkOffsets.parse(<String>[
        '[G54:1.010,2.000,3.000]',
      ]);

      expect(a.matches(almost), isTrue);
      expect(a.matches(different), isFalse);
      expect(a.matches(WorkOffsets.parse(<String>[])), isFalse);
    });

    test('sobrevive a JSON', () {
      final WorkOffsets offsets = WorkOffsets.parse(<String>['[G54:1,2,3]']);

      final WorkOffsets restored = WorkOffsets.fromJson(offsets.toJson());

      expect(restored.matches(offsets), isTrue);
    });

    test('ignora líneas ajenas', () {
      final WorkOffsets offsets = WorkOffsets.parse(<String>[
        'ok',
        '[MSG:algo]',
        'G54:1,2,3',
      ]);

      expect(offsets.isEmpty, isTrue);
    });
  });
}
