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

## 8. Cierre

- Volcar los resultados en `ESTADO_PROYECTO.md` (sección de riesgos: R-10, R-13, R-19).
- Si todo pasa, cerrar R-10 y planificar el flujo «reiniciar trabajo guardado» (R-18).
