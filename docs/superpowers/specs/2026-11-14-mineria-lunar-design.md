# Neo-Luna — Minería lunar (diseño)

Fecha: 2026-11-14 · Estado: pendiente de aprobación del dueño del proyecto

Lo marcado como **[mi decisión]** lo propuse yo y no fue confirmado por el dueño.
Todo lo demás lo dijo el dueño.

## Intención
Juego de Roblox para todo público (pensado para niños), colorido y amable. El
jugador llega a la Luna y mina minerales cada vez más lejos de la entrada de la
mina. Cuanto más lejos, mejor el mineral y más ganancia, pero más difícil
escapar de un ovni que persigue al jugador. Con el dinero mejora para llegar
más lejos y conseguir minerales mejores. Un tycoon/coleccionista de minerales
con riesgo y recompensa.

Reemplaza por completo el diseño anterior (ciudad lunar, drones, edificios,
domo con renacimientos). Ese diseño se descartó.

## Ciclo de juego
1. El jugador entra a la mina y se aleja de la **línea de inicio**. La
   profundidad es la distancia a esa línea. Cuanto más lejos, minerales más raros.
2. Mina **un solo mineral por viaje**. Para minar se acerca al mineral y
   **mantiene una tecla (E)**; mientras la mantiene se reproduce la animación de
   picar. Al completar el tiempo, el mineral se rompe y el jugador lo carga.
   (Antes era lanzar el pico a distancia; el dueño lo cambió a este método.)
3. Al sacar el mineral aparece un **ovni** que persigue al jugador. Cuanto más
   profundo está el jugador, **más rápido es el ovni**.
4. Si el jugador cruza la línea de inicio, el mineral se guarda en su
   **inventario**. Si el ovni lo alcanza, **pierde el mineral** y debe volver a
   entrar por la línea.
5. Con un mineral en el inventario el jugador decide: **dejarlo en un puesto de
   su fábrica**, **venderlo en la tienda** o **dárselo a otro jugador**.

## Multijugador (hasta 5 jugadores por servidor)
- **Bases:** cada jugador tiene su propia base; las 5 están juntas en una misma
  zona. Cada jugador aparece en la suya.
- **Plaza central:** espacio común delante de las bases, con una esfera (adorno
  o punto de encuentro).
- **Mina compartida:** todos usan el mismo espacio de la mina, pero **cada
  jugador ve sus propios cristales y minerales** (nadie le quita un mineral a
  otro). Un cristal que rompes solo desaparece para ti.
- **Tiendas a los costados de la entrada de la mina:** una de **mejoras**
  (pico, fuerza, velocidad; también se venden los minerales) y una de **Robux**
  (pases y compras; el contenido está por definir).
- **[mi decisión]** Si entran más de 5, los extra aparecen en la plaza sin base.
  El máximo de jugadores del servidor se fija en Configuración del juego de Roblox.

## Mejoras (se compran con dinero)
- **Velocidad**: lo rápido que corre el jugador. Es clave para escapar del ovni.
- **Fuerza**: lo rápido que pica. **[mi decisión]** acorta el tiempo que hay que
  mantener la tecla (4 % por nivel, hasta quedar en el 40 %).
- **Pico**: su calidad. Los minerales raros o mejores piden cierto nivel de pico.
  Sin él **se pueden picar igual, pero tardan mucho más** (+50 % de tiempo por
  cada nivel que falta); con el nivel adecuado, se pican a velocidad normal.
No hay minado por clicks rápidos ni lanzamiento del pico.

## Minerales
Cada mineral tiene una **familia** (normal, radiactivo, extraterrestre, mutante)
y una **rareza**. Aunque el jugador mejore, siguen saliendo minerales normales.
Valor de venta = valor base × multiplicador de rareza. Los más raros dan mucha
más ganancia. Lista inicial **[mi decisión]**, a ajustar en el balance:

| Rareza | Familia | Ejemplos |
|---|---|---|
| Común | Normal | Roca lunar, hierro, cobre |
| Poco común | Normal | Cuarzo lunar, cristal helado |
| Raro | Radiactivo | Uranio brillante, cristal radiactivo |
| Épico | Extraterrestre | Fragmento de meteorito, cristal alienígena |
| Exótico | Mutante | Esporas mutantes, núcleo mutante |
| Legendario | Especial | Corazón de la Luna, pieza de ovni |

El mineral de cada nodo se decide cuando el nodo aparece, según la zona, y se
ve por el color del cristal (los raros brillan). **Tiempo de picado**: cuanto
más profundo y más raro el mineral, más hay que mantener la tecla (1 s en zona 1
con un mineral común, hasta ~10 s en zona 5 con uno legendario sin mejoras).
**[mi decisión]** La mina se divide en zonas por distancia a la línea (aprox. 5);
cada zona tiene su tabla de probabilidades, y las zonas lejanas solo dan raros
con buena probabilidad si el pico es bueno.

## Fábrica gigante (almacén)
- Se organiza **por pisos, con 8 puestos por piso**, que van subiendo.
- Para tener más almacenamiento se **compran más pisos**.
- Aquí se guardan minerales en puestos (estantes o envases) y también sirven para
  exhibirlos.
- **Ingreso automático (esto es lo que hace de esto un tycoon):** cada mineral que
  tienes en un puesto **genera créditos solo**, según qué mineral es; los más raros
  generan más. Se puede **vender** (te pagan de una vez) o **dejar en un puesto**
  (genera de a poco, para siempre). **[mi decisión, por confirmar]** el ingreso por
  segundo de un mineral es su valor de venta dividido en 900 (se paga solo en unos
  15 minutos), y los detalles de cómo se cobra están por definir.
- El cartel de la base muestra cuánto está ganando el jugador por segundo.
- **Fusión**: solo minerales **raros, exóticos y superiores**; los normales no
  se pueden fusionar. **[mi decisión]** 3 minerales iguales de rareza Raro o
  superior dan 1 mineral de la rareza siguiente.

## Inventario, tienda y regalos
- El inventario recibe el mineral al cruzar la línea.
- **Tienda**: el jugador vende los minerales que quiera de su inventario.
- **Regalar**: puede dárselo a otro jugador si quiere. **[mi decisión]** solo
  regalos (sin intercambio por dinero) y con confirmación del receptor, para
  reducir estafas en un juego para niños.
- El inventario tiene **al menos 10 espacios**. En el HUD normal se ven solo
  **5**; para ver el resto, el jugador abre su **mochila** (la selecciona) y ve
  todos los espacios.
- **[mi decisión]** Si el inventario está lleno no se puede minar hasta liberar
  espacio. Empieza en 10 y se podría ampliar más adelante.

## El ovni (simpático, no amenazante) **[mi decisión]**
Platillo de dibujos animados con carita que se lleva el mineral con un rayo de
luz. Sale cuando el jugador saca un mineral, aparece a cierta distancia detrás
del jugador y lo persigue. El jugador lo "pierde" al cruzar la línea.
Velocidad del ovni = base + (profundidad × factor), ajustable en Config.

## Estilo
Colorido, luminoso y amigable (pastel, formas redondeadas, texto grande y
claro), HUD con Fusion y fuente tipo cartoon. Nada de neón ni oscuridad.

## Objetivos
- Un ciclo muy claro y repetible: arriesgar más profundidad por mejor mineral.
- Progreso rápido al inicio y comprensible para niños.
- Coleccionar y exhibir minerales raros.

## No objetivos / anti-objetivos
- No hay ciudad, drones, edificios, domos ni renacimientos (descartado).
- No hay minado por clicks rápidos ni lanzamiento del pico.
- No llevar más de un mineral por viaje.
- Si el juego se siente injusto (el ovni siempre alcanza) o de mucho espera,
  el diseño fracasó aunque funcione.

## Se reutiliza del proyecto actual
Rojo y la estructura de carpetas, ProfileStore (guardado), Fusion y el estilo
visual colorido del HUD, el patrón de remotes cliente/servidor y la
configuración en `src/shared/Config.luau`.
Se reemplaza: drones, edificios, plataforma de ciudad, pueblo y domo.

## Orden de construcción
1. **Jugable mínimo**: mina con línea de inicio y zonas, minerales con rareza,
   lanzamiento del pico, ovni perseguidor, cruzar la línea, inventario, tienda
   para vender y las tres mejoras.
2. **Fábrica**: pisos de 8 puestos, comprar pisos, guardar desde el inventario.
3. **Fusión** de minerales raros.
4. **Regalar** a otros jugadores.
5. Arte, balance y monetización.

## Preguntas abiertas
- Valores de balance (precios, probabilidades, velocidades): se ajustan en la
  fase de balance, con pruebas.
- Controles de picado en móvil y mando: el prompt de Roblox funciona con toque,
  pendiente de comprobar.
