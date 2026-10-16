import AppKit
import ApplicationServices

// Optional non-activating palette. It keeps the target AX window captured while shown.
final class GreenButtonController {
    private let manager: WindowManager
    private let prefs: Preferences
    private var timer: Timer?
    private var hoverSince: Date?
    private var hoverRect: CGRect?
    private var target: ManagedWindow?
    private var panel: NSPanel?
    private var actions: [PaletteAction] = []
    private var openedAt=Date.distantPast
    init(manager:WindowManager,prefs:Preferences) {
        self.manager=manager; self.prefs=prefs
        timer=Timer.scheduledTimer(withTimeInterval:0.15,repeats:true) { [weak self] _ in self?.tick() }
    }
    private func tick() {
        guard prefs.greenButton, !prefs.paused, WindowManager.trusted, NSEvent.pressedMouseButtons == 0 else { hide(); return }
        let p=WindowManager.mouse
        if let panel, panel.isVisible {
            let cocoa=NSEvent.mouseLocation
            if panel.frame.insetBy(dx:-16,dy:-16).contains(cocoa) || hoverRect?.insetBy(dx:-8,dy:-8).contains(p) == true { return }
            if Date().timeIntervalSince(openedAt)>0.5 { hide() }
            return
        }
        let system=AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system,0.1)
        var el: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system,Float(p.x),Float(p.y),&el) == .success, let el else { hoverSince=nil; return }
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(el,kAXSubroleAttribute as CFString,&role)
        guard let role=role as? String, role == "AXFullScreenButton" || role == "AXZoomButton" else { hoverSince=nil; return }
        var pos: CFTypeRef?, size: CFTypeRef?
        AXUIElementCopyAttributeValue(el,kAXPositionAttribute as CFString,&pos); AXUIElementCopyAttributeValue(el,kAXSizeAttribute as CFString,&size)
        guard let pos, let size, CFGetTypeID(pos)==AXValueGetTypeID(), CFGetTypeID(size)==AXValueGetTypeID() else { return }
        var point=CGPoint.zero, s=CGSize.zero
        AXValueGetValue(pos as! AXValue,.cgPoint,&point); AXValueGetValue(size as! AXValue,.cgSize,&s)
        let rect=CGRect(origin:point,size:s)
        if hoverRect != rect || hoverSince == nil { hoverRect=rect; hoverSince=Date() }
        if let since=hoverSince, Date().timeIntervalSince(since)>prefs.greenDelay, let window=manager.window(at:p) {
            target=window; show(below:rect)
        }
    }
    private func show(below rect:CGRect) {
        let p=NSPanel(contentRect:CGRect(x:0,y:0,width:260,height:134),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        p.isOpaque=false; p.backgroundColor = .clear; p.hasShadow=true; p.level = .popUpMenu
        let effect=NSVisualEffectView(frame:p.contentView!.bounds); effect.material = .popover; effect.blendingMode = .behindWindow; effect.state = .active; effect.wantsLayer=true; effect.layer?.cornerRadius=12
        p.contentView=effect
        let layouts: [Layout]=[.left,.right,.topLeft,.topRight,.bottomLeft,.bottomRight,.leftThird,.centerThird,.rightThird,.maximize,.center,.restore]
        actions=[]
        for (index,layout) in layouts.enumerated() {
            let b=NSButton(frame:CGRect(x:10+(index%6)*40,y:12+(1-index/6)*46,width:36,height:36))
            b.bezelStyle = .texturedRounded; b.title=""; b.image=AppDelegate.glyph(layout); b.toolTip=layout.title
            let a=PaletteAction { [weak self] in guard let self, let target=self.target else { return }; self.manager.apply(layout,to:target); self.hide() }
            actions.append(a); b.target=a; b.action=#selector(PaletteAction.run); effect.addSubview(b)
        }
        let text=NSTextField(labelWithString:L("选择窗口布局")); text.font = .systemFont(ofSize:10); text.textColor = .secondaryLabelColor; text.frame=CGRect(x:12,y:111,width:230,height:14); effect.addSubview(text)
        let anchor=WindowManager.cocoaRect(rect)
        var frame=CGRect(x:anchor.minX-12,y:anchor.minY-142,width:260,height:134)
        if let screen=NSScreen.screens.first(where:{$0.frame.contains(anchor.origin)}) { frame=Geometry.clamp(frame,to:screen.visibleFrame) }
        p.setFrame(frame,display:true); p.orderFrontRegardless(); panel=p; openedAt=Date()
    }
    private func hide() { panel?.orderOut(nil); panel=nil; actions=[]; target=nil; hoverSince=nil }
    deinit { timer?.invalidate() }
}
final class PaletteAction: NSObject {
    let callback: () -> Void
    init(_ callback:@escaping () -> Void) { self.callback=callback }
    @objc func run() { callback() }
}
