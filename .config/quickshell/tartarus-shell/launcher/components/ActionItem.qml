LauncherRow {
    required property var action
    title: action?.name ?? ""
    description: action?.description ?? ""
    symbol: action?.icon ?? "apps"
    showChevron: true
}
