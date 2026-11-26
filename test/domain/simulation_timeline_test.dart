import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/domain/services/gcode_interpreter.dart';
import 'package:grbl_app/domain/services/simulation_timeline.dart';

void main() {
  const GcodeInterpreter interpreter = GcodeInterpreter();

  test('reparte la duración según los avances del programa', () {
    final SimulationTimeline timeline = SimulationTimeline(
      program: interpreter.parse('G21\nG90\nG1 X10 Y0 F600\nG1 X10 Y10 F300'),
    );

    expect(timeline.segmentCount, 2);
    // 10 mm a 600 mm/min = 1 s; 10 mm a 300 mm/min = 2 s.
    expect(timeline.totalSeconds, closeTo(3, 1e-9));
    expect(timeline.startSeconds(0), 0);
    expect(timeline.startSeconds(1), closeTo(1, 1e-9));
    expect(timeline.endSeconds(1), closeTo(3, 1e-9));
  });

  test('los rápidos usan el avance supuesto y el cursor interpola', () {
    final SimulationTimeline timeline = SimulationTimeline(
      program: interpreter.parse('G21\nG90\nG0 X100\nG1 X100 Y50 F1000'),
      rapidFeedMmMin: 6000,
    );

    // 100 mm a 6000 mm/min = 1 s; 50 mm a 1000 mm/min = 3 s.
    expect(timeline.totalSeconds, closeTo(4, 1e-9));
    final SimulationCursor first = timeline.cursorAt(0.5)!;
    expect(first.segmentIndex, 0);
    expect(first.rapid, isTrue);
    expect(first.position.x, closeTo(50, 1e-6));

    final SimulationCursor middle = timeline.cursorAt(2)!;
    expect(middle.segmentIndex, 1);
    expect(middle.rapid, isFalse);
    expect(middle.position.y, closeTo(50 / 3, 1e-6));

    final SimulationCursor end = timeline.cursorAt(timeline.totalSeconds)!;
    expect(end.segmentIndex, 1);
    expect(end.position.y, closeTo(50, 1e-6));
    expect(timeline.cursorAt(99)!.seconds, timeline.totalSeconds);
  });

  test('un programa sin avances sigue teniendo duración', () {
    final SimulationTimeline timeline = SimulationTimeline(
      program: interpreter.parse('G21\nG90\nG1 X8'),
    );

    // El intérprete asume 800 mm/min cuando el programa no declara `F`.
    expect(timeline.totalSeconds, closeTo(0.6, 1e-9));
  });

  test('un movimiento diminuto no congela el reloj', () {
    final SimulationTimeline timeline = SimulationTimeline(
      program: interpreter.parse('G21\nG90\nG1 X0.00001 F500\nG1 X10 F500'),
      minimumSegmentSeconds: 0.002,
    );

    expect(timeline.startSeconds(1), closeTo(0.002, 1e-9));
    expect(timeline.totalSeconds, closeTo(1.202, 1e-3));
    expect(timeline.indexAt(0.001), 0);
    expect(timeline.indexAt(0.5), 1);
  });

  test('sin segmentos no hay cursor ni duración', () {
    final SimulationTimeline timeline = SimulationTimeline(
      program: interpreter.parse('G21\nG90\n'),
    );

    expect(timeline.isEmpty, isTrue);
    expect(timeline.totalSeconds, 0);
    expect(timeline.cursorAt(1), isNull);
    expect(timeline.indexAt(1), 0);
  });
}
