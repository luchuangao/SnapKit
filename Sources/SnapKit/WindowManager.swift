import AppKit
import ApplicationServices

struct ManagedWindow {
    let element: AXUIElement
    let pid: pid_t
    let appID: String
    func attribute(_ name: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(element,name as CFString,&v) == .success ? v : nil
    }
    var frame: CGRect? {
        guard let p = attribute(kAXPositionAttribute), let s = attribute(kAXSizeAttribute), CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue,.cgPoint,&point), AXValueGetValue(s as! AXValue,.cgSize,&size) else { return nil }
        return CGRect(origin:point,size:size)
    }
    var valid: Bool {
        (attribute(kAXRoleAttribute) as? String) == kAXWindowRole && (attribute(kAXMinimizedAttribute) as? Bool) != true
    }
    func setFrame(_ frame: CGRect) -> Bool {
        var p = frame.origin, s = frame.size
        guard let pv = AXValueCreate(.cgPoint,&p), let sv = AXValueCreate(.cgSize,&s) else { return false }
        // Some apps constrain size at the old position. Apply size/position/size in that order.
        AXUIElementSetAttributeValue(element,kAXSizeAttribute as CFString,sv)
        let position = AXUIElementSetAttributeValue(element,kAXPositionAttribute as CFString,pv)
        let size = AXUIElementSetAttributeValue(element,kAXSizeAttribute as CFString,sv)
        return position == .success && size == .success
    }
}

final class WindowManager {
    let prefs: Preferences
    private struct History { var window: ManagedWindow; var original: CGRect; var snapped: CGRect }
    private var history: [History] = []
    private(set) var lastExternalApp: NSRunningApplication?
    init(_ prefs: Preferences) { self.prefs=prefs }
    static var trusted: Bool { AXIsProcessTrusted() }
    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }
    static func axRect(_ cocoa: CGRect) -> CGRect {
        CGRect(x:cocoa.minX,y:primaryHeight-cocoa.maxY,width:cocoa.width,height:cocoa.height)
    }
    static func cocoaRect(_ ax: CGRect) -> CGRect { axRect(ax) }
    static var mouse: CGPoint { let p = NSEvent.mouseLocation; return CGPoint(x:p.x,y:primaryHeight-p.y) }
    static var visibleScreens: [CGRect] { NSScreen.screens.map { axRect($0.visibleFrame) } }
    static var fullScreens: [CGRect] { NSScreen.screens.map { axRect($0.frame) } }
    func remember(_ app: NSRunningApplication?) {
        if let app, app.processIdentifier != getpid(), app.activationPolicy == .regular { lastExternalApp=app }
    }
    func focused() -> ManagedWindow? {
        guard Self.trusted else { return nil }
        let app = NSWorkspace.shared.frontmostApplication
        let target = app?.processIdentifier == getpid() ? lastExternalApp : app
        guard let target else { return nil }
        let ax = AXUIElementCreateApplication(target.processIdentifier)
        AXUIElementSetMessagingTimeout(ax,0.25)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ax,kAXFocusedWindowAttribute as CFString,&value) == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return eligible(ManagedWindow(element:value as! AXUIElement,pid:target.processIdentifier,appID:target.bundleIdentifier ?? ""))
    }
    func eligible(_ window: ManagedWindow) -> ManagedWindow? {
        guard window.pid != getpid(), window.valid, !prefs.ignored.contains(window.appID) else { return nil }
        return window
    }
    func window(at point: CGPoint) -> ManagedWindow? {
        guard Self.trusted else { return nil }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system,0.2)
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system,Float(point.x),Float(point.y),&element) == .success, var el = element else { return nil }
        for _ in 0..<12 {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(el,kAXRoleAttribute as CFString,&role)
            if role as? String == kAXWindowRole {
                var pid: pid_t = 0; AXUIElementGetPid(el,&pid)
                let id = NSRunningApplication(processIdentifier:pid)?.bundleIdentifier ?? ""
                return eligible(ManagedWindow(element:el,pid:pid,appID:id))
            }
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el,kAXParentAttribute as CFString,&parent) == .success, let parent, CFGetTypeID(parent) == AXUIElementGetTypeID() else { return nil }
            el = parent as! AXUIElement
        }
        return nil
    }
    func historyIndex(_ w: ManagedWindow) -> Int? { history.firstIndex { $0.window.pid == w.pid && CFEqual($0.window.element,w.element) } }
    func original(for w: ManagedWindow) -> CGRect? { historyIndex(w).map { history[$0].original } }
    func forget(_ w: ManagedWindow) { if let i=historyIndex(w) { history.remove(at:i) } }
    func record(_ w: ManagedWindow, original: CGRect, snapped: CGRect) {
        // Discard records from exited apps, and bound retained AX references.
        history.removeAll { NSRunningApplication(processIdentifier:$0.window.pid) == nil }
        if let i=historyIndex(w) { history[i].snapped=snapped }
        else { history.append(History(window:w,original:original,snapped:snapped)) }
        if history.count > 200 { history.removeFirst(history.count-200) }
    }
    func targetFrame(_ layout: Layout, screen: CGRect, current: CGRect) -> CGRect {
        if let override=prefs.commandOverrides[layout.rawValue], layout.unitRect != nil { return override.frame(in:screen.insetBy(dx:prefs.margin,dy:prefs.margin)) }
        if screen.height > screen.width {
            return Geometry.portraitFrame(layout,in:screen,current:current,gap:prefs.gap,margin:prefs.margin)
        }
        return layout.frame(in:screen,current:current,gap:prefs.gap,margin:prefs.margin)
    }
    @discardableResult func apply(_ layout: Layout, to supplied: ManagedWindow? = nil, on screen: CGRect? = nil, original: CGRect? = nil) -> Bool {
        guard !prefs.paused else { return false }
        guard Self.trusted else { prefs.feedback=L("请先在系统设置中允许 SnapKit 使用辅助功能。"); return false }
        guard let w = supplied ?? focused(), let old = w.frame else { prefs.feedback=L("当前没有可以调整的窗口，或此应用已被忽略。"); return false }
        let screens = Self.visibleScreens
        guard let index = Geometry.screenIndex(for:old,screens:screens) else { return false }
        var target: CGRect
        if layout == .restore {
            guard let saved = self.original(for:w) else { prefs.feedback=L("这个窗口没有保存的原始尺寸。"); return false }
            let bounds = screens[Geometry.screenIndex(for:saved,screens:screens) ?? index]
            target=Geometry.clamp(saved,to:bounds)
        } else if layout == .nextDisplay || layout == .previousDisplay {
            guard screens.count > 1 else { prefs.feedback=L("当前只有一个显示器。"); return false }
            let next = (index + (layout == .nextDisplay ? 1 : screens.count-1)) % screens.count
            target=Geometry.transfer(old,from:screens[index],to:screens[next])
        } else { target=targetFrame(layout,screen:screen ?? screens[index],current:old) }
        let ok = w.setFrame(target)
        if ok {
            if layout == .restore { forget(w) } else { record(w,original:original ?? old,snapped:target) }
            prefs.feedback=L("已应用：")+layout.title
        } else { prefs.feedback=L("窗口拒绝调整尺寸；请检查辅助功能权限或应用的最小窗口尺寸。") }
        return ok
    }
    func commandFrame(_ id: String, screen:CGRect, current:CGRect) -> CGRect? {
        if let layout=Layout(rawValue:id) { return targetFrame(layout,screen:screen,current:current) }
        return prefs.custom.first(where:{$0.id == id})?.frame(in:screen.insetBy(dx:prefs.margin,dy:prefs.margin))
    }
    func applyCommand(_ id:String, to supplied:ManagedWindow? = nil, on screen:CGRect? = nil, original:CGRect? = nil) {
        if let layout=Layout(rawValue:id) { apply(layout,to:supplied,on:screen,original:original) }
        else if let custom=prefs.custom.first(where:{$0.id == id}) { apply(custom,to:supplied,on:screen,original:original) }
    }
    func apply(_ custom: CustomLayout, to supplied:ManagedWindow? = nil, on screen:CGRect? = nil, original:CGRect? = nil) {
        guard !prefs.paused, Self.trusted, let w=supplied ?? focused(), let old=w.frame, let i=Geometry.screenIndex(for:old,screens:Self.visibleScreens) else { prefs.feedback=L("当前没有可调整的窗口，或缺少辅助功能权限。"); return }
        let target=custom.frame(in:(screen ?? Self.visibleScreens[i]).insetBy(dx:prefs.margin,dy:prefs.margin))
        if w.setFrame(target) { record(w,original:original ?? old,snapped:target); prefs.feedback=L("已应用：")+custom.name }
        else { prefs.feedback=L("窗口拒绝调整尺寸。") }
    }
}
