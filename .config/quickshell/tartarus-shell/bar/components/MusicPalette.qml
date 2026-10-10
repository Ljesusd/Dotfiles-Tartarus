import QtQuick

// ColorQuantizer in this Quickshell build only accepts local images. Canvas
// loads remote MPRIS artwork as well; sample once per cover, never per frame.
Canvas {
    id: root
    property string source: ""
    property var colors: []
    property string loadedSource: ""
    opacity: 0
    width: 24
    height: 24

    onSourceChanged: {
        root.colors = []
        if (root.loadedSource) root.unloadImage(root.loadedSource)
        root.loadedSource = root.source
        if (root.source) root.loadImage(root.source)
    }
    onImageLoaded: if (root.source && root.isImageLoaded(root.source)) root.requestPaint()
    onPaint: {
        if (!root.source || !root.isImageLoaded(root.source)) return
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.drawImage(root.source, 0, 0, width, height)
        const pixels = ctx.getImageData(0, 0, width, height).data
        const palette = []
        for (let i = 0; i < pixels.length; i += 4) {
            if (pixels[i + 3] > 128)
                palette.push(Qt.rgba(pixels[i] / 255, pixels[i + 1] / 255, pixels[i + 2] / 255, 1))
        }
        root.colors = palette
    }
}
