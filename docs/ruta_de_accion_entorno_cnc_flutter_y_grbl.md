<!--
  COPIA DE TRABAJO — Documento original del autor, importado sin modificar.
  Origen: C:\Users\Panda\Downloads\ruta_de_accion_entorno_cnc_flutter_y_grbl.md
  Importado: 2026-11-24 (sesión S-01)
  No editar este archivo para aplicar correcciones: los ajustes viven en
  docs/revision_tecnica_ruta_de_accion.md (§7 "Parches concretos").
-->

# Ruta de Acción: Entorno de Trabajo CNC en Flutter para GRBL v1.1h

**Arquitectura de Software e Ingeniería de Sistemas**  
Noviembre 2026

---

## Resumen

Este documento establece la ruta de acción técnica para desarrollar una aplicación multiplataforma enfocada en escritorio utilizando Flutter y Material Design 3, orientada al control y generación de trayectorias para máquinas CNC controladas por firmware GRBL v1.1h en Arduino mediante comunicación serial. Se abordan los retos críticos de concurrencia, latencia de búfer serial, persistencia segura del estado de máquina y procesamiento geométrico/CAM.

---

## 1. Arquitectura de Software y Stack Tecnológico

Para garantizar estabilidad operativa, fluidez gráfica y mantenibilidad a largo plazo, la aplicación se estructurará bajo Clean Architecture combinada con el patrón reactivo MVVM / MVI. La lógica de hardware y los cálculos pesados se aislarán por completo del hilo principal de interfaz de usuario mediante Dart Isolates.

| Capa / Componente | Tecnología | Justificación Técnica |
| :--- | :--- | :--- |
| **UI y Diseño** | Flutter + Material Design 3 | Uso de `NavigationRail` en escritorio y `NavigationBar` en móvil. Soporte de atajos de teclado para jogging manual y tema oscuro de alto contraste. |
| **Gestión de Estado** | Riverpod (o BLOC) | Propagación reactiva y granular de telemetría de alta frecuencia (posición en tiempo real) sin reconstrucciones innecesarias de la interfaz. |
| **Concurrencia** | Dart Isolates | Aislamiento del Worker Serial GRBL y del Motor CAM para mantener una tasa de refresco estable en la vista 3D. |
| **Puerto Serial** | `flutter_libserialport` + Abstracción | Acceso nativo en escritorio (Windows, Linux, macOS) detrás de una interfaz `SerialPortRepository` extensible a adaptadores USB-OTG en Android. |
| **Motor 3D** | `CustomPainter` + `vector_math` | Proyección matricial 3D-a-2D con ordenamiento por profundidad y renderizado por lotes de segmentos `G0`/`G1`. |
| **Persistencia** | Drift (SQLite) + Archivos `.cncproj` | Base de datos local para perfiles de máquina e historial; contenedores portables para proyectos con G-code y punto de reanudación. |

*Cuadro 1: Arquitectura por capas y selección tecnológica*

---

## 2. Núcleo de Comunicación: Protocolo GRBL v1.1h

El controlador GRBL sobre microcontroladores tipo ATmega328P cuenta con un búfer de recepción serial limitado a 128 bytes. Para evitar saturaciones o pausas indeseadas durante trayectorias complejas, el Isolate serial debe implementar dos mecanismos fundamentales:

* **Streaming por Conteo de Caracteres (Character-Counting):** En lugar de esperar una confirmación `ok` por cada línea enviada, el worker calcula los bytes ocupados en tránsito dentro del búfer de 128 bytes del Arduino y transmite nuevas líneas conforme se liberan bytes, manteniendo abastecido el planificador de movimientos (*look-ahead planner*).
* **Inyección de Comandos en Tiempo Real:** Las órdenes de control inmediato se envían como bytes directos sin salto de línea (`\n`) para ejecutarse de forma prioritaria:
  * `?` **(consulta periódica):** Solicita el reporte de estado, coordenadas de máquina/trabajo (`MPos`/`WPos`) y velocidad/potencia (`FS`).
  * `!` **(Feed Hold):** Pausa el avance con desaceleración controlada sin pérdida de pasos.
  * `~` **(Cycle Start):** Reanuda la ejecución suspendida.
  * `0x18` **(Ctrl-X):** Reinicio suave (*Soft Reset*) del controlador GRBL.

---

## 3. Diseño Detallado por Módulos

### 3.1 Pantalla Principal (Home)

El punto de entrada de la aplicación centraliza la operación diaria y la gestión documental:

* **Barra Superior de Conexión y Perfil:** Selección de puerto serial, velocidad fija de 115200 baudios, selector del perfil de CNC activo e indicador visual de estado (`Idle`, `Run`, `Hold`, `Alarm`, `Disconnected`).
* **Accesos a Módulos:** Tarjetas en Material Design 3 para acceder al Visor de Proyectos, al Módulo Generativo de G-Code y al Módulo de Calibración.
* **Historial de Proyectos:** Listado de proyectos recientes con vista previa, perfil asociado, fecha y estado de ejecución (listo, pausado en una línea específica o completado).

### 3.2 Módulo de Calibración y Perfiles de Máquina

Este módulo administra dos niveles de configuración: los parámetros almacenados en la EEPROM de GRBL (`$x=valor`) y los atributos específicos de la aplicación guardados en el perfil local de cada CNC.

* **Control Manual (Jogging):** Desplazamiento eje por eje mediante comandos `$J=` y cancelación inmediata al liberar el control.
* **Calibración de Pasos por Milímetro (`$100`, `$101`, `$102`):** Tras ordenar un avance teórico de $10\text{ mm}$ y medir el desplazamiento real ($d_{real}$) obtenido en la máquina, el sistema calcula y actualiza el valor correspondiente:

$$\text{Pasos/mm}_{\text{nuevo}} = \text{Pasos/mm}_{\text{actual}} \times \frac{10}{d_{real}} \quad (1)$$

* **Velocidades, Aceleración y Tamaño de Cama:** Gestión de parámetros de velocidad máxima (`$110`–`$112`), aceleración (`$120`–`$122`) y dimensiones máximas de trabajo (`$130`–`$132`), junto con rutinas de Homing (`$H`) y definición del origen de trabajo.
* **Compensación de Holgura (Backlash):** Dado que GRBL v1.1h estándar no compensa holguras mecánicas en firmware, el módulo guía al usuario en una prueba de inversión de sentido (por ejemplo, avanzar y retroceder $5\text{ mm}$) para medir la holgura ($\Delta_{holgura}$) en cada eje y guardarla en el perfil local. Antes de ejecutar o exportar una tarea, un post-procesador inyecta la compensación al cambiar de sentido y reajusta la coordenada lógica (`G92`) para preservar las dimensiones reales de la pieza.

### 3.3 Visor de Proyectos y Ejecución 3D

Permite preparar, simular, supervisar y persistir tareas de CNC según el perfil seleccionado:

* **Modalidades de Tarea:** Configuración específica para plotting/dibujado (elevación de herramienta o servo), grabado láser (modulación de potencia) y fresado de madera (velocidad de husillo, profundidad de pasada y altura segura).
* **Visualización 3D en Tiempo Real:** Representa el volumen de trabajo según las dimensiones del perfil activo, distinguiendo trayectorias rápidas en vacío, rutas pendientes y segmentos ya ejecutados sincronizados con la telemetría del controlador.
* **Exportación de G-Code y Proyecto:** Permite guardar el G-code resultante y el estado completo del proyecto en un archivo portable.
* **Pausa, Detención con Alerta y Reanudación Segura:** Ante acciones de pausar o detener, se muestra una advertencia explícita sobre los riesgos asociados al movimiento o activación de la herramienta/láser. El progreso queda guardado en el archivo de proyecto (índice de línea, coordenadas de trabajo, modalidad de movimiento, avance, estado de herramienta y perfil) para permitir reanudar o reiniciar en cualquier momento mediante una secuencia segura (elevar eje Z a altura segura, posicionar en plano XY, reactivar herramienta con margen de estabilización y descender a cota de trabajo).

### 3.4 Módulo Generativo de G-Code (CAM)

Si el usuario carga un archivo `.gcode`, el flujo avanza directamente al Visor de Proyectos. Si se carga una imagen, un Isolate procesa la entrada según tres estilos:

* **Detección de Bordes y Vectorización (Corte, Fresado, Trazado):** Conversión a escala de grises, suavizado, detección de bordes, adelgazamiento de trazos y simplificación poligonal para generar movimientos `G0` y `G1`.
* **Umbrales y Semitonos / Dithering (Grabado Láser):** Aplicación de umbrales o difusión de error (*dithering*) para generar barridos con modulación de potencia y márgenes de aceleración.
* **Mapa de Altitud / Relieve 2.5D-3D (Tallado):** Mapeo de intensidades de píxel a cotas de profundidad Z, cálculo de trayectorias con paso lateral (*stepover*) y opción de pasadas de desbaste y acabado.

---

## 4. Hoja de Ruta de Implementación por Fases

| Fase | Objetivo | Entregables y Criterios de Validación |
| :--- | :--- | :--- |
| **Fase 1: Núcleo y Serial** | Base arquitectónica y enlace con GRBL. | Estructura Clean Architecture, esquema SQLite, navegación Material 3 e Isolate serial con *character-counting* y lectura de posición. |
| **Fase 2: Calibración** | Control de ejes y perfiles de máquina. | Jogging manual, cálculo de pasos/mm, lectura/escritura de parámetros GRBL, persistencia de perfiles y compensación de *backlash*. |
| **Fase 3: Visor 3D** | Simulación, control de flujo y persistencia. | Renderizador 3D, interpretación de G-code, alertas de pausa/detención, guardado de progreso en archivo y secuencia de reanudación segura. |
| **Fase 4: Generador CAM** | Transformación de imágenes a G-code. | Isolate de procesamiento con vectorización, *dithering*/umbrales y relieve 2.5D con previsualización antes del envío. |
| **Fase 5: Optimización y Empaquetado** | Rendimiento y despliegue multiplataforma. | Pruebas con archivos extensos de G-code, atajos de escritorio y empaquetado para Windows, Linux, macOS y Android. |

*Cuadro 2: Planificación iterativa de desarrollo*