# Neo-Luna — Minería lunar (Roblox)

## Concepto
Juego para todo público (pensado para niños), colorido y amable. El jugador
llega a la Luna y mina minerales cada vez más lejos de la entrada de la mina.
Para minar se acerca al mineral y mantiene E (animación de picar). Cuanto más
lejos, mejor y más raro el mineral, pero un ovni lo persigue y es
más rápido cuanto más profundo está. Un solo mineral por viaje: si cruza la
línea de inicio lo guarda en el inventario; si el ovni lo alcanza, lo pierde.
Los minerales que deja en los puestos de su fábrica generan créditos solos
(tycoon: un objeto que produce dinero automáticamente según qué es).
Con el dinero mejora velocidad, fuerza (pica más rápido) y pico (calidad). Los minerales se guardan en una fábrica gigante por pisos
(8 puestos por piso), se venden, se fusionan (solo raros o superiores) o se
regalan a otros jugadores.

Hasta 5 jugadores por servidor: cada uno con su base, mina compartida pero con
cristales propios para cada jugador, y tiendas (mejoras y Robux) junto a la
entrada de la mina.

Diseño completo: `docs/superpowers/specs/2026-11-14-mineria-lunar-design.md`

> Antes el proyecto fue un tycoon cyberpunk, luego una ciudad lunar. Ambos se
> descartaron. El código de drones/edificios/ciudad es de esas versiones y se
> reemplaza.

## Formato del dinero
Todo el dinero que se muestra lleva el signo `$` delante y es un número entero con comas
(`Config.FormatMoney`), sin "cr" ni "créditos". No se muestra cuánto genera nada por segundo;
solo el total del jugador. (El informe de estantes del panel de admin sí lo muestra, en enteros.)

## Panel de administrador
Botón "ADMIN" (arriba a la izquierda) o la tecla ` abren el panel; solo lo ven los admins.
Admins: los UserIds de `Config.AdminUserIds` (el dueño: 3282659647), el dueño del juego
publicado y quien pruebe en Studio. El servidor valida cada orden (`src/server/Admin.luau`).
Funciones: dar o quitar dinero (a uno mismo o a otro jugador), dar minerales, subir o bajar
mejoras, ir a una zona, informe de estantes.

## Sistemas ya construidos
15 zonas de mina (velocidad mínima por zona y ovni que castiga ir por debajo), 25 minerales,
fábrica de hasta 5 pisos (4 estantes abiertos por piso, el resto se desbloquea pagando),
horno de fusión y altar de renacimiento en la plaza (costo proporcional a lo que gana el
jugador), regalos entre jugadores, "vender todo", y compras con Robux (los Ids de pases y
productos están en `Config.RobuxProducts`; con Id = 0 dice "¡Muy pronto!").

## Revisión del código (sin abrir Studio)
Después de cada cambio: `rojo sourcemap default.project.json -o sourcemap.json` y
`luau-lsp analyze --sourcemap sourcemap.json --ignore "src/shared/Fusion/**" --ignore "src/server/ProfileStore.luau" src`
(ignorar los avisos de "Unknown global", son porque no se cargan las definiciones de Roblox).
Un error de sintaxis en el HUD tumba toda la interfaz del cliente, así que conviene correrlo siempre.

## Pruebas en Studio
- En Studio, el primer jugador aparece en la base 3 (`Config.DevPreferredBase`), la del
  centro. En el juego publicado las bases se reparten en orden: 1, 2, 3, 4, 5.
- Las teclas 1 a 5 eligen el mineral de la mano. Para dinero, minerales o zonas, usa el panel
  de administrador.

## Stack
- Roblox Studio + Rojo (sync de archivos -> Studio)
- Luau
- Fusion (UI reactiva, HUD colorido y redondeado)
- ProfileStore (sucesor de ProfileService, copiado en src/server) para persistencia
- Git/GitHub para versionamiento
- Props generados por código; modelos custom en Blender más adelante

## Estructura
- src/server — economía, guardado, mina, ovni
- src/client — HUD con Fusion y controles
- src/shared — configuración (Config), tipos, Fusion

## Roadmap
Fase 0 Setup (Rojo+Git) -> Fase 1 Prototipo del loop -> Fase 2 Persistencia
-> Fase 3 UI Fusion -> Fase 4 Arte -> Fase 5 Balance -> Fase 6 Monetización
y publicación. El proyecto se reorienta a minería: ver el orden de construcción
en el documento de diseño.
