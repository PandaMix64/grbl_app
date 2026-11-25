# grbl_app

Aplicación de escritorio (y Android) para **controlar máquinas CNC con firmware GRBL v1.1h**, generar trayectorias (CAM) desde imágenes o G-code y supervisarlas en un visor 3D.

Flutter + Material Design 3, Clean Architecture con gestión de estado reactiva, y comunicación serial y procesamiento CAM aislados en Dart Isolates para no bloquear la interfaz.

> ⚠️ **Aviso de seguridad.** Esta aplicación controla maquinaria real: husillos, láseres y motores paso a paso. Una secuencia incorrecta puede causar daños materiales, quemaduras o incendio. Antes de conectar una máquina, lee `docs/revision_tecnica_ruta_de_accion.md` (§3, hallazgos P0). El documento `docs/seguridad_operativa.md` está pendiente de redacción (ver `ESTADO_PROYECTO.md` §8).

## Estado del proyecto

| Fase | Estado |
| :--- | :--- |
| Fase 0 — Fundaciones | 🟢 Casi cerrada (M0.1–M0.3 entregados) |
| Fase 1 — Núcleo y Serial | 🟡 En curso (navegación y capa serial listas; falta la implementación FFI) |
| Fase 2 — Calibración | ⬜ Pendiente |
| Fase 3 — Visor 3D | ⬜ Pendiente |
| Fase 4 — Generador CAM | ⬜ Pendiente |
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
  app/          # GrblApp y HomeShell (NavigationRail / NavigationBar adaptativo)
  core/grbl/    # constantes de protocolo (bytes en tiempo real, búfer, baudios)
  core/widgets/ # widgets compartidos
  domain/       # entidades puras y contrato SerialPortRepository
  data/serial/  # control de flujo por conteo de caracteres y servicio GRBL
  features/     # home, calibration, viewer, cam
test/
  domain/       # parseo de telemetría, settings, perfiles, proyectos
  serial/       # presupuesto de 128 B y secuencias de seguridad
  helpers/      # FakeSerialPort: emulador GRBL de pruebas
```

## Convenciones

- Commits convencionales con etiqueta de sesión: `tipo(alcance): descripción [S-xx]`.
- `dart format .` y `flutter analyze` sin issues antes de cada commit.
- Código en inglés; documentación y UI en español.

