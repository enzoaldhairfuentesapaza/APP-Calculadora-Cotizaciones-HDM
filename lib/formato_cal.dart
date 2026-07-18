import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hdm_calculadora/button_values.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  int _tabIndex = 0;

  String _moneda = 'Dolares'; 
  final _precioOriginalCtrl = TextEditingController();
  final _tipoCambioCtrl = TextEditingController(text: '3.35');

  String? _marcaSeleccionada; 
  final _precioMarcaCtrl = TextEditingController();
  final _porc1Ctrl = TextEditingController();
  final _porc2Ctrl = TextEditingController();

  final _precioDescCtrl = TextEditingController();
  List<TextEditingController> _descuentosCtrl = [TextEditingController()];

  bool _precioMarcaManual = false;
  bool _precioDescManual = false;

  TextEditingController? _campoActivo;
  final List<Map<String, dynamic>> _historial = [];

  @override
  void initState() {
    super.initState();
    // reloj que avanza cada segundo
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _precioOriginalCtrl.dispose();
    _tipoCambioCtrl.dispose();
    _precioMarcaCtrl.dispose();
    _porc1Ctrl.dispose();
    _porc2Ctrl.dispose();
    _precioDescCtrl.dispose();
    for (final c in _descuentosCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  String get _weekday {
    const names = ['Domingo', 'Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado'];
    return names[_now.weekday % 7];
  }

  // convierte texto de los inputs a numero
  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  // calcula el precio segun la moneda
  double get _conversion {
    final precio = _num(_precioOriginalCtrl);
    final valor = _moneda == 'Soles' ? precio * _num(_tipoCambioCtrl) : precio;
    return valor.roundToDouble(); 
  }

  // saca el porcentaje de la marca
  double get _porcentajeMarca {
    if (_marcaSeleccionada == 'CAT') return 18;
    return _num(_porc1Ctrl) + _num(_porc2Ctrl);
  }

  // suma el porcentaje de marca al precio
  double get _precioConMarca {
    final precio = _num(_precioMarcaCtrl);
    final total = precio + precio * (_porcentajeMarca / 100);
    return total.roundToDouble();
  }

  // aplica los descuentos uno por uno
  double get _precioFinal {
    double precio = _num(_precioDescCtrl);
    for (final c in _descuentosCtrl) {
      final d = _num(c);
      precio = precio - precio * (d / 100); 
    }
    return precio.roundToDouble();
  }

  // saca el monto segun la pestana donde se quedo
  double get _montoFinal {
    if (_precioDescCtrl.text.isNotEmpty) return _precioFinal;
    if (_precioMarcaCtrl.text.isNotEmpty) return _precioConMarca;
    return _conversion;
  }

  // pasa los datos automaticamente a las siguientes pestanas
  void _recalcularCascada() {
    if (!_precioMarcaManual) {
      _precioMarcaCtrl.text = _conversion.toStringAsFixed(0);
    }
    if (!_precioDescManual) {
      _precioDescCtrl.text = _precioConMarca.toStringAsFixed(0);
    }
  }

  String get _tituloPestana {
    switch (_tabIndex) {
      case 1: return 'Aplicar % de marca';
      case 2: return 'Descuento';
      default: return 'Tipo de moneda';
    }
  }

  Widget get _panelActual {
    switch (_tabIndex) {
      case 1: return _panelMarca();
      case 2: return _panelDescuento();
      default: return _panelMoneda();
    }
  }

  void _siguiente() {
    if (_tabIndex >= 2) return;
    setState(() {
      _tabIndex++;
      _recalcularCascada();
    });
  }

  void _anterior() {
    if (_tabIndex <= 0) return;
    setState(() => _tabIndex--);
  }

  // escribe el numero presionado en el input activo
  void _escribir(String valor) {
    if (_campoActivo == null) return;
    setState(() {
      _campoActivo!.text += valor;
      if (_campoActivo == _precioMarcaCtrl) _precioMarcaManual = true;
      if (_campoActivo == _precioDescCtrl) _precioDescManual = true;
      _recalcularCascada();
    });
  }

  // borra el ultimo numero
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

  // limpia toda la pantalla
  void _resetear() {
    setState(() {
      _precioOriginalCtrl.clear();
      _tipoCambioCtrl.text = '3.35';
      _moneda = 'Dolares';
      _marcaSeleccionada = null;
      _precioMarcaCtrl.clear();
      _porc1Ctrl.clear();
      _porc2Ctrl.clear();
      _precioDescCtrl.clear();
      for (final c in _descuentosCtrl) {
        c.dispose();
      }
      _descuentosCtrl = [TextEditingController()];
      _campoActivo = null;
      _tabIndex = 0;
      _precioMarcaManual = false;
      _precioDescManual = false;
    });
  }

  void _confirmarPestana() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cambios guardados: $_tituloPestana'),
        duration: const Duration(milliseconds: 900),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // guarda la ficha de la cotizacion en la lista
  void _guardarEnHistorial() {
    final huboMarca = _precioMarcaCtrl.text.isNotEmpty && _marcaSeleccionada != null;
    final descuentosUsados = _descuentosCtrl.map(_num).where((d) => d > 0).toList();
    setState(() {
      _historial.add({
        'fecha': _now,
        'moneda': _moneda,
        'tipoCambio': _num(_tipoCambioCtrl),
        'precioOriginal': _num(_precioOriginalCtrl),
        'conversion': _conversion,
        'marca': huboMarca ? _marcaSeleccionada : null,
        'porcentajeMarca': huboMarca ? _porcentajeMarca : null,
        'precioConMarca': huboMarca ? _precioConMarca : null,
        'descuentos': descuentosUsados,
        'precioFinal': _montoFinal,
      });
    });
    _resetear();
  }

  // abre el panel de abajo para ver el historial
  void _mostrarHistorial() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      isScrollControlled: true,
      builder: (_) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: _cuerpoHistorial(),
        );
      },
    );
  }

  Widget _cuerpoHistorial() {
    if (_historial.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Todavia no hay cotizaciones guardadas', style: TextStyle(color: Colors.white)),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _historial.length,
      itemBuilder: (_, i) {
        final item = _historial[_historial.length - 1 - i]; 
        final fecha = item['fecha'] as DateTime;
        final fechaTexto = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}  ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
        final descuentos = (item['descuentos'] as List).cast<double>();
        final descuentosTexto = descuentos.map((d) => '${d.toStringAsFixed(0)}%').join(' + ');
        final marca = item['marca'] as String?;
        final moneda = item['moneda'] as String;
        final simboloOriginal = moneda == 'Soles' ? 'S/' : '\$';

        Widget linea(String texto) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(texto, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            );

        return Card(
          color: Colors.grey.shade800,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fechaTexto, style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                linea('Moneda: $moneda ($simboloOriginal)   •   Tipo de cambio: ${item['tipoCambio']}'),
                linea('Precio original: $simboloOriginal ${(item['precioOriginal'] as double).toStringAsFixed(0)}   •   Conversion: \$ ${(item['conversion'] as double).toStringAsFixed(0)}'),
                if (marca != null) ...[
                  linea('Marca: $marca   •   % marca: ${(item['porcentajeMarca'] as double).toStringAsFixed(0)}%'),
                  linea('Precio con marca: \$ ${(item['precioConMarca'] as double).toStringAsFixed(0)}'),
                ],
                if (descuentos.isNotEmpty) linea('Descuentos aplicados: $descuentosTexto'),
                const Divider(color: Colors.white24, height: 14),
                Text('Precio final: \$ ${(item['precioFinal'] as double).toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }

  // caja de texto falsa que responde a nuestro propio teclado
  Widget _campo(String label, TextEditingController ctrl,
      {bool readOnly = false, bool atenuado = false, String unidad = '\$'}) {
    final deshabilitado = readOnly || atenuado;
    final activo = !deshabilitado && _campoActivo == ctrl;

    final Color bgColor = atenuado ? Colors.grey.shade400 : (readOnly ? Colors.grey.shade300 : Colors.grey.shade700);
    final Color txtColor = atenuado ? Colors.grey.shade600 : (readOnly ? Colors.black87 : Colors.white);
    final Color labelColor = atenuado ? Colors.grey.shade500 : Colors.black87;
    final String textoValor = unidad == '%'
        ? '${ctrl.text.isEmpty ? '0' : ctrl.text} %'
        : '\$ / ${ctrl.text.isEmpty ? '0.00' : ctrl.text}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
        const SizedBox(height: 3),
        GestureDetector(
          onTap: deshabilitado ? null : () => setState(() => _campoActivo = ctrl),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: activo ? Border.all(color: Colors.yellow, width: 2) : null,
            ),
            child: Text(
              textoValor,
              style: TextStyle(color: txtColor, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoFijo(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
          child: Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
        ),
      ],
    );
  }

  Widget _botonMoneda(String texto, String valor) {
    final seleccionado = _moneda == valor;
    return GestureDetector(
      onTap: () => setState(() {
        _moneda = valor;
        if (valor == 'Dolares' && _campoActivo == _tipoCambioCtrl) {
          _campoActivo = null;
        }
        _precioMarcaManual = false;
        _precioDescManual = false;
        _recalcularCascada();
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: seleccionado ? Colors.green : Colors.grey.shade600,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _panelMoneda() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _campo('Precio Original (\$)', _precioOriginalCtrl)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('TIPO DE CAMBIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  _botonMoneda('Dolares (\$)', 'Dolares'),
                  _botonMoneda('Soles (s/)', 'Soles'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _campo('Tipo de cambio', _tipoCambioCtrl, atenuado: _moneda == 'Dolares'),
        const Divider(height: 18, color: Colors.black26),
        const Text('Conversion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _campo('Precio Original (\$)', _precioOriginalCtrl, readOnly: true)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('x', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            Expanded(child: _campo('Tipo de cambio (s/)', _tipoCambioCtrl, readOnly: true, atenuado: _moneda == 'Dolares')),
          ],
        ),
        const SizedBox(height: 6),
        Text('= \$ ${_conversion.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
      ],
    );
  }

  Widget _panelMarca() {
    if (_marcaSeleccionada == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(
            'Toca CAT, CTP, HANDOK o IDP en el teclado para continuar',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final esCat = _marcaSeleccionada == 'CAT';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _campo('Precio (\$ o s/)', _precioMarcaCtrl)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('+', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            Expanded(
              child: esCat
                  ? _campoFijo('Porcentaje CAT', '18 %')
                  : Column(
                      children: [
                        _campo('Porcentaje 1 (%)', _porc1Ctrl, unidad: '%'),
                        const SizedBox(height: 6),
                        _campo('Porcentaje 2 (%)', _porc2Ctrl, unidad: '%'),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text('= \$ ${_precioConMarca.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
      ],
    );
  }

  Widget _panelDescuento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _campo('Precio (\$)', _precioDescCtrl)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Descuentos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  ..._descuentosCtrl.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _campo('%', c, unidad: '%'),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _descuentosCtrl.add(TextEditingController())),
                    child: const Text('Agregar +', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 18, color: Colors.black26),
        Text('Precio final (\$) = \$ ${_precioFinal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final formattedDate = '${_now.day.toString().padLeft(2, '0')}/${_now.month.toString().padLeft(2, '0')}/${_now.year}';
    final formattedTime = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}';
    final displayWidth = screenSize.width * 0.96;
    final displayHeight = screenSize.height * 0.38;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // logo principal con ajuste nativo original
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: SizedBox(
                  height: screenSize.height * 0.12,
                  child: Image.asset(
                    'assets/logo.png',
                    width: screenSize.width * 0.72,
                    fit: BoxFit.contain, 
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          'Logo no disponible',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _mostrarHistorial,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Historial', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                      decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        '${_weekday.toLowerCase()}  $formattedDate  •  $formattedTime',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.yellow),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Center(
              child: Container(
                width: displayWidth,
                height: displayHeight,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(_tituloPestana, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ),
                          if (_marcaSeleccionada != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(20)),
                              child: Text(_marcaSeleccionada!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _anterior,
                              child: Icon(Icons.arrow_back_ios, size: 22, color: _tabIndex == 0 ? Colors.grey.shade300 : Colors.grey.shade700),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: _panelActual,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _siguiente,
                              child: Icon(Icons.arrow_forward_ios, size: 22, color: _tabIndex == 2 ? Colors.grey.shade300 : Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // botones del teclado mapeados dinamicamente
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
              child: Column(
                children: [
                  Wrap(
                    spacing: 3,
                    runSpacing: 4,
                    children: Btn.btnAux
                        .map((value) => SizedBox(
                              width: (screenSize.width - 24) / 4,
                              height: screenSize.width / 7.2,
                              child: buildButton(value),
                            ))
                        .toList(),
                  ),
                  Wrap(
                    spacing: 3,
                    runSpacing: 4,
                    children: Btn.btnMarcasynum
                        .map((value) => SizedBox(
                              width: (screenSize.width - 22) / 4,
                              height: screenSize.width / 7.2,
                              child: buildButton(value),
                            ))
                        .toList(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: SizedBox(height: screenSize.width / 7.2, child: buildButton(Btn.btn0)),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 1,
                          child: SizedBox(height: screenSize.width / 7.2, child: buildButton('.')),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 1,
                          child: SizedBox(height: screenSize.width / 7.2, child: buildButton(Btn.btnIdp)),
                        ),
                      ],
                    ),
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
    double fontSize = 18;
    FontWeight fontWeight = FontWeight.normal;

    if (isMarca) {
      bgColor = Colors.yellow;
      txtColor = Colors.black;
      fontWeight = FontWeight.bold;
    } else if (isNumber) {
      bgColor = Colors.black;
      txtColor = Colors.white;
    } else if (isEqual) {
      bgColor = Colors.grey;
      txtColor = Colors.white;
      fontWeight = FontWeight.bold;
    } else if (value == Btn.btnReset) {
      bgColor = Colors.red;
      txtColor = Colors.white;
      fontWeight = FontWeight.bold;
    } else if (value == Btn.btnCheck) {
      bgColor = Colors.green;
      txtColor = Colors.white;
      fontWeight = FontWeight.w900;
      fontSize = 22;
    } else if (value == Btn.btnTerminar) {
      bgColor = Colors.teal;
      txtColor = Colors.white;
      fontWeight = FontWeight.w900;
      fontSize = 15;
    } else if (value == Btn.btnAtras) {
      bgColor = Colors.orange;
      txtColor = Colors.white;
      fontWeight = FontWeight.w900;
      fontSize = 22;
    } else if (value == '.') {
      bgColor = Colors.grey;
      txtColor = Colors.white;
    } else {
      bgColor = Colors.white;
      txtColor = Colors.black;
    }

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Material(
        color: bgColor,
        clipBehavior: Clip.hardEdge,
        shape: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: Colors.white24),
        ),
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
            child: Text(
              value,
              style: TextStyle(color: txtColor, fontSize: fontSize, fontWeight: fontWeight),
            ),
          ),
        ),
      ),
    );
  }
}