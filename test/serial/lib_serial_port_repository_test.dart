import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/data/serial/grbl_worker.dart';
import 'package:grbl_app/data/serial/grbl_worker_client.dart';
import 'package:grbl_app/domain/repositories/serial_port_repository.dart';

void main() {
  // Prueba de humo del camino real: isolate + FFI + libserialport nativa.
  // Se limita a Windows porque en los runners de Linux/CI la biblioteca
  // nativa no está instalada para `flutter test`.
  test(
    'el worker real carga libserialport y enumera puertos',
    () async {
      final GrblWorkerClient client = await GrblWorkerClient.spawn();
      try {
        final List<SerialPortInfo> ports = await client.listPorts();
        expect(ports, isA<List<SerialPortInfo>>());
        for (final SerialPortInfo port in ports) {
          expect(port.name, isNotEmpty);
        }
      } on GrblWorkerException catch (error) {
        if (error.message.contains('Failed to load dynamic library')) {
          // `flutter_libserialport` despliega la DLL mediante CMake en el
          // bundle de la app; el host de `flutter test` no la incluye.
          markTestSkipped(
            'La biblioteca nativa solo está disponible en un build de la '
            'aplicación: ${error.message}',
          );
          return;
        }
        rethrow;
      } finally {
        await client.dispose();
      }
    },
    skip: !Platform.isWindows
        ? 'Requiere la librería nativa de libserialport para el host de pruebas.'
        : null,
  );
}
