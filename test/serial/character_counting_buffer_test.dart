import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/core/grbl/grbl_constants.dart';
import 'package:grbl_app/data/serial/character_counting_buffer.dart';

void main() {
  group('CharacterCountingBuffer', () {
    test('respeta el presupuesto de bytes del búfer', () {
      final CharacterCountingBuffer buffer = CharacterCountingBuffer();
      // 10 líneas de 20 B + '\r' = 210 B: no caben de golpe en 128 B.
      buffer.enqueueAll(<String>[
        for (int i = 0; i < 10; i++) 'G1 X10.000 Y10.00$i',
      ]);

      final List<String> first = buffer.drainSendable();

      expect(first, isNotEmpty);
      expect(buffer.bytesInFlight, lessThanOrEqualTo(buffer.budget));
      expect(buffer.pendingCount, 10 - first.length);
    });

    test('cada ok libera exactamente el espacio de su línea', () {
      final CharacterCountingBuffer buffer = CharacterCountingBuffer();
      buffer.enqueue('G21');
      buffer.enqueue('G90');

      expect(buffer.drainSendable(), <String>['G21', 'G90']);
      expect(buffer.bytesInFlight, 4 + 4);

      buffer.acknowledgeOk();
      expect(buffer.bytesInFlight, 4);

      buffer.acknowledgeOk();
      expect(buffer.bytesInFlight, 0);
      expect(buffer.isBusy, isFalse);
    });

    test('un error también libera la línea (no congela el flujo)', () {
      final CharacterCountingBuffer buffer = CharacterCountingBuffer();
      buffer.enqueue('G1 X1');
      buffer.drainSendable();

      buffer.acknowledgeError();

      expect(buffer.bytesInFlight, 0);
      expect(buffer.inFlightCount, 0);
    });

    test('un ok no solicitado no deja el contador negativo', () {
      final CharacterCountingBuffer buffer = CharacterCountingBuffer();

      buffer.acknowledgeOk();
      buffer.acknowledgeOk();

      expect(buffer.bytesInFlight, 0);
    });

    test('rechaza líneas que no caben ni siquiera con el búfer vacío', () {
      final CharacterCountingBuffer buffer = CharacterCountingBuffer();

      expect(
        () => buffer.enqueue('G1 X${'9' * 200}'),
        throwsA(isA<CharacterBudgetException>()),
      );
    });

    test('normaliza los terminadores para no contar de más', () {
      final CharacterCountingBuffer buffer = CharacterCountingBuffer();
      buffer.enqueue('G21\r\n');
      buffer.drainSendable();

      expect(buffer.bytesInFlight, 4);
    });

    test('10 000 líneas nunca exceden el presupuesto', () {
      final CharacterCountingBuffer buffer = CharacterCountingBuffer();
      int sent = 0;

      for (int i = 0; i < 10000; i++) {
        buffer.enqueue('G1 X${(i % 100).toStringAsFixed(3)} Y1.000');

        for (final String line in buffer.drainSendable()) {
          expect(line, isNotEmpty);
          sent++;
          expect(
            buffer.bytesInFlight,
            lessThanOrEqualTo(buffer.budget),
            reason: 'desborde tras $sent líneas',
          );
          buffer.acknowledgeOk();
        }
      }

      expect(sent, 10000);
      expect(buffer.isBusy, isFalse);
      expect(buffer.bytesInFlight, 0);
    });

    test('reset descarta pendientes y en vuelo', () {
      final CharacterCountingBuffer buffer = CharacterCountingBuffer();
      buffer.enqueueAll(<String>['G21', 'G90', 'G0 X0']);
      buffer.drainSendable();

      buffer.reset();

      expect(buffer.isBusy, isFalse);
      expect(buffer.bytesInFlight, 0);
    });

    test('la constante documentada del búfer es 128 B', () {
      expect(kDefaultRxBufferSize, 128);
      expect(CharacterCountingBuffer().budget, 127);
    });
  });
}
