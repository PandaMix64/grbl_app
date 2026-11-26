import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grbl_app/data/serial/android_usb_serial_repository.dart';
import 'package:grbl_app/domain/repositories/serial_port_repository.dart';

/// Verifica el contrato con el `MethodChannel` de `usb_serial` sin hardware:
/// el plugin real pide permiso al `UsbManager`, aquí solo se emula su respuesta.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('usb_serial');

  void mockChannel(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  Map<String, Object?> device({
    String name = '/dev/bus/usb/001/002',
    int vid = 0x2341,
    int pid = 0x0043,
    String? product = 'Arduino Uno',
    String? manufacturer = 'Arduino (www.arduino.cc)',
    int deviceId = 1002,
  }) => <String, Object?>{
    'deviceName': name,
    'vid': vid,
    'pid': pid,
    'productName': product,
    'manufacturerName': manufacturer,
    'deviceId': deviceId,
    'serialNumber': null,
    'interfaceCount': 2,
  };

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('enumera los dispositivos USB con una descripción legible', () async {
    mockChannel((MethodCall call) async {
      if (call.method == 'listDevices') {
        return <Map<String, Object?>>[device()];
      }
      return null;
    });
    final AndroidUsbSerialRepository repository = AndroidUsbSerialRepository();
    addTearDown(repository.dispose);

    final List<SerialPortInfo> ports = await repository.listPorts();

    expect(ports, hasLength(1));
    expect(ports.single.name, '/dev/bus/usb/001/002');
    expect(ports.single.description, contains('Arduino Uno'));
    expect(ports.single.description, contains('0x2341:0x0043'));
    expect(repository.isOpen, isFalse);
  });

  test(
    'abrir un dispositivo desconectado no lanza el diálogo de permiso',
    () async {
      mockChannel((MethodCall call) async {
        if (call.method == 'listDevices') {
          return const <Map<String, Object?>>[];
        }
        fail('No debe abrirse un dispositivo que ya no está en la lista.');
      });
      final AndroidUsbSerialRepository repository =
          AndroidUsbSerialRepository();
      addTearDown(repository.dispose);

      await expectLater(
        repository.open(portName: '/dev/bus/usb/001/002'),
        throwsA(
          isA<SerialPortException>().having(
            (SerialPortException error) => error.message,
            'message',
            contains('ya no está conectado'),
          ),
        ),
      );
    },
  );

  test('si el usuario deniega el permiso el error lo explica', () async {
    mockChannel((MethodCall call) async {
      switch (call.method) {
        case 'listDevices':
          return <Map<String, Object?>>[device()];
        case 'create':
          throw PlatformException(
            code: 'UsbSerialPortAdapter',
            message: 'Failed to acquire permissions.',
          );
        default:
          return null;
      }
    });
    final AndroidUsbSerialRepository repository = AndroidUsbSerialRepository();
    addTearDown(repository.dispose);

    await expectLater(
      repository.open(portName: '/dev/bus/usb/001/002'),
      throwsA(
        isA<SerialPortException>().having(
          (SerialPortException error) => error.message,
          'message',
          AndroidUsbSerialRepository.permissionDeniedMessage,
        ),
      ),
    );
  });
}
