import Quickshell
import "../../utils"

LauncherRow {
    id: root
    required property var application
    title: application?.name ?? ""
    description: application?.comment || application?.genericName || ""
    symbol: Icons.appCategoryIcon(application?.id ?? "", "apps")
    iconSource: {
        const icon = String(root.application?.icon ?? "")
        if (icon.startsWith("/") || icon.startsWith("file://"))
            return icon.startsWith("/") ? "file://" + icon : icon
        const resolved = icon ? Quickshell.iconPath(icon, true) : ""
        if (resolved) return resolved
        // Fall back to the application's own hicolor icon when its desktop
        // entry names an icon unavailable in the current theme (e.g. Nemo).
        const id = String(root.application?.id ?? "").replace(/\.desktop$/, "")
        return id ? Quickshell.iconPath(id, true) : ""
    }
}
