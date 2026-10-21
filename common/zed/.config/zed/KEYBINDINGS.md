# Neovim → Zed

**Estado: migración revertida durante el diagnóstico de Inline Assist.**
El keymap activo conserva la configuración anterior, con cuatro duplicados
eliminados: `Ctrl+Enter`, `Shift+Enter`, `Alt+Enter` en `Editor && mode == full`,
y `Tab` en `Editor && edit_prediction`. Se conservan las acciones que antes
prevalecían: Inline Assist, Expand Excerpts, Open Excerpts y Accept Edit Prediction.
No se modificaron modelos ni autenticación.

El resto de este documento describe el borrador de migración, **no los atajos
activos**. Los tests verifican ahora el keymap activo y detectan definiciones
repetidas entre bloques del mismo contexto.

`SPC` = Espacio. Salvo indicación contraria, estos atajos funcionan en un editor
de archivo, en modo Normal y sin un menú abierto. No se aplican a los inputs del
agente ni a los pickers. Los mappings existentes de navegación del agente y las
pestañas se conservan.

Los atajos de IA en Visual (`SPC ae/ac/aa`) conservan exactamente el bloque
original, con contexto `vim_mode == visual`, antes del bloque Insert. No se les
agregan restricciones `mode == full` ni `!menu`. El surround Visual `S` se
configura por separado.

## Navegación y edición

| Tecla | Acción |
| --- | --- |
| Flechas | Movimiento Vim; izquierda/derecha cruzan líneas como `whichwrap` |
| `h j k l` | Deshabilitados en Normal/Visual (no en modo operador) |
| `Home` / `End` | Primer / último carácter no blanco (`^` / `g_`) |
| `Ctrl+Right` / `Ctrl+Left` | Inicio de palabra siguiente/anterior (`w` / `b`) |
| `Alt+i` / `Alt+e` | Página anterior/siguiente |
| `Ctrl+n/e/i/o` | Pane izquierdo/inferior/superior/derecho |
| `Ctrl+=` | Igualar tamaños de panes |
| `Ctrl++` / `Ctrl+-` / `Ctrl+0` | Aumentar/reducir/restaurar fuente |
| `t` | Sneak: salto buscando dos caracteres, no Leap entre ventanas |
| `s{motion}` / `ss` / `S` | Reemplazar con registro: movimiento / línea / hasta fin de línea |
| Visual `s` | Reemplazar selección con registro |
| `ys`, `yss`, `cs`, `ds` | Surround nativo |
| Visual `S` | Añadir surround |

Flechas, Home/End, movimientos por palabra y `s` también funcionan en Visual.
`gr` abre referencias; sigue siendo prefijo de bindings como `grn`/`grr`, por lo
que puede esperar el timeout del chord. `ga`/`gr` aceptan/rechazan cambios solo
en la vista de revisión del agente.

## Guardado, cierre y terminal

| Tecla | Acción |
| --- | --- |
| `Ctrl+w Ctrl+w` / `Ctrl+w Ctrl+a` | Guardar archivo / todos |
| `Ctrl+q Ctrl+q` | Cerrar el item activo en todos los panes (aproximación a `:bd`) |
| `Ctrl+q Ctrl+w` | Cerrar la vista/pestaña activa (no todo un pane con varias pestañas) |
| `Ctrl+q Ctrl+a` | Cerrar la ventana actual de Zed, no todas las ventanas de la aplicación |
| `Ctrl+t` en Normal/Insert | Enfocar/alternar terminal |
| `Ctrl+t` en terminal | Alternar dock inferior (binding existente) |
| `Ctrl+Backspace` en Insert/terminal | Borrar palabra / enviar `Ctrl+w` (existente) |

Los prefijos `Ctrl+q` y `Ctrl+w` no ejecutan una acción destructiva al vencer su
timeout en Normal. Los cierres conservan las confirmaciones de Zed; no se usa
`save_intent: skip`. Los atajos de guardado/cierre de Neovim no se hacen globales
para no interferir con Insert, terminales e inputs. `Esc` sigue llegando al
terminal; no se intercepta para simular el buffer terminal de Neovim.

## Búsquedas y herramientas

| Tecla | Acción |
| --- | --- |
| `SPC SPC`, `SPC fg` | Buscar archivos del proyecto abierto |
| `SPC fr` | Buscar archivos con historial separado/priorizado |
| `SPC fs` | Búsqueda literal en proyecto |
| `SPC fc` | Búsqueda literal por palabra completa; Zed propone selección/palabra o búsqueda activa |
| `SPC ff` | Outline: todos los símbolos, no solo funciones/métodos |
| `SPC ft`, `SPC xt` | Búsqueda regex de etiquetas TODO/FIXME/NOTE/etc. seguidas de `:` |
| `]t` / `[t` | Siguiente/anterior etiqueta en el archivo; modifica la búsqueda del buffer |
| `SPC fp`, `Ctrl+s` | Proyectos recientes, en la misma ventana |
| `SPC t` | Tab switcher |
| `Ctrl+d` en Tab Switcher | Cerrar el item seleccionado |
| `SPC dn` / `SPC dN` | Diagnóstico siguiente/anterior |
| `SPC dd` / `SPC xw` | Diagnósticos del archivo / proyecto |
| `SPC mp` en Markdown | Abrir preview interno |
| `SPC ll`, `SPC li` | Extensiones |

Los TODOs se buscan como texto, no solo dentro de comentarios. `SPC fg` no cambia
la raíz: abre Zed desde la raíz Git si quieres ese alcance. `SPC fr` no reproduce
el historial global de `oldfiles`, y `SPC fp`/`Ctrl+s` no reproducen el escaneo de
repositorios ni las sesiones de AutoSession. El tab switcher no es el modelo de
buffers/tabpages de Neovim.

En File Finder se conservan `Ctrl+x`/`Ctrl+v` para split inferior/derecho. En los
inputs de búsqueda de proyecto, `Ctrl+e`/`Ctrl+i` recorren el historial. Abrir un
resultado no incluye el selector de ventana destino de Snacks/Telescope.

`SPC SPC`, `SPC e`, `SPC fp`, `SPC aa` y `Ctrl+s` también funcionan en
Welcome/EmptyPane. `Ctrl+s` en Insert mantiene signature help.

## Explorador, Git e IA

- `SPC e`: Project Panel, no Fyler. Dentro del explorador, `^`/Backspace
  seleccionan el padre y `Ctrl+t` abre una pestaña permanente. Backspace deja de
  enviar el archivo a la papelera; Delete mantiene la operación existente.
- `SPC gg`: Git Panel; `SPC gn`/`SPC gN`: hunk siguiente/anterior;
  `SPC gb`: blame de Zed, no el mismo toggle inline de Gitsigns.
- En la lista de cambios Git: `s`/`u` stage/unstage del archivo; `S`/`U`
  stage/unstage de todos; `Ctrl+s` stage de todos; `x` restaura **con confirmación**;
  `gf` abre el archivo; `c` enfoca el editor de commit; `f` fetch, `p` pull, `P` push
  (no force push).
- En el editor de commit: `Ctrl+c Ctrl+c` confirma, `Ctrl+c Ctrl+k` cancela,
  `SPC gc` en Normal genera el mensaje con la IA de Zed. La generación usa su configuración,
  no el prompt `/commit_message` de CodeCompanion.
- `SPC aa` y `SPC ac` en Normal: enfocar/alternar agente. `SPC aa` no es la paleta
  de acciones de CodeCompanion.
- `SPC ae`: abre directamente Inline Assist sobre la línea actual; en Visual
  usa la selección. No requiere simular Visual ni reenviar el mismo atajo.
- Visual `SPC ac`: añadir selección al hilo; Visual `SPC aa`: citar selección.

## Pendientes deliberados

No se agregan atajos que finjan funcionalidades inexistentes o tasks sin definir:

- `SPC ai`: requiere portar CtxIngest a un script/task de clipboard.
- `SPC ml`: requiere definir linters por proyecto/lenguaje; ejecutar una task no
  publica automáticamente diagnósticos.
- `SPC mp` fuera de Markdown: requiere servidor de preview externo/task.
- `SPC xq`/`SPC xl`: no hay una quickfix/location list general equivalente.
- Mutaciones de Fyler, selección de ventana con etiquetas y Leap entre ventanas.
- Menús avanzados y editor de rebase interactivo de Neogit.
- `SPC rc`, `SPC lu`: sin traducción literal; Zed recarga su configuración y
  gestiona extensiones de otra manera.

## Validación

Ejecutar desde la raíz del repo:

```sh
python3 tests/test-zed-keymap.py
```

Los tests comprueban JSONC, claves duplicadas y regresiones de los overrides.
No sustituyen una prueba interactiva con tu versión de Zed. Las acciones se
contrastaron con el código oficial de Zed (`main`); si alguna aparece como
inválida en tu instalación, comprobar la versión y `zed: open keymap`.

Probar especialmente: `s`/`ss`/`S` y repetición `.`, registros nombrados, selección
Visual, `Ctrl+t` desde Insert, cierres con cambios sin guardar, navegación con
completado abierto y `SPC ae`. Para inspeccionar precedencias usar
`dev: open key context view`.

Referencias: [Vim](https://zed.dev/docs/vim),
[keybindings](https://zed.dev/docs/key-bindings),
[tasks](https://zed.dev/docs/tasks).
