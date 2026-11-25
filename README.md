# grbl_app

Aplicación de escritorio (y Android) para **controlar máquinas CNC con firmware GRBL v1.1h**, generar trayectorias (CAM) desde imágenes o G-code y supervisarlas en un visor 3D.

Flutter + Material Design 3, Clean Architecture con gestión de estado reactiva, y comunicación serial y procesamiento CAM aislados en Dart Isolates para no bloquear la interfaz.

> ⚠️ **Aviso de seguridad.** Esta aplicación controla maquinaria real: husillos, láseres y motores paso a paso. Una secuencia incorrecta puede causar daños materiales, quemaduras o incendio. Antes de conectar una máquina, lee `docs/revision_tecnica_ruta_de_accion.md` (§3, hallazgos P0). El documento `docs/seguridad_operativa.md` está pendiente de redacción (ver `ESTADO_PROYECTO.md` §8).

## Estado del proyecto

| Fase | Estado |
| :--- | :--- |
| Fase 0 — Fundaciones | 🟡 En curso |
| Fase 1 — Núcleo y Serial | ⬜ Pendiente |
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

- Flutter 3.29.2 / Dart 3.7.2 o superior (ver `ESTADO_PROYECTO.md` §8 para la actualización pendiente).
- Windows 10+, Linux, macOS o Android 8+ con USB-OTG.
- Controlador GRBL v1.1h a 115200 baudios, 8-N-1.

## Puesta en marcha

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

## Estructura objetivo (Clean Architecture)

```text
lib/
  core/        # constantes, errores, tema, utilidades
  domain/      # entidades y contratos (repositorios)
  data/        # implementaciones: serial, base de datos, archivos
  features/    # home, calibration, viewer, cam
  main.dart
```

## Convenciones

- Commits convencionales con etiqueta de sesión: `tipo(alcance): descripción [S-xx]`.
- `dart format .` y `flutter analyze` sin issues antes de cada commit.
- Código en inglés; documentación y UI en español.

