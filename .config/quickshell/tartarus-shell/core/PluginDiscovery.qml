pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Qt.labs.folderlistmodel

import Quickshell.Io

Item {
    id: root

    required property var registry

    property url pluginsDirectory:
        Qt.resolvedUrl("../plugins")

    width: 0
    height: 0

    FolderListModel {
        id: pluginFolders

        folder: root.pluginsDirectory

        showDirs: true
        showFiles: false
        showDotAndDotDot: false
    }

    Repeater {
        model: pluginFolders

        delegate: Item {
            id: candidate

            required property string fileName
            required property string filePath

            property var manifest: null
            property url pluginSource: ""

            width: 0
            height: 0

            FileView {
                id: manifestFile

                path:
                    candidate.filePath
                    + "/manifest.json"

                blockLoading: true
                printErrors: false
            }

            Component.onCompleted: {
                root.loadCandidate(
                    candidate,
                    manifestFile,
                    pluginLoader
                )
            }

            Loader {
                id: pluginLoader

                active: false

                source:
                    candidate.pluginSource

                asynchronous: false

                onLoaded: {
                    if (!item) {
                        console.warn(
                            "PluginDiscovery:",
                            candidate.fileName,
                            "returned no plugin object"
                        )

                        return
                    }

                    if (
                        item.pluginId
                        !== candidate.manifest.id
                    ) {
                        console.warn(
                            "PluginDiscovery:",
                            "manifest id does not match pluginId:",
                            candidate.manifest.id,
                            item.pluginId
                        )

                        return
                    }

                    root.registry.registerPlugin(
                        item
                    )

                }

                onStatusChanged: {
                    if (
                        pluginLoader.status
                        === Loader.Error
                    ) {
                        console.warn(
                            "PluginDiscovery:",
                            candidate.fileName,
                            "failed to load plugin"
                        )
                    }
                }
            }
        }
    }

    function loadCandidate(
        candidate,
        manifestFile,
        pluginLoader
    ) {
        const text = manifestFile.text()

        if (text.trim() === "") {
            console.warn(
                "PluginDiscovery:",
                candidate.fileName,
                "manifest is empty"
            )

            return
        }

        try {
            const parsed =
                JSON.parse(text)

            if (
                !root.validateManifest(
                    parsed,
                    candidate.fileName
                )
            ) {
                return
            }

            candidate.manifest = parsed

            const entryPoint =
                parsed.entryPoints.plugin

            candidate.pluginSource =
                Qt.resolvedUrl(
                    candidate.filePath
                    + "/"
                    + entryPoint
                )

            pluginLoader.active = true
        } catch (error) {
            console.warn(
                "PluginDiscovery:",
                candidate.fileName,
                "invalid manifest:",
                error
            )
        }
    }

    function validateManifest(
        manifest,
        directoryName
    ) {
        if (!manifest) {
            console.warn(
                "PluginDiscovery:",
                directoryName,
                "manifest is empty"
            )

            return false
        }

        if (
            typeof manifest.id !== "string"
            || manifest.id === ""
        ) {
            console.warn(
                "PluginDiscovery:",
                directoryName,
                "manifest has no valid id"
            )

            return false
        }

        if (!Array.isArray(manifest.capabilities)) {
            console.warn(
                "PluginDiscovery:",
                manifest.id,
                "capabilities must be an array"
            )

            return false
        }

        if (
            !manifest.entryPoints
            || typeof manifest.entryPoints.plugin
                !== "string"
            || manifest.entryPoints.plugin === ""
        ) {
            console.warn(
                "PluginDiscovery:",
                manifest.id,
                "has no plugin entry point"
            )

            return false
        }

        return true
    }
}
