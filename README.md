# grbl_app

Aplicación de escritorio (y Android) para **controlar máquinas CNC con firmware GRBL v1.1h**, generar trayectorias (CAM) desde imágenes o G-code y supervisarlas en un visor 3D.

Flutter + Material Design 3, Clean Architecture con gestión de estado reactiva, y comunicación serial y procesamiento CAM aislados en Dart Isolates para no bloquear la interfaz.

> ⚠️ **Aviso de seguridad.** Esta aplicación controla maquinaria real: husillos, láseres y motores paso a paso. Una secuencia incorrecta puede causar daños materiales, quemaduras o incendio. Antes de conectar una máquina, lee `docs/revision_tecnica_ruta_de_accion.md` (§3, hallazgos P0). El documento `docs/seguridad_operativa.md` está pendiente de redacción (ver `ESTADO_PROYECTO.md` §8).

## Estado del proyecto

| Fase | Estado |
| :--- | :--- |
| Fase 0 — Fundaciones | ✅ Cerrada |
| Fase 1 — Núcleo y Serial | ✅ Cerrada |
| Fase 2 — Calibración | ✅ Cerrada |
| Fase 3 — Visor 3D | 🟡 En curso (visor y ejecución listos) |
| Fase 4 — Generador CAM | 🟡 En curso (grabado láser) |
| Fase 5 — Optimización y empaquetado | ⬜ Pendiente |

El detalle de tareas, decisiones (ADR), riesgos y bitácora de cada sesión vive en **[`ESTADO_PROYECTO.md`](ESTADO_PROYECTO.md)**. Empieza por ahí si retomas el proyecto.

## Documentación

| Documento | Contenido |
| :--- | :--- |
| [`docs/ruta_de_accion_entorno_cnc_flutter_y_grbl.md`](docs/ruta_de_accion_entorno_cnc_flutter_y_grbl.md) | Plan original del autor (arquitectura, protocolo GRBL, módulos, fases) |
| [`docs/revision_tecnica_ruta_de_accion.md`](docs/revision_tecnica_ruta_de_accion.md) | Revisión contra la especificación oficial de GRBL v1.1h: hallazgos P0/P1/P2 y parches propuestos |
| [`ESTADO_PROYECTO.md`](ESTADO_PROYECTO.md) | Tablero de avance, ADR, riesgos y bitácora de sesiones |

## Requisitos

- Flutter 3.50.1 / Dart 3.14.0 o superior (`channel stable`).
- Windows 10+, Linux, macOS o Android 8+ con USB-OTG.
- Controlador GRBL v1.1h a 115200 baudios, 8-N-1.

## Dependencias principales

| Paquete | Versión | Uso |
| :--- | :--- | :--- |
| `flutter_riverpod` | ^3.5.0 | Estado e inyección de dependencias (ADR-001) |
| `material_ui` | ^1.11.1 | Widgets Material 3 (reemplaza `package:flutter/material.dart`, deprecado) |
| `drift` / `drift_flutter` | ^2.35.4 / ^0.3.1 | Persistencia SQLite multiplataforma |
| `flutter_libserialport` | ^0.6.0 | Acceso serial nativo (FFI) |
| `vector_math` | ^2.4.4 | Geometría 3D del visor (`vector_math_64`) |
| `image` / `file_selector` | ^4.13.1 / ^1.1.0 | Entrada del motor CAM |
| `custom_lint` / `riverpod_lint` | — | *(pendiente de decidir)* |

## Puesta en marcha

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter run -d windows
```

## Estructura

```text
lib/
  app/          # GrblApp, HomeShell y providers de Riverpod
  core/grbl/    # constantes de protocolo (bytes en tiempo real, búfer, baudios)
  core/widgets/ # widgets compartidos
  domain/
    entities/   # StatusReport, BuildInfo, ParserState, WorkOffsets, perfiles, proyectos
    repositories/  # contrato SerialPortRepository
    services/   # ProfileConsistency (perfil ↔ EEPROM)
  data/
    serial/     # conteo de caracteres, servicio GRBL, FFI y worker isolate
    database/   # esquema drift (perfiles, proyectos, recientes) + mappers
    repositories/  # ProjectRepository: persistir y confirmar antes del reset
  features/
    connection/ # controlador y barra de conexión
    calibration/ # jog, parámetros $, pasos/mm y perfiles
    viewer/     # intérprete → segmentos, proyección, pintor y visor 3D
    home/ cam/
test/
  domain/       # protocolo, perfiles, proyectos, consistencia, jog, pasos/mm, G-code
  serial/       # presupuesto de 128 B, seguridad, handshake, jog y escritura
  data/         # base de datos real y persistencia del punto de reanudación
  features/     # controladores, proyección y visor
  helpers/      # FakeSerialPort: emulador GRBL de pruebas
```

## Conexión serial

El puerto vive en un isolate propio y la UI solo habla con `GrblWorkerClient`:

```dart
final GrblWorkerClient client = await GrblWorkerClient.spawn();
final List<SerialPortInfo> ports = await client.listPorts();
final GrblHandshake session = await client.connect(portName: ports.first.name);

print('GRBL ${session.firmwareVersion} · búfer ${session.rxBufferSize} B');
client.statusReports.listen((StatusReport report) => print(report.state.label));
await client.startPolling(); // 5 Hz

// Pausa segura: `!` + `0x9E`, con verificación de herramienta apagada.
await client.pause();
```

`connect()` ejecuta el handshake completo: banner, `$I` (de donde sale el **tamaño real** del búfer RX), `$$`, `$G` y `$#`. `stopJob()` emite un `WorkerPersistRequest`: hasta que no se llame `confirmPersisted()` no se envía el soft reset (SEG-03).

> **Nota de entorno:** `flutter_libserialport` despliega la biblioteca nativa mediante CMake en el *bundle* de la aplicación. Por eso `flutter test` no puede cargarla: la prueba de humo FFI se salta y la verificación real se hace con `flutter run -d windows` (ver R-10 en `ESTADO_PROYECTO.md`).

## Calibración

El módulo de Calibración permite:

- **Jogging** con `$J=` (el avance `F` es obligatorio en cada comando) y cancelación con `0x85`; solo se acepta en `Idle`/`Jog`.
- **Parámetros `$`**: lectura de la EEPROM y escritura **solo de los valores que cambian** (`GrblSettings.diff`), con un `ok` por parámetro.
- **Pasos/mm**: se ordena un avance de 10 mm, se mide el desplazamiento real y la app calcula y escribe `nuevo = actual × 10 / medido` (rechaza medidas fuera del ±50 %).
- **Perfiles**: alta, edición y borrado con validación de volumen, altura segura, holgura y herramienta, más un botón para **aplicar** el perfil a la EEPROM (`$32`, `$30`, `$130-$132`), escribiendo solo lo que difiere.
- **Holgura**: prueba guiada (ida y vuelta con jog), estimación y guardado en el perfil. La compensación se aplica con movimiento real (`BacklashCompensator`), nunca con `G92`.
- **Homing y origen**: `$H` y `G10 L20 P1` (cero de G54 persistente), siempre con confirmación explícita.

## Visor

`Visor` interpreta G-code (`G0`/`G1`/`G2`/`G3` con `I`/`J` o `R`, `G90`/`G91`, `G20`/`G21`) y lo dibuja con `CustomPainter` en tres lotes: rápido, pendiente y ejecutado. El cabezal se sincroniza con la telemetría y el volumen de trabajo sale del perfil activo.

- Arrastrar desplaza, pellizcar/rueda acerca, girar rota y doble toque restablece la vista.
- El botón **Centrar trazado** reencuadra el programa (y al cargar un archivo nuevo el encuadre es automático).
- El cabezal usa la **última posición conocida**: GRBL omite `WCO` en la mayoría de reportes, así que la app memoriza el offset y conserva el WPos en lugar de borrarlo. Si un reporte no trae posición, la barra y el panel de origen lo indican como «(última lectura)».
- Los códigos que cambian el sistema de coordenadas (`G28`, `G30`, `G53`, `G92`) **no se simulan**: se muestran como avisos.

## Ejecución

La barra de ejecución del visor envía el programa con la **holgura del perfil aplicada** (movimientos
`G1` cortos en cada inversión de sentido, nunca `G92`), pinta el avance real por línea confirmada y
permite pausar, reanudar y detener:

- **Pausa** (`!` → `0x9E`): guarda línea, `$G`, `$#` y posición en SQLite antes de confirmar; GRBL queda
  en `Hold` con la herramienta apagada.
- **Reanudar**: verifica `$G`/`$#` contra lo guardado, reactiva la herramienta con `0x9E` y envía `~`.
  No reenvía G-code: GRBL conserva su planificador.
- **Detener** (`0x18`): pide confirmación con las consecuencias y resetea el controlador.
- **Reanudar trabajo guardado**: tras una pausa, una detención o una pérdida de USB, retoma el trabajo desde su
  última línea confirmada. Verifica `$G`/`$#` contra lo guardado y exige que la máquina esté a ≤ 1 mm del punto
  guardado (botón **Llevar al punto guardado**); si algo no coincide, se cancela en lugar de arriesgar la pieza.

## CAM

`CAM` convierte una **imagen** (PNG/JPG/BMP) en G-code de grabado láser con `M4`:

- **Modos**: umbral (silueta), tramado Floyd–Steinberg (medios tonos) y escala de grises (potencia proporcional).
- **Parámetros**: ancho en mm (el alto sale por proporción), mm por celda, potencia `S` máxima y avance. El botón
  «Valores del perfil» toma potencia, avance y ancho del perfil activo.
- La conversión corre en un **isolate** con un tope de 250 000 celdas; el perfil debe ser de tipo láser y el grabado
  debe caber en su recorrido.
- **Previsualización obligatoria**: el resultado se carga en el visor (con la holgura aplicada al ejecutar) y nunca se
  envía a la máquina desde el CAM.


## Barra superior


Siempre visible: estado de la máquina, puerto, perfil activo (se puede cambiar sin ir a «Calibración»), aviso de
discrepancias con la EEPROM, consola de comandos y accesos rápidos a `$X` (desbloquear) y soft reset.

La consola muestra el tráfico real (`→` enviado, `←` recibido) **sin** telemetría ni la ráfaga de `ok`, guarda 400
líneas con historial de comandos y permite enviar líneas sueltas: las que empiezan por `$` se aceptan siempre; el
resto exige `Idle`. El soft reset pide confirmación y se rechaza si hay un trabajo en curso («Detener» guarda el
progreso antes).

## Persistencia


Los perfiles, proyectos y archivos recientes viven en SQLite (drift). El esquema está en `lib/data/database/app_database.dart` y **el código generado se versiona**, así que un clon nuevo compila sin pasos extra:

```powershell
# solo si cambias tablas o consultas
dart run build_runner build --delete-conflicting-outputs
```

`ProjectRepository.persistAndConfirm()` guarda el punto de reanudación en disco y **solo después** confirma al worker; si la escritura falla, no se envía el soft reset y la máquina queda en `Hold` con la herramienta apagada.



## Convenciones

- Commits convencionales con etiqueta de sesión: `tipo(alcance): descripción [S-xx]`.
- `dart format .` y `flutter analyze` sin issues antes de cada commit.
- Código en inglés; documentación y UI en español.

