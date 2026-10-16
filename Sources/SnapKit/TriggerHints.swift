import AppKit

final class TriggerHintsView: NSView {
    var prefs: Preferences?
    override var isFlipped:Bool { true }
    override func draw(_ rect:NSRect) {
        guard let prefs else { return }
        let threshold=prefs.threshold
        var regions: [(String,CGRect)] = []
        if bounds.width >= bounds.height {
            let w=bounds.width, h=bounds.height, c=w*0.16, cy=h*0.16
            regions=[(Layout.left.rawValue,CGRect(x:0,y:cy,width:threshold,height:h-2*cy)),(Layout.right.rawValue,CGRect(x:w-threshold,y:cy,width:threshold,height:h-2*cy)),(Layout.maximize.rawValue,CGRect(x:c,y:0,width:w-2*c,height:threshold)),(Layout.topLeft.rawValue,CGRect(x:0,y:0,width:threshold,height:cy)),(Layout.topRight.rawValue,CGRect(x:w-threshold,y:0,width:threshold,height:cy)),(Layout.bottomLeft.rawValue,CGRect(x:0,y:h-cy,width:threshold,height:cy)),(Layout.bottomRight.rawValue,CGRect(x:w-threshold,y:h-cy,width:threshold,height:cy))]
            for (l,x) in [(Layout.leftThird,w/6),(.centerThird,w/3),(.rightThird,w*2/3)] { regions.append((l.rawValue,CGRect(x:x,y:h-threshold,width:l == .leftThird ? w/6 : l == .centerThird ? w/3 : w/6,height:threshold))) }
        } else {
            for x in [0,bounds.width-threshold] { for (index,l) in [Layout.leftThird,.centerThird,.rightThird].enumerated() { regions.append((l.rawValue,CGRect(x:x,y:CGFloat(index)*bounds.height/3,width:threshold,height:bounds.height/3))) } }
        }
        regions=regions.filter { !prefs.disabledTriggers.contains($0.0) && prefs.customTriggers[$0.0] == nil }
        for (id,region) in prefs.customTriggers where !prefs.disabledTriggers.contains(id) { regions.append((id,region.frame(in:bounds))) }
        for (_,r) in regions {
            let path=NSBezierPath(roundedRect:r.insetBy(dx:1,dy:1),xRadius:4,yRadius:4)
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill(); path.fill()
            NSColor.controlAccentColor.withAlphaComponent(0.35).setStroke(); path.lineWidth=1; path.stroke()
        }
    }
}
final class TriggerHints {
    private var panel:NSPanel?
    func show(screen:CGRect,prefs:Preferences) {
        guard prefs.highlightTriggers else { hide(); return }
        if panel == nil {
            let p=NSPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            p.isOpaque=false; p.backgroundColor = .clear; p.ignoresMouseEvents=true; p.level = .floating; p.hasShadow=false
            p.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
            p.contentView=TriggerHintsView(); panel=p
        }
        let content=panel?.contentView as? TriggerHintsView; content?.prefs=prefs; content?.needsDisplay=true
        panel?.setFrame(WindowManager.cocoaRect(screen),display:true); panel?.orderFrontRegardless()
    }
    func hide() { panel?.orderOut(nil) }
}
