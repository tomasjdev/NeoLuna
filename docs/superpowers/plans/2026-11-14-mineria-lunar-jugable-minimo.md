# Minería lunar — jugable mínimo (plan)

> Para quien ejecute: implementar tarea por tarea. No hay tests automáticos
> (Roblox/Luau sin framework configurado): cada tarea se verifica con
> `rojo build -o <tmp>.rbxl` (debe compilar) y una prueba manual en Studio.

**Meta:** primera versión jugable del diseño: mina con zonas, minerales con
rareza, lanzamiento del pico, ovni perseguidor, cruzar la línea, inventario
(10 espacios, 5 visibles + mochila), tienda y tres mejoras.

**Arquitectura:** el servidor es la autoridad (datos, minado, ovni, ventas,
mejoras). El cliente solo muestra (HUD con Fusion) y envía intenciones
(lanzar, comprar, vender). Toda la configuración y fórmulas viven en
`src/shared/Config.luau`.

**Tecnología:** Roblox + Rojo, Luau, Fusion 0.3, ProfileStore.

**Diseño:** `docs/superpowers/specs/2026-11-14-mineria-lunar-design.md`

## Restricciones globales
- Mínimo 10 espacios de inventario; el HUD muestra 5; la mochila muestra todos.
- Un solo mineral por viaje; el ovni acelera con la profundidad.
- Estilo colorido y amable (pastel, redondeado, fuente FredokaOne), sin neón.
- No hay minado de cerca ni por clicks rápidos.

## Foco de revisión (comportamientos que el diseño no menciona)
- Lanzar el pico con la mochila llena: avisar y no gastar el viaje.
- Jugador que muere o sale mientras lleva un mineral: limpiar ovni y mineral.
- Clientes que mandan datos falsos (posición NaN, índices fuera de rango,
  compras sin estar en la tienda): el servidor valida todo.
- Dos jugadores lanzando al mismo nodo: solo uno se lo lleva.
- Cruzar la línea con el ovni encima: se salva si cruza antes de ser alcanzado.

## Tareas
1. **Config** (`src/shared/Config.luau`): rarezas, minerales, zonas con pesos,
   mejoras, ovni, funciones `GetZone`, `RollMineral`, `GetUpgradeCost`,
   `GetWalkSpeed`, `GetThrowRange`, `GetUfoSpeed`.
2. **Datos del jugador** (`src/server/Economy.luau`): perfil con dinero,
   niveles e inventario; `AddMineral`, `Sell`, `PurchaseUpgrade`.
3. **Props y mundo** (`Props.luau`, `WorldBuilder.luau`, `BuildingModels.luau`
   recortado a la tienda): ovni, pico lanzado, gema que se carga, base con
   tienda, entrada con línea, zonas, paredes, carteles de profundidad.
4. **Mina** (`src/server/MineService.luau`): nodos, lanzamiento, minerales,
   ovni, captura, entrega.
5. **Servidor principal** (`Main.server.luau`): remotes, velocidad, tienda.
6. **HUD y cliente** (`HUD.luau`, `Main.client.luau`): dinero, profundidad,
   barra de 5, mochila, tienda con mejoras y venta, avisos, lanzar con clic o
   toque.
7. **Limpieza y publicación**: borrar drones/edificios, compilar, commit y push.
