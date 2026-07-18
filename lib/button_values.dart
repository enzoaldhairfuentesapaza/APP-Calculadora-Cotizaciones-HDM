// =====================================================================
// button_values.dart
// ---------------------------------------------------------------------
// Este archivo NO dibuja nada en pantalla: solo guarda TEXTOS (Strings)
// y LISTAS de textos que después usa formato_cal.dart para armar el
// teclado. La idea de separarlo en su propio archivo es que, si mañana
// querés cambiar el orden de los botones o agregar uno nuevo, lo hacés
// acá, sin tener que tocar el archivo grande de la pantalla.
//
// `static const` quiere decir dos cosas:
// - `static`: la variable pertenece a la CLASE Btn en sí (no a un
//   "objeto" Btn en particular). Por eso se usa como `Btn.btn1`, sin
//   necesidad de escribir `Btn().btn1`.
// - `const`: el valor es fijo, se conoce desde que se compila la app y
//   nunca cambia mientras la app corre.
// =====================================================================
class Btn {
  // ---------------- botones numéricos individuales ----------------
  // Cada número del 0 al 9 como texto, para poder reusarlos más abajo
  // dentro de las listas (así no repetimos el string "7" muchas veces
  // sueltos: si en algún momento hiciera falta cambiar cómo se ve un
  // número, alcanza con cambiarlo acá arriba).
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

  // ---------------- botones de acción (no numéricos) ----------------
  static const String btnAtras = ' ← '; // borra el último caracter escrito
  static const String btnReset = 'RES'; // borra TODO y reinicia la calculadora
  static const String btnCheck = '✓'; // confirma los cambios de la pestaña actual
  static const String btnTerminar = 'FIN'; // cierra la cotización y la guarda en el historial
  static const String btnCat = 'CAT'; // marca con % fijo (18%)
  static const String btnCtp = 'CTP'; // marca con % editable
  static const String btnHandok = 'HANDOK'; // marca con % editable
  static const String btnIdp = 'IDP'; // botón adicional del teclado
  static const String btnIgual = '='; // botón "=" (visual, de cierre de cuenta)

  // ---------------- listas usadas para dibujar el teclado ----------------
  // formato_cal.dart recorre estas listas con un `.map(...)` y, por
  // cada texto que encuentra, dibuja un botón (ver buildButton() en
  // formato_cal.dart). Por eso el ORDEN en que aparecen acá es el mismo
  // orden en el que se ven los botones en pantalla.

  // Fila auxiliar de arriba del todo: atrás, reset, check y ahora
  // también FIN (para cerrar y guardar la cotización completa).
  static const List<String> btnAux = [
    " ← ",
    "RES",
    "✓",
    "FIN",
    ////
  ];

  // Números del 1 al 9 combinados con los botones de marca, en 3 filas
  // de 4 columnas cada una (los "////" son solo un separador visual
  // para nosotros al leer el código; a Dart no le importan).
  static const List<String> btnMarcasynum = [
    btn7,
    btn8,
    btn9,
    "CAT",
    ////
    btn4,
    btn5,
    btn6,
    "CTP",
    ////
    btn1,
    btn2,
    btn3,
    "HANDOK",
    ////
  ];

  // Última fila: el 0, el punto decimal y el signo "=".
  // OJO: esta lista quedó como referencia, pero en formato_cal.dart esa
  // última fila en realidad se arma "a mano" con un Row (para poder
  // darle más ancho al botón 0), no leyendo esta lista.
  static const List<String> btnfin = [
    btn0,
    ".",
    "=",
    ////
  ];
}