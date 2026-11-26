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
| Fase 4 — Generador CAM | ✅ Cerrada (grabado, contornos y relieve) |
| Fase 5 — Optimización y empaquetado | 🟡 En curso (APK y release de Windows) |

El detalle de tareas, decisiones (ADR), riesgos y bitácora de cada sesión vive en **[`ESTADO_PROYECTO.md`](ESTADO_PROYECTO.md)**. Empieza por ahí si retomas el proyecto.

## Documentación

| Documento | Contenido |
| :--- | :--- |
| [`docs/ruta_de_accion_entorno_cnc_flutter_y_grbl.md`](docs/ruta_de_accion_entorno_cnc_flutter_y_grbl.md) | Plan original  (arquitectura, protocolo GRBL, módulos, fases) |
| [`docs/revision_tecnica_ruta_de_accion.md`](docs/revision_tecnica_ruta_de_accion.md) | Revisión contra la especificación oficial de GRBL v1.1h: hallazgos P0/P1/P2 y parches propuestos |
| [`ESTADO_PROYECTO.md`](ESTADO_PROYECTO.md) | Tablero de avance, ADR, riesgos y bitácora de sesiones |
| [`docs/empaquetado.md`](docs/empaquetado.md) | Build de Windows y APK de Android: requisitos, firma y limitaciones |

## Requisitos

- Flutter 3.50.1 / Dart 3.14.0 o superior (`channel stable`).
- Windows 10+, Linux o macOS con puerto USB; Android 8+ con USB-OTG (la serie
  usa el permiso USB del sistema, ver [Empaquetado](#empaquetado)).
- Controlador GRBL v1.1h a 115200 baudios, 8-N-1.

## Dependencias principales

| Paquete | Versión | Uso |
| :--- | :--- | :--- |
| `flutter_riverpod` | ^3.5.0 | Estado e inyección de dependencias (ADR-001) |
| `material_ui` | ^1.11.1 | Widgets Material 3 (reemplaza `package:flutter/material.dart`, deprecado) |
| `drift` / `drift_flutter` | ^2.35.4 / ^0.3.1 | Persistencia SQLite multiplataforma |
| `flutter_libserialport` | ^0.6.0 | Acceso serial nativo (FFI) en escritorio; parche local para Gradle 9 (ADR-046) |
| `usb_serial` | ^0.6.0 | Serie por USB-OTG en Android (permiso `UsbManager` + *bulk transfers*, ADR-048) |
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
- La **barra de ejecución** va superpuesta al lienzo (iconos, progreso fino y estado en una línea): el viewport ocupa todo
  el espacio disponible.
- **Simulador** (barra inferior, dentro del viewport): ⏮️ ⏯️ ⏭️ y **línea de tiempo arrastrable** con velocidad
  (0,25×–8×). El cabezal simulado recorre el programa al ritmo que marcan los avances del G-code, deja una estela de lo ya
  reproducido **sobre la propia trayectoria** (mismo lienzo y mismo origen) y muestra tiempo y línea; nunca habla con la
  máquina y se pausa solo si hay un trabajo real en marcha.
- **Capas conmutables**: cada barra tiene un ojo para apagar/encender su previsualización —avance ejecutado y cabezal real
  en la de ejecución; estela del simulador en la de reproducción— sin perder el progreso de ninguna de las dos.
- **Encuadre compartido**: la vista encuadra **junto** el programa y el volumen de trabajo (cama), así ambos comparten el
  mismo sistema de referencia; la trayectoria se proyecta una sola vez y se cachea, de modo que reproducir la simulación
  no bloquea la interfaz aunque el programa tenga decenas de miles de segmentos.
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

## Trazado (plóter)

Pestaña dedicada a **dibujar con rotulador**, con dos procesados de imagen:

- **Rutas vectoriales**: silueta vectorizada, simplificada y **ordenada por proximidad** para minimizar los viajes con
  el rotulador levantado. Ideal para line-art y contornos.
- **Suavizar (mm)**: elimina el diente de sierra de diagonales y curvas promediando vecinos y **conservando las esquinas**
  marcadas (0 = sin suavizar).
- **Bordado raster**: líneas paralelas que rellenan las zonas oscuras, con **separación, ángulo y puntadas**
  configurables; el zigzag entre líneas reduce los desplazamientos.
- **Rotulador** configurable: `M3 S…`/`M5` (servo en el husillo) o `G1 Z…`/`G0 Z…` (eje Z), con avances de dibujo y de
  viaje separados.
- **Altura segura**: con «Eje Z» la Z de viaje se propone desde la **altura segura del perfil** y el G-code eleva la
  punta (`G0 Z…`) **antes de cada desplazamiento en XY**; si se baja de esa altura, la app avisa de que la punta
  puede arrastrar. La bajada usa el avance de dibujo, no el rápido del viaje.
- Los parámetros del formulario **se conservan al cambiar de pestaña**: generar, revisar en el visor y volver ya no
  reinicia el rotulador ni el modo.
- Vista previa del dibujo, validación de volumen del perfil y **envío al visor** (nunca directo a la máquina).


## CAM


`CAM` convierte una **imagen** (PNG/JPG/BMP) en G-code, en dos modos:

**Grabado** (raster, láser `M4`)
- **Modos**: umbral (silueta), tramado Floyd–Steinberg (medios tonos) y escala de grises (potencia proporcional).
- **Parámetros**: ancho en mm (el alto sale por proporción), mm por celda, potencia `S` máxima y avance.

**Contorno** (corte de la silueta)
- Vectoriza la imagen (con islas y huecos), simplifica los polígonos (Douglas–Peucker) y genera el corte.
- **Láser**: una pasada con el haz conmutado; **husillo** (`M3`): pasadas en Z hasta la profundidad final.
- **Pestañas** de sujeción: suben la Z (o apagan el haz) en tramos repartidos por el perímetro.

**Relieve** (2.5D, fresadora)
- La imagen se cuantiza en niveles de profundidad (claro = sin fresar, oscuro = profundidad máxima).
- Cada nivel se fresa por bandas con pasadas hasta su cota: escalera de profundidad predecible.
- Vista previa del **mapa de altura**; requiere perfil de fresadora y que la profundidad quepa en su recorrido Z.

Común:
- La conversión corre en un **isolate** con topes de celdas/puntos; el grabado exige perfil láser y todo debe caber en el
  recorrido del perfil.
- **Previsualización obligatoria**: el resultado se carga en el visor (con la holgura aplicada al ejecutar) y nunca se
  envía a la máquina desde el CAM.
- **Vista previa en la propia pantalla**: mapa de potencia del grabado o los contornos que se van a cortar, sobre fondo
  claro, antes de enviar nada.


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



## Empaquetado

Los artefactos se compilan desde el repositorio; la guía completa (requisitos de
SDK, firma, limitaciones por plataforma) está en
[`docs/empaquetado.md`](docs/empaquetado.md).

```powershell
flutter build windows --release                 # build\windows\x64\runner\Release\
flutter build apk --release --split-per-abi     # ~19-22 MB por ABI
flutter build apk --release                     # universal, ~62 MB
```

El APK de Android incluye `libsqlite3.so` y `libserialport.so` por ABI y la
etiqueta visible es **GRBL CNC**. Mientras no exista `android/key.properties` se
firma con la clave de depuración.

**En Android la serie va por USB-OTG** (ADR-048): al pulsar «Conectar» el sistema
pide permiso para el dispositivo y la app habla con el chip por *bulk transfers*
(CDC-ACM, CH340, CP210x, FTDI, PL2303). Necesita un adaptador OTG que alimente la
placa; si el móvil no entrega corriente, usa un *hub* con alimentación. La misma
app sirve para preparar el trabajo (CAM, plóter, visor) sin máquina conectada.

La única dependencia `vendorizada` es `flutter_libserialport`
(`third_party/flutter_libserialport`, ver ADR-046): su build de Android no
funciona con Gradle 9 y se sustituyó por `build.gradle.kts`. Se activa con
`dependency_overrides` en `pubspec.yaml`.

## Convenciones

- Commits convencionales con etiqueta de sesión: `tipo(alcance): descripción [S-xx]`.
- `dart format .` y `flutter analyze` sin issues antes de cada commit.
- Código en inglés; documentación y UI en español.

