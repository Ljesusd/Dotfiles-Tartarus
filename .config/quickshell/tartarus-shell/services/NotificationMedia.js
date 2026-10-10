function source(value) {
    if (typeof value !== "string") return ""
    const url = value.trim()
    // image-path notifications use the icon provider, which can rasterize
    // photos as small square icons. Load the original file for a real preview.
    if (url.startsWith("image://icon/")) {
        const original = url.slice("image://icon/".length)
        if (original.startsWith("/") || /^(https?:\/\/|file:\/\/)/i.test(original)) return source(original)
        // Theme icon names are not image attachments (and may not exist).
        return ""
    }
    if (/^(https?:\/\/|file:\/\/|image:\/\/|data:image\/)/i.test(url)) return url
    return url.startsWith("/") ? "file://" + url : ""
}

function bodyImage(body) {
    if (typeof body !== "string") return ""
    const tags = body.match(/<img\b[^>]*>/gi) || []
    for (const tag of tags) {
        const match = tag.match(/\bsrc\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i)
        if (!match) continue
        const url = source((match[1] || match[2] || match[3] || "").replace(/&amp;/g, "&"))
        if (url) return url
    }
    return ""
}

function appNameIsChat(appName) {
    const name = String(appName || "").toLowerCase()
    return name.includes("discord") || name.includes("vesktop")
}

function fileImage(body) {
    if (typeof body !== "string") return ""

    // notify-send screenshot messages usually contain the saved path rather
    // than a notification image hint. Keep the path up to the image suffix.
    const match = body.match(/(\/[^<>\n]*?\.(?:png|jpe?g|webp|gif|bmp|tiff?))(?:\s|$)/i)
    return match ? source(match[1]) : ""
}

function avatar(image, appName) {
    return appNameIsChat(appName) ? source(image) : ""
}

function notificationPreview(image, body, appName) {
    const embedded = bodyImage(body)
    if (embedded) return embedded

    const attachedFile = fileImage(body)
    if (attachedFile) return attachedFile

    // Chat profile images belong in the circular avatar, not in the large
    // content preview.
    return appNameIsChat(appName) ? "" : source(image)
}

function preview(image, body) { return bodyImage(body) || source(image) }
function textBody(body) { return String(body || "").replace(/<img\b[^>]*>/gi, "") }
function persistentImage(image, body) {
    const url = preview(image, body)
    // Named icons are not attachments; process-owned image data cannot be restored.
    if (url.startsWith("image://icon/")) return source(url.slice("image://icon/".length))
    return url.startsWith("image://") ? "" : url
}
