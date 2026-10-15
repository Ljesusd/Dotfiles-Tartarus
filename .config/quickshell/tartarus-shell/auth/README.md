# Autenticador Tartarus

Agente de sesión independiente, con frontend Qt Quick/QML y backend `polkit-qt6`.
No necesita Quickshell en ejecución y sobrevive a sus recargas. Lee los colores
de `$XDG_STATE_HOME/tartarus-shell/active-theme.json` al abrir cada solicitud.

## Compilar y comprobar

Dependencias en Arch: `cmake`, `ninja`, `gcc`, `qt6-base`, `qt6-declarative`,
`polkit-qt6` y `polkit`. No instala paquetes ni necesita root para compilar.

```sh
~/.config/quickshell/tartarus-shell/scripts/polkit-agent.sh --build
~/.config/quickshell/tartarus-shell/scripts/polkit-agent.sh --preview
```

El binario y los tests se generan fuera del repositorio, en
`${XDG_CACHE_HOME:-~/.cache}/tartarus-shell/polkit`. Vuelve a compilar al cambiar
el código. `--preview` no registra Polkit y desactiva la entrada de contraseñas.
Los tests usan conversaciones simuladas: no autentican, no ejecutan paquetes
y no generan intentos PAM fallidos. `--check-ui` comprueba la carga del QML.

## Sesión y recuperación

`modules/autostart.lua` ya llama a `scripts/polkit-agent.sh`. El script evita
duplicados y prefiere este binario; si falta o falla usa LXQt/KDE/MATE. No mata
automáticamente otros agentes: al sustituir uno, primero termina su proceso
una vez y deshabilita su autostart para no competir por la misma sesión.

El diálogo se registra como `org.tartarus.PolkitAgent` en el bus de sesión solo
para identificar la instancia. No exporta contraseñas, métodos de respuesta ni
el controlador a ese bus. El protocolo real usa el bus **de sistema**, gestionado
por la biblioteca oficial. Las reglas de Hyprland lo mantienen flotante y centrado.

Prueba manual inocua, después de activar el agente:

```sh
pkexec /usr/bin/true
```

Cancelar debe devolver 126; autenticar correctamente devuelve 0. No hace ningún
cambio al equipo. Nunca pruebes contraseñas incorrectas repetidamente: PAM puede
bloquear la cuenta. Escape/cerrar cancela; el solicitante también puede cancelar.

## Límites de seguridad

- El agente es un proceso de usuario. No modifica políticas, sudoers ni PAM.
- `PolkitQt1::Agent::Session` invoca el helper oficial. El resultado visual no
  concede privilegios; la autorización la valida Polkit.
- La respuesta solo vive temporalmente en el campo QML y en la llamada nativa
  a la biblioteca. Se limpia al enviar/cancelar/cambiar de identidad; nunca se
  almacena, registra ni pasa por argumentos, archivos o IPC del shell.
- Los core dumps y el volcado del proceso están deshabilitados. No se promete
  borrado criptográfico de todas las copias temporales que Qt/PAM puedan crear.
- Solo se ofrecen identidades suministradas por Polkit. Hay un máximo de tres
  conversaciones por solicitud; las políticas de bloqueo siguen siendo las de PAM.
- Admite preguntas sucesivas, mensajes del proveedor, cancelación y reintento.
  Rechaza solicitudes concurrentes en vez de mezclar sus identidades/cookies.
- Todo texto externo se dibuja como texto plano, incluido el comando solicitado.

Referencia de API: [Polkit Qt](https://api.kde.org/legacy/polkit-qt-1/html/annotated.html).
