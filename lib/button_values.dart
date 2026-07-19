class Btn {
  // botones numericos
  static const String btn1 = '1';
  static const String btn2 = '2';
  static const String btn3 = '3';
  static const String btn4 = '4';
  static const String btn5 = '5';
  static const String btn6 = '6';
  static const String btn7 = '7';
  static const String btn8 = '8';
  static const String btn9 = '9';
  static const String btn0 = '0';

  // botones de accion
  static const String btnAtras = ' ← ';
  static const String btnReset = 'RES';
  static const String btnCheck = '✓';
  static const String btnTerminar = 'FIN';
  static const String btnIgual = '=';

  // marcas
  static const String btnCat = 'CAT';
  static const String btnCtp = 'CTP';
  static const String btnHandok = 'HANDOK';
  static const String btnIdp = 'IDP';

  // fila de marcas, arriba del teclado numerico
  static const List<String> btnMarcas = [
    btnCat,
    btnCtp,
    btnHandok,
    btnIdp,
  ];

  // columna de botones al costado del teclado numerico
  static const List<String> btnAux = [
    btnAtras,
    btnReset,
    btnTerminar,
    btnCheck,
  ];
}