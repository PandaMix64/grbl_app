import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform_capabilities.dart';
import '../data/database/app_database.dart';
import '../data/serial/android_usb_serial_repository.dart';
import '../data/serial/grbl_worker_client.dart';
import '../domain/entities/machine_profile.dart';
import '../domain/entities/project_file.dart';

/// Indica si la conexión serie por USB está disponible en esta plataforma.
///
/// En pruebas se sobrescribe para simular un destino sin host USB (iOS/web) sin
/// depender del sistema real.
final Provider<bool> serialSupportProvider = Provider<bool>(
  (Ref ref) => PlatformCapabilities.serialSupported,
);

/// Base de datos local.
///
/// En pruebas se sobrescribe con `AppDatabase.forTesting(NativeDatabase.memory())`.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((Ref ref) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// Cliente del worker serial: el puerto real vive en un isolate propio.
///
/// En escritorio el puerto es FFI (`libserialport`) y las lecturas bloquean, así
/// que el worker se lanza en un isolate aparte. En Android el acceso pasa por el
/// `MethodChannel` de `usb_serial` (permiso del `UsbManager` + *bulk transfers*),
/// que no funciona en un isolate de fondo; allí el servicio corre en el isolate
/// principal y no bloquea porque todas las operaciones son asíncronas.
///
/// En pruebas se sobrescribe con `GrblWorkerClient.inProcess(...)`, de modo que
/// la UI se puede probar sin hardware ni DLL nativa.
final FutureProvider<GrblWorkerClient> grblWorkerProvider =
    FutureProvider<GrblWorkerClient>((Ref ref) async {
      final GrblWorkerClient client = Platform.isAndroid
          ? GrblWorkerClient.inProcess(port: AndroidUsbSerialRepository())
          : await GrblWorkerClient.spawn();
      ref.onDispose(client.dispose);
      return client;
    });

/// Identificador del perfil activo, compartido por conexión y calibración.
///
/// Es un provider aparte para que `ConnectionController` no dependa del de
/// calibración (eso crearía un ciclo).
class ActiveProfileId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final NotifierProvider<ActiveProfileId, String?> activeProfileIdProvider =
    NotifierProvider<ActiveProfileId, String?>(ActiveProfileId.new);

/// Lista de perfiles guardados (barra superior y calibración).
///
/// Se invalida al crear, editar o borrar un perfil para que el selector de la
/// barra superior se mantenga al día.
final FutureProvider<List<MachineProfile>> profilesProvider =
    FutureProvider<List<MachineProfile>>((Ref ref) async {
      return ref.watch(databaseProvider).allProfiles();
    });

/// Último trabajo con punto de reanudación guardado.
///
/// Alimenta el botón «Reanudar trabajo guardado» del visor: un trabajo pausado,
/// detenido o interrumpido puede retomarse desde su línea sin volver a empezar.
final FutureProvider<ProjectFile?> resumableProjectProvider =
    FutureProvider<ProjectFile?>((Ref ref) async {
      final List<ProjectFile> projects = await ref
          .watch(databaseProvider)
          .recentProjects();
      for (final ProjectFile project in projects) {
        if (project.resume != null) {
          return project;
        }
      }
      return null;
    });

/// Perfil activo resuelto desde la base de datos.
///
/// Si el id guardado ya no existe, cae al perfil actualizado más recientemente.
final FutureProvider<MachineProfile?> activeProfileProvider =
    FutureProvider<MachineProfile?>((Ref ref) async {
      final AppDatabase database = ref.watch(databaseProvider);
      final String? id = ref.watch(activeProfileIdProvider);
      if (id != null) {
        final MachineProfile? byId = await database.profileById(id);
        if (byId != null) {
          return byId;
        }
      }
      return database.mostRecentProfile();
    });
