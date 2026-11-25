import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/serial/grbl_worker_client.dart';
import '../domain/entities/machine_profile.dart';

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
/// En pruebas se sobrescribe con `GrblWorkerClient.inProcess(...)`, de modo que
/// la UI se puede probar sin hardware ni DLL nativa.
final FutureProvider<GrblWorkerClient> grblWorkerProvider =
    FutureProvider<GrblWorkerClient>((Ref ref) async {
      final GrblWorkerClient client = await GrblWorkerClient.spawn();
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
