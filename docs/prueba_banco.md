# Prueba en banco con hardware real (R-10)

> Objetivo: validar el camino FFI + handshake + ejecución contra un Arduino con GRBL v1.1h **sin
> herramienta montada** y con la máquina en el aire. Cada bloque debe pasar antes de continuar con el
> siguiente.

## 0. Preparación (10 min)

1. Arduino UNO + CNC Shield (o placa equivalente) con GRBL **1.1h** flasheado y drivers alimentados.
2. **Sin fresa/láser**: el eje Z libre o desmontado; si hay láser, gafas y área despejada.
3. Puertos de los drivers sin motores conectados en la primera pasada (solo USB + placa).
4. Windows con drivers CH340/FTDI instalados; cerrar cualquier otro programa que abra el puerto.
5. Build de escritorio:

```powershell
flutter run -d windows
```

Anota en `docs/prueba_banco_resultados.md` (crear al terminar) la versión de GRBL, la placa y cada
resultado.

## 1. Conexión y handshake (M1.1)

| Paso | Acción | Esperado |
| :--- | :--- | :--- |
| 1.1 | Pulsar el icono de refresco de puertos | Aparece `COMx` del Arduino |
| 1.2 | Seleccionar el puerto y «Conectar» | Estado `Idle`, versión y búfer real en la barra |
| 1.3 | Revisar el log de mensajes | `[VER:1.1h…]` y `[OPT:…,bloques,bytes]` leídos; sin errores |
| 1.4 | Verificar que el tamaño de búfer mostrado coincide con `$I` | Mismo número de bytes |

**Si falla:** no continúes. Captura el error exacto y revisa que ningún otro programa tenga el puerto.

## 2. Parámetros y perfil (M2.1)

| Paso | Acción | Esperado |
| :--- | :--- | :--- |
| 2.1 | Abrir «Calibración → Parámetros de GRBL» | Tabla con `$$` real, sin escribir nada |
| 2.2 | Cambiar un único valor inocuo (`$110` por ejemplo) y guardar | Solo ese `$` se envía; mensaje «Parámetros escritos: 1» |
| 2.3 | Crear un perfil con el volumen real y **aplicarlo** | Solo se escriben los parámetros que difieren |
| 2.4 | Reconectar | El perfil coincide con la EEPROM (sin aviso de inconsistencia) |

## 3. Jog y pasos/mm (M2.1)

| Paso | Acción | Esperado |
| :--- | :--- | :--- |
| 3.1 | Jog X+ 10 mm con F500 | Movimiento suave, vuelve a `Idle` |
| 3.2 | Jog durante un `Hold` forzado | La app rechaza el jog y lo explica |
| 3.3 | Calibrar pasos/mm con 50 mm ordenados | Medición, corrección calculada y aplicada |
| 3.4 | Repetir la medición | Error dentro de la tolerancia del perfil |

## 4. Holgura, homing y origen (M2.2)

| Paso | Acción | Esperado |
| :--- | :--- | :--- |
| 4.1 | Prueba de holgura guiada | Ida y vuelta medida; valor guardado en el perfil |
| 4.2 | `$H` desde «Origen» | Ciclo de homing completo y vuelta a `Idle` |
| 4.3 | Fijar cero de trabajo (`G10 L20 P1`) | `WPos` a cero en los ejes elegidos; sin `G92` en el log |
| 4.4 | Reconectar y leer `$#` | `G54` conserva el cero fijado |

## 5. Visor y ejecución (M3.1 + M3.2)

Usa un programa **sin herramienta** y con recorridos cortos:

```gcode
G21
G90
G1 Z5 F300
G1 X0 Y0 F800
G1 X30 F800
G1 Y30
G1 X0
G1 Y0
G1 Z0
```

| Paso | Acción | Esperado |
| :--- | :--- | :--- |
| 5.1 | Cargar el archivo en el visor | Trayectoria dibujada, sin avisos inesperados |
| 5.2 | «Ejecutar» con el perfil de holgura ≠ 0 | Diálogo de confirmación; mensaje con «N compensaciones» |
| 5.3 | Observar el progreso | La línea avanza con el movimiento real; la parte ejecutada cambia de color |
| 5.4 | «Pausa» a mitad | `Hold`, herramienta apagada, «Progreso guardado en la línea N» |
| 5.5 | Comprobar SQLite (o el panel) | Proyecto en estado `paused` con línea, `$G`, `$#` y posición |
| 5.6 | «Reanudar» | Continúa desde donde quedó, **sin repetir** el tramo ya hecho |
| 5.7 | Repetir 5.2 y pulsar «Detener» | Confirmación con consecuencias; `0x18`, estado `Alarm`, progreso guardado |

**Criterios de aborto inmediato:** la herramienta no se apaga en `Hold`, el movimiento continúa tras
`!`, aparecen líneas duplicadas al reanudar o el estado de la UI no coincide con la máquina. En ese
caso: paro de emergencia físico, cerrar la app y anotar la secuencia exacta.

> **Estado de la última pasada (2026-11-24):** 5.1–5.5 correctos. 5.6 y 5.7 quedan pendientes, igual
> que §6–§9.

## 6. Divergencia de reanudación (SEG-05)

1. Ejecutar y pausar.
2. Con la app en pausa, cambiar el cero de trabajo desde otra vía (`G10 L20 P1` por consola o la UI de
   origen) o enviar `G55`.
3. Pulsar «Reanudar».

**Esperado:** la app se niega, explica si cambió el estado modal o los offsets y **no** envía `~`.

## 7. Pruebas de robustez

| Caso | Acción | Esperado |
| :--- | :--- | :--- |
| 7.1 | Desconectar el USB en `Hold` | La app deja de enviar y muestra el error; la máquina queda en `Hold` |
| 7.2 | Desconectar el USB durante `Run` | Sin más bytes; al reconectar hace falta handshake (R-19 abierto) |
| 7.3 | Programa con línea de más de 120 caracteres | Se rechaza antes de enviar con el número de línea |
| 7.4 | Archivo de 20 000 líneas | Se envía sin desbordar el búfer (sin `error:`) y el progreso se mantiene fluido |

## 9. Barra superior, consola y desconexión (S-09)

| Paso | Acción | Esperado |
| :--- | :--- | :--- |
| 9.1 | Desconectar desde Inicio y volver a conectar | **Sin cierre de la app** ni diálogo del CRT; el puerto queda libre |
| 9.2 | Abrir la consola y enviar `$$` | Lista de parámetros en la consola (`← $...`), sin telemetría intercalada |
| 9.3 | Enviar `?` | La respuesta `<...>` **no** aparece (filtrada); el estado de la barra sí se actualiza |
| 9.4 | Provocar una alarma (mover contra el tope con soft limits) y pulsar «Desbloquear» | Confirmación, `$X`, estado `Idle`; el origen sigue sin definir |
| 9.5 | Con la máquina en `Run`, escribir `G0 X10` en la consola | Se rechaza con el aviso de Idle y no se envía nada |
| 9.6 | Pulsar «Soft reset» sin trabajo | Confirmación, `0x18`, banner en la consola y estado `Alarm`/`Idle` |
| 9.7 | Con un trabajo en curso, pulsar «Soft reset» | Se rechaza y remite a «Detener» (no se pierde el progreso) |
| 9.8 | Refrescar `$$` con el perfil desactualizado | Aparece el icono de aviso en la barra con el detalle al pasar el ratón |
| 9.9 | Cambiar de perfil desde la barra | El aviso se recalcula al instante |

---

## 11. Reiniciar un trabajo guardado (S-11)

Requisitos previos: máquina encendida y conectada, **homing hecho**, misma pieza y mismo cero de trabajo,
herramienta montada.

| Paso | Acción | Esperado |
| :--- | :--- | :--- |
| 11.1 | Pausar un trabajo, desconectar el USB y volver a conectar | El visor muestra «Interrumpido» y el proyecto queda como `interrupted`; el punto de reanudación sigue ahí |
| 11.2 | Pulsar «Reanudar trabajo guardado» | Diálogo con nombre, línea y punto guardado; al aceptar, verifica `$G`/`$#` |
| 11.3 | Con la máquina lejos del punto guardado | Se niega e indica la distancia; usa «Llevar al punto guardado» |
| 11.4 | «Llevar al punto guardado» | Movimiento `$J=` hasta el punto y vuelta a `Idle` |
| 11.5 | Reanudar tras colocarla | Envía **desde** la línea confirmada: no debe repetir el tramo previo ni saltarse ninguno |
| 11.6 | Cambiar el cero de trabajo (`G10 L20 P1`) y reanudar | Se niega por offsets distintos |

---

## 12. CAM: grabado láser (S-12)

**Solo con láser y gafas de protección.** Usa material de prueba (cartón o madera blanda) y potencia baja.

| Paso | Acción | Esperado |
| :--- | :--- | :--- |
| 12.1 | Crear/seleccionar un perfil con herramienta **láser** | «Valores del perfil» rellena potencia, avance y ancho |
| 12.2 | Cargar una imagen pequeña (≤ 50 mm) en modo Umbral | Resumen: tamaño, celdas, líneas y % grabado, y **vista previa del resultado** sobre fondo claro |
| 12.3 | «Enviar al visor» | El visor dibuja el trazo y el archivo se llama `<imagen>_grabado.gcode` |
| 12.4 | Ejecutar con potencia baja | El haz solo se enciende en las celdas oscuras y se apaga en los rápidos |
| 12.5 | Probar Tramado y Escala de grises | Patrón de puntos y potencia variable respectivamente |
| 12.6 | Cargar una imagen grande o un ancho mayor que el recorrido | Se rechaza con el motivo y no se genera nada |
| 12.7 | Intentar generar con un perfil de fresadora | Se rechaza: el grabado por potencia requiere láser (`M4`) |
| 12.8 | Cambiar a **Contorno** con herramienta husillo y crear un perfil de fresadora | La vista previa muestra los polígonos; el resumen indica vueltas, puntos y pasadas |
| 12.9 | Ejecutar el contorno con `cutZ` mayor que una pasada | Baja por niveles hasta la profundidad final y sube a `Z` segura entre vueltas |
| 12.10 | Añadir 2–3 pestañas y cortar en madera blanda | El perímetro queda sujeto por las pestañas; en láser esas zonas no se marcan |
| 12.11 | Cambiar a **Relieve** con un perfil de fresadora y una imagen en escala de grises | Vista previa del mapa de altura y resumen con niveles y % fresado |
| 12.12 | Fresar el relieve en un taco de madera blanda | Baja por niveles y pasadas hasta la profundidad de cada banda, subiendo a Z segura entre tramos |
| 12.13 | Intentar relieve con un perfil láser | Se rechaza con el motivo (requiere fresadora y Z) |

---

## 13. Trazado con plóter (S-16)

Con un rotulador montado: **sin herramienta de corte**, pero el rotulador debe tocar el papel con la altura de bajada
correcta.

| Paso | Acción | Esperado |
| :--- | :--- | :--- |
| 13.1 | Pestaña **Trazado** → «Elegir imagen» y «Valores del perfil» | Ancho y avances tomados del perfil |
| 13.2 | Modo **Rutas vectoriales**, simplificar 0.15 mm | Vista previa del contorno y resumen con número de trayectos |
| 13.2b | Subir «Suavizar» a 0.8 mm con una imagen de curvas (corazón) | Desaparece el zigzag de las diagonales y la punta sigue afilada |
| 13.3 | Ejecutar y observar los viajes | El rotulador sube entre trayectos y el orden minimiza los desplazamientos |
| 13.4 | Cambiar a **Bordado raster** con separación 2 mm y ángulo 45° | Relleno de líneas paralelas; zigzag entre líneas |
| 13.5 | Añadir puntada de 3 mm | El relleno se ve a trazos (efecto bordado) |
| 13.6 | Cambiar el rotulador a **eje Z** | Aparecen «Altura segura Z» (con el valor del perfil) y «Z de dibujo»; se emite `G1 Z…`/`G0 Z…` en lugar de `M3 S`/`M5` |
| 13.6b | Inspeccionar el G-code del visor | Antes de cada `G0 X… Y…` hay un `G0 Z<altura segura>`; la punta nunca viaja apoyada |
| 13.6c | Bajar «Altura segura Z» por debajo de la del perfil | La app avisa de que la punta puede arrastrar entre trayectos |
| 13.6d | Generar, ir al visor y volver a Trazado | El formulario conserva rotulador, modo, umbral y avances |
| 13.7 | Enviar al visor y ejecutar | Se revisa el dibujo antes de empezar; el archivo termina en `_trazado.gcode` |

---

## 14. Cierre

- Volcar los resultados en `ESTADO_PROYECTO.md` (sección de riesgos: R-10, R-13, R-19).
- Si todo pasa, cerrar R-10 y planificar el flujo «reiniciar trabajo guardado» (R-18).
