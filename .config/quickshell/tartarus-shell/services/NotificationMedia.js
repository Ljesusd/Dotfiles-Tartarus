function source(value) {
    if (typeof value !== "string") return ""
    const url = value.trim()
    // image-path notifications use the icon provider, which can rasterize
    // photos as small square icons. Load the original file for a real preview.
    if (url.startsWith("image://icon/")) {
        const original = url.slice("image://icon/".length)
        if (original.startsWith("/") || /^(https?:\/\/|file:\/\/)/i.test(original)) return source(original)
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

function preview(image, body) { return bodyImage(body) || source(image) }
function textBody(body) { return String(body || "").replace(/<img\b[^>]*>/gi, "") }
function persistentImage(image, body) {
    const url = preview(image, body)
    // Named icons are not attachments; process-owned image data cannot be restored.
    if (url.startsWith("image://icon/")) return source(url.slice("image://icon/".length))
    return url.startsWith("image://") ? "" : url
}
