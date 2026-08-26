import QtQml

QtObject {
    id: root

    property var plugins: []

    signal pluginRegistered(var plugin)

    function registerPlugin(plugin) {
        if (!plugin)
            return

        const exists = root.plugins.some(item => {
            return item.pluginId === plugin.pluginId
        })

        if (exists)
            return

        root.plugins = [
            ...root.plugins,
            plugin
        ]

        root.pluginRegistered(plugin)
    }

    function plugin(id) {
        return root.plugins.find(item => {
            return item.pluginId === id
        }) ?? null
    }

    function pluginsWithCapability(capability) {
        return root.plugins.filter(plugin => {
            return plugin.capabilities
                && plugin.capabilities.includes(capability)
        })
    }

    function barPlugins(section) {
        return root.pluginsWithCapability("bar-widget")
            .filter(plugin => {
                return plugin.barSection === section
            })
            .sort((a, b) => {
                return a.barOrder - b.barOrder
            })
    }

}
