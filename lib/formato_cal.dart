import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hdm_calculadora/button_values.dart';

// Esta es la pantalla principal (y única) de la calculadora de cotizaciones.
// La idea general: el usuario pasa por 4 pasos (pestañas), uno seguido del
// otro, y cada paso usa el resultado del paso anterior:
//   1) Precio original  ->  2) Marca (+ %)  ->  3) Descuento (- %)  ->  4) Cantidad (x N)
// Al final, con el botón FIN, todo se guarda en un historial.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  // Timer que se usa solo para ir borrando del historial lo que ya
  // cumplió 24 horas (no hay reloj visible en pantalla).
  late Timer _timer;

  // En qué pestaña está parado el usuario ahora mismo.
  // 0 = precio, 1 = marca, 2 = descuento, 3 = cantidad.
  int _tabIndex = 0;

  // ---------- pestaña 1: precio original (todo en dolares) ----------
  final _precioOriginalCtrl = TextEditingController();

  // caja de tipo de cambio: es solo informativa (una referencia para el
  // usuario), no participa en ninguna cuenta de la calculadora.
  final _tipoCambioCtrl = TextEditingController(text: '3.14');

  // ---------- pestaña 2: marca ----------
  String? _marcaSeleccionada; // CAT, CTP, HANDOK o IDP (se elige con el teclado)
  final _precioMarcaCtrl = TextEditingController(); // precio que llega de la pestaña 1
  final _marcaInputCtrl = TextEditingController(); // caja donde se escribe cada % antes de sumarlo
  final List<double> _porcentajesMarca = []; // los % que ya se fueron aplicando (máx. 2, salvo CAT)

  // ---------- pestaña 3: descuento ----------
  final _precioDescCtrl = TextEditingController(); // precio que llega de la pestaña 2
  final _descuentoInputCtrl = TextEditingController(); // caja donde se escribe el % antes de sumarlo
  final List<double> _descuentosAplicados = []; // descuentos ya agregados con el +

  // ---------- pestaña 4: cantidad ----------
  final _cantidadCtrl = TextEditingController(text: '1');

  // Estas 3 banderas sirven para no pisar lo que el usuario ya escribió a
  // mano. Mientras sean "false", la app puede seguir autocompletando el
  // campo por su cuenta; en cuanto el usuario toca algo, pasan a "true" y
  // la app deja de tocar ese campo.
  bool _precioMarcaManual = false;
  bool _precioDescManual = false;
  bool _cantidadManual = false; // ademas: si es false, el "1" de por defecto se borra apenas escribas

  // Cual caja de texto esta "activa" ahora mismo: el teclado de la app le
  // escribe a esta. Ya no hace falta tocar las cajas para elegirlas: cada
  // vez que cambiamos de pestaña, se elige sola (ver _autoenfocarPestana).
  // La unica excepcion es la caja de tipo de cambio, que es aparte del
  // flujo principal y por eso hay que tocarla para poder editarla.
  TextEditingController? _campoActivo;

  // Cada cotizacion que se cierra con FIN queda guardada aca, como un
  // Map con todos los datos de esa cuenta.
  final List<Map<String, dynamic>> _historial = [];

  @override
  void initState() {
    super.initState();
    // Apenas arranca la app, la pestaña 1 (precio) ya queda lista para
    // escribir, sin necesidad de tocarla primero.
    _campoActivo = _precioOriginalCtrl;

    // Cada minuto se revisa el historial y se borran las cotizaciones
    // que ya pasaron las 24 horas guardadas.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {
        _historial.removeWhere((item) => DateTime.now().difference(item['fecha'] as DateTime).inHours >= 24);
      });
    });
  }

  @override
  void dispose() {
    // Hay que liberar todos los controllers cuando la pantalla se cierra,
    // sino quedan ocupando memoria de mas.
    _timer.cancel();
    _precioOriginalCtrl.dispose();
    _cantidadCtrl.dispose();
    _tipoCambioCtrl.dispose();
    _precioMarcaCtrl.dispose();
    _marcaInputCtrl.dispose();
    _precioDescCtrl.dispose();
    _descuentoInputCtrl.dispose();
    super.dispose();
  }

  // Convierte lo que hay escrito en una caja a un numero de verdad. Si la
  // caja esta vacia o tiene algo raro, devuelve 0 en vez de romper la app.
  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  // La cantidad nunca puede ser 0 (no tendria sentido cotizar "0
  // unidades"), asi que si esta vacia se usa 1 por defecto.
  double get _cantidad {
    final c = _num(_cantidadCtrl);
    return c == 0 ? 1 : c;
  }

  // Aplica una lista de porcentajes uno atras del otro sobre un precio
  // base (encadenados: el segundo % se calcula sobre el resultado del
  // primero, no sobre el precio original). Se redondea al entero mas
  // cercano en cada paso. La usan tanto la marca como el descuento.
  double _aplicarCadena(double base, List<double> porcentajes, {required bool suma}) {
    double valor = base;
    for (final p in porcentajes) {
      valor = suma ? valor + valor * (p / 100) : valor - valor * (p / 100);
      valor = valor.roundToDouble();
    }
    return valor;
  }

  // Resultado final de la pestaña de marca. CAT es un caso especial: su
  // 18% se aplica directo, una sola vez. Las demas marcas usan los
  // porcentajes que se fueron agregando con el +, en cadena.
  double get _precioConMarca {
    final precio = _num(_precioMarcaCtrl);
    if (_marcaSeleccionada == 'CAT') {
      return (precio + precio * 0.18).roundToDouble();
    }
    return _aplicarCadena(precio, _porcentajesMarca, suma: true);
  }

  // Resultado final de la pestaña de descuento: se van restando, en
  // cadena, todos los % que el usuario fue agregando con el +.
  double get _precioFinal => _aplicarCadena(_num(_precioDescCtrl), _descuentosAplicados, suma: false);

  // Paso 4, el ultimo: el precio que ya tiene marca y descuento
  // aplicados, multiplicado por la cantidad.
  double get _totalFinal => (_precioFinal * _cantidad).roundToDouble();

  // Como ya no hay forma de "retroceder" entre pestañas (solo se avanza
  // con el check), _tabIndex nos dice justo hasta donde llego el
  // usuario. Sirve para saber que numero mostrar si aprieta FIN sin
  // pasar por todas las pestañas (por ejemplo, si solo queria el precio
  // con marca y no le importa el descuento ni la cantidad).
  double get _montoFinal {
    switch (_tabIndex) {
      case 3:
        return _totalFinal;
      case 2:
        return _precioFinal;
      case 1:
        return _precioConMarca;
      default:
        return _num(_precioOriginalCtrl);
    }
  }

  // Copia el resultado de una pestaña al campo de precio de la
  // siguiente, para que el usuario no tenga que volver a tipearlo. Si ya
  // lo edito a mano, no lo pisa (por eso el chequeo de las banderas
  // "manual").
  void _recalcularCascada() {
    if (!_precioMarcaManual) {
      _precioMarcaCtrl.text = _num(_precioOriginalCtrl).toStringAsFixed(0);
    }
    if (!_precioDescManual) {
      _precioDescCtrl.text = _precioConMarca.toStringAsFixed(0);
    }
  }

  // Decide que caja de texto queda "activa" (lista para escribir) apenas
  // se entra a cada pestaña, para no tener que tocarla primero.
  void _autoenfocarPestana() {
    switch (_tabIndex) {
      case 0:
        _campoActivo = _precioOriginalCtrl;
        break;
      case 1:
        // si todavia no eligio marca, o eligio CAT (que no tiene campo
        // para escribir, su % es fijo), no hay nada que enfocar
        _campoActivo = (_marcaSeleccionada == null || _marcaSeleccionada == 'CAT') ? null : _marcaInputCtrl;
        break;
      case 2:
        _campoActivo = _descuentoInputCtrl;
        break;
      case 3:
        _campoActivo = _cantidadCtrl;
        break;
    }
  }

  // El texto que va arriba de la tarjeta blanca, cambia segun la pestaña.
  String get _tituloPestana {
    switch (_tabIndex) {
      case 1:
        return 'Aplicar % de marca';
      case 2:
        return 'Descuento';
      case 3:
        return 'Cantidad';
      default:
        return 'Precio';
    }
  }

  // Que widget (panel) se dibuja adentro de la tarjeta, segun la pestaña.
  Widget get _panelActual {
    switch (_tabIndex) {
      case 1:
        return _panelMarca();
      case 2:
        return _panelDescuento();
      case 3:
        return _panelCantidad();
      default:
        return _panelPrecio();
    }
  }

  // Escribe el numero que se toco en el teclado, en la caja activa.
  void _escribir(String valor) {
    if (_campoActivo == null) return;
    setState(() {
      if (_campoActivo == _cantidadCtrl && !_cantidadManual) {
        _campoActivo!.text = valor; // el primer toque reemplaza el "1" por defecto
        _cantidadManual = true;
      } else {
        _campoActivo!.text += valor; // los demas toques se van agregando al final
      }
      if (_campoActivo == _precioMarcaCtrl) _precioMarcaManual = true;
      if (_campoActivo == _precioDescCtrl) _precioDescManual = true;
      _recalcularCascada();
    });
  }

  // Borra el ultimo caracter de la caja activa (el boton naranja con el
  // icono de flecha).
  void _borrar() {
    if (_campoActivo == null) return;
    final texto = _campoActivo!.text;
    if (texto.isEmpty) return;
    setState(() {
      _campoActivo!.text = texto.substring(0, texto.length - 1);
      if (_campoActivo == _precioMarcaCtrl) _precioMarcaManual = true;
      if (_campoActivo == _precioDescCtrl) _precioDescManual = true;
      _recalcularCascada();
    });
  }

  // Toma el numero que esta escrito en la caja de marca, lo agrega a la
  // lista de porcentajes (maximo 2, porque asi es la regla del negocio
  // para CTP/HANDOK/IDP) y limpia la caja para poder escribir el
  // siguiente sin tener que tocar nada.
  void _agregarPorcentajeMarca() {
    if (_marcaSeleccionada == null || _marcaSeleccionada == 'CAT') return;
    if (_porcentajesMarca.length >= 2) return;
    final valor = _num(_marcaInputCtrl);
    if (valor <= 0) return;
    setState(() {
      _porcentajesMarca.add(valor);
      _marcaInputCtrl.clear();
      _precioMarcaManual = true;
      _recalcularCascada();
    });
  }

  // Quita el ultimo porcentaje de marca que se agrego.
  void _quitarPorcentajeMarca() {
    if (_porcentajesMarca.isEmpty) return;
    setState(() => _porcentajesMarca.removeLast());
  }

  // Igual que el de marca, pero para los descuentos (que no tienen limite
  // de cantidad, se puede agregar los que hagan falta).
  void _agregarDescuento() {
    final valor = _num(_descuentoInputCtrl);
    if (valor <= 0) return;
    setState(() {
      _descuentosAplicados.add(valor);
      _descuentoInputCtrl.clear();
      _precioDescManual = true;
      _recalcularCascada();
    });
  }

  // Quita el ultimo descuento que se agrego.
  void _quitarDescuento() {
    if (_descuentosAplicados.isEmpty) return;
    setState(() => _descuentosAplicados.removeLast());
  }

  // Vuelve toda la pantalla al estado inicial, para empezar una
  // cotizacion nueva desde cero (boton RES).
  void _resetear() {
    setState(() {
      _precioOriginalCtrl.clear();
      _cantidadCtrl.text = '1';
      _cantidadManual = false;
      _marcaSeleccionada = null;
      _precioMarcaCtrl.clear();
      _marcaInputCtrl.clear();
      _porcentajesMarca.clear();
      _precioDescCtrl.clear();
      _descuentoInputCtrl.clear();
      _descuentosAplicados.clear();
      _tabIndex = 0;
      _precioMarcaManual = false;
      _precioDescManual = false;
      _autoenfocarPestana();
    });
  }

  // El check (✓): avisa con un mensajito que se guardaron los datos de
  // esta pestaña, y pasa solo a la siguiente (si no es la ultima).
  void _confirmarPestana() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Guardado: $_tituloPestana'),
        duration: const Duration(milliseconds: 700),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    if (_tabIndex < 3) {
      setState(() {
        _tabIndex++;
        _recalcularCascada();
        _autoenfocarPestana();
      });
    }
  }

  // El FIN: junta todos los datos de la cotizacion actual (hasta donde
  // haya llegado el usuario) y los guarda como una ficha nueva en el
  // historial. Despues limpia la pantalla para la siguiente cotizacion.
  void _guardarEnHistorial() {
    // Como no hay vuelta atras entre pestañas, _tabIndex nos dice
    // exactamente hasta donde llego el usuario esta vez.
    final huboMarca = _tabIndex >= 1 && _marcaSeleccionada != null;
    final huboDescuento = _tabIndex >= 2;
    final huboCantidad = _tabIndex >= 3;
    final esCat = _marcaSeleccionada == 'CAT';
    setState(() {
      _historial.add({
        'fecha': DateTime.now(),
        'precioOriginal': _num(_precioOriginalCtrl),
        'marca': huboMarca ? _marcaSeleccionada : null,
        'esCat': huboMarca ? esCat : null,
        'precioAntesMarca': huboMarca ? _num(_precioMarcaCtrl) : null,
        'porcentajesMarca': huboMarca ? (esCat ? <double>[18.0] : List<double>.from(_porcentajesMarca)) : <double>[],
        'precioConMarca': huboMarca ? _precioConMarca : null,
        'precioAntesDescuento': huboDescuento ? _num(_precioDescCtrl) : null,
        'descuentos': huboDescuento ? List<double>.from(_descuentosAplicados) : <double>[],
        'precioTrasDescuento': huboDescuento ? _precioFinal : null,
        'cantidad': huboCantidad ? _cantidad : null,
        'totalConCantidad': huboCantidad ? _totalFinal : null,
        'precioFinal': _montoFinal,
      });
    });
    _resetear();
  }

  // Abre el panel de abajo (bottom sheet) con la lista del historial.
  void _mostrarHistorial() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF232323),
      isScrollControlled: true,
      builder: (_) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: _cuerpoHistorial(),
        );
      },
    );
  }

  // Arma el texto de una "cadena" de porcentajes para mostrar en el
  // historial, tipo "$100 +10% = $110  →  +15% = $127". Sirve tanto para
  // la marca (suma) como para el descuento (resta).
  String _textoCadena(double base, List<double> porcentajes, {required bool suma}) {
    final partes = <String>['\$ ${base.toStringAsFixed(0)}'];
    double valor = base;
    for (final p in porcentajes) {
      valor = suma ? valor + valor * (p / 100) : valor - valor * (p / 100);
      valor = valor.roundToDouble();
      final signo = suma ? '+' : '-';
      partes.add('$signo${p.toStringAsFixed(0)}% = \$ ${valor.toStringAsFixed(0)}');
    }
    return partes.join('   →   ');
  }

  // Arma la lista de tarjetas del historial: una por cada cotizacion
  // guardada, mostrando la cuenta completa tal cual se hizo.
  Widget _cuerpoHistorial() {
    if (_historial.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Todavía no hay cotizaciones guardadas', style: TextStyle(color: Colors.white70)),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _historial.length,
      itemBuilder: (_, i) {
        final item = _historial[_historial.length - 1 - i]; // el mas nuevo arriba
        final fecha = item['fecha'] as DateTime;
        final fechaTexto = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}  '
            '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

        // lee un numero del historial sin importar si quedo guardado
        // como int o double, asi nunca truena el cast
        double num_(String key) => (item[key] as num?)?.toDouble() ?? 0;

        final precioOriginal = num_('precioOriginal').toStringAsFixed(0);
        final marca = item['marca'] as String?;
        final porcentajesMarca = ((item['porcentajesMarca'] as List?) ?? []).map((d) => (d as num).toDouble()).toList();
        final descuentos = ((item['descuentos'] as List?) ?? []).map((d) => (d as num).toDouble()).toList();
        final huboCantidad = item['cantidad'] != null;
        final precioFinal = num_('precioFinal').toStringAsFixed(0);

        Widget linea(String texto) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(texto, style: const TextStyle(color: Colors.white70, fontSize: 16.5)),
            );

        return Card(
          color: const Color(0xFF2E2E2E),
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fechaTexto, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14.5)),
                const SizedBox(height: 8),
                linea('Precio original:  \$ $precioOriginal'),
                if (marca != null) linea('Marca $marca:  ${_textoCadena(num_('precioAntesMarca'), porcentajesMarca, suma: true)}'),
                if (descuentos.isNotEmpty)
                  linea('Descuento:  ${_textoCadena(num_('precioAntesDescuento'), descuentos, suma: false)}'),
                if (huboCantidad)
                  linea('Cantidad:  \$ ${num_('precioTrasDescuento').toStringAsFixed(0)}'
                      '  x  ${num_('cantidad').toStringAsFixed(0)}'
                      '  =  \$ ${num_('totalConCantidad').toStringAsFixed(0)}'),
                const Divider(color: Colors.white24, height: 16),
                Text('Precio final:  \$ $precioFinal',
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 22)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------- widgets reutilizables ----------------

  // Esta es la "caja" que se repite en casi toda la app (precio,
  // cantidad...). No es un TextField de verdad: solo muestra texto, y
  // como ahora cada pestaña se autoenfoca sola, normalmente no hace
  // falta tocarla (se puede tocar igual, por si se quiere corregir algo
  // a mano). unidad decide si se ve con $, con % o solo el numero.
  Widget _campo(String label, TextEditingController ctrl,
      {bool readOnly = false, bool atenuado = false, String unidad = '\$'}) {
    final deshabilitado = readOnly || atenuado;
    final activo = !deshabilitado && _campoActivo == ctrl;

    final Color bgColor = atenuado ? const Color(0xFFE0E0E0) : (readOnly ? const Color(0xFFEDEDED) : const Color(0xFF4A4A4A));
    final Color txtColor = atenuado ? Colors.grey.shade500 : (readOnly ? const Color(0xFF333333) : Colors.white);
    final Color labelColor = atenuado ? Colors.grey.shade400 : const Color(0xFF555555);
    final String textoValor = unidad == '%'
        ? '${ctrl.text.isEmpty ? '0' : ctrl.text} %'
        : unidad == 'u'
            ? (ctrl.text.isEmpty ? '1' : ctrl.text)
            : '\$ ${ctrl.text.isEmpty ? '0.00' : ctrl.text}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: labelColor)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: deshabilitado ? null : () => setState(() => _campoActivo = ctrl),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: activo ? Border.all(color: const Color(0xFFFDBD00), width: 2) : null,
            ),
            child: Text(textoValor, style: TextStyle(color: txtColor, fontWeight: FontWeight.w800, fontSize: 26)),
          ),
        ),
      ],
    );
  }

  // Caja de tipo de cambio: es la unica que sigue necesitando que la
  // toques para poder escribir, porque no forma parte del flujo de las
  // 4 pestañas (es solo una referencia aparte, siempre visible arriba).
  Widget _cajaTipoCambio() {
    final activo = _campoActivo == _tipoCambioCtrl;
    return GestureDetector(
      onTap: () => setState(() => _campoActivo = _tipoCambioCtrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(20),
          border: activo ? Border.all(color: const Color(0xFFFDBD00), width: 2) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Tipo de cambio  ', style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
              _tipoCambioCtrl.text.isEmpty ? '0.00' : _tipoCambioCtrl.text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }

  // Caja de solo lectura, se usa para mostrar el 18% fijo de la marca CAT
  // (esa marca no tiene nada para escribir, su porcentaje ya viene fijo).
  Widget _campoFijo(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(color: const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(14)),
          child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 26, color: Color(0xFF333333))),
        ),
      ],
    );
  }

  // Texto chico gris, para mostrar la cuenta que se esta haciendo
  // (por ejemplo "100 x 3"), arriba del resultado grande.
  Widget _formula(String texto) => SizedBox(
        width: double.infinity,
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Color(0xFF888888)),
        ),
      );

  // El numero grande y negro que se ve como resultado de cada pestaña.
  Widget _resultado(String texto) => SizedBox(
        width: double.infinity,
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 42, color: Color(0xFF222222)),
        ),
      );

  // Caja con un "%" y dos botones circulares (+ y -), que se repite en
  // marca y en descuento: escribis el numero, tocas + y se agrega a la
  // lista (y la caja se limpia sola para el siguiente); con el - se
  // borra el ultimo que agregaste.
  Widget _cajaMasBotones({
    required TextEditingController ctrl,
    required VoidCallback onSumar,
    required VoidCallback onQuitar,
  }) {
    final activo = _campoActivo == ctrl;
    return GestureDetector(
      onTap: () => setState(() => _campoActivo = ctrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF4A4A4A),
          borderRadius: BorderRadius.circular(14),
          border: activo ? Border.all(color: const Color(0xFFFDBD00), width: 2) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                ctrl.text.isEmpty ? '%' : '${ctrl.text} %',
                style: TextStyle(
                  color: ctrl.text.isEmpty ? Colors.white38 : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 23,
                ),
              ),
            ),
            _botonMasMenos('+', onSumar, const Color(0xFFFDBD00)),
            const SizedBox(width: 8),
            _botonMasMenos('−', onQuitar, const Color(0xFF6A6A6A)),
          ],
        ),
      ),
    );
  }

  // Chip amarillo que muestra la lista de porcentajes ya agregados,
  // separados por coma (ej: "10%, 20%").
  Widget _chipPorcentajes(List<double> valores) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFDBD00), borderRadius: BorderRadius.circular(14)),
      child: Text(
        valores.map((d) => '${d.toStringAsFixed(0)}%').join(', '),
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 20),
      ),
    );
  }

  // El bloque final resaltado con fondo verde, para el precio final de
  // verdad (el que aparece en la ultima pestaña, la de cantidad).
  Widget _bloquePrecioFinal(double monto) {
    return Center(
      child: Column(
        children: [
          const Text('PRECIO FINAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF888888), letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFDFF3E3), borderRadius: BorderRadius.circular(18)),
            child: Text(
              '\$ ${monto.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 44, color: Color(0xFF2E7D4F)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- las 4 pestañas ----------------

  // Pestaña 1: solo el precio original (todo en dolares).
  Widget _panelPrecio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFDFF3E3), borderRadius: BorderRadius.circular(20)),
            child: const Text('TODO EN DÓLARES (\$)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2E7D4F), letterSpacing: 0.5)),
          ),
        ),
        const SizedBox(height: 14),
        _campo('Precio original (\$)', _precioOriginalCtrl),
        const SizedBox(height: 18),
        _resultado('\$ ${_num(_precioOriginalCtrl).toStringAsFixed(0)}'),
      ],
    );
  }

  // Pestaña 2: se elige una marca desde el teclado (arriba de los
  // numeros) y se le suma su porcentaje al precio. CAT es un solo paso
  // fijo (18%); las demas marcas dejan agregar hasta 2 porcentajes, uno
  // atras del otro (el segundo se calcula sobre el resultado del primero).
  Widget _panelMarca() {
    if (_marcaSeleccionada == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(
            'Toca CAT, CTP, HANDOK o IDP arriba del teclado para continuar',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final esCat = _marcaSeleccionada == 'CAT';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (esCat)
          _campoFijo('% marca (CAT)', '18 %')
        else
          _cajaMasBotones(
            ctrl: _marcaInputCtrl,
            onSumar: _agregarPorcentajeMarca,
            onQuitar: _quitarPorcentajeMarca,
          ),
        if (!esCat && _porcentajesMarca.isNotEmpty) ...[
          const SizedBox(height: 12),
          _chipPorcentajes(_porcentajesMarca),
        ],
        const SizedBox(height: 16),
        _formula(esCat
            ? '\$ ${_num(_precioMarcaCtrl).toStringAsFixed(0)}   +   18%'
            : _textoCadena(_num(_precioMarcaCtrl), _porcentajesMarca, suma: true)),
        const SizedBox(height: 6),
        _resultado('= \$ ${_precioConMarca.toStringAsFixed(0)}'),
      ],
    );
  }

  // Pestaña 3: se van agregando descuentos (los que hagan falta) con el
  // mismo sistema de caja + botones que la marca.
  Widget _panelDescuento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Descuentos (%)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
        const SizedBox(height: 6),
        _cajaMasBotones(
          ctrl: _descuentoInputCtrl,
          onSumar: _agregarDescuento,
          onQuitar: _quitarDescuento,
        ),
        if (_descuentosAplicados.isNotEmpty) ...[
          const SizedBox(height: 12),
          _chipPorcentajes(_descuentosAplicados),
        ],
        const SizedBox(height: 18),
        _resultado('= \$ ${_precioFinal.toStringAsFixed(0)}'),
      ],
    );
  }

  // Pestaña 4 (la ultima): el precio que quedo despues de marca y
  // descuento, multiplicado por la cantidad. Aca se ve el precio final
  // de verdad, bien resaltado.
  Widget _panelCantidad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _campo('Cantidad', _cantidadCtrl, unidad: 'u'),
        const SizedBox(height: 18),
        _formula('\$ ${_precioFinal.toStringAsFixed(0)}   x   ${_cantidad.toStringAsFixed(0)}'),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFDDDDDD)),
        const SizedBox(height: 14),
        _bloquePrecioFinal(_totalFinal),
      ],
    );
  }

  // Botones circulares chiquitos de + y -, usados dentro de
  // _cajaMasBotones (marca y descuento).
  Widget _botonMasMenos(String simbolo, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(
          child: Text(simbolo, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20)),
        ),
      ),
    );
  }

  // ---------------- pantalla completa ----------------

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final displayWidth = screenSize.width * 0.96;
    final displayHeight = screenSize.height * 0.36;
    final filaAltura = screenSize.width / 6.2; // alto de cada fila de botones del teclado

    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // logo de la empresa arriba de todo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: SizedBox(
                  height: screenSize.height * 0.11,
                  child: Image.asset(
                    'assets/logo.png',
                    width: screenSize.width * 0.68,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text('Logo no disponible', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      );
                    },
                  ),
                ),
              ),
            ),
            // boton de Historial + caja de tipo de cambio
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _mostrarHistorial,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3A3A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    ),
                    child: const Text('Historial', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _cajaTipoCambio()),
                ],
              ),
            ),
            // tarjeta blanca con la pestaña que este activa
            Center(
              child: Container(
                width: displayWidth,
                height: displayHeight,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_tituloPestana,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
                      const SizedBox(height: 10),
                      Expanded(child: SingleChildScrollView(child: _panelActual)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // teclado: fila de marcas arriba, numeros a la izquierda y
            // botones de accion (atras, res, fin, check) a la derecha
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
              child: Column(
                children: [
                  Row(
                    children: Btn.btnMarcas
                        .map((v) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: SizedBox(height: filaAltura * 0.78, child: buildButton(v)),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            Row(children: [
                              Expanded(child: SizedBox(height: filaAltura, child: buildButton(Btn.btn7))),
                              Expanded(child: SizedBox(height: filaAltura, child: buildButton(Btn.btn8))),
                              Expanded(child: SizedBox(height: filaAltura, child: buildButton(Btn.btn9))),
                            ]),
                            Row(children: [
                              Expanded(child: SizedBox(height: filaAltura, child: buildButton(Btn.btn4))),
                              Expanded(child: SizedBox(height: filaAltura, child: buildButton(Btn.btn5))),
                              Expanded(child: SizedBox(height: filaAltura, child: buildButton(Btn.btn6))),
                            ]),
                            Row(children: [
                              Expanded(child: SizedBox(height: filaAltura, child: buildButton(Btn.btn1))),
                              Expanded(child: SizedBox(height: filaAltura, child: buildButton(Btn.btn2))),
                              Expanded(child: SizedBox(height: filaAltura, child: buildButton(Btn.btn3))),
                            ]),
                            Row(children: [
                              Expanded(flex: 2, child: SizedBox(height: filaAltura, child: buildButton(Btn.btn0))),
                              Expanded(flex: 1, child: SizedBox(height: filaAltura, child: buildButton('.'))),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: Btn.btnAux.map((v) => SizedBox(height: filaAltura, child: buildButton(v))).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dibuja un boton del teclado: decide de que color se pinta segun que
  // tipo de boton es, y que funcion se llama cuando lo tocan.
  Widget buildButton(String value) {
    final isNumber = RegExp(r'^\d$').hasMatch(value);
    final marcaSet = {Btn.btnCat, Btn.btnCtp, Btn.btnHandok, Btn.btnIdp};
    final isMarca = marcaSet.contains(value);
    final isEqual = value == Btn.btnIgual || value == '=';

    Color bgColor;
    Color txtColor;
    double fontSize = 20;
    FontWeight fontWeight = FontWeight.w700;

    if (isMarca) {
      // la marca elegida se ve amarilla, las demas grises (si no hay
      // ninguna elegida todavia, se quedan todas amarillas)
      final seleccionada = _marcaSeleccionada == value.trim();
      final hayOtraElegida = _marcaSeleccionada != null && !seleccionada;
      bgColor = hayOtraElegida ? const Color(0xFFE0E0E0) : const Color(0xFFFDBD00);
      txtColor = const Color(0xFF3A3000);
      fontWeight = FontWeight.w800;
      fontSize = 19;
    } else if (isNumber) {
      bgColor = const Color(0xFF4A4A4A);
      txtColor = Colors.white;
      fontSize = 29;
      fontWeight = FontWeight.w800;
    } else if (isEqual) {
      bgColor = const Color(0xFFDADADA);
      txtColor = const Color(0xFF333333);
      fontWeight = FontWeight.w700;
    } else if (value == Btn.btnReset) {
      bgColor = const Color(0xFFE57373);
      txtColor = Colors.white;
      fontWeight = FontWeight.w800;
    } else if (value == Btn.btnCheck) {
      bgColor = const Color(0xFF7FC98F);
      txtColor = Colors.white;
      fontWeight = FontWeight.w800;
      fontSize = 30;
    } else if (value == Btn.btnTerminar) {
      bgColor = const Color(0xFF4FB6AE);
      txtColor = Colors.white;
      fontWeight = FontWeight.w800;
      fontSize = 18;
    } else if (value == Btn.btnAtras) {
      bgColor = const Color(0xFFFFB870);
      txtColor = Colors.white;
      fontWeight = FontWeight.w800;
      fontSize = 34;
    } else if (value == '.') {
      bgColor = const Color(0xFFDADADA);
      txtColor = const Color(0xFF333333);
      fontSize = 26;
      fontWeight = FontWeight.w800;
    } else {
      bgColor = const Color(0xFFF0F0F0);
      txtColor = const Color(0xFF333333);
    }

    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Material(
        color: bgColor,
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: InkWell(
          onTap: () {
            if (isMarca) {
              setState(() {
                _marcaSeleccionada = value.trim();
                _recalcularCascada();
                _autoenfocarPestana();
              });
            } else if (value == Btn.btnAtras) {
              _borrar();
            } else if (value == Btn.btnReset) {
              _resetear();
            } else if (value == Btn.btnCheck) {
              _confirmarPestana();
            } else if (value == Btn.btnTerminar) {
              _guardarEnHistorial();
            } else {
              _escribir(value);
            }
          },
          child: Center(
            child: value == Btn.btnAtras
                ? Icon(Icons.backspace_rounded, color: txtColor, size: fontSize)
                : Text(value, style: TextStyle(color: txtColor, fontSize: fontSize, fontWeight: fontWeight)),
          ),
        ),
      ),
    );
  }
}

 // quitar el reloj y es su lugar el tipo de cambio como 3.35 y que este sea modificable 
 // las marcas que esten arriba de lo numerico y los otros bonones a los costados del numerico
 // quitar la marca de la esquina superior derecha y en su lugar una vez que se seleccione una marca esta debe aprecere del color amarillito y los demas gris 
 // quitar las flechas del recuadro en su lugar que cada vez que se pone el check se pase a la siguente
 // el historial debe mostrar las operacines realizadascomo 100+ 15 o no se - en caso de descuentos 0 100 x 3 en caso de cantidad
 // en la primeera pestaña que ya no sea tipo de cambio solo precio original y cantidad , cabe resaltar que todo es en dolares 
 // en la segunda pestaña de marca que solo muestre el porcentaje de marca en caso cat 18% y cuanto es eso en dolares y en caso de las otras amrcas que se ingresen los dos porcentajes y despues cuanto es eso en dolares apenas ingrese uno debo poder ingresar el otro 
 // tipo de letra y aumentar tamaño  diseño mas minimalista botones mas grandes y redondos y cambiar a colores menos profundos

//quitar reloj +
//donde esta la hora poner tipo de moneda  cambio --
// 2 da solo porcentajes +
//falta cantidad por defecto en 1 +
// cantidad despues de descuento +
// quqitar flechas cada que sea check pasar a la suiguiente +
// en porcentaje de marca que sea 
// check mas grande y atras +
// marcas arriba y btn al costado +
// los porcentajes de las marcaas sean secuenciales 
//tipo de cambio arriba 3.14 y ya +
//btn selecionado resaltado de marca +
// tipo de letra y aumentar tamaño 
// quitar marca esquina supeior derecha 
// minimalista 
//cambiar colore 


