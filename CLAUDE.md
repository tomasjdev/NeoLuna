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

## Herramientas de prueba (solo en Studio)
- En Studio, el primer jugador aparece en la base 3 (`Config.DevPreferredBase`), la del
  centro. En el juego publicado las bases se reparten en orden: 1, 2, 3, 4, 5.
- Teclas 1 a 5: teletransporta al inicio de esa zona de la mina. Tecla 0: +10.000 créditos.
  Tecla 9: te da un Cristal alienígena (épico). Los servidores publicados lo ignoran.

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
