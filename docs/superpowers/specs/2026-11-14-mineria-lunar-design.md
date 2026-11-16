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

## Panel de administrador
Decisión del dueño: un menú **solo para él o para quien él decida hacer admin**, para dar
dinero, regalar dinero y hacer lo que quiera dentro del juego. Los atajos de prueba de hoy
(solo Studio) pasarán a este panel y funcionarán también en el juego publicado.
- Quién es admin: una lista de UserIds en `Config.AdminUserIds` (el dueño, 3282659647, y a
  quien él agregue). **[mi decisión]** en Studio quien prueba y el dueño del juego publicado
  también cuentan como admin. **Construido.**
- Todo se valida en el servidor (un jugador normal no puede usarlo ni viéndolo). El botón
  del panel solo aparece para admins.
- **[mi decisión, por confirmar]** Funciones iniciales: dar o quitar dinero (a sí mismo o a
  otro jugador), dar minerales, subir o bajar niveles de mejoras, ir a una zona de la mina,
  ver el informe de los estantes.

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
  (genera de a poco, para siempre). **Ingreso (decisión del dueño + mi escala):** un mineral
  común genera **3 créditos por segundo** (el mínimo) y cada rareza genera **3 veces más**
  que la anterior: poco común 9/s, raro 27/s, épico 81/s, exótico 243/s, legendario 729/s.
  Así se nota el cambio apenas el jugador cobra. Un estante junta como máximo 2 horas de
  ingresos.
- **Economía (mi escala, ajustable en Config):** el valor de venta de un mineral es más o
  menos 1 minuto de lo que genera (común ~150-220, poco común ~480-600, raro ~1.400-1.850,
  épico ~4.200-5.400, exótico ~12.500-16.500, legendario ~38.000-48.000). Mejoras:
  Velocidad desde 250 (x1,7 por nivel), Fuerza desde 400 (x1,8), Pico desde 1.500 (x5).
  Dinero inicial: 100. Los pisos se precian cuando se construyan.
- **Todos** los minerales generan créditos cada segundo, sean comunes o raros. La
  interfaz **no muestra cuánto genera** cada mineral ni la base (decisión del dueño);
  el cartel de la base muestra el nombre del jugador y su dinero.
- Cobrar: una placa en el suelo frente a cada estante; el texto va pintado sobre ella.
- **Dejar un mineral en un estante** (decisión del dueño): mantener E junto al estante
  (deja el mineral elegido, o el primero), o pulsar 1 a 5 cerca de un estante vacío
  (deja el mineral de ese espacio de la barra). Mantener E en un estante ocupado lo retira.
  Sobre el estante solo se ve el cristal del mineral, sin textos.
- **Fusión**: solo minerales **raros, exóticos y superiores**; los normales no
  se pueden fusionar. **[mi decisión]** 3 minerales iguales de rareza Raro o
  superior dan 1 mineral de la rareza siguiente.

## Balance actual (15 zonas) **[mi decisión, ajustable en Config.luau]**
- **15 zonas** de 200 studs (mina de 3.000). La rareza de cada zona sale de una curva: cada
  rareza es más común en su "zona central" (Común 1, Poco común 3-4, Raro 6-7, Épico 9-10,
  Exótico 12-13, Legendario 15+); los Comunes y Poco comunes nunca desaparecen del todo.
- **Velocidad mínima por zona** (nivel): 0, 2, 3, 4, 6, 7, 9, 10, 11, 13, 14, 16, 17, 19, 20.
  El ovni va 3 studs/s más rápido que un jugador con ese nivel; con el nivel mínimo o más no
  alcanza, con menos puede alcanzarte (tiene que haber 50 studs de ventaja: aparece a 50 detrás).
- **Costos:** Velocidad 2.500 × 1,65^nivel; Fuerza 5.000 × 1,7^nivel; Pico 15.000 × 4,5^nivel;
  pisos 200 mil / 1,2 M / 7 M / 40 M; estantes 15 mil / 60 mil / 250 mil / 1 M / 4 M (se
  duplica en cada estante). Tiempo de picado: 1 s + 0,25 s por zona.
- Simulación (jugador que compra lo más barato útil): zona 2 a los ~4 min, zona 5 a ~45 min,
  zona 10 a ~3,3 h, zona 15 a ~9 h. Pendiente de probar con jugadores reales.

## Pisos y estantes (decisión del dueño; números **[mi decisión]**, ajustar en el balance)
- La base tiene hasta 5 pisos (Config.MaxFloors), de 8 estantes cada uno. El piso 1 viene con
  la base; los demás flotan encima (30 studs) y se suben por una **escalera vertical** al fondo de la base (centro del lado oeste) y se apoyan en
  columnas en las esquinas. **Fusión**: un solo horno en el centro de la plaza, lo usa cualquiera con sus propios minerales (nadie puede robar, no hay robo
  en el juego); 3 minerales de la misma rareza (Raro o superior) dan 1 de la siguiente.
- Cada piso comprado viene con **4 estantes desbloqueados**; los otros 4 se desbloquean **de a
  uno, en orden, pagando**. Se compran en la terminal "NUEVO PISO" de la base y en el propio
  estante bloqueado (mantener E).
- Precios de piso: 20.000 / 120.000 / 700.000 / 4.000.000. Estante (5º a 8º): base del piso
  (1.500 / 6.000 / 25.000 / 100.000 / 400.000) y se duplica con cada estante.

## Renacimiento (decisión del dueño; números **[mi decisión]**) — construido
- Al renacer **solo se pierde el dinero**; mejoras, minerales, pisos y estantes se conservan.
- Cada renacimiento da un **multiplicador permanente a lo que generan los estantes**, mayor
  con cada uno, y **cada renacimiento cuesta más que el anterior**.
- Máximo 10; **el costo es proporcional a lo que gana el jugador**: el primero cuesta 2 horas de
  lo que generan sus estantes (con el multiplicador que ya tiene) y cada renacimiento suma un
  30 % más de horas que el anterior (2 h, 2,6 h, 3,4 h...). Se usa el máximo que han generado
  (PeakIncome) para que quitar minerales no lo abarate; mínimo $50.000. +50 % de ganancia en los
  estantes por renacimiento (hasta ×6). Se renace en el altar de la plaza; la base muestra ★N
  junto al nombre. Al renacer se cobra antes lo que juntaron los estantes. Admin: +1, -1, Máx, 0.

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
