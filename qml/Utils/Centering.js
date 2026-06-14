.pragma library

function centerInParent(item) {
    if (item.parent) {
        item.x = Math.round((item.parent.width - item.width) / 2)
        item.y = Math.round((item.parent.height - item.height) / 2)
    }
}
