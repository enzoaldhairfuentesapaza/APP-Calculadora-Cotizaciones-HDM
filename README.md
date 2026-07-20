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

## Cómo poner el ícono de la app (el que se ve en el home del celular)

Ya tienes `icono.png` dentro de `assets/`, pero ese archivo por sí solo
**no** cambia el ícono del home — hay que generarlo con un paquete
aparte, porque Android e iOS necesitan el ícono en varios tamaños
distintos (no un solo PNG). Los pasos:

1. Abre `pubspec.yaml` y agrega esta dependencia de desarrollo (en la
   sección `dev_dependencies`, junto a `flutter_test`):

   ```yaml
   dev_dependencies:
     flutter_test:
       sdk: flutter
     flutter_launcher_icons: ^0.13.1
   ```

2. Más abajo en el mismo archivo (fuera de `dependencies`/`dev_dependencies`,
   al mismo nivel que `flutter:`), agrega esta configuración:

   ```yaml
   flutter_launcher_icons:
     android: true
     ios: true
     image_path: "assets/icono.png"
   ```

3. En la terminal, dentro de la carpeta del proyecto:

   ```bash
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```

   Este comando genera solo los íconos y reemplaza los que ya existen en
   `android/app/src/main/res/` y `ios/Runner/Assets.xcassets/`.

4. Vuelve a instalar la app (`flutter run` o reinstalando el `.apk`)
   para ver el ícono nuevo — si el celular queda mostrando el ícono
   viejo, suele bastar con desinstalar la app y volver a instalarla.

*Consejo:* para que el ícono se vea bien en Android (que recorta los
íconos en formas distintas según el celular), `icono.png` debería ser
cuadrado y de al menos 512x512 píxeles, con el diseño centrado y sin
texto pegado a los bordes.

## Cómo cambiar el nombre de la app (el que se ve en el home)

El `title` que está en `main.dart` (`DH&DM Calculadora`) solo se usa
puertas adentro de Flutter — no es lo que se ve como nombre debajo del
ícono en el celular. Ese nombre se cambia en otros dos archivos:

**Android** — abre `android/app/src/main/AndroidManifest.xml` y busca la
etiqueta `<application ...>`. Cambia el atributo `android:label`:

```xml
<application
    android:label="DH&amp;DM Calculadora"
    ...>
```

(Nota el `&amp;` en vez de `&`: en XML el símbolo `&` solo no es válido,
hay que escribirlo así.)

**iOS** — abre `ios/Runner/Info.plist` y busca la clave
`CFBundleDisplayName` (o agrégala si no existe):

```xml
<key>CFBundleDisplayName</key>
<string>DH&DM Calculadora</string>
```

Si quieres, súbeme esos dos archivos (`AndroidManifest.xml` e
`Info.plist`) junto con tu `pubspec.yaml`, y te dejo los tres ya
editados y listos para reemplazar.