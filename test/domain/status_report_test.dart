import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/entities/machine_state.dart';
import 'package:grbl_app/domain/entities/status_report.dart';

void main() {
  group('StatusReport.parse', () {
    test('parsea Idle con MPos y FS', () {
      final StatusReport report = StatusReport.parse(
        '<Idle|MPos:10.000,20.000,5.000|FS:800,0>',
      );

      expect(report.state, MachineState.idle);
      expect(report.machinePosition, <double>[10, 20, 5]);
      expect(report.feedMmMin, 800);
      expect(report.spindleSpeed, 0);
      expect(report.isSpindleOn, isFalse);
    });

    test('acepta el subestado de Hold', () {
      final StatusReport report = StatusReport.parse(
        '<Hold:0|MPos:1.000,2.000,3.000|WCO:-1.000,0.000,2.000|FS:0,0>',
      );

      expect(report.state, MachineState.hold);
      expect(report.workCoordinateOffset, <double>[-1, 0, 2]);
    });

    test('resuelve MPos desde WPos y WCO (WPos = MPos - WCO)', () {
      final StatusReport report = StatusReport.parse(
        '<Run|WPos:11.000,18.000,1.000|WCO:1.000,-2.000,4.000|FS:500,1500>',
      );

      expect(report.machinePosition, isNull);
      expect(report.resolvedMachinePosition, <double>[12, 16, 5]);
      expect(report.resolvedWorkPosition, <double>[11, 18, 1]);
      expect(report.isSpindleOn, isTrue);
      expect(report.spindleSpeed, 1500);
    });

    test('parsea el campo Bf sin usarlo para el control de flujo', () {
      final StatusReport report = StatusReport.parse(
        '<Run|MPos:0,0,0|Bf:15,128>',
      );

      expect(report.plannerBlocks, 15);
      expect(report.rxBufferBytes, 128);
    });

    test('ignora campos desconocidos y de pines', () {
      final StatusReport report = StatusReport.parse(
        '<Alarm|MPos:0,0,0|Pn:XYZ|Ov:100,100,100>',
      );

      expect(report.state, MachineState.alarm);
      expect(report.state.isBlocked, isTrue);
      expect(report.machinePosition, <double>[0, 0, 0]);
    });

    test('rechaza líneas que no son status report', () {
      expect(() => StatusReport.parse('ok'), throwsFormatException);
      expect(() => StatusReport.parse('<Idle'), throwsFormatException);
      expect(() => StatusReport.parse('<>'), throwsFormatException);
    });

    test('un estado desconocido no rompe el parseo', () {
      final StatusReport report = StatusReport.parse('<Weird|MPos:0,0,0>');

      expect(report.state, MachineState.unknown);
    });
  });

  group('MachineState', () {
    test('solo Idle y Jog permiten jog', () {
      expect(MachineState.idle.allowsJog, isTrue);
      expect(MachineState.jog.allowsJog, isTrue);
      expect(MachineState.run.allowsJog, isFalse);
      expect(MachineState.hold.allowsJog, isFalse);
    });

    test('Run y Jog se consideran movimiento', () {
      expect(MachineState.run.isMoving, isTrue);
      expect(MachineState.jog.isMoving, isTrue);
      expect(MachineState.idle.isMoving, isFalse);
    });

    test('Alarm y Door bloquean el movimiento', () {
      expect(MachineState.alarm.isBlocked, isTrue);
      expect(MachineState.door.isBlocked, isTrue);
      expect(MachineState.idle.isBlocked, isFalse);
    });
  });
}
