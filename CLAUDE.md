# Neo-Luna — Tycoon Cyberpunk Lunar (Roblox)

## Concepto
Ciudad lunar estilo cyberpunk (domo de neón, torres corporativas). El jugador
automatiza un distrito industrial: drones extraen regolito/minerales fuera del
domo, se procesan en fábricas, se venden a corporaciones de la ciudad.
Gancho: estética cyberpunk fuerte + profundidad real de optimización de
logística (rutas de drones, cadenas de producción).

## Stack
- Roblox Studio + Rojo (sync de archivos -> Studio)
- Luau
- Fusion (UI reactiva, HUD holográfico, estilo dashboard)
- ProfileService (persistencia de progreso)
- Git/GitHub para versionamiento
- Props custom en Blender (gratuito), piezas base construidas en Studio

## Estructura
- src/server — generadores, economía, guardado
- src/client — UI con Fusion
- src/shared — configuración de items, tipos, constantes

## Roadmap
Fase 0 Setup (Rojo+Git) -> Fase 1 Prototipo del loop -> Fase 2 Persistencia
(ProfileService) -> Fase 3 UI Fusion -> Fase 4 Arte cyberpunk -> Fase 5 Balance
-> Fase 6 Monetización y publicación

GDD completo: https://claude.ai/artifact/VM2SE17cPUB9s6EZRGcUuP