# Editar la configuración de Hyprland

La configuración personal empieza en `hypr/.config/hypr/hyprland.lua`.
HyDE aporta sus valores base y este archivo carga las preferencias personales.
Las rutas de la tabla son relativas a `hypr/.config/hypr/lua/`.

## Dónde cambiar cada cosa

| Cambio | Archivo que conviene leer primero |
| --- | --- |
| Agregar una app, su atajo, escritorio o arranque | `apps.lua` |
| Cambiar un atajo general, de volumen o de navegación | `bindings.lua` |
| Cambiar Kanata, monitores o Waybar según la computadora | `machines.lua` |
| Cambiar apariencia, animaciones o comportamiento general | `options.lua` |
| Cambiar teclado, mouse, touchpad o gestos | `input.lua` |
| Cambiar blur de Rofi, notificaciones o Waybar | Final de `rules.lua` |
| Agregar un servicio al inicio de sesión | `events.lua` |
| Corregir Ctrl+T, foco de Spotify, letras o movimiento de ventanas | `behaviors.lua` |
| Corregir la secuencia de arranque | `autostart.lua` |
| Corregir el cambio de escritorios al conectar un monitor | `workspaces.lua` |
| Corregir la selección o recarga de Waybar | `waybar.lua` |

Para un cambio cotidiano, empezá por la fila correspondiente. Para investigar
una automatización, leé después su módulo y las dependencias indicadas al
principio del archivo. Este mapa también sirve para limitar el contexto que
necesita leer una IA.

## Agregar una aplicación

Agregá una entrada a la lista de `apps.lua`:

```lua
{
    id = "notes",
    class = "notes.app",
    command = "notes",
    workspace = "6",
    key = "SHIFT + B",
    startup = "parallel",
},
```

Esto registra `Super+Shift+B`, asigna sus ventanas al escritorio 6 y la inicia
automáticamente. No necesitás agregar líneas en los módulos de atajos, reglas
o arranque. El comando debe estar instalado; `class` debe coincidir con la
clase real de su ventana, que podés consultar con `hyprctl -j clients`.

Todos los campos salvo `id` dependen de lo que quieras configurar:

| Campo | Significado |
| --- | --- |
| `id` | Nombre único y estable dentro del catálogo |
| `class` | Clase literal y completa de la ventana |
| `class_prefix` | Prefijo literal, para aplicaciones cuyas clases varían |
| `command` | Comando para abrirla |
| `workspace` | Escritorio numérico como `"6"`, o especial como `"special:notes"` |
| `key` | Tecla/combinación después del modificador principal; omitirla evita crear un atajo |
| `startup` | Etapa de arranque; omitirla evita iniciar la aplicación automáticamente |
| `properties` | Preferencias de sus ventanas, por ejemplo `float`, `opacity` o `group` |

Un atajo con escritorio especial muestra/oculta ese escritorio. Un atajo con
escritorio numérico o sin escritorio ejecuta `command`. Las ventanas se ubican
mediante las reglas generadas a partir del mismo catálogo.

Las etapas de arranque son:

- `sequential`: abre una app por vez y espera su ventana, hasta cinco segundos.
- `parallel`: abre juntas las apps de esta etapa después de las secuenciales.
- `last`: abre las apps finales cuando las anteriores están listas o agotaron
  su espera. Actualmente contiene el navegador principal.

El orden dentro de cada etapa es el orden de la lista. Si ya existe una ventana
de la aplicación, se omite su comando. Al recargar Hyprland se vuelve a revisar
la lista para completar el arranque: una app marcada para inicio automático
que hayas cerrado manualmente puede abrirse otra vez.

Los escritorios 1–4 tienen además la política de monitor de `workspaces.lua`.
Agregar una app al escritorio 6 no modifica esa política.

## Cambiar un atajo o una preferencia

Para aplicaciones, cambiá `key` en su entrada de `apps.lua`. Para acciones
generales, editá o agregá una línea en `bindings.lua`:

```lua
bind(mainMod .. " + SHIFT + Q", exec("mi-comando"))
```

El modificador principal está declarado una sola vez en `hyprland.lua`.
El helper `bind` reemplaza los atajos de HyDE que usan esa misma combinación.

Para apariencia general, editá los valores de `options.lua`, por ejemplo
`master.mfact`. Para una aplicación concreta, editá `properties` en su entrada.
Las constantes de opacidad al principio de `apps.lua` reúnen los valores
compartidos; una entrada puede usar una cadena propia si necesita otra opacidad.

## Agregar una computadora

Agregá su hostname como entrada en la tabla de `machines.lua` y definí:

```lua
mi_equipo = {
    kanata = false,
    waybar_layout = "francos_bar_desktop",
    monitors = {
        { output = "DP-1", mode = "2560x1440@60", position = "0x0", scale = 1 },
    },
    workspace_monitors = { "DP-1" },
},
```

Usá los nombres/descripciones de `hyprctl -j monitors`. En
`workspace_monitors`, el primer monitor conectado tiene prioridad para los
escritorios 1–4. `zenbook` ya prioriza el externo y después su panel integrado.
Un hostname desconocido no inicia Kanata ni impone modos de monitor o Waybar.

## Campos de compatibilidad y acciones especiales

Las entradas migradas tienen algunos campos adicionales para conservar su
comportamiento anterior:

- `runtime_suffix`: estrecha el prefijo que se usa al detectar ventanas en
  arranque/búsqueda. Las PWAs usan `"__"`; la regla de escritorio mantiene el
  prefijo más amplio de `class_prefix`.
- `match`: reemplaza la coincidencia generada para reglas de ventana. Son
  expresiones RE2, conservadas de la configuración original. Las clases
  literales de `class`/`class_prefix` se escapan automáticamente al generar
  reglas; no requieren escribir regexes.
- `workspace_match`: agrega condiciones solamente a la asignación de
  escritorio. La terminal `term` conserva su condición por título, sin
  restringir su regla de opacidad.
- `search`: el atajo que reemplaza Ctrl+T en esa app. `class` dentro de `search`
  restringe esa excepción a una clase exacta, como en WhatsApp.
- `action`: nombre de una función de `behaviors.lua` que reemplaza el atajo
  ordinario. Actualmente se usa para Spotify y letras de canciones.
- `focus_class`: clase exacta que usa la acción de Spotify al buscar su ventana.
- `bind_options`: opciones del atajo, como su descripción.

La pareja de eventos de pulsar/soltar en `behaviors.lua` evita que la tecla quede
presionada al reenviarla a Vivaldi. La supresión temporal del foco de Spotify
evita enviar su búsqueda dos veces al abrir el escritorio especial.

## Cómo se conectan los módulos

`hyprland.lua` construye las dependencias antes de configurar sus consumidores:

1. `machines.lua` selecciona el perfil.
2. `apps.lua` proporciona los datos; `app_helpers.lua` los valida, indexa e
   interpreta las coincidencias de ventana.
3. `behaviors.lua` devuelve las acciones especiales y registra el foco de Spotify.
4. `autostart.lua` devuelve la función de inicio y registra eventos de ventanas.
5. Los módulos de preferencias, atajos y reglas usan esas dependencias.
6. `events.lua` conecta el inicio/recarga con la función de arranque.

Los módulos reciben `ctx`: rutas (`home`, `scrPath`), modificador (`mainMod`),
helpers de atajos (`bind`, `exec`), perfil (`machine`), catálogo (`apps`,
`appsById`, `appHelpers`), acciones (`actions`) y función de arranque
(`startDesktopApplications`). Sus encabezados identifican las dependencias
menos evidentes. Las configuraciones antiguas se conservan como referencias
inactivas y no forman parte de esta cadena.

## Comprobar cambios

Desde la raíz del repositorio, con `lua` y `luac` instalados:

```bash
bash tests/hypr/check.sh
```

Comprueba la sintaxis y simula arranque, recargas, atajos y conexión de monitores.
Las pruebas no abren aplicaciones ni alteran la sesión. También permiten
validar una copia antes de aplicarla:

```bash
bash tests/hypr/check.sh /ruta/a/la/copia/hypr
```

Los archivos enlazados a `~/.config/hypr` pueden provocar una recarga al
guardarlos. Para un refactor que cambia varios módulos, trabajá en una copia
aislada, verificá el conjunto completo y aplicalo junto. Después de aplicarlo:

```bash
hyprctl reload
hyprctl configerrors
```

Las pruebas simuladas cubren la lógica personal. La recarga real verifica la
API del compositor; la prueba física de conectar/desconectar monitores se hace
en la computadora correspondiente.
