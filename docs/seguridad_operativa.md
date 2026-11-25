# Seguridad operativa — secuencias de control de GRBL

> **Documento normativo.** Define las únicas secuencias autorizadas para pausar, cancelar, detener
> y reanudar una máquina GRBL v1.1h. Todo código que envíe bytes al controlador debe implementar
> exactamente estas secuencias a través de un único `SafetyController`.
>
> Origen: hallazgos **P0-1** y **P0-3** de `docs/revision_tecnica_ruta_de_accion.md`.

---

## 1. Principios no negociables

1. **Ningún widget envía bytes.** La UI emite intenciones (`pause`, `jogCancel`, `stop`, `resume`)
   al `SafetyController`; solo él conoce la secuencia.
2. **La herramienta se apaga antes de considerar una pausa terminada.** El estado `Hold` de GRBL no
   implica herramienta apagada.
3. **`0x18` (soft reset) no es un botón de pausa.** Es la última opción y siempre implica pérdida de
   posición y `ALARM:3`.
4. **Toda acción destructiva requiere confirmación explícita** (pulsación mantenida ≥ 800 ms o
   diálogo modal con el texto de consecuencia).
5. **Se verifica, no se asume.** Cada paso comprueba el estado real reportado por `?` antes de
   continuar; si el estado no es el esperado, se aborta la secuencia y se informa al usuario.

---

## 2. Referencia de bytes y comandos

| Comando | Byte / ASCII | Naturaleza | Respuesta |
| :--- | :--- | :--- | :--- |
| Status report | `?` | Tiempo real, sin `\n` | `<Estado\|MPos:...\|FS:...>` |
| Feed hold | `!` | Tiempo real | El estado pasa a `Hold` |
| Cycle start / resume | `~` | Tiempo real | El estado pasa a `Run` |
| Soft reset | `0x18` | Tiempo real | Banner `Grbl 1.1h ['$' for help]` |
| Safety door | `0x84` | Tiempo real | `Door` → `Hold` |
| Jog cancel | `0x85` | Tiempo real; **solo actúa en estado `Jog`** | Vuelve a `Idle` |
| Spindle stop toggle | `0x9E` | Tiempo real; **solo actúa en `Hold`** | Apaga/activa husillo |
| Husillo / potencia | `M3`/`M4`/`M5`, `S<n>` | Bloque G-code (requiere `\r`) | `ok` |
| Desbloqueo de alarma | `$X` | Comando `$` | `ok` |
| Estado del parser | `$G` | Comando `$` | `[G0 G54 G17 G21 ...]` |
| Offsets | `$#` | Comando `$` | `[G54:...]`, `[G92:...]`, `[TLO:...]` |

Regla de transporte: los comandos en tiempo real se envían como **un solo byte sin terminador**;
los bloques G-code y los comandos `$` se envían terminados en `\r` (carriage return, no CRLF).

---

## 3. Secuencia: Pausa (Feed Hold + apagado de herramienta)

**Precondición:** estado `Run` o `Jog`.
**Postcondición:** estado `Hold`, herramienta apagada, progreso persistido.

| Paso | Acción | Verificación | Timeout / fallo |
| :--- | :--- | :--- | :--- |
| 1 | Enviar `!` | Sondear `?` a 5 Hz | 2 s → reintentar `!` una vez |
| 2 | Esperar estado `Hold` | `<Hold:...>` recibido | 5 s → escalar a "Detener" |
| 3 | Enviar `0x9E` (spindle stop) | `<Hold:...>` con `FS` mostrando `S:0` | 1 s → enviar `M5` + `S0` como respaldo |
| 4 | Confirmar herramienta apagada | `S:0` en el reporte **y** verificación física del operario si es láser | Sin confirmación → bloquear "Reanudar" y mostrar alerta roja |
| 5 | Persistir estado | `.cncproj`: índice de línea, `$G`, `$#`, `MPos`, `WPos`, estado de herramienta, hora | Fallo de escritura → no permitir cerrar la app |
| 6 | Informar | Banner "Pausado en línea N — herramienta apagada" | — |

**Prohibiciones:** no enviar `M5` durante `Run` (GRBL lo encola y puede ejecutarse tarde), no usar
`0x18` como pausa y no cerrar la aplicación en `Hold` sin haber persistido el paso 5.

---

## 4. Secuencia: Cancelar jog

**Precondición:** estado `Jog` (el comando se ignora en cualquier otro estado; `serial.c` lo condiciona
a `sys.state & STATE_JOG`).
**Postcondición:** estado `Idle`, planner purgado, parser sin cambios.

| Paso | Acción | Verificación |
| :--- | :--- | :--- |
| 1 | Enviar `0x85` | — |
| 2 | Sondear `?` hasta recibir `<Idle:...>` | Hasta 1 s |
| 3 | Descartar la posición objetivo del jog | Refrescar el DRO con la posición real del reporte |

La cancelación **no** modifica el estado modal del parser (no hay que restaurar `G90`/`G21`) y la
posición final es un punto intermedio del recorrido: el DRO debe refrescarse desde el status report
y nunca desde el valor objetivo.

---

## 5. Secuencia: Detener el trabajo

**Precondición:** cualquier estado excepto `Disconnected`.
**Postcondición:** `Idle` o `Alarm`, trabajo marcado como interrumpido.

1. Ejecutar la **secuencia de pausa completa** (§3): herramienta apagada y estado persistido.
2. Mostrar diálogo con las tres consecuencias: se pierde la posición de máquina, el trabajo queda
   marcado como interrumpido y se requerirá re-homing o re-definir el origen.
3. Solo con confirmación explícita: enviar `0x18`.
4. Esperar el banner `Grbl 1.1h ['$' for help]` (hasta 3 s). Sin banner → reconectar.
5. Si el estado es `Alarm` (`ALARM:3` esperado), enviar `$X` para desbloquear y **no** mover.
6. Marcar el `.cncproj` como `interrupted` con el índice de línea alcanzado.

---

## 6. Secuencia: Reanudar tras pausa

**Precondición:** estado `Hold`, herramienta apagada, progreso persistido y posición verificada.
**Postcondición:** ejecución continua desde la línea guardada, sin salto geométrico.

1. Leer `$G` (estado modal) y `$#` (offsets) y compararlos con lo guardado. Si difieren, **no**
   reanudar: ofrecer "reiniciar desde el inicio con secuencia segura".
2. Si hay `Alarm`, enviar `$X`; sin homing no se reanuda.
3. Elevar Z a la altura segura del perfil (`G0 Z<safeZ>` explícito, en `G90`).
4. Posicionar XY en la coordenada de trabajo guardada, solo si está dentro del volumen del perfil.
5. Reactivar la herramienta con el mismo código y potencia (`M3`/`M4` + `S`) y **esperar la
   estabilización** (≥ 4 s o el valor del perfil).
6. Enviar `~` (cycle start) y verificar la transición a `Run`.
7. Reanudar el streaming desde el índice guardado, con el conteo de caracteres reiniciado.

**Nunca** reanudar con `~` sin reactivar la herramienta antes: GRBL restaura el estado previo del
husillo y aplica su propio retardo, pero la app no debe depender de esa red de seguridad.

---

## 7. Secuencia: Emergencia (paro físico)

El paro de emergencia **nunca** es un botón de software. La UI debe indicar:

1. Accionar el paro de emergencia físico (corta potencia a los drivers).
2. Cerrar la sesión sin guardar progreso: la posición es desconocida.
3. Al reanudar: re-homing obligatorio, re-definir origen y **descartar** el progreso anterior.

Si el perfil tiene encapsulado o puerta, exponer `0x84` (safety door): produce `Door`/`Hold` con
reanudación controlada y sin pérdida de posición.

---

## 8. Máquina de estados de la UI

```text
Disconnected ──conectar──▶ Idle ◀────────────────────┐
                            │                        │
                     ┌──────┴──────┐                 │
                     ▼             ▼                 │
                   Alarm        Running ──jog──▶  Jog
                     │             │                 │
                     │ $X + homing │ !               │ 0x85
                     └──────▶ Idle ▼                 ▼
                                 Hold ◀──────────  Idle
                                   │
                                   │ 0x9E → Hold (herramienta OFF)
                                   │
                                   │ ~ tras reactivar y esperar
                                   └──────▶ Running
```

Reglas:

- `Hold` con herramienta activa y sin confirmación posterior **no** es un estado válido de reposo:
  la UI lo marca en rojo y bloquea el cierre de la aplicación.
- `Alarm` deshabilita todo control de movimiento salvo `$X` y homing.
- `Jog` deshabilita el envío de G-code (GRBL devuelve error si se mezclan).

---

## 9. Criterios de aceptación (verificables en tests)

| ID | Criterio | Cubierto por |
| :--- | :--- | :--- |
| SEG-01 | Tras la secuencia de pausa, el último status report contiene `S:0` y el estado es `Hold` | `test/serial/grbl_serial_service_test.dart` → *la pausa apaga la herramienta (SEG-01)* |
| SEG-02 | El worker nunca envía `M5`/`S0` mientras el estado reportado sea `Run` | `GrblSerialService` solo usa `0x9E` (solo efectivo en `Hold`); no existe camino de código que envíe `M5` |
| SEG-03 | Ningún camino de código alcanza `0x18` sin persistencia previa del progreso | `stopJob` exige `persistProgress`; test *no se resetea sin persistir el progreso (SEG-03)* |
| SEG-04 | `0x85` se envía solo si el estado reportado es `Jog`; en otro caso se registra y se ignora | tests *cancelar jog se ignora fuera del estado Jog* y *cancelar jog en Jog envía 0x85* |
| SEG-05 | La reanudación falla de forma segura si `$G`/`$#` difieren de lo guardado | Parcial: `ParserState.isCompatibleWith` y `WorkOffsets.matches` existen y están probados; falta conectarlos al flujo de reanudación (Fase 3) |
| SEG-06 | El botón "Detener" exige confirmación y enumera las tres consecuencias del §5 | Pendiente: UI de la Fase 1 |

### 9.1 Criterios de flujo de datos

| ID | Criterio | Cubierto por |
| :--- | :--- | :--- |
| FLOW-01 | El presupuesto de 128 B nunca se desborda | `test/serial/character_counting_buffer_test.dart` (10 000 líneas) y `FakeSerialPort.overflowDetected` |
| FLOW-02 | Un `error:` libera espacio igual que un `ok` | tests de `CharacterCountingBuffer` y del servicio |
| FLOW-03 | Los comandos en tiempo real no consumen presupuesto | `GrblSerialService` los escribe con `writeRealtime`, fuera del `CharacterCountingBuffer` |
| FLOW-04 | El presupuesto usa el búfer **real** del firmware, no 128 B asumidos | `BuildInfo` desde `$I` + `CharacterCountingBuffer.resize`; tests *detecta un búfer de 256 B* y *no asume 128 B* |
| FLOW-05 | El banner inicial no se pierde | La suscripción al puerto se crea antes de abrirlo (test de handshake: `bannerReceived`) |
| FLOW-06 | Un `stop` no resetea sin confirmación de persistencia a través del isolate | `GrblWorker` emite `persistRequest` y espera `persistDone`; test *stop exige confirmar la persistencia* |
| SEG-07 | El jog solo se envía en `Idle` o `Jog`, siempre con `F` | `JogCommand.validate()` + guardia en `GrblSerialService.jog`; tests *rechaza el jog fuera de Idle/Jog* y *valida ejes y avance* |
| SEG-08 | La escritura en EEPROM envía solo los parámetros que cambian | `GrblSettings.diff` en `CalibrationController.applyDraft`; test *solo escribe los parámetros que cambian* |
| SEG-09 | Una calibración de pasos/mm se rechaza si la medida no es plausible | `StepsPerMmCalibration.validate()` (±50 %); test *rechaza medidas imposibles sin escribir* |


