# Auditoría Tartarus frente a Caelestia

## Alcance

Revisión estática del árbol .config/quickshell/tartarus-shell (128 archivos
en el inventario), comprobación QML global con Qt 6 y lectura dirigida de
entrypoint, estado, ventanas, Sidebar, servicios, launcher, tray, red,
notificaciones, multimedia, OSD, Power, estilos y scripts de wallpaper/theme.
No es una validación funcional de todos los módulos ni de todas las rutas.
Se compararon los repositorios locales Repositorios/shell, caelestia y cli.
No se ejecutaron controles de hardware, cambios de wallpaper ni acciones de sesión.

## 1. Bloqueante: Sidebar invisible y captura de entrada

Archivo: shell/SidebarOverlay.qml.

- PanelWindow no declara id: root; el drawer utiliza root.offsetScale.
  Puede resolver un root del contexto exterior, que tampoco proporciona esta
  propiedad. La referencia no apunta al objeto que declara offsetScale.
- La ventana ocupa toda la pantalla y tiene un MouseArea que captura entrada.
  Una superficie transparente con contenido inválido explica el aparente bloqueo;
  no hay evidencia de que el compositor esté congelado.
- visible depende del monitor enfocado: cambia al mover el cursor y contradice
  el estado sidebarOpened independiente por pantalla.
- El margen derecho positivo desplaza el contenido hacia dentro al cerrarse.
  Caelestia utiliza un margen negativo para retirarlo hacia el borde exterior.
- Se animan margen y opacidad, pero visible cambia inmediatamente.
  La animación de cierre no puede terminar con la ventana ya oculta.
- No hay cierre por Escape/focus grab, ni interacción en el icono de cerrar.
- ColumnLayout sin scroll puede desbordarse al acumular controles.

Patrón de referencia:
Repositorios/shell/modules/sidebar/Wrapper.qml anima offsetScale;
ContentWindow.qml coordina mask/Regions, teclado y HyprlandFocusGrab.
ScreenState.qml mantiene las aperturas por pantalla.

Corrección propuesta: identidad QML explícita, estado local estable, una sola
progresión animada, ventana viva hasta finalizar el cierre y gestión deliberada
de entrada/foco. Mantener barra superior y ausencia de marcos de Tartarus.

## 2. Power: alcance y confirmaciones

Archivos: services/PowerService.qml, services/SidebarService.qml, shell.qml.

- logout ejecuta loginctl terminate-user: afecta todas las sesiones del usuario,
  no solamente la sesión gráfica actual.
- pendingPower es global y no se limpia al cerrar la Sidebar por monitor.
- confirmPower invoca dinámicamente una propiedad del servicio sin lista explícita
  de acciones aceptadas.
- El IPC power permite ejecutar acciones sin pasar por confirmación visual.
- loginctl lock-session necesita un gestor de bloqueo que atienda la solicitud;
  el código no confirma que exista ni informa el resultado.
- Falta informar errores de los procesos.

No validar logout/apagado/reinicio hasta definir la política de ejecución.
Caelestia separa contenido de sesión y SessionManager/configuración de comandos.

## 3. Tray: contrato roto

Archivo: bar/components/SystemTray.qml (llamadas menuAnchor.open()).
TrayMenu.qml no ofrece open(): ahora expone popupOpen.
Los clics que siguen usando open() producirán TypeError.
La flecha hasChildren se dibuja pero no existe navegación de submenús.
visible depende directamente de popupOpen, impidiendo la animación de salida.

## 4. Notifications: persistencia y vida útil

- services/NotificationService.qml guarda el modelo en su orden actual, inserta
  nuevas entradas al principio, pero loadHistory invierte todo con reverse().
  No garantiza recientes primero; puede alternar el orden entre reinicios.
- recordHistory identifica por id del servidor incluso tras restaurar historial.
  Debe separarse identidad persistente de ids efímeros para evitar colisiones.
- removeHistory solo elimina historial: no cierra el popup correspondiente.
- NotificationOverlay instancia todas las notificaciones en cada monitor y pone
  temporizadores en cada delegate, incluso cuando no se ve allí. La caducidad
  depende de vistas duplicadas en lugar del servicio.
- El límite de tres se calcula por índice global, no por notificaciones de cada
  monitor.
- NotificationCenter usa apertura global y visibilidad ligada al foco. Por eso
  puede seguir al cursor aunque la Sidebar tenga otra política.
- mediaLabel examina summary para emojis, aunque los ejemplos de Vesktop traen
  el marcador en body. Detectar GIF por cualquier aparición de esa palabra
  también puede producir falsos positivos.
- Las referencias image:// de Quickshell no son archivos persistentes garantizados.

Separar entidad/historial, temporizador global del evento y presentación local.
No afirmar que GIFs/emoji adicionales llegan por otro campo sin comprobarlo.

## 5. Red: métricas y dibujo

Archivos: plugins/network/Service.qml y PanelContent.qml.

- La interfaz se detecta una vez al iniciar, priorizando patrones Wi-Fi;
  no sigue cambios de ruta, desconexiones o cambio a Ethernet.
- El fallback wlan0 es específico de una máquina.
- No se reinicia la línea base de contadores al cambiar interfaz.
- Las barras usan una fórmula de índice y módulo del valor actual: no son un
  historial temporal del tráfico.
- Las últimas ocho tasas se promedian aritméticamente; para intervalos irregulares
  conviene sumar bytes y dividir por tiempo acumulado.
- Se ejecuta sh/cat cada 500 ms incluso sin mostrar el panel.

La UI debe consumir muestras reales y el backend resolver explícitamente la
interfaz seleccionada. El uso de contadores acumulados como base es correcto.

## 6. Multimedia

MediaService inicia playerctl cada segundo y separa metadatos con "|".
Un título que contenga ese carácter rompe la separación.
Los comandos no fijan el reproductor mostrado ni exponen capacidades/errores.
Caelestia services/Players.qml usa Quickshell.Services.Mpris con reproductor
activo explícito y propiedades observables, sin polling de subprocess por segundo.

## 7. Brillo y OSD

- Sidebar usa 0..100 (porcentaje) pero setBrightnessForScreen recibe valor bruto.
  El panel original utiliza maxBrightness del dispositivo: copiar ese contrato.
- Los sliders no se deshabilitan sistemáticamente cuando falta el dispositivo.
- Audio tiene varios disparadores de OSD: observadores, setters y binds con IPC.
  Pueden producir actualizaciones redundantes; conviene una política común.
- showBrightness y showMute del IPC aún son demostraciones con valores fijos,
  no consultas reales del brillo/micrófono.

## 8. Wallpaper y schemes

La prueba realizada por el usuario confirmó restauración por monitor al iniciar
sesión; conservar esa funcionalidad.

- wallpaper.py current sigue devolviendo path global; el selector compara contra
  él y puede marcar un wallpaper activo incorrecto para una salida.
- write_active hace read-modify-write sin escritura atómica/bloqueo.
  Selecciones simultáneas por monitor pueden perder actualizaciones.
- apply-saved oculta errores individuales y puede finalizar sin informar fallos.
- El camino de aplicación per-monitor con hyprpaper evita la preparación de
  set_hyprpaper. El fallback de recuperación reinicia el backend compartido,
  con posibles efectos sobre otras salidas.
- Themes/Wallpapers son instancias del launcher, no un estado compartido que
  garantice refresco cruzado entre monitores.

En el CLI de Caelestia, utils/wallpaper.py conserva una referencia global,
actualiza miniaturas y llama a scheme.update_colours()/apply_colours().
utils/scheme.py distingue scheme fijo y dynamic. Los dotfiles consumen los
colores mediante archivos como hypr/scheme/current.lua.
Adaptar esa separación, no ejecutar el instalador ni sustituir nuestros dots.

## 9. Estilo y arquitectura

Tartarus dispone de una buena base: PluginRegistry, servicios reutilizables,
MonitorShell y Style/Color. No requiere reescritura completa.

Deuda principal:
- aperturas distribuidas entre contextos locales y booleanos singleton;
- llamadas al registro repetidas y sin manejo consistente de servicios ausentes;
- botones Media/Power con nombres de iconos como texto, no MaterialIcon;
- estados activos de quick toggles no reflejados visualmente;
- escasez de controles compartidos para botones, sliders y tarjetas;
- animaciones duplicadas, números fijos y visible que corta transiciones;
- SidebarService conserva un segundo estado open que la vista ya no utiliza.

Caelestia ofrece ScreenState, wrappers, regiones de entrada, Anim y controles
estilizados compartidos. Adoptar esos principios con los tokens de Tartarus,
sin copiar sus dependencias nativas ni su marco alrededor de la pantalla.

## Validación realizada

- git diff --check: sin salida.
- QML global: /usr/lib/qt6/bin/qmllint (6.11.2).
- Registro de diagnósticos: /tmp/tartarus-review-qml.log (temporal).
- Se obtuvieron 159 líneas de Warning/Error; no equivalen a 159 bugs.
  Hay diagnósticos por metadatos/tipos de Quickshell, propiedades dinámicas
  y accesos no cualificados; requieren clasificación.
- El qmllint del PATH informa versión 1.0 y ofrece otro conjunto de verificaciones.
  Las anteriores declaraciones generales de "qmllint OK" no demostraban que el
  shell cargara o funcionara.
- No se inició otra instancia del shell: competiría con servicios de sesión.
- No se ha corregido código funcional en esta auditoría.

## Orden propuesto

1. Recuperar Sidebar: root, geometría, transición, entrada, Escape y cerrar.
2. Unificar ScreenState/contratos de apertura por monitor y limpiar confirmaciones.
3. Restringir Power y corregir contratos rotos del tray.
4. Corregir ciclo de vida e historial de notificaciones.
5. Componentes visuales compartidos y MPRIS; ajustar sliders.
6. Red con muestras reales y wallpaper con estado coherente/errores explícitos.
7. Probar startup, recarga, dos monitores, cambios de foco y ausencia de servicios.
8. Retomar scheme dinámico y nuevas funciones después de estabilizar la base.

## Auditoría ampliada: workspaces y repositorios de Caelestia

Se revisaron los 128 archivos del shell de Tartarus y los repositorios locales de Caelestia: shell (469 archivos), dots (57) y CLI (90). La comparación fue arquitectónica y de integración; no se copiaron dependencias nativas ni se instalaron los dots completos.

### Workspaces

Tartarus ya separa `Service`, `BarWidget` y `Workspace`, y calcula el workspace activo mediante `Hyprland.monitorFor(screen)`. La base por monitor es correcta, pero hay diferencias importantes:

- `workspaceBaseByMonitor` está fijado a `DP-2` y `HDMI-A-1`; cambiar nombres o hardware puede romper la agrupación.
- `activateWorkspaceForScreen()` enfoca primero el monitor y luego activa el workspace; es válido, pero el cambio de foco es un efecto lateral que debe probarse.
- El clic sobre el workspace activo fuerza el special genérico `special`, en vez de conservar necesariamente el special concreto activo.
- `specialWorkspacesForScreen()` presupone que `workspace.monitor` siempre identifica correctamente el monitor del special.
- No existe todavía un estado persistente por pantalla equivalente a `ShellState`/`ScreenState` de Caelestia.
- La UI usa una píldora y barras decorativas; Caelestia separa workspace, indicador activo y specials, y anima escala, opacidad, tamaño y revelado con tokens comunes.
- La configuración de Tartarus para workspaces es mayormente fija; Caelestia expone `shown`, `showUnoccupied`, `showWindows`, `maxWindowIcons` y el tipo de indicador.

### Arquitectura comparada

Caelestia organiza `Hypr`/`ShellState` por pantalla, componentes registrados por pantalla, ventanas con focus grabs y módulos visuales. Tartarus tiene una base equivalente con `MonitorShell`, `ShellState`, `PluginRegistry` y servicios, pero varios estados de UI todavía se resuelven directamente en vistas o singletons globales. Esto afecta Sidebar, NotificationCenter, OSD y wallpapers.

Caelestia centraliza animaciones en `Anim.qml` y tokens de configuración. Tartarus repite duraciones y `Behavior` en distintos componentes, lo que puede producir estilos y transiciones inconsistentes.

El CLI de Caelestia gestiona principalmente dots, schemes, wallpapers, clipboard y screenshots. No debe tratarse como backend directo del shell sin adaptar rutas, persistencia y manejo de errores.

### Prioridad resultante

1. Estabilizar Sidebar, focus y estado por monitor.
2. Definir un `ScreenState` persistente común para Sidebar, launcher, OSD, notifications y wallpaper.
3. Centralizar tokens y animaciones compartidas.
4. Revisar workspaces y specials con dos monitores antes de cambiar más su estética.
5. Corregir tray, lifecycle de notificaciones, MediaService y persistencia de wallpapers.
6. Después abrir calculadora científica, clima, calendario y hardware como servicios independientes.
