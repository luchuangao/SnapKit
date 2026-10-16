import AppKit
final class FixtureDelegate: NSObject, NSApplicationDelegate {
    var window:NSWindow!
    func applicationDidFinishLaunching(_ n:Notification) {
        let frame=NSScreen.screens.first!.visibleFrame
        window=NSWindow(contentRect:CGRect(x:frame.midX-240,y:frame.midY-160,width:480,height:320),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.title="SnapKit Test Window"; window.isReleasedWhenClosed=false
        let text=NSTextField(labelWithString:"SnapKit disposable test window\n用于验证快捷键、边缘拖拽和恢复。")
        text.alignment = .center; text.font = .systemFont(ofSize:18); text.frame=CGRect(x:20,y:110,width:440,height:80)
        window.contentView!.addSubview(text)
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
}
let app=NSApplication.shared; app.setActivationPolicy(.regular)
let delegate=FixtureDelegate(); app.delegate=delegate; app.run()
