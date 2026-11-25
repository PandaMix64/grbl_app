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
| **Fase 3: Visor 3D** | Renderizado, interpretación de G-code, pausa/detención y reanudación segura | 🟡 **En curso (~45 %)** | Intérprete, proyección, pintor y visor con telemetría listos; falta ejecución y pausa |
| **Fase 3: Visor 3D** | Renderizado, interpretación de G-code, pausa/detención y reanudación segura | ⬜ Pendiente | `ResumeState` y `MotionSegment` ya existen; falta persistencia y render |
| **Fase 4: Generador CAM** | Imagen → G-code (vectorización, dithering, relieve 2.5D) | ⬜ Pendiente | Modo láser requiere `$32` (P1-1) |
| **Fase 5: Optimización y Empaquetado** | Rendimiento, atajos, builds Windows/Linux/macOS/Android | ⬜ Pendiente | — |

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
| R-02 | `flutter_libserialport` sin mantenimiento (0.6.0, >1 año) | Bloqueo de plataforma | Fachada propia + segunda implementación sobre `libserialport` | 🟡 Mitigado en diseño |
| R-03 | SDK Flutter desactualizado | Dependencias antiguas o incompatibles | Resuelto en S-02: Flutter 3.50.1 / Dart 3.14.0 | ✅ Cerrado |
| R-04 | Sin emulador GRBL no se puede probar streaming ni alarmas | Errores detectados sólo en hardware | Puerto falso + emulador antes de la Fase 2 | 🟡 Mitigado en diseño |
| R-05 | Renderizado lento con G-code extenso | UI inutilizable en trabajos reales | Batching con `drawRawPoints` + criterio de 60 fps con 200 k segmentos | 🟡 Mitigado en diseño |
| R-06 | Sobrescritura de EEPROM en cada conexión | Desgaste del ATmega | Escribir sólo si el valor difiere de `$$` (`GrblSettings.diff`) | 🟡 Mitigado en diseño |
| R-07 | `LibSerialPortRepository` sin implementar: la app aún no habla con hardware | Fase 1 detenida hasta implementarlo | Implementado en S-03 (FFI + worker con handshake); queda la prueba en banco (R-10) | 🟢 Cerrado |
| R-08 | CI escrito pero nunca ejecutado en GitHub | Errores de entorno no detectados | Primer push y revisión del run | 🟡 Abierto |
| R-09 | `GrblSerialService` mezcla transporte y política de seguridad | Mantenibilidad | Extraer `SafetyController` antes de la UI de calibración | 🟡 Vigilado |
| R-10 | El camino FFI (DLL + handshake) no se ha ejecutado contra hardware ni en un build de escritorio | Fallos de plataforma no detectados hasta la primera prueba real | Primera pasada real en S-09: conexión, handshake, EEPROM, jog, holgura y origen OK; el cierre al desconectar se corrigió (ADR-028) y falta re-verificarlo | 🟡 En verificación |
| R-11 | Sin reconexión automática tras una pérdida de USB | Trabajo interrumpido y estado perdido | Detectar error de puerto, marcar `Disconnected` y exigir reconexión con handshake | 🟡 Vigilado |
| R-12 | La persistencia (Drift) aún no existe: `persistProgress` solo puede confirmar de memoria | El ack de SEG-03 no garantiza durabilidad todavía | Cerrado en S-04: `ProjectRepository.persistAndConfirm` escribe en SQLite antes de confirmar | ✅ Cerrado |
| R-13 | La conexión desde la UI se cubre en tests de controlador, no con un widget test que pulse «Conectar» | Un fallo de cableado UI ↔ controlador no se detectaría en CI | Prueba E2E en build con hardware (R-10) y revisión manual al integrar la Fase 2 | 🟡 Vigilado |
| R-14 | El jog es por pasos discretos: no hay modo continuo al mantener pulsado | Posicionamiento fino incómodo en recorridos largos | Implementar el bucle incremental `s = v·dt` de `jogging.md` cuando la UI esté estable | 🟡 Vigilado |
| R-15 | El perfil activo aún no se aplica a la conexión ni al post-procesado | Cambios de perfil no afectan a la ejecución | Cerrado en S-06: perfil compartido, comparado al conectar y aplicable a la EEPROM | ✅ Cerrado |
| R-16 | La compensación de holgura no cubre arcos ni el eje Z, y todavía no se aplica al ejecutar | Desviación residual en contornos con arcos | Cerrado en S-08: `ExecutionController` compensa antes de enviar y cuenta las inyecciones | ✅ Cerrado |
| R-17 | El intérprete es síncrono: un archivo de 100 000 líneas puede congelar la UI | Mala experiencia con trabajos grandes | Mover el parseo a un isolate (Fase 5 o antes si se nota) | 🟡 Vigilado |
| R-18 | Tras **detener** no se ofrece reanudar: hace falta re-homing y reenviar desde el visor | Trabajo interrumpido exige preparación manual | Diseñar el flujo "reiniciar trabajo guardado" con verificación de `$G`/`$#` y origen | 🟡 Abierto |
| R-19 | Si se pierde el USB durante la ejecución, el estado de ejecución no se limpia solo | UI mostrando «Ejecutando» con la máquina desconectada | Al pasar a `Disconnected`, cancelar suscripciones y marcar el trabajo como interrumpido | 🟡 Abierto |
| R-20 | La consola evita las salvaguardas de la UI (solo restrictiva fuera de `Idle`) | Un comando manual puede mover la máquina sin comprobaciones | Se aceptan `$` siempre y el resto solo en `Idle`; documentado como vía avanzada | 🟡 Vigilado |
| R-21 | `$X` sale de la alarma sin corregir la causa | Repetir el choque contra el tope o la pieza | Confirmación explícita con el aviso; el homing sigue siendo obligatorio antes de trabajar | 🟡 Vigilado |

---

## 8. Próximos pasos (orden estricto)

1. **Re-verificar en banco** (`flutter run -d windows`): desconexión limpia (sin cierre), consola con `$$`/`?`, `$X` desde la alarma, soft reset, aviso de perfil al refrescar e «ir a 0,0».
2. **Reiniciar trabajo guardado** (R-18): cargar el proyecto de la base y reenviar desde `ResumeState.lineIndex` con verificación de `$G`/`$#` y origen.
3. **Limpieza ante desconexión** (R-19): cancelar suscripciones y marcar el trabajo como interrumpido.
4. **M3.3 — CAM básico**: importar DXF/SVG, pestañas y mecanizado por pasadas reutilizando `BacklashCompensator`.
5. Push al remoto para ejecutar el CI (R-08).







