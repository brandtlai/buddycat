import AppKit

enum CatFrame {
    case idle
    case leftPaw
    case rightPaw
}

struct CatIconRenderer {
    static let idleImage = loadFrame("cat_idle")
    static let leftPawImage = loadFrame("cat_left")
    static let rightPawImage = loadFrame("cat_right")

    static func image(for frame: CatFrame) -> NSImage {
        switch frame {
        case .idle: return idleImage
        case .leftPaw: return leftPawImage
        case .rightPaw: return rightPawImage
        }
    }

    private static func loadFrame(_ name: String) -> NSImage {
        let iconSize = NSSize(width: 22, height: 22)

        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = iconSize
            image.isTemplate = true
            return image
        }
        NSLog("BuddyCat: Failed to load \(name).png from bundle")
        let fallback = NSImage(size: iconSize, flipped: false) { rect in
            NSColor.controlTextColor.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2)).fill()
            return true
        }
        fallback.isTemplate = true
        return fallback
    }
}
