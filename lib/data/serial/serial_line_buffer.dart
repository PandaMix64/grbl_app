/// Reensambla las líneas que llegan por un puerto serie.
///
/// GRBL responde con `\r\n` y los datos pueden llegar partidos en varios
/// eventos del lector, así que cada transporte acumula el fragmento pendiente y
/// entrega solo las líneas completas, sin el terminador.
class SerialLineBuffer {
  final StringBuffer _pending = StringBuffer();

  /// Añade un fragmento de texto y devuelve las líneas ya completas.
  List<String> add(String chunk) {
    _pending.write(chunk);
    final String text = _pending.toString();
    final List<String> lines = <String>[];
    int start = 0;
    int newline = text.indexOf('\n');
    while (newline >= 0) {
      String line = text.substring(start, newline);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      if (line.isNotEmpty) {
        lines.add(line);
      }
      start = newline + 1;
      newline = text.indexOf('\n', start);
    }
    _pending
      ..clear()
      ..write(text.substring(start));
    return lines;
  }

  /// Descarta el fragmento incompleto (al cerrar o cambiar de puerto).
  void clear() => _pending.clear();
}
