# Estado del Proyecto — grbl_app

> **Propósito:** este archivo es el punto de retorno. Cualquier agente o persona que retome el
> trabajo debe leerlo primero: dice en qué fase estamos, qué se hizo, qué falta y por qué se
> tomaron las decisiones que están en vigor.
> **Protocolo:** se actualiza al final de cada sesión (§4 bitácora, §3 tablero, §2 fases).

| Campo | Valor |
| :--- | :--- |
| Proyecto | `grbl_app` — entorno CNC con Flutter + GRBL v1.1h |
| Repositorio | Git local, rama `main` (inicializado 2026-11-24) |
| Sesión actual | **S-02 (cerrada)** |
| Fase actual | **Fase 0 — Fundaciones (cierre) · Fase 1 iniciada** |
| Avance global estimado | ~35 % |
| Bloqueos | Ninguno. El CI está escrito pero aún no se ha ejecutado en GitHub |
| Siguiente hito | **M1.1** — `LibSerialPortRepository` (FFI) + isolate worker real con el `GrblSerialService` dentro |

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
| **Fase 1: Núcleo y Serial** | Clean Architecture, esquema SQLite, navegación M3, isolate serial con *character-counting* | 🟡 **En curso** | Navegación M3, dominio y control de flujo listos; falta la implementación FFI y el isolate |
| **Fase 2: Calibración** | Jogging, pasos/mm, parámetros `$`, perfiles y *backlash* | ⬜ Pendiente | *Backlash* según P0-2 (sin `G92`) |
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
- [ ] `LibSerialPortRepository` (FFI sobre `flutter_libserialport`)
- [ ] Isolate worker que posea el puerto y exponga el servicio por mensajes
- [ ] Extraer `SafetyController` como fachada explícita (hoy las secuencias viven en el servicio)

### M1.1 Persistencia y conexión real
- [ ] Esquema Drift (`machine_profiles`, `projects`, `recent_files`) y migraciones
- [ ] Lectura de `$$`, `$G`, `$#` al conectar y comparación con el perfil
- [ ] Sondeo de estado a 5 Hz con `?` desde el isolate
- [ ] Detección del búfer real al conectar (no asumir 128 B)

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

**Abierto al cierre:** `LibSerialPortRepository` (FFI), isolate worker real, extracción del `SafetyController`, esquema Drift, licencia/CHANGELOG y ejecución del CI en remoto.

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
| R-07 | `LibSerialPortRepository` sin implementar: la app aún no habla con hardware | Fase 1 detenida hasta implementarlo | FFI + isolate; validar con un Arduino en banco antes de la UI | 🔴 Abierto |
| R-08 | CI escrito pero nunca ejecutado en GitHub | Errores de entorno no detectados | Primer push y revisión del run | 🟡 Abierto |
| R-09 | `GrblSerialService` mezcla transporte y política de seguridad | Mantenibilidad | Extraer `SafetyController` antes de la UI de calibración | 🟡 Vigilado |

---

## 8. Próximos pasos (orden estricto)

1. `LibSerialPortRepository` sobre `flutter_libserialport`: listar puertos, abrir a 115200, `writeLine` con `\r`, exponer `lines`. Verificar en Windows que `libserialport.dll` llega al build.
2. Mover el puerto y el `GrblSerialService` a un isolate worker (`ReceivePort`/`SendPort`) y exponer un canal tipado a la UI.
3. Extraer `SafetyController` como fachada única de acciones críticas y conectar los botones de la pantalla de conexión.
4. Esquema Drift (`machine_profiles`, `projects`, `recent_files`) con migraciones y test de apertura/cierre.
5. Lectura de `$$`, `$G` y `$#` al conectar; comparar con el perfil activo y avisar de discrepancias.
6. Prueba de humo con hardware real: pausa con herramienta apagada, jog cancel y detención con `$X` posterior.
7. `CHANGELOG.md`, licencia del proyecto y `NOTICE` con la atribución GPLv3 de GRBL.
8. Primer push al remoto para que el CI corra de verdad.


