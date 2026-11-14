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
2. Mina **un solo mineral por viaje**, **lanzando el pico** (una sola forma de
   minar, sin picar de cerca). Al lanzar, el pico viaja hacia el objetivo y, si
   alcanza un mineral, lo rompe y el jugador lo carga.
3. Al sacar el mineral aparece un **ovni** que persigue al jugador. Cuanto más
   profundo está el jugador, **más rápido es el ovni**.
4. Si el jugador cruza la línea de inicio, el mineral se guarda en su
   **inventario**. Si el ovni lo alcanza, **pierde el mineral** y debe volver a
   entrar por la línea.
5. Con un mineral en el inventario el jugador decide: **dejarlo en un puesto de
   su fábrica**, **venderlo en la tienda** o **dárselo a otro jugador**.

## Mejoras (se compran con dinero)
- **Velocidad**: lo rápido que corre el jugador. Es clave para escapar del ovni.
- **Fuerza**: la potencia del lanzamiento del pico (hasta dónde llega).
- **Pico**: su calidad. Permite romper minerales más duros y mejora la
  probabilidad de sacar minerales mejores.
Ya no hay velocidad de clicks ni minado de cerca.

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

Las probabilidades dependen de la profundidad (zona) y del nivel del pico.
**[mi decisión]** La mina se divide en zonas por distancia a la línea (aprox. 5);
cada zona tiene su tabla de probabilidades, y las zonas lejanas solo dan raros
con buena probabilidad si el pico es bueno.

## Fábrica gigante (almacén)
- Se organiza **por pisos, con 8 puestos por piso**, que van subiendo.
- Para tener más almacenamiento se **compran más pisos**.
- Aquí se guardan minerales en puestos (también sirven para exhibirlos).
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
- No hay minado de cerca ni minado por clicks rápidos.
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
- Controles en móvil y mando para lanzar el pico (apuntar y soltar): por decidir
  al construir el lanzamiento.
