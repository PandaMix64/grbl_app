import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/serial/grbl_worker_client.dart';

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
