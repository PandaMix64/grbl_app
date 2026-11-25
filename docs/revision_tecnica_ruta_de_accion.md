# Revisión técnica de la ruta de acción — CNC + GRBL v1.1h en Flutter

| Campo | Valor |
| :--- | :--- |
| Documento revisado | `docs/ruta_de_accion_entorno_cnc_flutter_y_grbl.md` (versión original del autor, sin modificar) |
| Fecha de revisión | 2026-11-24 |
| Revisor | Cline |
| Método | Contraste 1:1 contra el código y la documentación oficiales de `gnea/grbl` (rama `master` = v1.1h): `grbl/config.h`, `grbl/serial.c`, `doc/markdown/interface.md`, `commands.md`, `settings.md`, `jogging.md`; y contra las fichas vigentes en pub.dev |
| Veredicto | **Aprobado con cambios obligatorios** (3 hallazgos P0 antes de escribir código que toque hardware) |

---

## 1. Resumen ejecutivo

El documento tiene una calidad muy superior a la media de una hoja de ruta. Identifica correctamente el cuello de botella real del proyecto (el búfer serial de 128 B y el *look-ahead planner*), aísla la lógica de hardware en isolates, define persistencia híbrida (SQLite + contenedor portable) y plantea la reanudación segura como un problema de estado, no de "replay". La elección de `CustomPainter` en lugar de un motor 3D completo es además la decisión pragmática correcta para segmentos `G0`/`G1`.

De las 15 afirmaciones técnicas verificables, **12 se confirman literalmente** contra la documentación oficial, **3 son incompletas** y hay **3 decisiones con riesgo físico** que deben corregirse antes de implementarse (P0). Faltan además 9 piezas de protocolo sin las cuales el módulo de calibración y el de láser no funcionarán como se describen (P1).

**Conteo de hallazgos:** 12 validados · 3 P0 · 9 P1 · 8 P2.

El riesgo principal del plan no es de arquitectura, sino de **seguridad operativa**: el documento asume que `!` (Feed Hold) "pausa sin pérdida de pasos", lo que es cierto para el movimiento pero **no apaga el husillo ni el láser**. Con un láser de diodo o un husillo de 500 W, una pausa mal definida es la diferencia entre un trabajo perdido y un incendio.

---

## 2. Matriz de verificación (afirmación → veredicto → evidencia)

| # | Afirmación del documento | Veredicto | Evidencia |
| :--- | :--- | :--- | :--- |
| 1 | GRBL v1.1h tiene búfer de recepción serial de 128 bytes en ATmega328P | ✅ Correcto | `grbl/serial.c`: `#define RX_RING_BUFFER (RX_BUFFER_SIZE+1)`; con el búfer vacío `serial_get_rx_buffer_available()` devuelve exactamente `RX_BUFFER_SIZE` (128 por defecto en `config.h`). El `+1` existe para distinguir lleno de vacío, no para dar un byte extra |
| 2 | El streaming por conteo de caracteres evita esperar un `ok` por línea | ✅ Correcto | Cada `ok`/`error` libera el espacio de la línea que lo generó; el `ok` significa "parseado y encolado", no "ejecutado" |
| 3 | `?`, `!`, `~`, `0x18` son comandos en tiempo real sin `\n` | ✅ Correcto | `grbl/config.h`: `CMD_STATUS_REPORT '?'`, `CMD_FEED_HOLD '!'`, `CMD_CYCLE_START '~'`, `CMD_RESET 0x18` |
| 4 | La pausa (`!`) es segura y reanudable | ⚠️ **Incompleto (P0-1)** | El Feed Hold desacelera y **conserva** el estado de la herramienta: no la apaga |
| 5 | El jogging usa `$J=` y se cancela al liberar el control | ⚠️ **Incompleto (P0-3)** | `jogging.md`: `F` es obligatorio en cada jog y no es modal; sólo se acepta en estado `Idle` o `Jog`; la cancelación real es `0x85`, y `serial.c` sólo la atiende si `sys.state & STATE_JOG` |
| 6 | `$100`/`$101`/`$102` = pasos/mm y la fórmula de recalibración es válida | ✅ Correcto | `settings.md`. Matiz: el valor se guarda como decimal, la medición debe ser la distancia **real** y conviene validar contra el límite de *step rate* (~30 kHz en 328P) |
| 7 | `$110–$112` (max rate), `$120–$122` (aceleración), `$130–$132` (recorrido) | ✅ Correcto | `settings.md`: max rate en mm/min, aceleración en mm/s², max travel sólo se usa con soft limits + homing |
| 8 | La velocidad es fija a 115200 baudios | ⚠️ Parcial | `config.h`: `#define BAUD_RATE 115200` es el valor **compilado por defecto**; existen máquinas a 9600, 57600 y 250000. La UI debe permitir override y auto-detección |
| 9 | GRBL v1.1 estándar no compensa holgura mecánica | ✅ Correcto | GRBL v1.1 no implementa *backlash compensation* en firmware |
| 10 | La holgura se compensa inyectando `G92` y "reajustando la coordenada lógica" | ❌ **Incorrecto (P0-2)** | `G92` es un offset de trabajo **no persistente** y altera el marco de referencia del usuario |
| 11 | Reanudar por índice de línea es suficiente | ⚠️ **Incompleto (P1-2)** | GRBL no tiene "resume": hay que reconstruir estado modal (`$G`), offsets (`$#`) y desbloquear `Alarm` (`$X`) |
| 12 | `flutter_libserialport` cubre escritorio y es extensible a Android | ✅ Correcto | pub.dev 0.6.0: Android, Linux, macOS, Windows (sin iOS ni web); envoltorio del paquete Dart `libserialport`; licencia MIT |
| 13 | Los Isolates aíslan serial y CAM sin afectar la UI | ⚠️ Matiz importante | El paquete es FFI, así que funciona en isolates; pero **un `MethodChannel` no funciona en un isolate de fondo** sin `BackgroundIsolateBinaryMessenger`. El worker serial debe hablar sólo por FFI |
| 14 | `CustomPainter` + `vector_math` basta para el visor 3D | ⚠️ Viable con condiciones | Correcto para cientos de miles de segmentos **sólo** con batching (`drawRawPoints`/`drawPath` en lotes) y sin reconstruir geometría por frame |
| 15 | Drift + archivos `.cncproj` para persistencia | ✅ Correcto | Drift 2.35.4 es multiplataforma y soporta ejecutar consultas en isolates |

---

## 3. Hallazgos P0 — bloqueantes de seguridad o de corrección

### P0-1. La secuencia de pausa no detiene la herramienta (riesgo de incendio y lesión)

**Problema.** El documento describe la pausa como "advertencia + guardar progreso + reanudar". En GRBL, `!` (Feed Hold) desacelera hasta detener el movimiento, pero **deja el husillo, el láser y el refrigerante en el estado en que estaban**. En modo láser (`$32=1`) el haz sigue emitiendo sobre la pieza inmóvil: quemadura puntual, material fundido o incendio. En fresado, la fresa detenida contra la pieza con el husillo girando deja marcas y puede astillar la herramienta al reanudar.

**Evidencia.** `commands.md` documenta `0x9E` (Toggle Spindle Stop) como el mecanismo de apagado inmediato y lo restringe al estado `HOLD` justamente para impedir apagados accidentales en movimiento. Al reanudar, GRBL restaura el estado del husillo y **espera 4,0 s configurables** antes de retomar la trayectoria, para que el usuario no olvide reactivarlo.

**Corrección propuesta (secuencia de pausa obligatoria).**

1. Enviar `!` y esperar a que el estado reportado sea `Hold` (con timeout y un reintento).
2. Enviar `0x9E` (spindle stop toggle) o, si el perfil no usa husillo variable, un bloque `M5` seguido de `S0`.
3. Persistir en el `.cncproj`: índice de línea, estado modal (`$G`), offsets (`$#`), `MPos`/`WPos` y marca temporal.
4. Reanudar sólo con confirmación explícita del usuario: reactivar herramienta, esperar estabilización (≥ 4 s o el valor del perfil), posicionar según la secuencia ya prevista y enviar `~`.

**Criterio de aceptación.** Test de integración con emulador: tras `!` + `0x9E`, el estado reportado debe ser `Hold` y la salida de husillo/láser debe ser 0 antes de permitir siquiera cerrar la aplicación.

### P0-2. `G92` no es un mecanismo válido para compensar holgura

**Problema.** El plan propone "inyectar la compensación al cambiar de sentido y reajustar la coordenada lógica (`G92`)". Ese enfoque rompe cuatro cosas:

1. **No persiste.** `$#` lo confirma: `G92`, `G43.1` y los datos de `G38.2` se pierden en reset o power-cycle. Si el usuario pausa, resetea o reanuda, la compensación desaparece a mitad del trabajo.
2. **Interfiere con el marco del usuario.** Si el operario ya definió su origen con `G92` o con `G10 L20`, el post-procesador sobrescribe ese contrato y la pieza sale desplazada.
3. **Puede disparar `ALARM:2`.** Con soft limits activos (`$20=1`), un `G92` que empuja la posición fuera del volumen de trabajo provoca alarma y bloqueo.
4. **Es invisible al visor.** El renderizador simula la geometría del programa, no la posición real compensada: la vista 3D y la máquina divergen.

**Corrección propuesta.** Compensar con **movimiento real**, no con coordenadas:

- Al detectar inversión de sentido en un eje, emitir un `G1` corto (la holgura del perfil) a velocidad de trabajo y continuar desde ahí. La herramienta se desplaza físicamente en lugar de "mentir" sobre las coordenadas.
- Aplicar la compensación **sólo** en el post-procesador de exportación/ejecución, nunca en Z, y dejarla desactivable por perfil.
- Registrar en el `.cncproj` la holgura aplicada y el número de compensaciones inyectadas, para auditar desviaciones.

> **Implementado en S-06:** `lib/domain/services/backlash_compensator.dart` (con pruebas de inversión de sentido, exclusión de Z y respeto del avance). El origen de trabajo usa `G10 L20 P1`, no `G92` (ADR-020).

**Criterio de aceptación.** Un cuadrado de 100 mm ejecutado con holgura de 0,3 mm por eje debe medir 100 mm ± 0,05 mm, y la prueba debe poder repetirse tras un soft reset sin perder la compensación.

### P0-3. Faltan los comandos de cancelación y de parada correctos

**Problema.** El documento lista `0x18` como "reinicio suave" y no distingue tres acciones con efectos radicalmente distintos. Un botón "Detener" mapeado a `0x18` durante un trabajo deja la máquina en `ALARM:3` (reset durante movimiento), **pierde el cero de máquina** y obliga a un homing completo. A la inversa, usar `!` como "detener" deja el husillo girando indefinidamente.

**Corrección propuesta.**

| Acción de UI | Byte / comando | Efecto real | Recuperación |
| :--- | :--- | :--- | :--- |
| Pausa | `!` → `0x9E` | `Hold`; movimiento detenido, herramienta apagada | `~` restaura herramienta tras la espera de estabilización |
| Cancelar jog | `0x85` | Vacía el planner y vuelve a `Idle` **sin soft reset**; sólo actúa en estado `Jog` | Ninguna: el parser no cambia de estado |
| Detener trabajo | `!` → `M5`/`S0` → `0x18` | Soft reset: `ALARM:3`, planner purgado, posición perdida | `$X` para desbloquear y re-homing o re-definir origen |
| Emergencia física | Paro de emergencia por hardware | Corte de potencia a drivers | Re-homing completo, sin excepciones |

Además, `0x84` (safety door) debe exponerse si el perfil tiene puerta o encapsulado: produce parada con `HOLD` y reanudación controlada sin perder posición, algo que ningún otro comando ofrece.

**Criterio de aceptación.** Ningún flujo de código envía `0x18` sin un `$X` posterior en el mismo caso de uso, y el botón "Detener" declara explícitamente en la UI las tres consecuencias de la tabla.

---

## 4. Hallazgos P1 — omisiones que rompen módulos completos

### P1-1. Falta `$32` (laser mode), `$30` y `$31`

El "grabado láser con modulación de potencia" no puede implementarse como se describe sin `$32=1` (modo láser) y sin `$30`/`$31` (rango de `S` mapeado al PWM). En modo láser GRBL deja de detenerse en cada cambio de `S` y respeta la aceleración; con `M4` la potencia es proporcional a la velocidad real, evitando puntos quemados en las esquinas. **Acción:** añadir al perfil de máquina el campo `laserMode`, escribir `$32` al activarlo y emitir `M4` (no `M3`) en el CAM láser.

### P1-2. La reanudación necesita `$G` y `$#`, no sólo el índice de línea

GRBL no conserva estado tras un soft reset, y `G92`/`G43.1` no son persistentes. La secuencia correcta al reanudar es: leer `$G` (estado modal del parser), `$#` (offsets G54–G59, G28/G30, G92, TLO), `$X` si el estado es `Alarm`, emitir de forma explícita `G21 G90 G94` + el sistema de coordenadas + la potencia/velocidad y el avance, y sólo entonces continuar. **Acción:** el `.cncproj` debe guardar el bloque `$G` completo, no un resumen.

### P1-3. El concierto de comandos en tiempo real está incompleto

Faltan los overrides, que son requisito de facto en cualquier CNC: `0x90–0x94` (feed override 100 %, ±10 %, ±1 %), `0x95–0x97` (rapid 100/50/25 %), `0x99–0x9D` (spindle speed override), `0x9E` (spindle stop toggle), `0xA0`/`0xA1` (refrigerante). **Acción:** añadir al §2 la tabla definitiva tomada de `config.h` y una nota de que los overrides de avance no aplican a `G0`, `G28`, `G30` ni a los jogs.

### P1-4. Falta el flujo de control fino del conteo de caracteres

Tres reglas que el documento no menciona y que producen corrupción de estado si se ignoran:

1. Los bytes en tiempo real (`?`, `!`, `~`, `0x18`, `0x84`, `0x85`, overrides) son **capturados por la ISR antes de entrar al búfer** —`serial.c` lo comenta literalmente: *"Pick off realtime command characters directly from the serial stream. These characters are not passed into the main buffer"*—. Por eso **no** deben descontarse del presupuesto de 128 B.
2. Un `error:` libera el espacio de su línea igual que un `ok`; si el worker no descuenta en el error, el contador se "congela" y el streaming se detiene solo.
3. El conteo debe presupuestar el tamaño de la línea **más** el `\r` (GRBL espera CR, no CRLF) y reservar 1 byte de margen para no alcanzar el llenado exacto.

**Acción:** escribir el algoritmo como pseudo-código en el documento y cubrirlo con tests unitarios de casos límite (líneas de 90 B, respuestas `error:` intercaladas, reset durante streaming).

### P1-5. Falta el manejo de alarms y errores

Sin tablas de `ALARM:` y `error:` la UI no puede reaccionar ni ofrecer la recuperación correcta. Los alarms que hay que mapear: `ALARM:1` (hard limit), `ALARM:2` (soft limit), `ALARM:3` (reset durante movimiento), `ALARM:4`/`ALARM:5` (fallo de sonda), `ALARM:6`/`ALARM:7` (homing abortado), `ALARM:8`/`ALARM:9` (homing: fallo de pull-off o de aproximación). **Acción:** tabla de traducción `código → mensaje humano → acción sugerida → botón de recuperación`.

### P1-6. Falta `$C` (check mode), la simulación nativa de GRBL

GRBL puede validar un programa sin mover la máquina (`$C`): parsea todo el G-code, detecta límites y errores sin energizar motores. Es la verificación más barata y fiable que existe, y el documento la ignora. **Acción:** ofrecer "Validar con el controlador (`$C`)" como paso previo opcional al envío, además de la simulación propia.

### P1-7. Falta el tratamiento de arcos al importar `.gcode`

El CAM propio emite sólo `G0`/`G1`, pero el visor acepta archivos externos y **GRBL interpola `G2`/`G3` con centro `I`/`J`/`K`, no con radio `R`**. Un archivo generado por otro CAM con `R` fallará en GRBL aunque el visor lo dibuje. **Acción:** en el importador, convertir `R` a `I`/`J` (o rechazar el archivo con un mensaje claro) y subdividir el arco en segmentos para el renderizado y para el cálculo de longitud de trayectoria.

### P1-8. No hay estrategia de pruebas ni emulador

El punto más delicado del proyecto (streaming, reanudación, alarmas) no es probable con hardware real de forma repetible. **Acción:** definir tres niveles desde la Fase 1: (a) unitarios del controlador de flujo con un puerto falso basado en `StreamController`; (b) integración contra un emulador GRBL (loopback o simulador de la comunidad) que reproduzca respuestas `ok`/`error`/`<...>` con retardos; (c) hardware real limitado a pruebas de aceptación por fase.

### P1-9. Faltan versionado del `.cncproj`, migraciones y escritura de EEPROM

El contenedor portable necesita `schemaVersion`, migración explícita y validación al abrir (si no, la primera actualización rompe proyectos guardados). Además, escribir settings en EEPROM en cada arranque desgasta la memoria del ATmega (del orden de 10⁵ ciclos): sólo escribir cuando el valor difiera del leído con `$$`. **Acción:** incluir ambos puntos como criterios de aceptación de Fase 1 y Fase 2.

---

## 5. Hallazgos P2 — mejoras recomendadas

1. **`vector_math_64` en lugar de `vector_math`.** Es un reemplazo directo (`package:vector_math/vector_math_64.dart`) con precisión de 64 bits, coherente con el `Matrix4` de Flutter. La versión vigente es 2.4.4.
2. **Estrategia de renderizado explícita.** Guardar los segmentos en `Float32List` y pintar con `drawRawPoints(..., PointMode.polygon)` en lotes de ~5 000–10 000 puntos, separando por color/estado en 3 lotes fijos (ejecutado, pendiente, rápido). Nada de `Path` por segmento ni de `for` con `drawLine` por punto.
3. **Aislar el repintado.** `CustomPainter` con `repaint: Listenable` propio (valor de posición del cabezal) en lugar de `setState`; `RepaintBoundary` alrededor del lienzo 3D.
4. **Riverpod 3.x.** La versión vigente es 3.5.0; `StateNotifier` está desaconsejado en favor de `Notifier`/`AsyncNotifier` con `riverpod_generator`. Para telemetría a 5–10 Hz, un provider por magnitud (posición, estado, progreso) y `ref.watch(provider.select(...))` evita reconstrucciones globales.
5. **Riesgo de dependencia en `flutter_libserialport`.** 0.6.0, publicado hace ~16 meses, con 150 *pub points* y editor no verificado. La abstracción `SerialPortRepository` ya prevista es la mitigación correcta: añadir una segunda implementación sobre `libserialport` (paquete Dart) para no quedar bloqueados, y fijar la versión exacta en `pubspec.yaml`.
6. **i18n desde el inicio.** `flutter_localizations` + ARB, con `es` como locale por defecto; el costo de retrofitear traducciones en un CNC es alto por la cantidad de mensajes de seguridad.
7. **Accesibilidad y ergonomía de taller.** Objetivos táctiles ≥ 48 px, alto contraste (el documento ya lo prevé), confirmaciones por pulsación mantenida para acciones destructivas y bloqueo de atajos cuando el foco está en un campo numérico.
8. **Licencia y atribución.** GRBL es GPLv3; la app se comunica por serial (no deriva del código), pero si se redistribuye un binario de GRBL compilado, aplica GPLv3. Definir licencia del proyecto y un `NOTICE` con atribuciones antes de publicar.

---

## 6. Ajustes al stack (versiones verificadas en pub.dev)

| Componente | Documento | Recomendación | Motivo |
| :--- | :--- | :--- | :--- |
| Gestión de estado | Riverpod (o BLOC) | `flutter_riverpod ^3.5.0` + `riverpod_generator` | 3.5.0 vigente; API `Notifier`/`AsyncNotifier`; decidir Riverpod **o** BLOC, no ambos |
| Persistencia | Drift (SQLite) | `drift ^2.35.4` + `drift_flutter` + `drift_dev` + `build_runner` | Ejecución de consultas en isolate de forma nativa. **No** añadir `sqlite3_flutter_libs`: está obsoleto (`0.6.0+eol`, "no longer does anything") desde `sqlite3` 3.x, que `drift_flutter` ya resuelve |
| Motor 3D | `CustomPainter` + `vector_math` | `vector_math ^2.4.4` (import `vector_math_64`) | Precisión 64 bits, coherente con Flutter |
| Puerto serial | `flutter_libserialport` | `flutter_libserialport: ^0.6.0` fijado + fachada propia; `libserialport: ^0.3.0` como dependencia directa | 0.6.0 cubre Android/Linux/macOS/Windows; no iOS ni web. `libserialport` se declara explícitamente porque la implementación FFI lo importa (`depend_on_referenced_packages`) |
| Imágenes del CAM | (no especificado) | `image` (Dart puro, seguro en isolates) + `file_selector` o `file_picker` | `image` no depende de plugins, apto para `Isolate.run` |
| Internacionalización | (no especificado) | `material_ui` exporta `GlobalMaterialLocalizations`; no añadir `flutter_localizations` por separado | Desde Flutter 3.47 los widgets Material viven en `package:material_ui/material_ui.dart` y `package:flutter/material.dart` está deprecado |

**Nota de entorno (actualizada en la sesión S-02).** El SDK se actualizó de 3.29.2 a **Flutter 3.50.1 / Dart 3.14.0**, lo que cerró el riesgo R-03 de versiones incompatibles y aplicó ADR-006. Consecuencias verificadas en la práctica:

- `package:flutter/material.dart` **está deprecado**; el import correcto es `package:material_ui/material_ui.dart` (`material_ui ^1.11.1`). Los widgets y el tema siguen siendo Material 3, e incluso `GlobalMaterialLocalizations` se importa desde ese paquete (importarlo además desde `flutter_localizations` provoca `ambiguous_import`).
- `flutter pub get` migra `analysis_options.yaml` por sí solo para excluir `build/` y los directorios de plataforma.
- `sqlite3_flutter_libs` quedó obsoleto: en Flutter 3.50 la base SQLite viene de `sqlite3` 3.x, ya resuelta por `drift_flutter`. **Verificado en S-04**: `sqlite3` 3.x trae `hook/build.dart` (*native assets*), así que SQLite **sí** está disponible en `flutter test` — al contrario que la DLL de `libserialport`, que solo existe en el bundle de la app.
- Los proyectos nuevos deben declarar `environment: sdk: ^3.14.0` para no prometer compatibilidad que el toolchain no ofrece.

La versión de `flutter_libserialport` (0.6.0) fue publicada hace más de un año: conviene verificar al momento de implementar que `libserialport.dll` se empaqueta correctamente en el build de Windows y que el permiso USB de Android (`android.hardware.usb.host` + intent de dispositivo) está declarado en el manifest.

---

## 7. Parches concretos al documento original

| Sección | Texto actual | Reemplazo sugerido |
| :--- | :--- | :--- |
| §2, viñeta 1 | "búfer de recepción serial limitado a 128 bytes" | "búfer de recepción de 128 bytes (`RX_BUFFER_SIZE`, valor de compilación; otros forks con ARM/ESP32 usan 256 o más). El presupuesto debe calcularse en tiempo de conexión, no asumirse" |
| §2, comandos | lista de 4 comandos | añadir `0x84` (safety door), `0x85` (jog cancel), `0x9E` (spindle stop), `0x90–0x9D` (overrides), `0xA0/0xA1` (refrigerante) |
| §2, streaming | "transmite nuevas líneas conforme se liberan bytes" | añadir: "los bytes en tiempo real no entran al búfer y no consumen presupuesto; un `error:` libera espacio igual que un `ok`" |
| §3.1 | "velocidad fija de 115200 baudios" | "115200 por defecto (valor de compilación de GRBL), editable y con auto-detección" |
| §3.2, jogging | "Desplazamiento eje por eje mediante comandos `$J=`" | "`$J=` con `F` obligatorio en cada comando; sólo válido en `Idle`/`Jog`; cancelación con `0x85` (o `!`), que purga el planner y devuelve a `Idle` sin reset" |
| §3.2, backlash | "reajusta la coordenada lógica (`G92`)" | ver P0-2: compensar con movimientos reales, nunca con `G92` |
| §3.3, pausa | "Pausa, Detención con Alerta y Reanudación Segura" | definir la secuencia de P0-1 y distinguir pausa / cancelar jog / detener / emergencia según P0-3 |
| §3.4 | "modulación de potencia" | "`M4` (potencia dinámica) con `$32=1` y `$30`/`$31` configurados; `M3` sólo si el perfil no es láser" |
| §4 | Fases 1–5 | insertar **Fase 0** (ver §8) y añadir criterios de aceptación medibles por fase |

---

## 8. Fase 0 propuesta (fundaciones) con criterios medibles

| Objetivo | Entregable | Criterio de aceptación |
| :--- | :--- | :--- |
| Entorno reproducible | Flutter actualizado, `pubspec` con versiones fijadas, README con requisitos, CI (analyze + test + format) | `flutter analyze` y `flutter test` en verde en CI desde el primer commit |
| Repositorio y trazabilidad | Git init, `.gitignore`/`.gitattributes`, convención de commits, `ESTADO_PROYECTO.md` | Cualquier cambio se rastrea a una sesión y a una fase |
| Contratos del dominio | Modelos `MachineProfile`, `GrblSettings`, `StatusReport`, `MotionSegment`, `ProjectFile` | Tests unitarios de parseo y serialización |
| Fachada serial | `SerialPortRepository` + worker isolate con conteo de caracteres | Test: 10 000 líneas sin desbordar el presupuesto simulado de 128 B y sin deadlock |
| Política de seguridad | Documento de secuencias (pausa/parada/emergencia) implementado como un único `SafetyController` | Ningún widget envía bytes directos; toda acción pasa por el controlador |

Criterios medibles para el resto del proyecto (recomendados): ≥ 60 fps con 200 000 segmentos, latencia de status < 100 ms, desviación de posición < 0,02 mm en un cubo de calibración, y cero pérdidas de línea en un archivo de 100 000 bloques con `error:` inyectados artificialmente.

---

## 9. Lo que el documento hace bien y conviene preservar

- Detectar el *character-counting* como requisito, en lugar de asumir streaming naíf por `ok`.
- Aislar hardware y CAM en isolates y no en el hilo de UI.
- Modelar la reanudación como persistencia de estado, no como "volver a enviar".
- Elegir `CustomPainter` sobre un motor 3D: para líneas, la proyección manual es más rápida y no añade 20 MB de dependencias.
- La fórmula de calibración de pasos/mm es la correcta y está bien expresada.
- La separación entre parámetros de EEPROM (`$x`) y atributos del perfil local es exactamente el límite que GRBL impone: no intentar meter holgura o altura segura en el firmware.




