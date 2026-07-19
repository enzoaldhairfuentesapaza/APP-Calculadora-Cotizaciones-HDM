import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hdm_calculadora/button_values.dart';

// Esta es la pantalla principal de la calculadora. Tiene 4 pasos (pestañas):
// 1) precio, 2) marca, 3) descuento, 4) cantidad. Cada pestaña usa lo que
// calculó la anterior, y al final todo se puede guardar en el historial.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  late Timer _timer;
  int _tabIndex = 0; // que pestaña se ve: 0 precio, 1 marca, 2 descuento, 3 cantidad

  // ---------- pestaña 1: precio original (todo en dolares) ----------
  final _precioOriginalCtrl = TextEditingController();

  // tipo de cambio: solo de referencia, no afecta ningun calculo
  final _tipoCambioCtrl = TextEditingController(text: '3.14');

  // ---------- pestaña 2: marca ----------
  String? _marcaSeleccionada;
  final _precioMarcaCtrl = TextEditingController();
  final _porc1Ctrl = TextEditingController();
  final _porc2Ctrl = TextEditingController();

  // ---------- pestaña 3: descuento ----------
  final _precioDescCtrl = TextEditingController();
  final _descuentoInputCtrl = TextEditingController(); // caja donde se escribe el % antes de sumarlo
  final List<double> _descuentosAplicados = []; // descuentos ya agregados con el +

  // ---------- pestaña 4: cantidad (ahora va al final, no al principio) ----------
  final _cantidadCtrl = TextEditingController(text: '1');

  bool _precioMarcaManual = false;
  bool _precioDescManual = false;
  bool _cantidadManual = false; // si es false, el "1" de por defecto se borra apenas escribas

  TextEditingController? _campoActivo;
  final List<Map<String, dynamic>> _historial = [];

  @override
  void initState() {
    super.initState();
    // revisa cada minuto si hay cotizaciones con mas de 24 horas para borrarlas
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {
        _historial.removeWhere((item) => DateTime.now().difference(item['fecha'] as DateTime).inHours >= 24);
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _precioOriginalCtrl.dispose();
    _cantidadCtrl.dispose();
    _tipoCambioCtrl.dispose();
    _precioMarcaCtrl.dispose();
    _porc1Ctrl.dispose();
    _porc2Ctrl.dispose();
    _precioDescCtrl.dispose();
    _descuentoInputCtrl.dispose();
    super.dispose();
  }

  // convierte texto de los inputs a numero
  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  // la cantidad nunca es 0: si está vacía vale 1
  double get _cantidad {
    final c = _num(_cantidadCtrl);
    return c == 0 ? 1 : c;
  }

  // primer paso: precio base + primer porcentaje (CAT no usa este paso,
  // su 18% se aplica directo y una sola vez)
  double get _paso1Marca {
    final precio = _num(_precioMarcaCtrl);
    if (_marcaSeleccionada == 'CAT') return precio;
    final p1 = _num(_porc1Ctrl);
    return (precio + precio * (p1 / 100)).roundToDouble();
  }

  // resultado final con marca: en CTP/HANDOK/IDP el segundo porcentaje se
  // aplica sobre el resultado del primero (en cadena), no sobre el precio
  // original. Cada paso se redondea al entero mas cercano.
  double get _precioConMarca {
    final precio = _num(_precioMarcaCtrl);
    if (_marcaSeleccionada == 'CAT') {
      return (precio + precio * 0.18).roundToDouble();
    }
    final p2 = _num(_porc2Ctrl);
    final paso1 = _paso1Marca;
    return (paso1 + paso1 * (p2 / 100)).roundToDouble();
  }

  // aplica los descuentos ya agregados, uno tras otro (en cadena)
  double get _precioFinal {
    double precio = _num(_precioDescCtrl);
    for (final d in _descuentosAplicados) {
      precio = (precio - precio * (d / 100)).roundToDouble();
    }
    return precio;
  }

  // paso 4 (el ultimo): el precio ya con marca y descuento, x la cantidad
  double get _totalFinal => (_precioFinal * _cantidad).roundToDouble();

  // como ya no hay flechas para ir "para atras", _tabIndex siempre dice
  // hasta donde llego el usuario. Con eso alcanza para saber que monto
  // mostrar si aprieta FIN sin pasar por todas las pestañas.
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

  // pasa los datos automaticamente a las siguientes pestañas
  void _recalcularCascada() {
    if (!_precioMarcaManual) {
      _precioMarcaCtrl.text = _num(_precioOriginalCtrl).toStringAsFixed(0);
    }
    if (!_precioDescManual) {
      _precioDescCtrl.text = _precioConMarca.toStringAsFixed(0);
    }
  }

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

  // escribe el numero presionado en el input activo
  void _escribir(String valor) {
    if (_campoActivo == null) return;
    setState(() {
      if (_campoActivo == _cantidadCtrl && !_cantidadManual) {
        _campoActivo!.text = valor; // reemplaza el "1" por defecto
        _cantidadManual = true;
      } else {
        _campoActivo!.text += valor;
      }
      if (_campoActivo == _precioMarcaCtrl) _precioMarcaManual = true;
      if (_campoActivo == _precioDescCtrl) _precioDescManual = true;
      _recalcularCascada();
    });
  }

  // borra el ultimo caracter
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

  // toma lo que hay escrito en la caja de descuento, lo agrega a la lista
  // y limpia la caja para el siguiente
  void _agregarDescuento() {
    final valor = _num(_descuentoInputCtrl);
    if (valor <= 0) return;
    setState(() {
      _descuentosAplicados.add(valor);
      _descuentoInputCtrl.clear();
      if (_campoActivo == _precioDescCtrl) _precioDescManual = true;
      _recalcularCascada();
    });
  }

  // quita el ultimo descuento que se agrego
  void _quitarDescuento() {
    if (_descuentosAplicados.isEmpty) return;
    setState(() => _descuentosAplicados.removeLast());
  }

  // limpia toda la pantalla
  void _resetear() {
    setState(() {
      _precioOriginalCtrl.clear();
      _cantidadCtrl.text = '1';
      _cantidadManual = false;
      _marcaSeleccionada = null;
      _precioMarcaCtrl.clear();
      _porc1Ctrl.clear();
      _porc2Ctrl.clear();
      _precioDescCtrl.clear();
      _descuentoInputCtrl.clear();
      _descuentosAplicados.clear();
      _campoActivo = null;
      _tabIndex = 0;
      _precioMarcaManual = false;
      _precioDescManual = false;
    });
  }

  // el check avisa que se guardo esa pestaña y pasa a la siguiente sola
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
      });
    }
  }

  // guarda la ficha de la cotizacion con cada operacion realizada
  void _guardarEnHistorial() {
    // como no hay vuelta atras entre pestañas, _tabIndex nos dice
    // exactamente hasta donde llego el usuario esta vez
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
        'porc1': huboMarca ? (esCat ? 18.0 : _num(_porc1Ctrl)) : null,
        'porc2': huboMarca ? (esCat ? null : _num(_porc2Ctrl)) : null,
        'precioAntesMarca': huboMarca ? _num(_precioMarcaCtrl) : null,
        'paso1Marca': huboMarca ? _paso1Marca : null,
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

  // abre el panel de abajo (bottom sheet) con la lista del historial
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

  // arma una tarjeta por cotizacion, mostrando la cuenta tal cual se hizo
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
        final item = _historial[_historial.length - 1 - i];
        final fecha = item['fecha'] as DateTime;
        final fechaTexto = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}  '
            '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

        // lee un numero del historial sin importar si quedo guardado como
        // int o double, asi nunca truena el cast
        double num_(String key) => (item[key] as num?)?.toDouble() ?? 0;
        bool esCatGuardado() => item['esCat'] as bool? ?? false;

        final precioOriginal = num_('precioOriginal').toStringAsFixed(0);
        final marca = item['marca'] as String?;
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
                if (marca != null)
                  linea(
                    esCatGuardado()
                        ? 'Marca $marca:  \$ ${num_('precioAntesMarca').toStringAsFixed(0)}'
                            '  +  18%'
                            '  =  \$ ${num_('precioConMarca').toStringAsFixed(0)}'
                        : 'Marca $marca:  \$ ${num_('precioAntesMarca').toStringAsFixed(0)}'
                            '  +${num_('porc1').toStringAsFixed(0)}%  =  \$ ${num_('paso1Marca').toStringAsFixed(0)}'
                            '   →   +${num_('porc2').toStringAsFixed(0)}%  =  \$ ${num_('precioConMarca').toStringAsFixed(0)}',
                  ),
                if (descuentos.isNotEmpty)
                  linea('Descuento:  \$ ${num_('precioAntesDescuento').toStringAsFixed(0)}  '
                      '${descuentos.map((d) => '-  ${d.toStringAsFixed(0)}%').join('  ')}'
                      '  =  \$ ${num_('precioTrasDescuento').toStringAsFixed(0)}'),
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

  // esta es la "caja" que se repite en casi toda la app (precio, cantidad,
  // porcentajes...). No es un TextField de verdad: solo muestra texto y,
  // al tocarla, se marca como el campo activo para que el teclado de la
  // app escriba ahi. unidad decide si se ve con $, con % o solo el numero.
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

  // caja de tipo de cambio: solo informativa, se puede tocar y editar
  // con el mismo teclado de la app, pero no entra en ningun calculo
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

  // caja de solo lectura, se usa para mostrar el 18% fijo de la marca CAT
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

  // texto chico gris, para mostrar la cuenta (ej: "100 x 3")
  Widget _formula(String texto) => SizedBox(
        width: double.infinity,
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Color(0xFF888888)),
        ),
      );

  // el numero grande y negro que se ve como resultado de cada pestaña
  Widget _resultado(String texto) => SizedBox(
        width: double.infinity,
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 42, color: Color(0xFF222222)),
        ),
      );

  // ---------------- las 4 pestañas ----------------

  // pestaña 1: solo el precio original (todo en dolares)
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

  // pestaña 2: se elige una marca desde el teclado y se le suma su
  // porcentaje al precio. CAT es un solo paso (18%); las demas marcas
  // son dos pasos, uno atras del otro (ver _paso1Marca y _precioConMarca)
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
        esCat
            ? _campoFijo('% marca (CAT)', '18 %')
            : Row(
                children: [
                  Expanded(child: _campo('Porcentaje 1 (%)', _porc1Ctrl, unidad: '%')),
                  const SizedBox(width: 12),
                  Expanded(child: _campo('Porcentaje 2 (%)', _porc2Ctrl, unidad: '%')),
                ],
              ),
        const SizedBox(height: 16),
        _formula(esCat
            ? '\$ ${_num(_precioMarcaCtrl).toStringAsFixed(0)}   +   18%'
            : '\$ ${_num(_precioMarcaCtrl).toStringAsFixed(0)}  +${_num(_porc1Ctrl).toStringAsFixed(0)}%  =  \$ ${_paso1Marca.toStringAsFixed(0)}   →   +${_num(_porc2Ctrl).toStringAsFixed(0)}%'),
        const SizedBox(height: 6),
        _resultado('= \$ ${_precioConMarca.toStringAsFixed(0)}'),
      ],
    );
  }

  Widget _panelDescuento() {
    final activo = _campoActivo == _descuentoInputCtrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Descuentos (%)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
        const SizedBox(height: 6),
        // recuadro unico: escribis el % y lo sumas con el +
        GestureDetector(
          onTap: () => setState(() => _campoActivo = _descuentoInputCtrl),
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
                    _descuentoInputCtrl.text.isEmpty ? '%' : '${_descuentoInputCtrl.text} %',
                    style: TextStyle(
                      color: _descuentoInputCtrl.text.isEmpty ? Colors.white38 : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 23,
                    ),
                  ),
                ),
                _botonMasMenos('+', _agregarDescuento, const Color(0xFFFDBD00)),
                const SizedBox(width: 8),
                _botonMasMenos('−', _quitarDescuento, const Color(0xFF6A6A6A)),
              ],
            ),
          ),
        ),
        if (_descuentosAplicados.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFFDBD00), borderRadius: BorderRadius.circular(14)),
            child: Text(
              _descuentosAplicados.map((d) => '${d.toStringAsFixed(0)}%').join(', '),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _resultado('= \$ ${_precioFinal.toStringAsFixed(0)}'),
      ],
    );
  }

  // pestaña 4 (la ultima): el precio que quedo despues de marca y
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
        Center(
          child: Column(
            children: [
              const Text('PRECIO FINAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF888888), letterSpacing: 1)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFDFF3E3), borderRadius: BorderRadius.circular(18)),
                child: Text(
                  '\$ ${_totalFinal.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 44, color: Color(0xFF2E7D4F)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // botones circulares + y - de la pestaña de descuento
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final displayWidth = screenSize.width * 0.96;
    final displayHeight = screenSize.height * 0.36;
    final filaAltura = screenSize.width / 6.2;

    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // logo
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
            // historial, minimalista
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
            // tarjeta con la pestaña activa
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
            // teclado: marcas arriba, numeros a la izquierda y acciones al costado
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


