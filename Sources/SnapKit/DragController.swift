import AppKit
import ApplicationServices

final class PreviewView: NSView {
    var opacity: Double = 0.22
    var outline: Double = 2
    override func draw(_ rect: NSRect) {
        let shape=NSBezierPath(roundedRect:bounds.insetBy(dx:2,dy:2),xRadius:10,yRadius:10)
        NSColor.controlAccentColor.withAlphaComponent(opacity).setFill(); shape.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.9).setStroke(); shape.lineWidth=outline; shape.stroke()
    }
}
final class Preview {
    private let panel: NSPanel
    private let content=PreviewView()
    init() {
        panel=NSPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isOpaque=false; panel.backgroundColor = .clear; panel.ignoresMouseEvents=true
        panel.level = .floating; panel.hasShadow=false
        panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
        panel.contentView=content
    }
    func show(_ frame: CGRect, opacity: Double, outline: Double) {
        content.opacity=opacity; content.outline=outline; content.needsDisplay=true
        panel.setFrame(WindowManager.cocoaRect(frame),display:true); panel.orderFrontRegardless()
    }
    func hide() { panel.orderOut(nil) }
}
final class DragController {
    private let manager: WindowManager
    private let prefs: Preferences
    private let preview=Preview()
    private let hints=TriggerHints()
    private var monitor: Any?
    private var localMonitor: Any?
    private var timer: Timer?
    private var window: ManagedWindow?
    private var initial: CGRect?
    private var dragOriginal: CGRect?
    private var startPoint=CGPoint.zero
    private var wasDragging=false
    private var restored=false
    private var candidate: String?
    private var candidateSince=Date.distantPast
    private var targetScreen: CGRect?
    private var previewReady=false
    private var bottomVisited: Set<Layout> = []
    private var lastBottom: Layout?
    init(manager: WindowManager,prefs: Preferences) {
        self.manager=manager; self.prefs=prefs
        monitor=NSEvent.addGlobalMonitorForEvents(matching:[.leftMouseDown,.leftMouseUp]) { [weak self] e in self?.event(e) }
        localMonitor=NSEvent.addLocalMonitorForEvents(matching:[.leftMouseDown,.leftMouseUp]) { [weak self] e in self?.event(e); return e }
    }
    private func event(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            reset()
            guard prefs.snapping, !prefs.paused, WindowManager.trusted else { return }
            startPoint=WindowManager.mouse
            window=manager.window(at:startPoint); initial=window?.frame
            dragOriginal=window.flatMap { manager.original(for:$0) } ?? initial
            if window != nil { timer=Timer.scheduledTimer(withTimeInterval:0.025,repeats:true) { [weak self] _ in self?.tick() } }
        } else {
            if previewReady, let l=candidate, let w=window, let initial, let targetScreen, !prefs.paused, prefs.snapping, !NSEvent.modifierFlags.contains(.option) {
                manager.applyCommand(l,to:w,on:targetScreen,original:dragOriginal ?? initial)
            }
            reset()
        }
    }
    private func reset() {
        timer?.invalidate(); timer=nil; window=nil; initial=nil; dragOriginal=nil; candidate=nil; targetScreen=nil
        wasDragging=false; restored=false; previewReady=false; bottomVisited=[]; lastBottom=nil; preview.hide(); hints.hide()
    }
    private func tick() {
        guard NSEvent.pressedMouseButtons & 1 != 0 else { reset(); return }
        guard let w=window, let start=initial, let current=w.frame, prefs.snapping, !prefs.paused else { preview.hide(); previewReady=false; return }
        let p=WindowManager.mouse
        let distance=hypot(p.x-startPoint.x,p.y-startPoint.y)
        if !wasDragging {
            guard distance > 5, hypot(current.minX-start.minX,current.minY-start.minY) > 3 else { return }
            // Resizing and text selection must never start snapping.
            guard abs(current.width-start.width) < 3, abs(current.height-start.height) < 3 else { reset(); return }
            wasDragging=true
        }
        if !restored, prefs.restoreOnDrag, let original=manager.original(for:w), distance > 16 {
            let ratio=min(max((startPoint.x-start.minX)/start.width,0.05),0.95)
            let restoredRect=CGRect(x:p.x-original.width*ratio,y:p.y-min(22,max(6,startPoint.y-start.minY)),width:original.width,height:original.height)
            if w.setFrame(restoredRect) { manager.forget(w) }
            restored=true
        }
        guard !NSEvent.modifierFlags.contains(.option), let index=WindowManager.fullScreens.firstIndex(where:{$0.contains(p)}) else {
            preview.hide(); hints.hide(); candidate=nil; previewReady=false; return
        }
        let full=WindowManager.fullScreens[index], visible=WindowManager.visibleScreens[index]
        hints.show(screen:visible,prefs:prefs)
        // Bottom trigger uses the usable edge (above a visible Dock) as well as the physical edge.
        let triggerBounds=CGRect(x:full.minX,y:full.minY,width:full.width,height:max(1,visible.maxY-full.minY))
        var layout=Geometry.trigger(at:p,screen:triggerBounds,threshold:prefs.threshold,portrait:full.height>full.width)
        if layout == nil, p.y >= triggerBounds.maxY, p.y <= full.maxY {
            layout=Geometry.trigger(at:CGPoint(x:p.x,y:triggerBounds.maxY-1),screen:triggerBounds,threshold:prefs.threshold,portrait:full.height>full.width)
        }
        if let l=layout, [.leftThird,.centerThird,.rightThird].contains(l), full.width>=full.height {
            if let lastBottom, lastBottom != l { bottomVisited.insert(lastBottom); bottomVisited.insert(l) }
            lastBottom=l
            if bottomVisited.contains(.leftThird) && bottomVisited.contains(.centerThird) { layout = .leftTwoThirds }
            if bottomVisited.contains(.rightThird) && bottomVisited.contains(.centerThird) { layout = .rightTwoThirds }
        } else { bottomVisited=[]; lastBottom=nil }
        var command=layout?.rawValue
        if let commandID=command, prefs.disabledTriggers.contains(commandID) || prefs.customTriggers[commandID] != nil { command=nil }
        // Explicit custom regions take precedence over the classic edge mapping.
        let ids=Layout.allCases.map(\.rawValue)+prefs.custom.map(\.id)
        for id in ids where !prefs.disabledTriggers.contains(id) {
            if let region=prefs.customTriggers[id], region.frame(in:full).contains(p) { command=id; break }
        }
        if command != candidate || visible != targetScreen {
            candidate=command; targetScreen=visible; candidateSince=Date(); previewReady=false; preview.hide()
        }
        guard let command, Date().timeIntervalSince(candidateSince) >= prefs.dwell,
              let frame=manager.commandFrame(command,screen:visible,current:current) else { return }
        previewReady=true
        preview.show(frame,opacity:prefs.opacity,outline:prefs.outline)
    }
    deinit { if let monitor { NSEvent.removeMonitor(monitor) }; if let localMonitor { NSEvent.removeMonitor(localMonitor) }; timer?.invalidate() }
}
