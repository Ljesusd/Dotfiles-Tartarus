// Follow actual ownership, including workspaces migrated from a disconnected
// monitor. Configured ranges are only placeholders for optional empty slots.
function idsForScreen(workspaces, monitorName, activeId, base, count, showEmpty) {
    if (!monitorName) return []
    const ids = new Set()
    for (const workspace of workspaces) {
        const name = typeof workspace.monitor === "string" ? workspace.monitor : workspace.monitor?.name
        if (workspace.id > 0 && name === monitorName
            && (showEmpty || workspace.id === activeId || (workspace.toplevels?.values?.length ?? workspace.windows ?? 0) > 0))
            ids.add(workspace.id)
    }
    if (activeId > 0) ids.add(activeId)
    if (showEmpty) {
        for (let id = base; id < base + count; id++) {
            const owner = workspaces.find(workspace => workspace.id === id)?.monitor
            const name = typeof owner === "string" ? owner : owner?.name
            if (!name || name === monitorName) ids.add(id)
        }
    }
    return Array.from(ids).sort((a, b) => a - b)
}
