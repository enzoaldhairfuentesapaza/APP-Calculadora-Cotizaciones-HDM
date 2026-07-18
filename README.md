# DH&DM Calculadora

Calculadora de cotizaciones para **DH&DM Maquinarias SAC**, hecha en Flutter.
Permite armar una cotización paso a paso: convertir moneda, aplicar el
porcentaje de la marca del repuesto/máquina, aplicar descuentos, y guardar
todo en un historial.

## Qué hace la app

La calculadora tiene 3 pasos (pestañas), que se recorren con las flechas `<` `>`:

1. **Tipo de moneda**: se escribe el precio original y se elige si la
   cotización va en Dólares o en Soles. Si es Soles, el precio se
   multiplica por el tipo de cambio (editable); si es Dólares, no se
   multiplica nada.
2. **Aplicar % de marca**: se elige la marca (CAT, CTP, HANDOK o IDP)
   tocando el botón correspondiente en el teclado. CAT suma un 18% fijo;
   las demás marcas usan dos porcentajes que se escriben a mano.
3. **Descuento**: se pueden agregar uno o más descuentos (botón
   "Agregar +"), que se aplican en cadena sobre el precio.

Botones del teclado:
- **✓ (check)**: confirma los datos de la pestaña donde estás parado.
- **FIN**: cierra la cotización completa y la guarda en el Historial.
- **RES**: borra todo lo escrito y empieza de cero.
- **← (atrás)**: borra el último caracter escrito.

El botón **Historial** (arriba a la izquierda) muestra todas las
cotizaciones cerradas con FIN, con el detalle de cada operación que se
hizo. Las cotizaciones se guardan por **24 horas**; pasado ese tiempo
se borran solas. *Aclaración importante:* por ahora el historial vive
en la memoria de la app mientras está abierta — si se cierra la app del
todo, el historial se pierde antes de las 24 horas. Para que sobreviva
a cerrar la app hace falta agregar almacenamiento local (por ejemplo
con el paquete `shared_preferences`), que todavía no está incluido.

## Requisitos para poder correr el proyecto

Necesitas tener instalado:

- **Flutter SDK** (versión estable más reciente) — [flutter.dev/docs/get-started/install](https://docs.flutter.dev/get-started/install)
- **Dart SDK** (viene incluido con Flutter, no hace falta instalarlo aparte)
- **Git** (para clonar/descargar el proyecto)
- Un editor de código: **VS Code** (con la extensión de Flutter/Dart) o **Android Studio**
- Para probar en Android: **Android Studio** con un emulador configurado, o un celular Android físico con la depuración USB activada
- Para probar en iOS (solo desde una Mac): **Xcode**

Para confirmar que todo quedó bien instalado, corre en una terminal:

```bash
flutter doctor
```

Ese comando revisa tu instalación y te avisa si falta algo (por ejemplo,
si Android Studio no tiene el SDK de Android configurado).

## Cómo instalar y correr la app

1. Abre una terminal en la carpeta del proyecto (`HDM_CALCULADORA`, la
   que tiene el archivo `pubspec.yaml`).
2. Descarga las dependencias del proyecto:

   ```bash
   flutter pub get
   ```

3. Conecta un celular por USB (con depuración habilitada) o abre un
   emulador desde Android Studio.
4. Corre la app:

   ```bash
   flutter run
   ```

   Mientras la app está corriendo, podés apretar `r` en la terminal para
   recargar los cambios rápido (hot reload), o `R` para reiniciar la app
   entera (hot restart).

## Cómo generar el instalable (APK)

Para armar un archivo `.apk` que se pueda instalar directo en un
celular Android, sin pasar por Android Studio:

```bash
flutter build apk --release
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`.
Ese `.apk` se puede compartir y se instala tocándolo desde el celular
(puede pedir habilitar "instalar apps de orígenes desconocidos").

## Estructura del proyecto

```
lib/
 ├─ main.dart            → arranca la app (título, tema, pantalla inicial)
 ├─ formato_cal.dart      → toda la pantalla de la calculadora (lógica y diseño)
 └─ button_values.dart    → textos/valores de los botones del teclado

assets/
 ├─ logo.png              → logo que se ve arriba de la pantalla
 └─ icono.png             → ícono de la app (ver sección de abajo)
```
