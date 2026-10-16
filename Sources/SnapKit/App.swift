import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let prefs=Preferences.shared
    lazy var manager=WindowManager(prefs)
    private var status: NSStatusItem?
    private var settings: NSWindow?
    private var hotkeys: Hotkeys?
    private var drag: DragController?
    private var green: GreenButtonController?
    private var subscriptions: Set<AnyCancellable> = []
    private var activationObserver: NSObjectProtocol?
    private var refreshWork: DispatchWorkItem?
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        if ScreenshotCapture.outputDirectory != nil { NSApp.appearance=NSAppearance(named:.aqua) }
        if let iconURL=Bundle.main.url(forResource:"AppIcon",withExtension:"png"), let icon=NSImage(contentsOf:iconURL) { NSApp.applicationIconImage=icon }
        installMainMenu()
        // Opening the bundle a second time brings settings forward, even when its icon is hidden.
        DistributedNotificationCenter.default().addObserver(self,selector:#selector(showSettings),name:NSNotification.Name("local.luchuan.SnapKit.show"),object:nil)
        manager.remember(NSWorkspace.shared.frontmostApplication)
        activationObserver=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main) { [weak self] notification in
            self?.manager.remember(notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
        hotkeys=Hotkeys(); hotkeys?.register(prefs:prefs,manager:manager)
        drag=DragController(manager:manager,prefs:prefs)
        green=GreenButtonController(manager:manager,prefs:prefs)
        prefs.$recording.dropFirst().sink { [weak self] recording in
            if recording { self?.hotkeys?.unregister() }
            else { DispatchQueue.main.async { guard let self else { return }; self.hotkeys?.register(prefs:self.prefs,manager:self.manager) } }
        }.store(in:&subscriptions)
        prefs.onChange={ [weak self] in self?.scheduleRefresh() }
        prefs.$paused.dropFirst().sink { [weak self] _ in DispatchQueue.main.async { self?.updateIcon() } }.store(in:&subscriptions)
        updateIcon()
        let first = !UserDefaults.standard.bool(forKey:"hasLaunched")
        UserDefaults.standard.set(true,forKey:"hasLaunched")
        if first || CommandLine.arguments.contains("--settings") || ScreenshotCapture.outputDirectory != nil { showSettings() }
        if ScreenshotCapture.outputDirectory != nil, let settings { ScreenshotCapture.capture(settings) }
        if CommandLine.arguments.contains("--smoke-test") { SmokeTest.run(manager:manager) }
    }
    private func installMainMenu() {
        let menu=NSMenu()
        let appItem=NSMenuItem(); menu.addItem(appItem)
        let appMenu=NSMenu(); appItem.submenu=appMenu
        let settings=NSMenuItem(title:L("设置…"),action:#selector(showSettings),keyEquivalent:","); settings.target=self; appMenu.addItem(settings)
        appMenu.addItem(.separator())
        let quit=NSMenuItem(title:L("退出 SnapKit"),action:#selector(quit),keyEquivalent:"q"); quit.target=self; appMenu.addItem(quit)
        let editItem=NSMenuItem(); editItem.title=L("编辑"); let edit=NSMenu(title:L("编辑")); editItem.submenu=edit; menu.addItem(editItem)
        for (title,selector,key) in [(L("撤销"),"undo:","z"),(L("剪切"),"cut:","x"),(L("复制"),"copy:","c"),(L("粘贴"),"paste:","v"),(L("全选"),"selectAll:","a")] { edit.addItem(NSMenuItem(title:title,action:NSSelectorFromString(selector),keyEquivalent:key)) }
        NSApp.mainMenu=menu
    }
    private func scheduleRefresh() {
        refreshWork?.cancel()
        let work=DispatchWorkItem { [weak self] in guard let self else { return }; self.hotkeys?.register(prefs:self.prefs,manager:self.manager); self.updateIcon(); self.installMainMenu(); self.settings?.title=L("SnapKit 设置") }
        refreshWork=work; DispatchQueue.main.asyncAfter(deadline:.now()+0.12,execute:work)
    }
    private func updateIcon() {
        if !prefs.showIcon { if let status { NSStatusBar.system.removeStatusItem(status); self.status=nil }; return }
        if status == nil { status=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength) }
        status?.button?.image=prefs.paused ? NSImage(systemSymbolName:"pause.rectangle",accessibilityDescription:L("SnapKit 已暂停")) : BrandIcon.menuBar
        status?.button?.toolTip=L("SnapKit · 窗口管理")
        let menu=NSMenu(); menu.delegate=self; menu.autoenablesItems=false; status?.menu=menu
    }
    func menuWillOpen(_ menu:NSMenu) {
        manager.remember(NSWorkspace.shared.frontmostApplication)
        menu.removeAllItems()
        if !WindowManager.trusted { let item=add(L("需要辅助功能权限…"),to:menu,action:#selector(requestAccess)); item.image=NSImage(systemSymbolName:"lock",accessibilityDescription:nil); menu.addItem(.separator()) }
        for (index,group) in Layout.groups.enumerated() {
            if index>0 { menu.addItem(.separator()) }
            for layout in group {
                let item=add(layout.title,to:menu,action:#selector(applyLayout(_:)))
                item.representedObject=layout.rawValue; item.image=Self.glyph(layout)
                let enabled=WindowManager.trusted && !prefs.paused && (!(layout == .nextDisplay || layout == .previousDisplay) || NSScreen.screens.count>1)
                item.isEnabled=enabled
                if let shortcut=prefs.shortcut(for:layout.rawValue), prefs.shortcutsEnabled {
                    let attr=NSMutableAttributedString(string:layout.title+"\t"+shortcut.label)
                    let paragraph=NSMutableParagraphStyle(); paragraph.tabStops=[NSTextTab(textAlignment:.right,location:260)]
                    attr.addAttribute(.paragraphStyle,value:paragraph,range:NSRange(location:0,length:attr.length)); item.attributedTitle=attr
                }
            }
        }
        if !prefs.custom.isEmpty {
            menu.addItem(.separator())
            for c in prefs.custom { let item=add(c.name,to:menu,action:#selector(applyCustom(_:))); item.representedObject=c.id; item.isEnabled = !prefs.paused && WindowManager.trusted }
        }
        menu.addItem(.separator())
        if let app=manager.lastExternalApp, let id=app.bundleIdentifier {
            let ignored=prefs.ignored.contains(id)
            let item=add((ignored ? L("取消忽略 ") : L("忽略 "))+(app.localizedName ?? id),to:menu,action:#selector(ignoreApp(_:)))
            item.representedObject=id; item.state=ignored ? .on : .off
        }
        let pause=add(prefs.paused ? L("继续窗口管理") : L("暂停窗口管理"),to:menu,action:#selector(togglePause)); pause.state=prefs.paused ? .on : .off
        menu.addItem(.separator()); add(L("设置…"),to:menu,action:#selector(showSettings)); add(L("退出 SnapKit"),to:menu,action:#selector(quit))
    }
    @discardableResult private func add(_ title:String,to menu:NSMenu,action:Selector) -> NSMenuItem {
        let item=NSMenuItem(title:title,action:action,keyEquivalent:""); item.target=self; menu.addItem(item); return item
    }
    static func glyph(_ layout:Layout) -> NSImage {
        let image=NSImage(size:NSSize(width:22,height:18),flipped:false) { rect in
            NSColor.labelColor.withAlphaComponent(0.6).setStroke()
            let bounds=rect.insetBy(dx:1,dy:2); let outer=NSBezierPath(roundedRect:bounds,xRadius:2,yRadius:2); outer.lineWidth=1; outer.stroke()
            if let unit=layout.unitRect {
                let r=CGRect(x:bounds.minX+unit.minX*bounds.width+1,y:bounds.maxY-unit.maxY*bounds.height+1,width:max(1,unit.width*bounds.width-2),height:max(1,unit.height*bounds.height-2))
                NSColor.labelColor.setFill(); NSBezierPath(roundedRect:r,xRadius:1,yRadius:1).fill()
            } else {
                let symbol = layout == .restore ? "↶" : layout == .nextDisplay ? "→" : layout == .previousDisplay ? "←" : "⊙"
                (symbol as NSString).draw(at:NSPoint(x:5,y:1),withAttributes:[.font:NSFont.systemFont(ofSize:13),.foregroundColor:NSColor.labelColor])
            }
            return true
        }; image.isTemplate=true; return image
    }
    @objc private func applyLayout(_ item:NSMenuItem) { if let raw=item.representedObject as? String, let l=Layout(rawValue:raw) { manager.apply(l) } }
    @objc private func applyCustom(_ item:NSMenuItem) { if let id=item.representedObject as? String, let c=prefs.custom.first(where:{$0.id == id}) { manager.apply(c) } }
    @objc private func ignoreApp(_ item:NSMenuItem) { if let id=item.representedObject as? String { if prefs.ignored.contains(id) { prefs.ignored.removeAll{$0 == id} } else { prefs.ignore(id) } } }
    @objc private func togglePause() { prefs.paused.toggle() }
    @objc private func requestAccess() { WindowManager.requestAccess(); showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc func showSettings() {
        if settings == nil {
            let w=NSWindow(contentRect:CGRect(x:0,y:0,width:840,height:720),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
            w.title=L("SnapKit 设置"); w.titlebarAppearsTransparent=true; w.isReleasedWhenClosed=false
            w.contentView=NSHostingView(rootView:ReferenceSettingsView(prefs:prefs,manager:manager)); w.center(); settings=w
        }
        NSApp.activate(ignoringOtherApps:true); settings?.makeKeyAndOrderFront(nil)
    }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool) -> Bool { showSettings(); return true }
}

@main struct SnapKitMain {
    static func main() {
        let app=NSApplication.shared
        if let id=Bundle.main.bundleIdentifier, NSRunningApplication.runningApplications(withBundleIdentifier:id).contains(where:{$0.processIdentifier != getpid()}) {
            DistributedNotificationCenter.default().post(name:NSNotification.Name("local.luchuan.SnapKit.show"),object:nil); return
        }
        let delegate=AppDelegate(); app.delegate=delegate; withExtendedLifetime(delegate) { app.run() }
    }
}
