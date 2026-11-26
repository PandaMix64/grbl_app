# Estado del Proyecto — grbl_app

> **Propósito:** este archivo es el punto de retorno. Cualquier agente o persona que retome el
> trabajo debe leerlo primero: dice en qué fase estamos, qué se hizo, qué falta y por qué se
> tomaron las decisiones que están en vigor.
> **Protocolo:** se actualiza al final de cada sesión (§4 bitácora, §3 tablero, §2 fases).

| Campo | Valor |
| :--- | :--- |
| Proyecto | `grbl_app` — entorno CNC con Flutter + GRBL v1.1h |
| Repositorio | Git local, rama `main` (inicializado 2026-11-24) |
| Sesión actual | **S-07 (cerrada)** |
| Fase actual | **Fase 3 — Visor 3D (en curso)** |
| Avance global estimado | ~80 % |
| Bloqueos | Ninguno. Prueba en banco pospuesta (R-10) |
| Siguiente hito | **M3.2** — ejecución desde el visor con holgura aplicada, pausa y reanudación persistida |

---

## 1. Cómo retomar el trabajo (checklist de arranque)

1. Leer este archivo completo y `docs/revision_tecnica_ruta_de_accion.md` (§3, hallazgos P0).
2. Ejecutar `flutter analyze` y `flutter test` para confirmar que la línea base está sana.
3. Revisar §8 (próximos pasos): la primera tarea pendiente es la de arriba.
4. Al terminar, actualizar §3, §4 y §2 y hacer commit con la etiqueta `[S-xx]`.

---

## 2. Fases del plan

| Fase | Objetivo | Estado | Notas |
| :--- | :--- | :--- | :--- |
| **Fase 0: Fundaciones** | Repo, entorno, contratos de dominio, fachada serial, política de seguridad | 🟢 **Cerrada salvo licencia y CHANGELOG** | Añadida por la revisión técnica; M0.1–M0.3 entregados en S-02 |
| **Fase 1: Núcleo y Serial** | Clean Architecture, esquema SQLite, navegación M3, isolate serial con *character-counting* | ✅ **Cerrada** | Conexión, handshake, worker, Drift, providers y barra de conexión entregados |
| **Fase 2: Calibración** | Jogging, pasos/mm, parámetros `$`, perfiles y *backlash* | ✅ **Cerrada** | Jogging, parámetros, pasos/mm, perfiles, holgura, homing y origen |
| **Fase 3: Visor 3D** | Renderizado, interpretación de G-code, pausa/detención y reanudación segura | ✅ **Cerrada** | Visor, ejecución con progreso real, pausa persistente, `interrupted` y reanudación verificada (S-08–S-11) |
| **Fase 4: Generador CAM** | Imagen → G-code (vectorización, dithering, relieve 2.5D) | ✅ Cerrada (grabado, contornos con pestañas y relieve) | Modo láser requiere `$32` (P1-1) |
| **Fase 5: Optimización y Empaquetado** | Rendimiento, atajos, builds Windows/Linux/macOS/Android | 🟡 En curso | APK de Android (con serie USB-OTG desde S-19) y release de Windows listos; faltan isolate (R-17), atajos, Linux/macOS, CHANGELOG y licencia |

Leyenda: 🟡 en curso · ✅ cerrada · ⬜ pendiente · 🔴 bloqueada

---

## 3. Tablero de tareas — Fase 0

### M0.1 Entorno reproducible
- [x] Repositorio Git inicializado (`main`)
- [x] Proyecto Flutter creado para `windows`, `linux`, `macos`, `android`
- [x] `.gitignore` de Flutter + `.gitattributes` con normalización LF
- [x] `flutter upgrade` a **Flutter 3.50.1 / Dart 3.14.0** (R-03 cerrado)
- [x] Dependencias base fijadas en `pubspec.yaml` + `flutter pub get`
- [x] CI con `flutter analyze`, `flutter test` y `dart format --set-exit-if-changed`
- [ ] Verificar el CI en GitHub (primer push al remoto)

### M0.2 Trazabilidad y documentación
- [x] Ruta de acción incorporada a `docs/`
- [x] Revisión técnica con hallazgos P0/P1/P2 (`docs/revision_tecnica_ruta_de_accion.md`)
- [x] Tablero de estado (este archivo)
- [x] `docs/seguridad_operativa.md` con las secuencias de pausa/parada/emergencia y criterios SEG/FLOW
- [ ] `CHANGELOG.md` + licencia + `NOTICE` de atribuciones (GPLv3 de GRBL)

### M0.3 Contratos y fachada
- [x] Modelos: `MachineProfile`, `GrblSettings`, `StatusReport`, `MotionSegment`, `ProjectFile`, `ResumeState`
- [x] `SerialPortRepository` (interfaz) y `FakeSerialPort` para pruebas
- [x] `CharacterCountingBuffer` (presupuesto de 128 B, `error:` libera, tiempo real excluido)
- [x] `GrblSerialService` con streaming, telemetría y secuencias de seguridad (SEG-01/03/04)
- [x] `LibSerialPortRepository` (FFI sobre `flutter_libserialport`)
- [x] Isolate worker tipado (`GrblWorker` + `GrblWorkerClient`) con el servicio dentro
- [ ] Extraer `SafetyController` como fachada explícita (hoy las secuencias viven en el servicio)

### M1.1 Conexión real (cerrada en S-03)
- [x] `LibSerialPortRepository`: 8-N-1, sin flow control, `\r`, reensamblado de líneas
- [x] Worker en isolate propio + protocolo de mensajes tipado
- [x] Sondeo de estado a 5 Hz (`?`) desde el worker (200 ms configurable)
- [x] Handshake al conectar: `$I`, `$$`, `$G`, `$#` y banner
- [x] Detección del búfer real vía `[OPT:...,<bloques>,<bytes>]` y ajuste del presupuesto
- [x] `ProfileConsistency`: comparación perfil ↔ EEPROM con bloqueos y avisos
- [x] `stopJob` con confirmación de persistencia a través del canal (SEG-03)
- [ ] Verificación con hardware real (ver R-10)

### M1.2 Persistencia y UI de conexión (cerrada en S-04)
- [x] Esquema Drift (`machine_profiles`, `projects`, `recent_files`) con migraciones y pruebas con SQLite real
- [x] Providers de Riverpod para el `GrblWorkerClient` y la telemetría
- [x] Barra de conexión: puerto, baudios, estado y avisos de `ProfileConsistency`
- [x] Persistencia del punto de reanudación al confirmar `WorkerPersistRequest` (R-12 cerrado)

### M2.1 Calibración (cerrada en S-05)
- [x] Jogging con `$J=` (F obligatorio) y cancelación con `0x85` al soltar
- [x] Lectura/escritura de parámetros `$` con `GrblSettings.diff` (sin desgastar EEPROM)
- [x] Calibración de pasos/mm guiada (avance teórico vs. medido)
- [x] CRUD de perfiles de máquina sobre Drift

### M2.2 Compensación y aplicación de perfiles (cerrada en S-06)
- [x] Post-procesador de *backlash* con movimiento real (nunca `G92`, ver P0-2)
- [x] Prueba guiada de holgura por eje (avanzar/retroceder y medir), guardada en el perfil
- [x] Aplicar el perfil activo a la conexión (perfil compartido + escritura por diferencias)
- [x] Homing (`$H`) y definición de origen de trabajo (`G10 L20 P1`)

### M3.1 Visor (cerrada en S-07)
- [x] Intérprete de G-code a `MotionSegment` (incluida conversión de arcos `R` a `I`/`J`)
- [x] Renderizado con `CustomPainter` y `drawRawPoints` por lotes (ejecutado/pendiente/rápido)
- [x] Cabezal sincronizado con la telemetría y volumen de trabajo del perfil

### M3.2 Ejecución y reanudación — siguiente
- [ ] Enviar el programa desde el visor aplicando `BacklashCompensator` antes del streaming
- [ ] Progreso por índice de línea y pintado de lo ejecutado
- [ ] Pausa con `WorkerPersistRequest` → `ProjectRepository` → confirmación (cierra SEG-05)
- [ ] Reanudación verificando `$G`/`$#` contra lo guardado

---

## 4. Bitácora de sesiones

Cada commit de una sesión lleva su etiqueta en el mensaje (`... [S-01]`), de modo que
`git log --grep="S-01"` reconstruye exactamente lo hecho en esa sesión.

### S-01 — 2026-11-24 · Bootstrap y verificación de la ruta de acción

**Alcance:** verificar el documento del autor, inicializar el repositorio, crear el esqueleto Flutter y establecer el sistema de seguimiento.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | Proyecto Flutter multiplataforma (windows, linux, macos, android), 84 archivos generados | `lib/`, `windows/`, `linux/`, `macos/`, `android/`, `test/`, `pubspec.yaml` | ✅ |
| 2 | Normalización de finales de línea y exclusiones de assets | `.gitattributes` | ✅ |
| 3 | Documento del autor importado con cabecera de procedencia | `docs/ruta_de_accion_entorno_cnc_flutter_y_grbl.md` | ✅ |
| 4 | Revisión técnica: 15 afirmaciones verificadas, 3 P0, 9 P1, 8 P2, parches de texto y Fase 0 | `docs/revision_tecnica_ruta_de_accion.md` | ✅ |
| 5 | Tablero de fases, tareas y bitácora (este archivo) | `ESTADO_PROYECTO.md` | ✅ |
| 6 | README con estado, requisitos y estructura objetivo | `README.md` | ✅ |

**Verificaciones ejecutadas en la sesión:** `flutter create` OK · `git init` OK · `flutter analyze` → *No issues found* · `flutter test` → *All tests passed*.

**Trazabilidad (commits de S-01):**

| Hash | Commit |
| :--- | :--- |
| `cd41c96` | `chore(project): inicializa app Flutter para windows, linux, macos y android` |
| `2926b30` | `chore(repo): normaliza finales de linea y excluye secretos de firma` |
| `5cc8d70` | `docs: incorpora ruta de accion y revision tecnica de GRBL v1.1h` |
| `9b55990` | `docs(estado): crea tablero de seguimiento de fases y bitacora` |

Para recuperar la sesión completa: `git log --oneline --grep="S-01"`.


**Decisiones tomadas (ver §6):** ADR-001 a ADR-006.

**Abierto al cierre:** actualizar Flutter antes de añadir dependencias (ADR-006); escribir `docs/seguridad_operativa.md`; implementar `SerialPortRepository` y el worker isolate.

---

### S-02 — 2026-11-24 · Fundaciones técnicas: entorno, dominio y capa serial

**Alcance:** actualizar el toolchain, fijar dependencias, escribir el documento normativo de seguridad, implementar los contratos de dominio y la capa serial con sus pruebas, y añadir CI.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | SDK actualizado 3.29.2 → **3.50.1 / Dart 3.14.0**; `material_ui` adoptado y `sqlite3_flutter_libs` retirado (obsoleto) | `pubspec.yaml`, `pubspec.lock` | ✅ |
| 2 | Secuencias normativas de pausa, jog cancel, detención, reanudación y emergencia + criterios SEG/FLOW | `docs/seguridad_operativa.md` | ✅ |
| 3 | Esqueleto de app: `GrblApp`, tema oscuro de alto contraste y navegación adaptativa `NavigationRail`/`NavigationBar` | `lib/app/`, `lib/features/*`, `lib/core/widgets/` | ✅ |
| 4 | Constantes de protocolo (bytes en tiempo real, `\r`, 128 B, baudios) | `lib/core/grbl/grbl_constants.dart` | ✅ |
| 5 | Dominio puro: `Axis`, `MachineState`, `StatusReport`, `GrblSettings`, `MachineProfile`, `MotionSegment`, `ProjectFile` + `ResumeState` | `lib/domain/entities/` | ✅ |
| 6 | Contrato `SerialPortRepository` | `lib/domain/repositories/` | ✅ |
| 7 | `CharacterCountingBuffer`: presupuesto de 128 B, liberación en `ok` y en `error:`, sin contar tiempo real | `lib/data/serial/` | ✅ |
| 8 | `GrblSerialService`: streaming, telemetría, sondeo a 5 Hz y secuencias de seguridad (SEG-01/03/04) | `lib/data/serial/` | ✅ |
| 9 | 51 pruebas nuevas: dominio, presupuesto de caracteres, seguridad y navegación | `test/domain/`, `test/serial/`, `test/helpers/` | ✅ |
| 10 | CI (formato + análisis + tests + cobertura) | `.github/workflows/ci.yml` | ✅ |

**Verificaciones ejecutadas:** `flutter analyze` → *No issues found* · `flutter test` → **54 tests, todos en verde** · `dart format .` aplicado (15 archivos).

**Decisiones tomadas:** ADR-006 aplicado (upgrade), ADR-007, ADR-008, ADR-009.

**Trazabilidad (commits de S-02):**

| Hash | Commit |
| :--- | :--- |
| `e08180a` | `chore(deps): actualiza a Flutter 3.50.1 y fija el stack aprobado` |
| `d39c438` | `feat(app): esqueleto Material 3 con navegacion adaptativa` |
| `d017d66` | `feat(domain): entidades GRBL y contrato de puerto serial` |
| `0421f72` | `feat(serial): conteo de caracteres y secuencias de seguridad` |
| `20d3f3a` | `ci: analisis, formato y pruebas en cada push` |
| `5f7dd34` | `docs: normativa de seguridad y tablero de la sesion S-02` |

Recuperación de la sesión: `git log --oneline --grep="S-02"`.

**Abierto al cierre:** `LibSerialPortRepository` (FFI), isolate worker real, extracción del `SafetyController`, esquema Drift, licencia/CHANGELOG y ejecución del CI en remoto.

---

### S-03 — 2026-11-24 · Conexión real: FFI, isolate y handshake (M1.1)

**Alcance:** cerrar el camino de conexión con hardware (M1.1): implementación FFI del puerto, worker en isolate, handshake con `$I`/`$$`/`$G`/`$#`, detección del búfer real y comparación perfil ↔ EEPROM.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `BuildInfo` desde `$I`: versión, fecha, flags, bloques del planner y **búfer RX real** | `lib/domain/entities/build_info.dart` | ✅ |
| 2 | `ParserState` desde `$G` con comparación modal para reanudar (SEG-05) | `lib/domain/entities/parser_state.dart` | ✅ |
| 3 | `WorkOffsets` desde `$#` con comparación por tolerancia | `lib/domain/entities/work_offsets.dart` | ✅ |
| 4 | `GrblHandshake` (instantánea de sesión) con serialización JSON | `lib/domain/entities/grbl_handshake.dart` | ✅ |
| 5 | Consultas de sistema acumulando líneas hasta el `ok`, con timeout y bloqueo en movimiento | `lib/data/serial/grbl_serial_service.dart` | ✅ |
| 6 | `connectAndIdentify`: banner → `$I` → ajuste de búfer → `$$`/`$G`/`$#` | idem | ✅ |
| 7 | **Bug corregido:** la suscripción al puerto se crea antes de abrirlo (el banner se perdía) | idem | ✅ |
| 8 | `LibSerialPortRepository`: FFI 8-N-1 sin flow control, `\r`, reensamblado de líneas | `lib/data/serial/lib_serial_port_repository.dart` | ✅ |
| 9 | Worker en isolate + protocolo de mapas + cliente tipado; `stop` con ack de persistencia | `lib/data/serial/grbl_worker*.dart` | ✅ |
| 10 | `ProfileConsistency`: perfil ↔ EEPROM con bloqueos y avisos justificados | `lib/domain/services/profile_consistency.dart` | ✅ |
| 11 | 28 pruebas nuevas (82 en total, 1 saltada por entorno) | `test/domain/`, `test/serial/` | ✅ |

**Verificaciones ejecutadas:** `flutter analyze` → *No issues found* · `flutter test` → **82 en verde, 1 saltada** · `dart format` → 0 cambios.

**Hallazgo de entorno:** la biblioteca `serialport.dll` **solo** la despliega CMake en el bundle de la aplicación; no está disponible para `flutter test`. La prueba de humo FFI se salta con motivo explícito y la verificación real queda en R-10.

**Decisiones tomadas:** ADR-011, ADR-012, ADR-013, ADR-014.

**Trazabilidad (commits de S-03):**

| Hash | Commit |
| :--- | :--- |
| `9a662e4` | `chore(deps): declara libserialport como dependencia directa` |
| `98f29f7` | `feat(domain): build info, estado del parser y offsets de trabajo` |
| `d8bfe25` | `feat(serial): handshake real, deteccion de bufer y worker en isolate` |
| `df5c280` | `docs: tablero de S-03 y criterios de flujo del handshake` |

Recuperación de la sesión: `git log --oneline --grep="S-03"`.

**Abierto al cierre:** esquema Drift, providers de Riverpod, UI de conexión, extracción del `SafetyController` y verificación con hardware real.

---

### S-04 — 2026-11-24 · Persistencia, providers y barra de conexión (M1.2 · Fase 1 cerrada)

**Alcance:** cerrar M1.2: esquema Drift con pruebas reales, providers de Riverpod, barra de conexión en Inicio y persistencia del punto de reanudación antes del soft reset.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | Esquema Drift: `machine_profiles`, `projects`, `recent_files` + mappers y DAOs | `lib/data/database/app_database.dart` (+ `.g.dart`) | ✅ |
| 2 | 8 pruebas contra SQLite real (`NativeDatabase.memory()`) | `test/data/app_database_test.dart` | ✅ |
| 3 | `ProjectRepository.persistAndConfirm`: escribe y **solo después** confirma al worker (R-12) | `lib/data/repositories/project_repository.dart` | ✅ |
| 4 | `persistRequest` enriquecido con `$G` y timeout configurable | `lib/data/serial/grbl_worker*.dart` | ✅ |
| 5 | Providers: `databaseProvider` y `grblWorkerProvider` (sobrescribibles en pruebas) | `lib/app/providers.dart` | ✅ |
| 6 | `ConnectionController` con estado tipado y telemetría acoplada | `lib/features/connection/connection_controller.dart` | ✅ |
| 7 | Barra de conexión (puerto, baudios, chip de estado, firmware, búfer y avisos) | `lib/features/connection/widgets/connection_bar.dart`, `lib/features/home/home_page.dart` | ✅ |
| 8 | 16 pruebas nuevas (98 en total, 1 saltada) | `test/data/`, `test/features/`, `test/widget_test.dart` | ✅ |

**Verificaciones ejecutadas:** `flutter analyze` → *No issues found* · `flutter test` → **98 en verde, 1 saltada** · `dart format` → 0 cambios · `build_runner` → código generado sin conflictos.

**Hallazgo de entorno:** a diferencia de `libserialport`, **SQLite sí funciona en `flutter test`** porque `sqlite3` 3.x usa *native assets* (`hook/build.dart`). Por eso la persistencia se prueba de verdad y no con un doble.

**Bug de diseño corregido:** `spindleOn` se derivaba del status report posterior a la pausa, que ya tiene `S:0` porque `pauseSafely` apagó la herramienta. Ahora se deriva del estado modal `$G`, que es la fuente autoritativa de `M3`/`M4`/`M5` y de `F`/`S`.

**Decisiones tomadas:** ADR-015, ADR-016.

**Trazabilidad (commits de S-04):**

| Hash | Commit |
| :--- | :--- |
| `a346cbd` | `feat(db): esquema drift de perfiles, proyectos y recientes` |
| `1eb41f9` | `feat(serial): persistRequest con estado modal y timeout configurable` |
| `752ab66` | `feat(repository): persiste el punto de reanudacion antes del reset` |
| `159f0da` | `feat(connection): providers riverpod y barra de conexion` |
| `333c4b7` | `docs: cierra la fase 1 con persistencia y UI de conexion` |

Recuperación de la sesión: `git log --oneline --grep="S-04"`.

**Abierto al cierre:** prueba en banco (R-10, pospuesta por decisión del usuario hasta completar la UI) y toda la Fase 2.

---

### S-05 — 2026-11-24 · Calibración: jogging, parámetros y pasos/mm (M2.1)

**Alcance:** M2.1 completo: comandos de jog, lectura/escritura de `$` por diferencias, calibración de pasos/mm guiada, CRUD de perfiles y toda la UI del módulo.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `JogCommand` con validación (`F` obligatorio) y modos relativo/absoluto de máquina | `lib/domain/entities/jog_command.dart` | ✅ |
| 2 | `StepsPerMmCalibration` con rechazo de medidas fuera del ±50 % | `lib/domain/services/steps_per_mm_calibration.dart` | ✅ |
| 3 | `jog()` con guardia `Idle`/`Jog` y `writeSettings()` con `diff` y `ok` por parámetro | `lib/data/serial/grbl_serial_service.dart` | ✅ |
| 4 | Comandos `jog` y `writeSettings` en el worker y en el cliente | `lib/data/serial/grbl_worker*.dart` | ✅ |
| 5 | `CalibrationController` (perfiles, EEPROM, pasos/mm, jog) | `lib/features/calibration/calibration_controller.dart` | ✅ |
| 6 | UI: jog, parámetros, pasos/mm, perfiles y formulario de perfil | `lib/features/calibration/widgets/`, `calibration_page.dart` | ✅ |
| 7 | 26 pruebas nuevas (124 en total, 1 saltada) | `test/domain/`, `test/serial/`, `test/features/`, `test/widget_test.dart` | ✅ |

**Verificaciones ejecutadas:** `flutter analyze` → *No issues found* · `flutter test` → **124 en verde, 1 saltada** · `dart format` → 0 cambios.

**Bugs reales corregidos en la sesión**

1. **El jog se rechazaba al conectar**: `connectAndIdentify` devolvía el handshake antes de recibir la primera telemetría, así que `state` era `unknown` y la guardia `Idle/Jog` lo bloqueaba. Ahora espera hasta 2 s el primer status report (ADR-018).
2. **`copyWith` no podía limpiar el perfil seleccionado**: el `??` mantenía el valor anterior al borrar el último perfil. Añadido `clearSelectedProfile`.
3. **`Axis` colisionaba con el `Axis` de Flutter**: renombrado a `MachineAxis` (ADR-017). El primer reemplazo automático se hizo sin distinguir mayúsculas y hubo que corregir identificadores a mano — lección registrada.
4. **Overflow de 21 px** en la cabecera del panel de jog a 800 px de ancho: título con `Expanded` y `ellipsis`.

**Decisiones tomadas:** ADR-017, ADR-018.

**Trazabilidad (commits de S-05):**

| Hash | Commit |
| :--- | :--- |
| `359d972` | `feat(domain): jog con F obligatorio, pasos/mm y MachineAxis` |
| `4c33f9b` | `feat(serial): jog y escritura de parametros por diferencias` |
| `d0e1655` | `feat(calibration): controlador y UI de jogging, parametros y perfiles` |
| `0cef4cf` | `docs: tablero de S-05 y criterios SEG de calibracion` |

Recuperación de la sesión: `git log --oneline --grep="S-05"`.

**Abierto al cierre:** compensación de holgura con movimiento real, aplicación automática del perfil y homing (M2.2); prueba en banco (R-10).

---

### S-06 — 2026-11-24 · Holgura, perfil aplicado, homing y origen (M2.2 · Fase 2 cerrada)

**Alcance:** M2.2 completo: compensación de holgura con movimiento real, prueba guiada de holgura, perfil activo compartido y aplicable a la máquina, homing y definición de origen.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `BacklashCompensator`: inyecta un `G1` de la holgura al invertir sentido; nunca Z ni arcos | `lib/domain/services/backlash_compensator.dart` | ✅ |
| 2 | `BacklashEstimate`: ida/vuelta con validación (±50 %, no negativa) | `lib/domain/services/backlash_estimate.dart` | ✅ |
| 3 | `setWorkZero` con `G10 L20 P1` (servicio, worker y cliente), bloqueado en `Alarm` | `lib/data/serial/*` | ✅ |
| 4 | `activeProfileIdProvider` / `activeProfileProvider`: la conexión compara el perfil **elegido** | `lib/app/providers.dart`, `connection_controller.dart` | ✅ |
| 5 | Controlador: holgura→perfil, aplicar perfil (`$32`, `$30`, `$130-$132` por diferencias), homing, origen | `lib/features/calibration/calibration_controller.dart` | ✅ |
| 6 | UI: panel de origen/homing y de holgura con confirmaciones, botón «Aplicar perfil» | `lib/features/calibration/widgets/` | ✅ |
| 7 | 26 pruebas nuevas (150 en total, 1 saltada) | `test/domain/`, `test/serial/`, `test/features/` | ✅ |

**Verificaciones ejecutadas:** `flutter analyze` → *No issues found* · `flutter test` → **150 en verde, 1 saltada** · `dart format` → 0 cambios.

**Criterio de diseño clave:** al invertir el sentido, la mesa va retrasada respecto al motor, así que un movimiento extra de `holgura` en la dirección nueva consume el juego y el bloque siguiente mueve la mesa exactamente lo ordenado. Todo ocurre en coordenadas de motor: no se falsea ningún origen ni se usa `G92` (P0-2 resuelto).

**Incidente de sesión:** al reemplazar un bloque de pruebas se eliminó sin querer el caso *un error: al escribir no se silencia*; se detectó al ejecutar la suite y se restauró.

**Decisiones tomadas:** ADR-019, ADR-020, ADR-021.

**Trazabilidad (commits de S-06):**

| Hash | Commit |
| :--- | :--- |
| `e277793` | `feat(domain): compensador de holgura con movimiento real` |
| `4e88055` | `feat(serial): origen de trabajo con G10 L20` |
| `50117ed` | `feat(calibration): holgura, aplicar perfil, homing y origen en la UI` |
| `20910e6` | `docs: cierra M2.2 con holgura y origen documentados` |

Recuperación de la sesión: `git log --oneline --grep="S-06"`.

**Abierto al cierre:** el compensador aún no está conectado al flujo de ejecución (no existe ejecución hasta la Fase 3); arcos y Z quedan fuera por diseño (R-16).

---

### S-07 — 2026-11-24 · Intérprete de G-code y visor 3D (M3.1)

**Alcance:** M3.1 completo: de G-code a segmentos (con arcos), proyección ortográfica propia, pintor por lotes y visor conectado a la telemetría y al perfil activo.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `GcodeProgram`: segmentos, línea de origen, avisos, volumen y longitudes | `lib/domain/entities/gcode_program.dart` | ✅ |
| 2 | `GcodeInterpreter`: G0/G1, G2/G3 con `I/J` y `R`, G90/G91, G20/G21, comentarios y avisos | `lib/domain/services/gcode_interpreter.dart` | ✅ |
| 3 | `ViewProjection`: proyección ortográfica con guiñada/cabeceo y `fitScale` | `lib/features/viewer/view_projection.dart` | ✅ |
| 4 | `ProgramPainter`: tres lotes con `drawRawPoints`, volumen, rejilla y cabezal | `lib/features/viewer/program_painter.dart` | ✅ |
| 5 | `ViewerCanvas`: desplazar, acercar y rotar con gestos; doble toque restablece | `lib/features/viewer/widgets/viewer_canvas.dart` | ✅ |
| 6 | `ViewerController` y página con estadísticas, avisos y apertura de archivo | `lib/features/viewer/viewer_controller.dart`, `viewer_page.dart` | ✅ |
| 7 | 28 pruebas nuevas (178 en total, 1 saltada) | `test/domain/`, `test/features/`, `test/widget_test.dart` | ✅ |

**Verificaciones ejecutadas:** `flutter analyze` → *No issues found* · `flutter test` → **178 en verde, 1 saltada** · `dart format` → 0 cambios.

**Decisiones de diseño**

- El visor simula **coordenadas de trabajo** y avisa (en lugar de fingir) de `G28`, `G30`, `G53` y `G92`.
- Los arcos se subdividen a 5° por defecto, lo que permite estimar longitudes y preparar la compensación de holgura por segmentos.
- Los tres lotes (rápido / pendiente / ejecutado) se envían con `drawRawPoints(PointMode.lines)` para no cambiar de `Paint` por segmento.

**Lección de proceso (segunda vez):** al reemplazar bloques grandes de pruebas se volvieron a perder assertions existentes; se detectó al ejecutar y se restauró. A partir de ahora los cambios en pruebas se harán con anclas cortas y única ocurrencia.

**Decisiones tomadas:** ADR-022, ADR-023.

**Trazabilidad (commits de S-07):**

| Hash | Commit |
| :--- | :--- |
| `35395a0` | `feat(domain): interprete de G-code con arcos y programa simulado` |
| `e77818a` | `feat(viewer): proyeccion, pintor por lotes y visor 3D` |
| `0526325` | `docs: cierra M3.1 con el visor documentado` |

Recuperación de la sesión: `git log --oneline --grep="S-07"`.

**Abierto al cierre:** ejecución desde el visor, pausa/reanudación y el parseo asíncrono para archivos grandes (R-17).

---

### S-08 — 2026-11-24 · Ejecución desde el visor, pausa y reanudación (M3.2)

**Alcance:** M3.2 completo: enviar el programa del visor con la holgura aplicada, pintar el avance real, pausar **persistiendo** el punto de reanudación y reanudar solo si `$G`/`$#` coinciden con lo guardado.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `streamProgram` con progreso por `ok` confirmados y `cancelProgram` | `lib/data/serial/grbl_serial_service.dart` | ✅ |
| 2 | Comandos `streamProgram`, `pauseJob` y `resumeJob`; evento `progress` | `lib/data/serial/{grbl_worker,grbl_worker_client,grbl_worker_protocol}.dart` | ✅ |
| 3 | Consultas `$G`/`$#` **directas** al puerto (`direct: true`) válidas en `Hold` | `lib/data/serial/grbl_serial_service.dart` | ✅ |
| 4 | `$#` dentro del `persistRequest`; `ResumeState.offsets` | `lib/data/serial/grbl_worker.dart`, `lib/domain/entities/project_file.dart` | ✅ |
| 5 | Esquema Drift **v2** con `resume_offsets` y migración `addColumn` | `lib/data/database/app_database.dart` | ✅ |
| 6 | `BacklashCompensationResult.lineIndexes`: mapa salida → línea de origen | `lib/domain/services/backlash_compensator.dart` | ✅ |
| 7 | `ExecutionController`: compensar, guardar proyecto, enviar, pausar, reanudar y detener | `lib/features/viewer/execution_controller.dart` | ✅ |
| 8 | `ExecutionBar` con progreso, estado y confirmaciones de ejecutar/detener | `lib/features/viewer/widgets/execution_bar.dart` | ✅ |
| 9 | Progreso pintado en el lienzo (`executedUpToLine`) y texto fuente en el visor | `lib/features/viewer/{viewer_page,viewer_controller}.dart` | ✅ |
| 10 | `confirmAction` movido a `core/widgets` para reutilizarlo | `lib/core/widgets/confirm_dialog.dart` | ✅ |
| 11 | 10 pruebas nuevas (187 en verde, 1 saltada) + `ackDelay` y `Hold` realista en el emulador | `test/features/execution_controller_test.dart`, `test/helpers/fake_serial_port.dart`, `test/widget_test.dart` | ✅ |

**Verificaciones ejecutadas:** `dart format .` → 0 cambios · `flutter analyze` → *No issues found* · `flutter test` → **187 en verde, 1 saltada** (`flutter_libserialport` fuera de un build de la app) · `flutter build windows --debug` → **OK**, con `serialport.dll`, `flutter_libserialport_plugin.dll` y `sqlite3.dll` en `build/windows/x64/runner/Debug` (el camino FFI carga; R-10 queda listo para la prueba en banco).

**Decisiones de diseño**

- **Pausa ≠ detención.** La pausa deja intacto el búfer de GRBL y se reanuda con `0x9E` (reactivar herramienta) + `~`; reenviar líneas duplicaría el trabajo. Detener sí resetea y descarta.
- El progreso se deriva de los `ok` reales, no de líneas escritas: un programa "enviado" no está ejecutado.
- Las consultas de estado en `Hold` se escriben **directamente** al puerto: las líneas del programa en vuelo no se confirman y el búfer interno nunca se vaciaría.
- Un `ok` suelto ya no cierra una consulta sin respuesta; era la causa de persistir `$#` vacío y rechazar toda reanudación.
- Si `$G`/`$#` no se pueden leer, se guarda `null` y la reanudación avisa en vez de inventar estado.

**Decisiones tomadas:** ADR-024, ADR-025, ADR-026, ADR-027.

**Trazabilidad (commits de S-08):**

| Hash | Commit |
| :--- | :--- |
| `331cc73` | `feat(serial): progreso confirmado, pausa persistente y reanudacion segura` |
| `ffd603b` | `feat(persistencia): guarda los offsets del punto de reanudacion` |
| `970ac8f` | `feat(viewer): ejecuta el programa con holgura y progreso real` |
| `7c6abd6` | `test: cubre ejecucion, pausa con persistencia y reanudacion verificada` |
| `9045dde` | `docs: cierra M3.2 con la guia de prueba en banco` |
| `a3cf101` | `docs: anota el build de escritorio verificado antes de la prueba en banco` |

Recuperación de la sesión: `git log --oneline --grep="S-08"`.

**Abierto al cierre:** flujo "reiniciar trabajo guardado" tras un `stop` (hoy exige re-homing y volver a enviar desde el visor) y la limpieza automática de la ejecución si se pierde el USB (R-19). La guía de la primera prueba con hardware está en `docs/prueba_banco.md`.

---

### S-09 — 2026-11-24 · Primera prueba con hardware, cierre crítico y barra de mando (M3.3)

**Alcance:** corregir lo observado en la primera pasada con Arduino + GRBL 1.1h (P0 de desconexión), añadir consola de comandos, barra superior persistente con perfil activo y los ajustes de calibración pedidos.

**Hallazgos de la prueba en banco**

| # | Observación | Resolución |
| :--- | :--- | :--- |
| 1 | Log ilegible: la telemetría lo sobrescribía | Consola con búfer de 400 líneas, sin `<...>` ni ráfaga de `ok` |
| 2 | **Cierre de la app al desconectar** (`_CrtIsValidHeapPointer`, `debug_heap.cpp:904`) | Doble `free` del `sp_port_config` + `use-after-free` del puerto frente al lector |
| 3 | El aviso de perfil no aparecía al refrescar `$$` | `ConnectionController.revalidate` tras cada lectura y al cambiar de perfil |
| 4 | Sin forma de salir de `Alarm` ni de resetear | `$X` y soft reset en la barra superior, con confirmación |
| 5 | Pasos/mm se podía reaplicar por accidente | El campo «Medido» se vacía tras aplicar |
| 6 | Faltaba «ir a 0,0» | `goToWorkZero()` con `$J=` calculado desde `WPos` |

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | Config del puerto sin liberar dos veces y espera de drenaje del lector | `lib/data/serial/lib_serial_port_repository.dart` | ✅ |
| 2 | `consoleLines`, `sendConsoleCommand` y `softReset` en el servicio | `lib/data/serial/grbl_serial_service.dart` | ✅ |
| 3 | Comandos `consoleCommand`/`softReset` y evento `console` en el worker | `lib/data/serial/{grbl_worker,grbl_worker_client,grbl_worker_protocol}.dart` | ✅ |
| 4 | `ConsoleController` + `ConsolePanel` (búfer, historial, filtros) | `lib/features/console/` | ✅ |
| 5 | `AppTopBar`: estado, perfil activo, consola, `$X` y soft reset | `lib/app/widgets/app_top_bar.dart`, `home_shell.dart` | ✅ |
| 6 | `profilesProvider` y revalidación al refrescar y al cambiar de perfil | `lib/app/providers.dart`, `connection_controller.dart`, `calibration_controller.dart` | ✅ |
| 7 | `goToWorkZero` y limpieza del campo de medición | `calibration_controller.dart`, `steps_panel.dart`, `origin_panel.dart` | ✅ |
| 8 | 9 pruebas nuevas (196 en verde, 1 saltada) | `test/serial/console_command_test.dart`, `test/features/calibration_controller_test.dart`, `test/widget_test.dart` | ✅ |

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed` → 0 cambios · `flutter analyze` → *No issues found* · `flutter test` → **196 en verde, 1 saltada**.

**Decisiones de diseño**

- El `config` del puerto se considera **propiedad** de `SerialPort`: liberarlo además es un doble `free` que solo se manifiesta al desconectar (y en debug aborta el proceso).
- El isolate lector puede seguir dentro de `sp_wait` durante su timeout (50 ms): se espera 150 ms antes de `sp_close`/`sp_free_port`.
- La consola acepta comandos `$` en cualquier estado; el resto exige `Idle`, para no inyectar movimiento en mitad de un trabajo.
- El soft reset de la barra **no** sustituye a «Detener»: con un trabajo activo se rechaza y se remite al visor para no perder el progreso.
- El aviso de discrepancias se recalcula con cada lectura de `$$` y con cada cambio de perfil, no solo al conectar.

**Decisiones tomadas:** ADR-028, ADR-029, ADR-030.

**Trazabilidad (commits de S-09):**

| Hash | Commit |
| :--- | :--- |
| `82096b0` | `fix(serial): evita el doble free del config y el use-after-free al desconectar` |
| `05ead34` | `feat(serial): consola de comandos y soft reset con espera de banner` |
| `3293d46` | `feat(app): barra superior con estado, perfil, consola y comandos basicos` |
| `1557acc` | `fix(calibracion): avisa al refrescar la EEPROM, limpia la medicion y permite ir a 0,0` |
| `ccbf6b8` | `test: cubre consola, revalidacion del perfil, ir a cero y barra superior` |
| `5396f6b` | `fix(serial): descarta escrituras mientras el puerto se cierra` |

Recuperación de la sesión: `git log --oneline --grep="S-09"`.

**Abierto al cierre:** re-verificar en banco el cierre al desconectar; `$X` no elimina la causa de la alarma (R-21); la consola es una vía avanzada que evita las salvaguardas de la UI (R-20).

---

### S-10 — 2026-11-24 · Telemetría persistente y encuadre del visor (M3.4)

**Alcance:** corregir la desaparición de la posición (cabezal 3D y cero de trabajo) y dar control de encuadre al visor; la ejecución desde el visor quedó validada en banco hasta 5.5.

**Hallazgos**

| # | Observación | Causa | Resolución |
| :--- | :--- | :--- | :--- |
| 1 | La posición desaparecía casi al instante | GRBL omite `WCO` en la mayoría de reportes y el controlador **borraba** `workPosition` cuando no podía resolver `WPos` | Se memoriza el último `WCO` y se conserva la última posición válida |
| 2 | Difícil posicionar en el origen sin datos de posición | Consecuencia de (1) | La UI mantiene el WPos y marca «(última lectura)» en lugar de vaciar |
| 3 | El visor quedaba «atorado» si el trazado salía del viewport | No había forma de reencuadrar y el paneo sobrevivía al cambio de programa | Botón «Centrar trazado», encuadre automático al cargar y `RepaintBoundary` |

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `_onStatusReport` con `WCO` memorizado, posición persistente y `positionIsLive` | `lib/features/connection/connection_controller.dart` | ✅ |
| 2 | Semilla del `WCO` con `G54` del handshake | `connection_controller.dart` | ✅ |
| 3 | Descarte de valores no finitos (`NaN`/`Infinity`) en la telemetría | `lib/domain/entities/status_report.dart` | ✅ |
| 4 | «Centrar trazado», encuadre automático y capa de repintado | `lib/features/viewer/{viewer_page,viewer_canvas}.dart` | ✅ |
| 5 | 3 pruebas nuevas (199 en verde, 1 saltada) | `test/features/connection_telemetry_test.dart`, `test/widget_test.dart` | ✅ |

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed` → 0 cambios · `flutter analyze` → *No issues found* · `flutter test` → **199 en verde, 1 saltada**.

**Decisiones de diseño**

- La posición de trabajo es un **estado retenido**: solo el handshake (al conectar) y la desconexión la reinician.
- `positionIsLive` distingue «viene de este reporte» de «última conocida» sin mentir al operario.
- El paneo/zoom **no** se conserva entre programas: un archivo nuevo siempre entra encuadrado.

**Decisiones tomadas:** ADR-031, ADR-032.

---

### S-11 — 2026-11-24 · Reinicio de trabajos guardados e interrupción segura (M3.5)

**Alcance:** cerrar R-18 (retomar un trabajo tras pausa, detención o pérdida de enlace) y R-19 (limpieza de la ejecución al desconectar), sin repetir tramo ya ejecutado.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `ExecutionStatus.interrupted` y detección de enlace perdido con trabajo activo | `lib/features/viewer/execution_controller.dart` | ✅ |
| 2 | `markProjectInterrupted` en la base de datos | `lib/data/database/app_database.dart` | ✅ |
| 3 | `resumableProjectProvider`: último trabajo con punto de reanudación | `lib/app/providers.dart` | ✅ |
| 4 | `start(resumeFromLine:, projectId:)`: envía desde la línea guardada y reutiliza la fila | `execution_controller.dart` | ✅ |
| 5 | `restartFromSaved()`: `$G`/`$#` (SEG-05) + distancia al punto guardado (≤ 1 mm) | `execution_controller.dart` | ✅ |
| 6 | `jogToWorkPosition`: mover al punto guardado con `$J=` desde `WPos` | `lib/features/calibration/calibration_controller.dart` | ✅ |
| 7 | Botones «Reanudar trabajo guardado» y «Llevar al punto guardado» con confirmación | `lib/features/viewer/widgets/execution_bar.dart` | ✅ |
| 8 | 5 pruebas nuevas (204 en verde, 1 saltada) | `test/features/execution_restart_test.dart` | ✅ |

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed` → 0 cambios · `flutter analyze` → *No issues found* · `flutter test` → **204 en verde, 1 saltada**.

**Decisiones de diseño**

- Reiniciar **reenvía** el programa desde la línea confirmada (no usa `~`): tras un `stop` el planificador está vacío y el bloque guardado puede no haberse ejecutado.
- Se exige que la máquina esté a ≤ 1 mm del punto guardado: la app no mueve la máquina por su cuenta, solo ofrece «Llevar al punto guardado».
- Perder el enlace **no** borra el progreso: el proyecto pasa a `interrupted` y el punto guardado sigue disponible.
- `executedLine` arranca en `lineIndex - 1` para que el visor pinte lo ya hecho sin saltos.

**Decisiones tomadas:** ADR-033, ADR-034.

---

### S-12 — 2026-11-24 · CAM: grabado láser desde imagen (M4 primera parte)

**Alcance:** primer bloque de la Fase 4 según el plan del autor («dithering/umbrales láser con `M4`»): imagen → G-code de grabado, en isolate y con previsualización obligatoria en el visor.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `EngravingGenerator`: umbral, tramado Floyd–Steinberg y escala de grises con `M4` | `lib/domain/services/engraving_generator.dart` | ✅ |
| 2 | Generación en isolate (`Isolate.run`) y límite de 250 000 celdas | `engraving_generator.dart` | ✅ |
| 3 | `CamController`: valida perfil láser y volumen antes de generar; envía al visor | `lib/features/cam/cam_controller.dart` | ✅ |
| 4 | Pantalla CAM con imagen, parámetros, resultado y avisos | `lib/features/cam/cam_page.dart` | ✅ |
| 5 | 11 pruebas nuevas (215 en verde, 1 saltada) | `test/domain/engraving_generator_test.dart`, `test/features/cam_controller_test.dart`, `test/widget_test.dart` | ✅ |

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed` → 0 cambios · `flutter analyze` → *No issues found* · `flutter test` → **215 en verde, 1 saltada**.

**Decisiones de diseño**

- Solo láser: la potencia por celda solo tiene sentido con `M4`; con husillo (`M3`) el `S` es velocidad, no potencia.
- El G-code se agrupa por tramos de potencia igual y cada fila entra con `G0 ... S0`: menos líneas y láser apagado en los rápidos.
- La fila 0 de la imagen es el borde **superior** del grabado (como en un editor gráfico), con origen en la esquina inferior izquierda.
- El CAM **no** envía nada a la máquina: carga el resultado en el visor, donde se revisa y se ejecuta con las barreras de M3.2.

**Decisiones tomadas:** ADR-035, ADR-036.

**Trazabilidad (commits de S-12):**

| Hash | Commit |
| :--- | :--- |
| `8af109a` | `feat(cam): genera grabado laser desde imagen en un isolate` |
| `f929ae6` | `test: cubre el generador de grabado y el controlador CAM` |

Recuperación de la sesión: `git log --oneline --grep="S-12"`.

**Abierto al cierre:** vectorización de contornos y relieve 2.5D (resto de la Fase 4); las pestañas de sujeción siguen pendientes.

---

### S-13 — 2026-11-24 · Vista previa del grabado y visor a pantalla completa (M3.6)

**Alcance:** que el CAM muestre **el resultado** (no solo la trayectoria) y recuperar viewport en el visor.

**Hallazgos**

| # | Observación | Resolución |
| :--- | :--- | :--- |
| 1 | En el visor solo se veía la trayectoria: no se entendía qué iba a quedar grabado | Vista previa en la propia pantalla CAM: una celda = un píxel, con el material quemado en negro |
| 2 | La barra de ejecución robaba altura al lienzo | Barra compacta superpuesta al viewport, con iconos y una sola línea de estado |

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `EngravingResult.previewPng`: PNG del mapa de potencia (celdas reales) | `lib/domain/services/engraving_generator.dart` | ✅ |
| 2 | Vista previa en CAM sobre fondo claro, sin interpolación y con pie de tamaño | `lib/features/cam/cam_page.dart` | ✅ |
| 3 | `ExecutionBar` compacta: iconos, progreso fino y estado en una línea | `lib/features/viewer/widgets/execution_bar.dart` | ✅ |
| 4 | Lienzo a pantalla completa con la barra superpuesta; «Centrar trazado» pasa a la barra | `lib/features/viewer/viewer_page.dart` | ✅ |
| 5 | pruebas: vista previa en el generador y barra nueva en el widget test (216 en verde, 1 saltada) | `test/domain/engraving_generator_test.dart`, `test/widget_test.dart` | ✅ |

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed` → 0 cambios · `flutter analyze` → *No issues found* · `flutter test` → **216 en verde, 1 saltada** · `flutter build windows --debug` → OK.

**Decisiones de diseño**

- La vista previa es el **mapa de potencia** que se enviará, no la foto original: así se ven el umbral, el tramado y la escala real de celdas.
- Se dibuja con `FilterQuality.none` sobre fondo claro para simular el material y no maquillar los píxeles.
- La barra superpuesta ocupa una fila (~56 px) en lugar de una tarjeta completa; los avisos (sin conexión, alarma, error) se resumen en una línea bajo el progreso.

**Decisiones tomadas:** ADR-037, ADR-038.

**Trazabilidad (commits de S-13):**

| Hash | Commit |
| :--- | :--- |
| `98f5f82` | `feat(cam): muestra la vista previa del grabado en la propia pantalla` |
| `df3c22f` | `feat(visor): barra de ejecucion compacta sobre el lienzo` |

Recuperación de la sesión: `git log --oneline --grep="S-13"`.

---

### S-14 — 2026-11-24 · Fase 4: contornos vectorizados con pestañas (M4.1)

**Alcance:** segundo bloque del CAM: vectorizar la silueta de una imagen y cortarla con pasadas en Z y pestañas de sujeción, con previsualización del recorrido.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `ContourGenerator`: umbral → rejilla → aristas de píxel → bucles cerrados (con huecos) | `lib/domain/services/contour_generator.dart` | ✅ |
| 2 | Simplificación (colineales + Douglas–Peucker) y límites de celdas/puntos | `contour_generator.dart` | ✅ |
| 3 | Pasadas en Z para husillo (`M3`) y corte láser (`M4` con `S` conmutado) | `contour_generator.dart` | ✅ |
| 4 | Pestañas: subdivisión por longitud de arco, subida de Z o apagado del haz | `contour_generator.dart` | ✅ |
| 5 | Vista previa vectorial (PNG de los contornos simplificados) | `contour_generator.dart`, `cam_page.dart` | ✅ |
| 6 | CAM con selector **Grabado / Contorno** y panel de parámetros de corte | `cam_controller.dart`, `cam_page.dart` | ✅ |
| 7 | 11 pruebas nuevas (227 en verde, 1 saltada) | `test/domain/contour_generator_test.dart`, `test/features/cam_controller_test.dart`, `test/widget_test.dart` | ✅ |

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed` → 0 cambios · `flutter analyze` → *No issues found* · `flutter test` → **227 en verde, 1 saltada** · `flutter build windows --debug` → OK.

**Decisiones de diseño**

- La silueta se traza con las **aristas de cada píxel** y se encadena por vértices: detecta islas y huecos, es determinista y no necesita dependencias externas.
- Douglas–Peucker con tolerancia en mm (0.2 por defecto) convierte la escalera de píxeles en diagonales mecanizables.
- Con láser el contorno es una sola pasada y las pestañas apagan el haz (`S0`); con husillo se baja por niveles hasta `cutZ` y las pestañas levantan la Z.
- En CAM solo hay **una operación activa**: cambiar de pestaña descarta el resultado anterior para que la vista previa nunca mienta.

**Decisiones tomadas:** ADR-039, ADR-040.

**Trazabilidad (commits de S-14):**

| Hash | Commit |
| :--- | :--- |
| `9ebee0b` | `feat(cam): vectoriza contornos con pasadas y pestañas` |

Recuperación de la sesión: `git log --oneline --grep="S-14"`.

**Abierto al cierre:** relieve 2.5D (último bloque de la Fase 4) y pestañas en el grabado raster (hoy solo en contorno).

---

### S-15 — 2026-11-24 · Fase 4 cerrada: relieve 2.5D (M4.2)

**Alcance:** último bloque del CAM: mapa de altura cuantizado en niveles y fresado por bandas de profundidad con el husillo, con vista previa del relieve.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `ReliefGenerator`: luminancia → nivel (0..N) con muestreo por celda | `lib/domain/services/relief_generator.dart` | ✅ |
| 2 | Fresado por bandas: cada nivel corta las celdas de ese nivel o más profundas | `relief_generator.dart` | ✅ |
| 3 | Pasadas dentro de cada nivel (`passDepth`) hasta su cota | `relief_generator.dart` | ✅ |
| 4 | Vista previa del mapa de altura (oscuro = más profundo) | `relief_generator.dart`, `cam_page.dart` | ✅ |
| 5 | Tercera operación del CAM (**Grabado / Contorno / Relieve**) con panel propio | `cam_controller.dart`, `cam_page.dart` | ✅ |
| 6 | Validaciones: niveles 2–16, profundidad ≤ recorrido Z, perfil de fresadora | `relief_generator.dart`, `cam_controller.dart` | ✅ |
| 7 | 9 pruebas nuevas (236 en verde, 1 saltada) | `test/domain/relief_generator_test.dart`, `test/features/cam_controller_test.dart`, `test/widget_test.dart` | ✅ |

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed` → 0 cambios · `flutter analyze` → *No issues found* · `flutter test` → **236 en verde, 1 saltada**.

**Decisiones de diseño**

- **Bandas acumulativas**: la celda de nivel `L` se fresa en todos los niveles `1..L`, de modo que el resultado es una escalera de profundidad sin un algoritmo de desbaste complejo.
- La profundidad de cada nivel se reparte en pasadas de `passDepth` (nunca se baja más de golpe).
- El relieve es **solo con fresadora**: con láser el equivalente ya existe (grabado en escala de grises).
- Los avisos son de una línea: si el conteo supera 400 000 líneas se rechaza y se sugiere subir los mm/celda.

**Decisiones tomadas:** ADR-041, ADR-042.

**Trazabilidad (commits de S-15):**

| Hash | Commit |
| :--- | :--- |
| `75a3786` | `feat(cam): relieve 2.5D por niveles de profundidad` |

Recuperación de la sesión: `git log --oneline --grep="S-15"`.

**Abierto al cierre:** el relieve es escalonado (no hay desbaste continuo ni acabado), y las pestañas no aplican al relieve. **Fase 4 cerrada**: grabado, contornos con pestañas y relieve.

---

### S-16 — 2026-11-24 · Módulo de trazado para plóter (M4.3)

**Alcance:** pestaña dedicada a **dibujar con rotulador**, con dos procesados de imagen: rutas vectoriales optimizadas y bordado raster para dibujos complejos.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `ContourTracer` compartido (trazado + Douglas–Peucker) usado por CAM y trazado | `lib/domain/services/contour_tracer.dart` | ✅ |
| 2 | `PlotGenerator`: modo **vectorial** con contornos cerrados y orden por proximidad | `lib/domain/services/plot_generator.dart` | ✅ |
| 3 | `PlotGenerator`: modo **bordado raster** con separación, ángulo y puntadas | `plot_generator.dart` | ✅ |
| 4 | Control de rotulador configurable: `M3 S…`/`M5` o `G1 Z…`/`G0 Z…` | `plot_generator.dart` | ✅ |
| 5 | Vista previa del dibujo (vectorial o tramado) | `plot_generator.dart` | ✅ |
| 6 | `PlotController` y pantalla **Trazado · Plóter** con selector de modo | `lib/features/plot/` | ✅ |
| 7 | Nueva pestaña **Trazado** en la navegación | `lib/app/home_shell.dart` | ✅ |
| 8 | 12 pruebas nuevas (248 en verde, 1 saltada) | `test/domain/plot_generator_test.dart`, `test/features/plot_controller_test.dart`, `test/widget_test.dart` | ✅ |

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed` → 0 cambios · `flutter analyze` → *No issues found* · `flutter test` → **248 en verde, 1 saltada** · `flutter build windows --debug` → OK.

**Decisiones de diseño**

- El trazado de siluetas se **comparte** con el CAM de contornos: un solo algoritmo y un solo juego de pruebas.
- **Vectorial**: contornos cerrados simplificados y ordenados por vecino más cercano (eligiendo el extremo más próximo) para minimizar los viajes con el rotulador levantado.
- **Bordado raster**: líneas paralelas con ángulo configurable y zigzag entre líneas; `stitchMm` divide cada pasada en puntadas para el efecto de bordado.
- El rotulador se controla por **husillo** (`M3 S…`/`M5`, típico de un servo en el eje del spindle) o por **Z** (`G1 Z…`/`G0 Z…`), sin asumir hardware.
- Igual que el CAM, el resultado **nunca se envía**: se carga en el visor para revisarlo y ejecutarlo con las barreras de seguridad.

**Decisiones tomadas:** ADR-043, ADR-044.

**Trazabilidad (commits de S-16):**

| Hash | Commit |
| :--- | :--- |
| `c4390cd` | `refactor(cam): extrae el trazado de contornos a un servicio compartido` |
| `ed76e6b` | `feat(plot): pestana de trazado con rutas vectoriales y bordado raster` |

Recuperación de la sesión: `git log --oneline --grep="S-16"`.

**Abierto al cierre:** sin relleno en espiral (solo tramado recto) y sin simulación de ancho de trazo.

---

### S-17 — 2026-11-24 · Suavizado de diagonales en el trazado (M4.4)

**Alcance:** corregir el zigzag de las líneas diagonales y curvas del trazado vectorial (por ejemplo, el contorno de un corazón), detectado en las pruebas del usuario.

**Causa:** la silueta es una escalera de píxeles; con una tolerancia pequeña, Douglas–Peucker conserva cada escalón y el rotulador dibuja decenas de micro-movimientos en diente de sierra.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `PlotSettings.smoothMm` (0..5 mm; 0.4 por defecto) con validación | `lib/domain/services/plot_generator.dart` | ✅ |
| 2 | Suavizado por promedio de vecinos **conservando esquinas** + re-simplificación | `plot_generator.dart` | ✅ |
| 3 | Campo «Suavizar (mm)» en la pestaña de trazado | `lib/features/plot/plot_page.dart` | ✅ |
| 4 | Prueba de regresión: en un rombo, la suma de giros baja > 30 % | `test/domain/plot_generator_test.dart` | ✅ |

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed` → 0 cambios · `flutter analyze` → *No issues found* · `flutter test` → **249 en verde, 1 saltada** · `flutter build windows --debug` → OK.

**Decisiones de diseño**

- Un vértice se considera **esquina** si se separa del punto medio de sus vecinos más de `1,5 × ventana` píxeles: los escalones de una diagonal se suavizan, la punta de un corazón se conserva.
- Después de suavizar se vuelve a simplificar (media tolerancia) para no inflar el número de líneas del G-code.
- 0 mm desactiva el suavizado: útil para trazados geométricos con ángulos duros.

**Decisiones tomadas:** ADR-045.

**Trazabilidad (commits de S-17):**

| Hash | Commit |
| :--- | :--- |
| `bc44fe3` | `feat(plot): suaviza diagonales conservando las esquinas` |
| `61a8a21` | `docs: documenta el suavizado del trazado` |

Recuperación de la sesión: `git log --oneline --grep="S-17"`.

---

### S-18 — 2026-11-25 · Primer APK de Android (Fase 5)

**Alcance:** sacar el primer APK instalable, adaptando el proyecto a la cadena de
Android que exige Flutter 3.50 y dejando documentado cómo firmarlo.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | Andamiaje de Android regenerado con la plantilla 3.50: Gradle 9.5.0, AGP 9.3.1, Kotlin 2.4.20, Java 17 | `android/**` | ✅ |
| 2 | Wrapper de Gradle versionado (`gradlew`, `gradlew.bat`, `gradle-wrapper.jar`) para que un clon limpio compile | `.gitignore` | ✅ |
| 3 | `flutter_libserialport` vendorizado con `android/build.gradle.kts` para Gradle 9 (`jcenter()` fuera, `compileSdk 36`, CMake intacto) | `third_party/flutter_libserialport/**`, `pubspec.yaml` | ✅ |
| 4 | Etiqueta **GRBL CNC** y `uses-feature usb.host` no requerida | `AndroidManifest.xml` | ✅ |
| 5 | Firma de release opcional por `android/key.properties`, con caída a la clave de depuración | `android/app/build.gradle.kts` | ✅ |
| 6 | Conexión serie bloqueada con aviso fuera de escritorio (`serialSupportProvider`) | `lib/core/platform_capabilities.dart`, `connection_controller.dart`, `connection_bar.dart` | ✅ |
| 7 | Guía de empaquetado (requisitos, firma, ABIs, limitaciones) | `docs/empaquetado.md`, `README.md` | ✅ |

**Artefactos:** `app-armeabi-v7a-release.apk` (19,3 MB), `app-arm64-v8a-release.apk`
(21,1 MB), `app-x86_64-release.apk` (22,3 MB) y universal (61,9 MB). Contienen
`libapp.so`, `libflutter.so`, `libsqlite3.so`, `libdartjni.so` y `libserialport.so`
por ABI; `minSdk 24`, `targetSdk 36`.

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed` → 0 cambios ·
`flutter analyze` → *No issues found* · `flutter test` → **251 en verde, 1 saltada** ·
`flutter build apk --release --split-per-abi` → OK · `flutter build windows --debug`
→ OK · `aapt2 dump badging` → paquete, etiqueta y SDK correctos. La instalación en
un móvil real quedó **pendiente**: HyperOS exige activar «Instalar por USB»
(`INSTALL_FAILED_USER_RESTRICTED`).

**Decisiones de diseño**

- La cadena de Android se **regenera** desde la plantilla de la versión de Flutter en
  uso en lugar de parchear la vieja: evita arrastrar incompatibilidades de AGP 8.
- El plugin se **vendoriza** solo en su build de Android; cualquier otra vía (bajar
  Gradle y saltarse la validación con `--android-skip-build-dependency-validation`)
  deja el proyecto en una configuración que Flutter ya no soporta.
- En Android se **oculta** la conexión serie en vez de mostrar el error nativo: sin
  flujo de permiso USB el `open()` falla con un mensaje que no ayuda al operario.
- La firma real es **opcional por fichero**: el build funciona en local y en CI sin
  secretos, y en cuanto existe `key.properties` se usa el keystore de publicación.

**Decisiones tomadas:** ADR-046, ADR-047.

**Abierto al cierre:** habilitar serie en Android (permiso `UsbManager` + apertura por
descriptor), icono de la app (sigue el de la plantilla), builds Linux/macOS e isolate
de parseo (R-17).

**Trazabilidad (commits de S-18):**

| Hash | Commit |
| :--- | :--- |
| `0212231` | `build(android): migra a gradle 9 y agp 9 con el plugin de serie parcheado` |
| `4797280` | `feat(conexion): bloquea la serie fuera de escritorio con un aviso` |
| `1cf05b1` | `docs: guia de empaquetado y bitacora de la sesion` |

Recuperación de la sesión: `git log --oneline --grep="S-18"`.

---

### S-19 — 2026-11-25 · Serie por USB-OTG en Android

**Alcance:** conectar el GRBL desde el APK sin tocar dominio, servicio ni worker:
un transporte nuevo detrás de `SerialPortRepository`, la fachada que ya existía
para esto.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `AndroidUsbSerialRepository`: permiso `UsbManager`, 8-N-1, DTR/RTS, cola de escrituras ordenada y aviso de desconexión | `lib/data/serial/android_usb_serial_repository.dart` | ✅ |
| 2 | `SerialLineBuffer` compartido por los dos transportes | `lib/data/serial/serial_line_buffer.dart`, `lib_serial_port_repository.dart` | ✅ |
| 3 | Android: servicio en proceso (el `MethodChannel` no existe en un isolate de fondo); escritorio: worker FFI en isolate | `lib/app/providers.dart` | ✅ |
| 4 | `serialSupported` incluye Android; el aviso queda solo para iOS/web | `lib/core/platform_capabilities.dart`, `connection_controller.dart`, `connection_bar.dart` | ✅ |
| 5 | Descripción del dispositivo bajo el selector (producto, fabricante, `VID:PID`) | `connection_bar.dart` | ✅ |
| 6 | Dependencia `usb_serial 0.6.0` (drivers vendorizados, sin JitPack) | `pubspec.yaml`, `pubspec.lock` | ✅ |
| 7 | Guía de empaquetado y README actualizados | `docs/empaquetado.md`, `README.md` | ✅ |
| 8 | 6 pruebas nuevas: ensamblado de líneas y contrato del canal Android (lista, dispositivo ausente, permiso denegado) | `test/serial/` | ✅ |

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed .` → 0 cambios ·
`flutter analyze` → *No issues found* · `flutter test` → **257 en verde, 1
saltada** · `flutter build apk --debug` → OK · `flutter build apk --release
--split-per-abi` → OK (19,3 / 21,0 / 22,4 MB, sin cambios de tamaño) ·
`flutter build windows --debug` → OK. Los únicos avisos son las deprecaciones de
`UsbRequest` en los drivers Java vendorizados. La prueba con placa real queda
pendiente.

**Decisiones de diseño**

- Se **reutiliza la fachada** `SerialPortRepository`: dominio, `GrblSerialService`,
  worker, controladores y UI no cambian.
- Android usa `usb_serial` y no `libserialport` porque el chip USB no aparece como
  `tty` y hace falta el permiso del `UsbManager`; el plugin trae los drivers de
  `usb-serial-for-android` empaquetados y no exige JitPack.
- En Android el worker corre en el **isolate principal**: el `MethodChannel` no
  funciona en un isolate de fondo y las operaciones del plugin ya son asíncronas
  (no hay lecturas FFI bloqueantes que justifiquen el isolate).
- Las escrituras se **encadenan** en Dart para conservar el orden (`writeLine` es
  síncrono para el servicio) y respetar el *character counting* de GRBL.
- Los errores del plugin se traducen a mensajes accionables (permiso denegado,
  dispositivo ausente, no es un adaptador serie).

**Decisiones tomadas:** ADR-048 (sustituye ADR-047).

**Abierto al cierre:** probar con placa real (OTG, corriente, primer permiso y
desconexión); el timeout de 30 s del cliente puede saltar si el diálogo de permiso
queda abierto mucho tiempo (basta reintentar); el APK sigue empaquetando
`libserialport.so` sin usarlo; `usb_serial` busca mantenedor (R-22).

**Trazabilidad (commits de S-19):** `26948c1` —
`feat(conexion): habilita la serie por USB-OTG en Android [S-19]`.

---

### S-20 — 2026-11-25 · Rotulador de Z: altura segura y estado del formulario

**Síntoma reportado:** en el modo de plóter, el G-code generado no elevaba la
punta a una altura segura y el cabezal seguía dibujando entre trayectos.

**Diagnóstico:** el generador **sí** emitía el retroceso. Se comprobó generando
un programa con rotulador por Z y observando el puerto emulado de punta a punta
(`generate` → visor → `ExecutionController.start`): cada trayecto salía con
`G0 Z2.000` antes del `G0 X… Y…`. La causa estaba antes: `_ModuleRouter`
devolvía un widget nuevo en cada cambio de pestaña, así que el `State` de
`PlotPage` se destruía y el formulario volvía a sus valores por defecto
—rotulador **«Husillo»**—. Al regenerar después de revisar el trabajo en el
visor, el programa salía con `M3 S…`/`M5` y **sin ningún movimiento de Z**.
Además, la Z de viaje por defecto (2 mm) era independiente de la altura segura
del perfil.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | Módulos montados una vez y conservados con `IndexedStack` (lazy): el formulario ya no se reinicia al navegar | `lib/app/home_shell.dart` | ✅ |
| 2 | «Altura segura Z» se propone desde `MachineProfile.safeZmm` mientras el campo no se toque; «Valores del perfil» también la aplica | `lib/features/plot/plot_page.dart` | ✅ |
| 3 | Aviso no bloqueante si `zUpMm` queda por debajo de la altura segura del perfil (la punta arrastraría) | `lib/features/plot/plot_controller.dart` | ✅ |
| 4 | Bajada `G1 Z…` con `F` explícito (avance de dibujo), sin heredar el rápido del viaje | `lib/domain/services/plot_generator.dart` | ✅ |
| 5 | `M5` final solo con rotulador por husillo | `plot_generator.dart` | ✅ |
| 6 | Ayuda contextual en la pestaña: «Husillo» no emite movimiento de Z | `plot_page.dart` | ✅ |
| 7 | 4 pruebas nuevas: orden `G0 Z` → `G0 X… Y…`, aviso de altura segura y parámetros conservados al cambiar de pestaña | `test/domain/plot_generator_test.dart`, `test/features/plot_controller_test.dart`, `test/widget_test.dart` | ✅ |

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed .` → 0 cambios ·
`flutter analyze` → *No issues found* · `flutter test` → **260 en verde, 1
saltada**. La prueba del formulario se validó revirtiendo el arreglo: con el
enrutador antiguo falla (`Altura segura Z` no aparece) y con `IndexedStack` pasa.

**Decisiones tomadas:** ADR-049, ADR-050.

**Abierto al cierre:** confirmar en la placa los pasos §13.6b y §13.6c de
`docs/prueba_banco.md`; el `State` de los módulos vive ahora toda la sesión (las
páginas pesadas no se liberan al cambiar de pestaña).

**Trazabilidad (commits de S-20):**

| Hash | Commit |
| :--- | :--- |
| `3f0a66a` | `fix(ploter): eleva la punta a la altura segura y conserva el formulario al navegar` |
| `b865b15` | `docs: bitacora de S-20 y checklist de banco del rotulador` |

---

### S-21 — 2026-11-25 · Simulador de reproducción en el visor

**Alcance:** revisar la secuencia completa de un programa **antes** de ejecutarlo,
con reproducción, línea de tiempo y velocidad, sin tocar la máquina.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `SimulationTimeline`: reparto del tiempo por `longitud / avance` (los `G0` a un rápido supuesto), búsqueda binaria del bloque y cursor interpolado | `lib/domain/services/simulation_timeline.dart` | ✅ |
| 2 | `SimulationController`: reproducir, pausar, saltar a bloque, retroceder, línea de tiempo y velocidad (0,25×–8×); se reinicia al cargar otro programa y conserva la velocidad | `lib/features/viewer/simulation_controller.dart` | ✅ |
| 3 | Barra slim ⏮️ ⏯️ ⏭️ + slider arrastrable + velocidad + tiempo/línea, superpuesta **abajo** del lienzo, con ticker propio y paso máximo de 250 ms por fotograma | `lib/features/viewer/widgets/simulation_bar.dart`, `viewer_page.dart` | ✅ |
| 4 | Estela del simulador en **capa de pintura aparte** (`RepaintBoundary` + `CustomPaint`), con el búfer proyectado cacheado: el prefijo reproducido se dibuja con una vista `Float32List`, así el repintado es O(1) | `lib/features/viewer/simulation_painter.dart`, `widgets/viewer_canvas.dart` | ✅ |
| 5 | El lienzo pasa a `ConsumerStatefulWidget`: solo él se reconstruye por fotograma; la ruta completa no se recalcula | `widgets/viewer_canvas.dart` | ✅ |
| 6 | Módulos ocultos con `TickerMode(false)`: el simulador no avanza al cambiar de pestaña | `lib/app/home_shell.dart` | ✅ |
| 7 | Con un trabajo real activo el simulador se pausa y sus controles quedan deshabilitados | `widgets/simulation_bar.dart` | ✅ |
| 8 | 16 pruebas nuevas: reparto de tiempo y cursor, control de reproducción completo y barra (juego, pausa, bloques, velocidad, móvil sin desbordar) | `test/domain/simulation_timeline_test.dart`, `test/features/simulation_controller_test.dart`, `test/features/simulation_bar_test.dart` | ✅ |

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed .` → 0 cambios ·
`flutter analyze` → *No issues found* · `flutter test` → **276 en verde, 1
saltada** · `flutter build windows --debug` → OK.

**Decisiones tomadas:** ADR-051, ADR-052.

**Abierto al cierre:** el rápido de los `G0` se supone 5000 mm/min (en GRBL depende
de `$110`–`$112`), así que los tiempos de los desplazamientos en vacío son
aproximados; si molestan, se pueden tomar de la EEPROM del perfil conectado.

**Trazabilidad (commits de S-21):**

| Hash | Commit |
| :--- | :--- |
| `7ba8d84` | `feat(visor): simulador de reproduccion con linea de tiempo y velocidad` |
| `9042485` | `docs: bitacora de S-21 y checklist del simulador` |

---

### S-22 — 2026-11-25 · Estela alineada con la trayectoria y capas conmutables

**Síntoma reportado:** en el visor la simulación aparecía **desplazada** (arriba
y a la izquierda) respecto al recorrido y a la cama; se sospechaba de la
perspectiva del viewport.

**Causa:** la estela se dibujaba en **su propia capa** (`CustomPaint` +
`RepaintBoundary` dentro de un `Stack`) con su propio búfer proyectado. Dos
capas independientes solo coinciden si tamaño, proyección y origen son idénticos
en el mismo fotograma; cualquier divergencia (tamaño del lienzo, caché del
búfer, repintado independiente) se ve como un desplazamiento o un cambio de
escala, que es exactamente lo que mostraba la captura.

**Entregado**

| # | Cambio | Archivo(s) | Estado |
| :--- | :--- | :--- | :--- |
| 1 | Estela y trayectoria en **un único `CustomPaint`** (`painter` + `foregroundPainter`): mismo tamaño, misma proyección y mismo origen, sin posibilidad de desfase | `lib/features/viewer/widgets/viewer_canvas.dart` | ✅ |
| 2 | Se conserva el rendimiento: prefijo O(1) sobre el búfer cacheado y `willChange` mientras hay estela; una sola capa que repintar | `widgets/viewer_canvas.dart`, `simulation_painter.dart` | ✅ |
| 3 | `previewVisibilityProvider` con `showExecution` y `showSimulation` | `lib/features/viewer/preview_visibility.dart` | ✅ |
| 4 | Conmutador de ojo en la barra de ejecución (avance ejecutado + cabezal real) y en la del simulador (estela) | `widgets/execution_bar.dart`, `widgets/simulation_bar.dart` | ✅ |
| 5 | 3 pruebas nuevas: lienzo compartido y cabezal en la posición que dicta la proyección, conmutadores y ocultar la simulación desde la barra | `test/features/viewer_canvas_test.dart`, `test/features/simulation_bar_test.dart` | ✅ |

**Verificaciones ejecutadas:** `dart format --set-exit-if-changed .` → 0 cambios ·
`flutter analyze` → *No issues found* · `flutter test` → **279 en verde, 1
saltada** · `flutter build windows --debug` → OK.

**Decisiones tomadas:** ADR-052 (revisada en esta sesión), ADR-053.

**Abierto al cierre:** la cama se dibuja en coordenadas absolutas (`0…$130`,
`0…$131`) mientras la vista se centra en el programa; si un trabajo está lejos
del origen, la cama puede quedar fuera del encuadre. Valorar un «encuadrar
programa + volumen» como botón aparte.

**Trazabilidad (commits de S-22):**

| Hash | Commit |
| :--- | :--- |
| `409243e` | `fix(visor): pinta la estela del simulador sobre la trayectoria y anade conmutadores de capa` |
| `0e0772a` | `docs: bitacora de S-22 y checklist de capas del visor` |

---

## 5. Decisiones de arquitectura (ADR resumidas)

| ID | Decisión | Motivo | Consecuencia |
| :--- | :--- | :--- | :--- |
| ADR-001 | Gestión de estado con **Riverpod 3.x** (no BLOC) | Un solo paradigma, `select()` granular para telemetría de 5–10 Hz, testabilidad | `Notifier`/`AsyncNotifier` + `riverpod_generator`; `StateNotifier` prohibido |
| ADR-002 | Streaming por **conteo de caracteres** con presupuesto calculado de 128 B | Es el único método que mantiene el planner abastecido sin desbordar | Los bytes en tiempo real **no** se descuentan; los `error:` sí liberan espacio |
| ADR-003 | Prohibido `G92` para compensar holgura; se compensa con movimiento real | `G92` no persiste, pisa el marco del usuario y dispara `ALARM:2` | El post-procesador emite `G1` cortos en inversiones de sentido |
| ADR-004 | Repositorio único multiplataforma (monorepo) | Windows es el objetivo primario; Android reutiliza dominio y UI | Sin paquetes internos por ahora; se separará si la app supera ~15 k LOC |
| ADR-005 | Trunk-based: `main` siempre verde, ramas cortas `feat/`, `fix/`, `docs/` | Proyecto de un solo desarrollador con asistencia de agentes | Todo cambio entra por commit convencional con etiqueta de sesión |
| ADR-006 | Actualizar Flutter **antes** de fijar dependencias | Riverpod 3.5.0 y Drift 2.35.4 son posteriores a Dart 3.7.2 | Riesgo: incompatibilidades del toolchain si se pospone |
| ADR-007 | Adoptar `package:material_ui` como único import de UI | Flutter 3.47+ deprecó `package:flutter/material.dart` | Prohibido importar `flutter/material.dart`; `GlobalMaterialLocalizations` viene de `material_ui` |
| ADR-008 | No usar `sqlite3_flutter_libs` | Está obsoleto (`0.6.0+eol`, "no longer does anything"); `sqlite3` 3.x lo reemplaza y `drift_flutter` ya lo resuelve | La persistencia se configura solo con `drift` + `drift_flutter` |
| ADR-009 | Las secuencias de seguridad viven en `GrblSerialService` hasta que exista `SafetyController` | Evita duplicar lógica y garantiza que ningún widget toque bytes; los criterios SEG están cubiertos por tests | Clase en crecimiento: extraer fachada al construir la UI de Fase 1 |
| ADR-010 | Pruebas contra `FakeSerialPort`, un emulador GRBL que detecta desbordes | Sin emulador, el flujo de 128 B no se puede probar de forma repetible | Todo cambio de protocolo debe añadir su caso al fake |
| ADR-011 | Worker en isolate propio con protocolo de mapas y `SendPort` | Aísla la FFI y el bucle de lectura del hilo de UI | Toda la API pasa por `GrblWorkerClient`; nada de bytes desde widgets |
| ADR-012 | El comando `stop` exige confirmación de persistencia desde el cliente | SEG-03 no se puede garantizar si el worker resetea por su cuenta | El worker emite `persistRequest` y espera `persistDone` (20 s); sin ack no hay `0x18` |
| ADR-013 | El tamaño de búfer se detecta con `$I` y se aplica antes de leer la EEPROM | P1-4: no asumir 128 B; `[OPT:...,bloques,bytes]` es la fuente oficial | Si `$I` no responde se conserva 128 B y se avisa por el canal de mensajes |
| ADR-014 | Las pruebas que requieren la biblioteca nativa se saltan fuera de un build de la app | CMake despliega `serialport.dll` solo en el bundle | La verificación FFI se hace con `flutter run -d windows` + hardware (R-10) |
| ADR-015 | El código generado por drift (`app_database.g.dart`) se versiona | CI y clones nuevos compilan sin ejecutar `build_runner` | Si se cambia el esquema hay que regenerar y commitear en el mismo cambio |
| ADR-016 | Providers escritos a mano (`Provider`/`NotifierProvider`), sin `@riverpod` todavía | La superficie de estado es pequeña y se lee mejor explícita; `riverpod_generator` queda disponible para features grandes | Si el número de providers crece, migrar a codegen en un cambio dedicado |
| ADR-017 | El enum de ejes se llama `MachineAxis`, no `Axis` | `Axis` colisiona con el `Axis` de Flutter en cualquier archivo que importe la UI | Los widgets usan `MachineAxis` sin `hide`; los parámetros se siguen llamando `axis` |
| ADR-018 | `connectAndIdentify` espera la primera telemetría (≤ 2 s) antes de devolver | Sin estado real, el jog y las consultas se rechazaban justo tras conectar | Si no llega telemetría se conecta igual, pero la UI lo verá en `unknown` |
| ADR-019 | El perfil activo se guarda en `activeProfileIdProvider`, no dentro de la conexión | Evita el ciclo conexión → calibración → conexión | Ambos controladores leen el mismo id; la conexión resuelve el perfil por id |
| ADR-020 | El origen de trabajo se fija con `G10 L20 P1`, nunca con `G92` | `G92` no persiste y puede disparar `ALARM:2` con soft limits (P0-2) | La UI no expone `G92` en ningún flujo |
| ADR-021 | La holgura se compensa con un movimiento extra en la dirección nueva; Z y arcos excluidos | Físicamente consume el juego mecánico sin falsear coordenadas | El post-procesador se aplicará al G-code antes de enviarlo (Fase 3) |
| ADR-022 | El visor simula coordenadas de trabajo y **avisa** de `G28`/`G30`/`G53`/`G92` | Simular esos códigos requeriría modelar offsets y homing, y una simulación incorrecta es peor que ninguna | El intérprete acumula avisos que la UI muestra como "N avisos" |
| ADR-023 | Render en tres lotes con `drawRawPoints(PointMode.lines)` y proyección propia | Evita un motor 3D y mantiene un `Paint` por categoría; escalable a cientos de miles de segmentos | La proyección se recalcula por frame (aceptable); si molesta, cachear por vista |
| ADR-024 | El progreso cuenta `ok` confirmados y se mapea a la línea de origen con `lineIndexes` | «Enviado» no es «ejecutado», y las compensaciones inyectadas desplazan los índices | Cada línea de salida declara su línea de origen; el pintor nunca retrocede |
| ADR-025 | Pausa conserva el búfer y se reanuda con `0x9E` + `~`; detener resetea | Reenviar líneas tras una pausa duplicaría bloques que GRBL aún tiene en el planner | `resumeJob` no envía G-code; el reinicio tras `stop` es un flujo aparte |
| ADR-026 | `$G`/`$#` se leen escribiendo directo al puerto y solo un `ok` con respuesta cierra la consulta | En `Hold` las líneas en vuelo no se confirman y los `ok` sueltos cerraban la consulta vacía | Se puede persistir el estado modal sin desbloquear el búfer |
| ADR-027 | El punto de reanudación incluye `$#` (Drift v2 con `addColumn`) | SEG-05 exige comparar offsets: cambiar `G54`/`G92` movería la pieza | Migración aditiva; si no se pudo leer, se guarda `null` y se avisa |
| ADR-028 | `port.config` es propiedad del `SerialPort`; el lector se drena antes de liberar el puerto | Liberar el config otra vez es doble `free` (aborta en debug) y liberar el puerto con el lector en `sp_wait` es `use-after-free` | `close()` espera 150 ms tras cerrar el lector (timeout 50 ms) |
| ADR-029 | La consola acepta comandos `$` siempre; el resto solo en `Idle` | Es la única vía que evita las salvaguardas de la UI sin exponer la máquina a movimiento accidental | El servicio lanza `GrblSafetyException`; la UI lo muestra y no envía nada |
| ADR-030 | Barra superior persistente con estado, perfil, consola, `$X` y soft reset | El operario necesita estado y salida de emergencia desde cualquier módulo | Vive fuera del enrutador; el soft reset se rechaza si hay trabajo activo |
| ADR-031 | La posición de trabajo se retiene entre reportes y se resuelve con el último `WCO` | GRBL omite `WCO` casi siempre: borrar la posición dejaba el cabezal y el origen sin datos | `positionIsLive` marca cuándo el dato viene del reporte actual |
| ADR-032 | El lienzo expone `resetView()` y se reencuadra al cambiar de programa | Un paneo viejo deja el trazado fuera del viewport sin forma de volver | Clave en un `Provider`; `RepaintBoundary` para que el paneo no repinte los lotes |
| ADR-033 | Reiniciar un trabajo guardado reenvía desde la línea confirmada, con `$G`/`$#` y distancia ≤ 1 mm como precondiciones | Tras `stop` el planificador está vacío: `~` no continúa nada y el bloque guardado puede no haberse ejecutado | La app no mueve sola: ofrece «Llevar al punto guardado» para que el operario confirme |
| ADR-034 | Perder el enlace con trabajo activo marca `interrupted` y conserva el punto de reanudación | El estado de la máquina es incierto pero el progreso guardado sigue siendo válido | Se cancelan suscripciones y el proyecto pasa a `interrupted` en SQLite |
| ADR-035 | El CAM de imágenes se limita a láser (`M4`) y ejecuta la conversión en un isolate con tope de 250 000 celdas | Con husillo el `S` es velocidad, no potencia; y una rejilla enorme generaría millones de líneas | Modos umbral, tramado y escala de grises; rechazo explícito si el perfil no es láser |
| ADR-036 | El CAM nunca envía a la máquina: carga el G-code en el visor | Una previsualización obligatoria evita ejecutar un grabado mal escalado o invertido | Se reutilizan visor, compensación de holgura y barreras de ejecución |
| ADR-037 | La vista previa del CAM es el mapa de potencia (1 celda = 1 píxel), no la imagen original | La trayectoria no permite juzgar el resultado; el mapa de celdas sí | PNG generado en el isolate junto al G-code; fondo claro y sin interpolación |
| ADR-038 | Barra de ejecución compacta superpuesta al lienzo | La tarjeta completa robaba altura al viewport, que es lo que se mira | Iconos + progreso fino + una línea de aviso; «Centrar trazado» se integra en ella |
| ADR-039 | Contornos por aristas de píxel + Douglas–Peucker (sin potrace ni dependencias) | Se necesitaba detectar islas y huecos con resultados deterministas y testeables | Bucles cerrados con simplificación en mm; tope de celdas y puntos |
| ADR-040 | Una sola operación CAM activa (Grabado o Contorno) | Mostrar una vista previa de grabado junto a parámetros de corte confunde y es peligroso | Cambiar de operación descarta el resultado anterior |
| ADR-041 | Relieve 2.5D por bandas acumulativas con pasadas por nivel | Un desbaste continuo exige algoritmos de offset que no aportan en esta fase | Escalera de profundidad predecible y testeable; celda de nivel L se corta en 1..L |
| ADR-042 | El relieve exige perfil de fresadora | Usa `M3` y `Z`; con láser el equivalente es el grabado en escala de grises | Error explicativo si el perfil no es de fresadora |
| ADR-043 | El trazado de contornos y la simplificación viven en `ContourTracer` | CAM y plóter necesitaban lo mismo y duplicarlo garantiza divergencias | Un solo algoritmo con una sola batería de pruebas |
| ADR-044 | Plóter con rotulador configurable (`M3 S…`/`M5` o `G1 Z…`/`G0 Z…`) y dos modos de dibujo | No todos los plóters usan servo ni todos los trabajos son line-art | Vectorial con orden por proximidad y bordado raster con ángulo/puntadas |
| ADR-045 | Suavizado por promedio de vecinos con conservación de esquinas, antes de simplificar | Las diagonales salían como escalera de píxeles con decenas de micro-movimientos | `smoothMm` (0 = sin suavizar); esquinas con desviación > 1,5 × ventana se mantienen |
| ADR-046 | Vendorizar `flutter_libserialport` (0.6.0) con un `android/build.gradle.kts` propio | Flutter 3.50 exige Gradle 9.5/AGP 9.3.1 y el build publicado usa `jcenter()` + AGP 8.7, que Gradle 9 ya no evalúa | Solo cambia el build de Android; el código Dart y las compilaciones CMake de escritorio son los publicados. Revisar al actualizar el plugin |
| ADR-047 | En Android la conexión serie se declara no soportada y se bloquea con aviso | Abrir el USB exige permiso del `UsbManager` y apertura por descriptor, flujo que el plugin no implementa; el error nativo no es accionable | Sustituida por ADR-048 en S-19: la fachada `SerialPortRepository` permitió añadir el transporte sin tocar el resto |
| ADR-048 | En Android la serie va por `usb_serial` (drivers de `usb-serial-for-android` vendorizados) y el worker corre en el isolate principal | Los chips USB no aparecen como `tty`; hace falta `UsbManager.requestPermission` y *bulk transfers*. Un `MethodChannel` no funciona en un isolate de fondo y el plugin ya es asíncrono, así que el isolate FFI no aporta | `AndroidUsbSerialRepository` detrás de `SerialPortRepository`; escritorio sigue con `libserialport` en isolate. Si el plugin deja de mantenerse, solo se cambia esa clase |
| ADR-049 | Los módulos de navegación se montan una vez y se **conservan** (`IndexedStack` perezoso) en lugar de recrearse | Devolver un widget nuevo por pestaña destruía el `State` de la página: los formularios de CAM y trazado volvían a los valores por defecto sin avisar —el plóter pasaba de «Eje Z» a «Husillo» y el G-code salía sin `G0 Z`, con la punta arrastrando— | Cada módulo se monta al visitarse y permanece en memoria hasta cerrar la app; no hay forma de reiniciar un formulario salvo recargar |
| ADR-050 | El retroceso del rotulador por Z usa la **altura segura del perfil** y avisa si el operario la baja | 2 mm fijos no garantizan que la punta libre el papel, y «altura segura» ya es un dato del perfil que usan las secuencias de reanudación | `G0 Z<safeZ>` antes de cada viaje en XY; aviso no bloqueante al generar; la bajada `G1 Z…` lleva el avance de dibujo |
| ADR-051 | El simulador del visor tiene **reloj propio derivado de los avances** del G-code, no de la telemetría | Revisar un programa requiere poder pausar, retroceder y acelerar; la máquina solo informa de su estado real y no permite ver el futuro | `SimulationTimeline` (dominio puro, testeable) + `SimulationController`; los `G0` usan un rápido supuesto (5000 mm/min) porque no llevan `F` |
| ADR-052 | La estela del simulador se pinta en la **misma capa** que la trayectoria, como prefijo del búfer proyectado | En una capa aparte cualquier divergencia de tamaño o proyección desplazaba la simulación respecto al recorrido (S-22) | Un solo `CustomPaint` (`painter` + `foregroundPainter`) ⇒ mismo origen garantizado; el coste se resuelve con `Float32List.view` sobre el prefijo (O(1)) y el búfer cacheado por programa+proyección |
| ADR-053 | Las previsualizaciones del visor (avance ejecutado y simulación) se pueden **apagar por separado** | Trayectoria, avance real y estela a la vez saturan el lienzo y estorban al comprobar el dibujo | `previewVisibilityProvider`; botón de ojo en cada barra; apagarlas no altera el estado de la ejecución ni de la reproducción |

---

## 6. Convenciones del repositorio

- **Commits:** `tipo(alcance): descripción en imperativo [S-xx]` con tipos `feat`, `fix`, `docs`, `chore`, `test`, `refactor`, `perf`, `build`, `ci`.
- **Formato:** `dart format .` obligatorio; `flutter analyze` sin issues antes de cada commit.
- **Idioma:** código e identificadores en inglés; documentación y UI en español.
- **Ramas:** `feat/<fase>-<tema>`, `fix/<tema>`, `docs/<tema>`; se fusionan a `main` al quedar verdes.
- **Versionado:** SemVer; la app arranca en `0.1.0` durante Fase 1 (el `1.0.0` del template es provisional).
- **Tamaño de cambio:** un commit debe poder revertirse sin arrastrar otra funcionalidad.

---

## 7. Riesgos abiertos

| ID | Riesgo | Impacto | Mitigación | Estado |
| :--- | :--- | :--- | :--- | :--- |
| R-01 | Pausa (`!`) con herramienta activa | Incendio / lesión | Secuencia `!` → `0x9E`, implementada en `SafetyController` (P0-1) | 🔴 Abierto |
| R-02 | `flutter_libserialport` sin mantenimiento (0.6.0, >1 año) | Bloqueo de plataforma | Fachada propia + segunda implementación sobre `libserialport`. En S-18 se vendoriza para Gradle 9 (ADR-046); desde S-19 solo se usa en escritorio (en Android manda `usb_serial`, ADR-048) | 🟡 Mitigado en diseño |
| R-03 | SDK Flutter desactualizado | Dependencias antiguas o incompatibles | Resuelto en S-02: Flutter 3.50.1 / Dart 3.14.0 | ✅ Cerrado |
| R-04 | Sin emulador GRBL no se puede probar streaming ni alarmas | Errores detectados sólo en hardware | Puerto falso + emulador antes de la Fase 2 | 🟡 Mitigado en diseño |
| R-05 | Renderizado lento con G-code extenso | UI inutilizable en trabajos reales | Batching con `drawRawPoints` + criterio de 60 fps con 200 k segmentos | 🟡 Mitigado en diseño |
| R-06 | Sobrescritura de EEPROM en cada conexión | Desgaste del ATmega | Escribir sólo si el valor difiere de `$$` (`GrblSettings.diff`) | 🟡 Mitigado en diseño |
| R-07 | `LibSerialPortRepository` sin implementar: la app aún no habla con hardware | Fase 1 detenida hasta implementarlo | Implementado en S-03 (FFI + worker con handshake); queda la prueba en banco (R-10) | 🟢 Cerrado |
| R-08 | CI escrito pero nunca ejecutado en GitHub | Errores de entorno no detectados | Primer push y revisión del run | 🟡 Abierto |
| R-09 | `GrblSerialService` mezcla transporte y política de seguridad | Mantenibilidad | Extraer `SafetyController` antes de la UI de calibración | 🟡 Vigilado |
| R-10 | El camino FFI (DLL + handshake) no se ha ejecutado contra hardware ni en un build de escritorio | Fallos de plataforma no detectados hasta la primera prueba real | Probado en S-09/S-10: conexión, EEPROM, jog, holgura, origen y ejecución (5.1–5.5) OK; el cierre al desconectar se corrigió y falta confirmarlo con 5.6–5.7 y las pruebas de robustez | 🟡 En verificación |
| R-11 | Sin reconexión automática tras una pérdida de USB | Trabajo interrumpido y estado perdido | Detectar error de puerto, marcar `Disconnected` y exigir reconexión con handshake | 🟡 Vigilado |
| R-12 | La persistencia (Drift) aún no existe: `persistProgress` solo puede confirmar de memoria | El ack de SEG-03 no garantiza durabilidad todavía | Cerrado en S-04: `ProjectRepository.persistAndConfirm` escribe en SQLite antes de confirmar | ✅ Cerrado |
| R-13 | La conexión desde la UI se cubre en tests de controlador, no con un widget test que pulse «Conectar» | Un fallo de cableado UI ↔ controlador no se detectaría en CI | Prueba E2E en build con hardware (R-10) y revisión manual al integrar la Fase 2 | 🟡 Vigilado |
| R-14 | El jog es por pasos discretos: no hay modo continuo al mantener pulsado | Posicionamiento fino incómodo en recorridos largos | Implementar el bucle incremental `s = v·dt` de `jogging.md` cuando la UI esté estable | 🟡 Vigilado |
| R-15 | El perfil activo aún no se aplica a la conexión ni al post-procesado | Cambios de perfil no afectan a la ejecución | Cerrado en S-06: perfil compartido, comparado al conectar y aplicable a la EEPROM | ✅ Cerrado |
| R-16 | La compensación de holgura no cubre arcos ni el eje Z, y todavía no se aplica al ejecutar | Desviación residual en contornos con arcos | Cerrado en S-08: `ExecutionController` compensa antes de enviar y cuenta las inyecciones | ✅ Cerrado |
| R-17 | El intérprete es síncrono: un archivo de 100 000 líneas puede congelar la UI | Mala experiencia con trabajos grandes | Mover el parseo a un isolate (Fase 5 o antes si se nota) | 🟡 Vigilado |
| R-18 | Tras **detener** no se ofrece reanudar: hace falta re-homing y reenviar desde el visor | Trabajo interrumpido exige preparación manual | Cerrado en S-11: «Reanudar trabajo guardado» verifica `$G`/`$#` y el punto guardado (≤ 1 mm) antes de reenviar desde la línea | ✅ Cerrado |
| R-19 | Si se pierde el USB durante la ejecución, el estado de ejecución no se limpia solo | UI mostrando «Ejecutando» con la máquina desconectada | Cerrado en S-11: al desconectar se cancela la ejecución, el proyecto pasa a `interrupted` y se conserva el punto de reanudación | ✅ Cerrado |
| R-20 | La consola evita las salvaguardas de la UI (solo restrictiva fuera de `Idle`) | Un comando manual puede mover la máquina sin comprobaciones | Se aceptan `$` siempre y el resto solo en `Idle`; documentado como vía avanzada | 🟡 Vigilado |
| R-21 | `$X` sale de la alarma sin corregir la causa | Repetir el choque contra el tope o la pieza | Confirmación explícita con el aviso; el homing sigue siendo obligatorio antes de trabajar | 🟡 Vigilado |
| R-22 | `usb_serial` busca mantenedor (el propio paquete lo anuncia) y sus drivers Java están vendorizados | Sin actualizaciones de seguridad/compatibilidad con Android nuevo | El transporte está aislado en `AndroidUsbSerialRepository`; si deja de funcionar se sustituye por un `MethodChannel` propio con los mismos drivers sin tocar el resto | 🟡 Vigilado |

---

## 8. Próximos pasos (orden estricto)

1. **Completar la verificación en banco**: 5.6 (reanudar sin repetir tramo), 5.7 (detener), §6 (divergencia de reanudación), reinicio del trabajo guardado (§11), CAM (§12) y robustez §7–§9.
2. **Fase 5 — Optimización y empaquetado** (el APK y el release de Windows ya salen, S-18): parseo de G-code en isolate (R-17), atajos de escritorio, builds Linux/macOS, icono propio y `CHANGELOG.md` + licencia + `NOTICE` con la atribución GPLv3 de GRBL.
3. Push al remoto para ejecutar el CI (R-08): el job de Android necesita `platforms;android-36` y el NDK, y el wrapper de Gradle ya está versionado.
4. Probar el APK en un móvil real con adaptador OTG y la placa GRBL (activando
   «Instalar por USB» en HyperOS): permiso USB, handshake, telemetría, jog y
   desconexión durante la ejecución.







