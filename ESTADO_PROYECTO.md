# Estado del Proyecto — grbl_app

> **Propósito:** este archivo es el punto de retorno. Cualquier agente o persona que retome el
> trabajo debe leerlo primero: dice en qué fase estamos, qué se hizo, qué falta y por qué se
> tomaron las decisiones que están en vigor.
> **Protocolo:** se actualiza al final de cada sesión (§5 bitácora, §3 tablero, §2 fases).

| Campo | Valor |
| :--- | :--- |
| Proyecto | `grbl_app` — entorno CNC con Flutter + GRBL v1.1h |
| Repositorio | Git local, rama `main` (inicializado 2026-11-24) |
| Sesión actual | **S-01 (cerrada)** |
| Fase actual | **Fase 0 — Fundaciones (en curso)** |
| Avance global estimado | ~10 % |
| Bloqueos | Ninguno |
| Siguiente hito | **M0.1** — entorno reproducible: Flutter actualizado + dependencias fijadas + CI verde |

---

## 1. Cómo retomar el trabajo (checklist de arranque)

1. Leer este archivo completo y `docs/revision_tecnica_ruta_de_accion.md` (§3, hallazgos P0).
2. Ejecutar `flutter analyze` y `flutter test` para confirmar que la línea base está sana.
3. Revisar §7 (próximos pasos): la primera tarea pendiente es la de arriba.
4. Al terminar, actualizar §3, §5 y §2 y hacer commit con la etiqueta `[S-xx]`.

---

## 2. Fases del plan

| Fase | Objetivo | Estado | Notas |
| :--- | :--- | :--- | :--- |
| **Fase 0: Fundaciones** | Repo, entorno, contratos de dominio, fachada serial, política de seguridad | 🟡 **En curso** | Añadida por la revisión técnica; no estaba en el documento original |
| **Fase 1: Núcleo y Serial** | Clean Architecture, esquema SQLite, navegación M3, isolate serial con *character-counting* | ⬜ Pendiente | Requiere cerrar P0-1/P0-3 antes del primer envío de bytes |
| **Fase 2: Calibración** | Jogging, pasos/mm, parámetros `$`, perfiles y *backlash* | ⬜ Pendiente | *Backlash* según P0-2 (sin `G92`) |
| **Fase 3: Visor 3D** | Renderizado, interpretación de G-code, pausa/detención y reanudación segura | ⬜ Pendiente | Necesita `$G`/`$#` (P1-2) |
| **Fase 4: Generador CAM** | Imagen → G-code (vectorización, dithering, relieve 2.5D) | ⬜ Pendiente | Modo láser requiere `$32` (P1-1) |
| **Fase 5: Optimización y Empaquetado** | Rendimiento, atajos, builds Windows/Linux/macOS/Android | ⬜ Pendiente | — |

Leyenda: 🟡 en curso · ✅ cerrada · ⬜ pendiente · 🔴 bloqueada

---

## 3. Tablero de tareas — Fase 0

### M0.1 Entorno reproducible
- [x] Repositorio Git inicializado (`main`)
- [x] Proyecto Flutter creado para `windows`, `linux`, `macos`, `android`
- [x] `.gitignore` de Flutter + `.gitattributes` con normalización LF
- [ ] `flutter upgrade` a la última versión estable (hoy: 3.29.2 / Dart 3.7.2, de marzo 2025)
- [ ] Fijar dependencias base en `pubspec.yaml` (riverpod, drift, vector_math, flutter_libserialport)
- [ ] CI con `flutter analyze`, `flutter test` y `dart format --set-exit-if-changed`

### M0.2 Trazabilidad y documentación
- [x] Ruta de acción incorporada a `docs/`
- [x] Revisión técnica con hallazgos P0/P1/P2 (`docs/revision_tecnica_ruta_de_accion.md`)
- [x] Este tablero de estado
- [ ] Documento `docs/seguridad_operativa.md` con las secuencias de pausa/parada/emergencia
- [ ] `CHANGELOG.md` + licencia + `NOTICE` de atribuciones

### M0.3 Contratos y fachada (inicio de Fase 1)
- [ ] Modelos: `MachineProfile`, `GrblSettings`, `StatusReport`, `MotionSegment`, `ProjectFile`
- [ ] `SerialPortRepository` (interfaz) + implementación `flutter_libserialport`
- [ ] Worker isolate con conteo de caracteres (presupuesto 128 B, bytes en tiempo real excluidos)
- [ ] `SafetyController` como único punto de envío de comandos críticos

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

## 5. Decisiones de arquitectura (ADR resumidas)

| ID | Decisión | Motivo | Consecuencia |
| :--- | :--- | :--- | :--- |
| ADR-001 | Gestión de estado con **Riverpod 3.x** (no BLOC) | Un solo paradigma, `select()` granular para telemetría de 5–10 Hz, testabilidad | `Notifier`/`AsyncNotifier` + `riverpod_generator`; `StateNotifier` prohibido |
| ADR-002 | Streaming por **conteo de caracteres** con presupuesto calculado de 128 B | Es el único método que mantiene el planner abastecido sin desbordar | Los bytes en tiempo real **no** se descuentan; los `error:` sí liberan espacio |
| ADR-003 | Prohibido `G92` para compensar holgura; se compensa con movimiento real | `G92` no persiste, pisa el marco del usuario y dispara `ALARM:2` | El post-procesador emite `G1` cortos en inversiones de sentido |
| ADR-004 | Repositorio único multiplataforma (monorepo) | Windows es el objetivo primario; Android reutiliza dominio y UI | Sin paquetes internos por ahora; se separará si la app supera ~15 k LOC |
| ADR-005 | Trunk-based: `main` siempre verde, ramas cortas `feat/`, `fix/`, `docs/` | Proyecto de un solo desarrollador con asistencia de agentes | Todo cambio entra por commit convencional con etiqueta de sesión |
| ADR-006 | Actualizar Flutter **antes** de fijar dependencias | Riverpod 3.5.0 y Drift 2.35.4 son posteriores a Dart 3.7.2 | Riesgo: incompatibilidades del toolchain si se pospone |

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
| R-03 | SDK Flutter desactualizado | Dependencias antiguas o incompatibles | `flutter upgrade` como primera tarea de M0.1 | 🔴 Abierto |
| R-04 | Sin emulador GRBL no se puede probar streaming ni alarmas | Errores detectados sólo en hardware | Puerto falso + emulador antes de la Fase 2 | 🟡 Mitigado en diseño |
| R-05 | Renderizado lento con G-code extenso | UI inutilizable en trabajos reales | Batching con `drawRawPoints` + criterio de 60 fps con 200 k segmentos | 🟡 Mitigado en diseño |
| R-06 | Sobrescritura de EEPROM en cada conexión | Desgaste del ATmega | Escribir sólo si el valor difiere de `$$` | 🟡 Mitigado en diseño |

---

## 8. Próximos pasos (orden estricto)

1. `flutter upgrade` y registrar la versión resultante en el README.
2. Fijar dependencias base en `pubspec.yaml` y ejecutar `flutter pub get`.
3. Crear `docs/seguridad_operativa.md` con las secuencias de pausa, cancelación de jog, detención y emergencia (contenido de P0-1 y P0-3 de la revisión).
4. Definir modelos de dominio y sus tests de serialización (M0.3).
5. Implementar `SerialPortRepository` + worker isolate con el algoritmo de conteo de caracteres y su suite de tests con puerto falso.
6. Configurar CI y proteger `main` frente a commits con el análisis en rojo.
7. Recién entonces iniciar la Fase 1 según el documento original.

