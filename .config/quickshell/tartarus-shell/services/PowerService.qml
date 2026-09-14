pragma Singleton
import Quickshell
import Quickshell.Io
import QtQml

QtObject {
    id: root
    function run(command) {
        action.command = ["sh", "-c", command]
        action.running = true
    }
    function lock() { root.run("loginctl lock-session") }
    function suspend() { root.run("systemctl suspend") }
    function logout() { root.run("loginctl terminate-user $USER") }
    function reboot() { root.run("systemctl reboot") }
    function shutdown() { root.run("systemctl poweroff") }
    readonly property Process action: Process {}
}
