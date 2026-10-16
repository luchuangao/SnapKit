import AppKit

enum BrandIcon {
    // Small monochrome companion to the approved left-pane / two-right-panes logo.
    static let menuBar: NSImage = {
        let image=NSImage(size:NSSize(width:18,height:18),flipped:false) { _ in
            NSColor.black.setFill()
            for rect in [NSRect(x:2.5,y:2.5,width:6,height:13),NSRect(x:9.5,y:9.5,width:6,height:6),NSRect(x:9.5,y:2.5,width:6,height:6)] {
                NSBezierPath(roundedRect:rect,xRadius:1.5,yRadius:1.5).fill()
            }
            return true
        }
        image.isTemplate=true
        image.accessibilityDescription=L("SnapKit 分屏")
        return image
    }()
}
