import SwiftUI
import AppKit
import Carbon
import ServiceManagement

struct LayoutGlyph: View {
    var layout: Layout
    var body: some View {
        GeometryReader { proxy in
            let outer=CGRect(x:2,y:3,width:proxy.size.width-4,height:proxy.size.height-6)
            ZStack(alignment:.topLeading) {
                RoundedRectangle(cornerRadius:3).stroke(.secondary.opacity(0.5),lineWidth:1).frame(width:outer.width,height:outer.height).offset(x:outer.minX,y:outer.minY)
                if let r=layout.unitRect {
                    RoundedRectangle(cornerRadius:1.5).fill(Color.accentColor.opacity(0.85)).frame(width:max(2,outer.width*r.width-3),height:max(2,outer.height*r.height-3)).offset(x:outer.minX+outer.width*r.minX+1.5,y:outer.minY+outer.height*r.minY+1.5)
                } else {
                    Image(systemName:layout == .restore ? "arrow.uturn.backward" : layout == .nextDisplay ? "arrow.right" : layout == .previousDisplay ? "arrow.left" : "dot.scope").font(.system(size:10)).frame(width:outer.width,height:outer.height).offset(x:outer.minX,y:outer.minY)
                }
            }
        }.frame(width:28,height:23).accessibilityHidden(true)
    }
}

struct SettingsPanels {
    var prefs: Preferences
    var general: some View { GeneralSettingsPanel(prefs:prefs) }
    func card<Content:View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment:.leading,spacing:14,content:content).padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(.separator.opacity(0.5)))
    }
    func adjustment(_ title:String,value:Binding<Double>,range:ClosedRange<Double>,unit:String) -> some View {
        HStack { Text(title).frame(width:100,alignment:.leading); Slider(value:value,in:range,step:1); Text("\(Int(value.wrappedValue)) \(unit)").font(.system(size:11,design:.monospaced)).foregroundStyle(.secondary).frame(width:50,alignment:.trailing) }
    }
    var permissionCard: some View {
        VStack(alignment:.leading,spacing:10) {
            Label(L("允许辅助功能访问"),systemImage:"hand.raised.fill").font(.headline)
            Text(L("SnapKit 需要此权限才能移动其他应用的窗口。请在系统设置 → 隐私与安全性 → 辅助功能中开启 SnapKit。")).font(.system(size:12)).fixedSize(horizontal:false,vertical:true)
            HStack { Button(L("请求访问")) { WindowManager.requestAccess() }; Button(L("打开系统设置")) { NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) } }
        }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(.orange.opacity(0.10),in:RoundedRectangle(cornerRadius:10))
    }
    var ignored: some View {
        VStack(alignment:.leading,spacing:18) {
            Text(L("这些应用不会被快捷键或拖拽吸附调整。")).font(.caption).foregroundStyle(.secondary)
            Button(L("添加应用…")) {
                let panel=NSOpenPanel(); panel.directoryURL=URL(fileURLWithPath:"/Applications"); panel.allowedContentTypes=[.application]; panel.allowsMultipleSelection=true
                if panel.runModal() == .OK { for url in panel.urls { if let id=Bundle(url:url)?.bundleIdentifier { prefs.ignore(id) } } }
            }
            card {
                if prefs.ignored.isEmpty { Text(L("没有忽略的应用")).foregroundStyle(.secondary) }
                ForEach(prefs.ignored,id:\.self) { id in
                    HStack {
                        Text(NSWorkspace.shared.urlForApplication(withBundleIdentifier:id).flatMap { Bundle(url:$0)?.object(forInfoDictionaryKey:"CFBundleName") as? String } ?? id).font(.system(size:13))
                        Spacer(); Button(L("移除")) { prefs.ignored.removeAll{$0 == id} }.buttonStyle(.borderless)
                    }
                }
            }
        }
    }
    var about: some View {
        let version=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "1.1.0"
        return card {
            Image(nsImage:NSApp.applicationIconImage).resizable().interpolation(.high).frame(width:80,height:80).accessibilityLabel(L("SnapKit 图标"))
            Text("SnapKit \(version)").font(.title2.bold())
            Text(L("参照 Magnet 官网与 App Store 公开展示独立实现的 macOS 窗口管理工具。")).font(.system(size:13))
            Text(L("包含本地设置、自定义布局和多显示器支持；不包含 iCloud 同步。公开资料没有展示的细节未经过原版运行对照。")).font(.system(size:12)).foregroundStyle(.secondary)
            Divider()
            Text(L("macOS 13+ · AppKit + SwiftUI · 无第三方依赖")).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct GeneralSettingsPanel: View {
    @ObservedObject var prefs:Preferences
    @State private var login=SMAppService.mainApp.status == .enabled
    @State private var loginError=""
    private var helpers:SettingsPanels { SettingsPanels(prefs:prefs) }
    var body: some View {
        VStack(spacing:18) {
            helpers.card {
                HStack {
                    Text(L("语言"))
                    Spacer()
                    Picker(L("语言"),selection:$prefs.language) {
                        Text(L("跟随系统")).tag("system")
                        Text("简体中文").tag("zh-Hans")
                        Text("English").tag("en")
                    }.labelsHidden().frame(width:180)
                }
            }
            helpers.card {
                Toggle(L("启用键盘快捷键"),isOn:$prefs.shortcutsEnabled)
                Divider(); Toggle(L("启用拖到边缘吸附"),isOn:$prefs.snapping)
                Divider(); Toggle(L("拖离分屏位置时恢复原始尺寸"),isOn:$prefs.restoreOnDrag)
                Divider(); Toggle(L("暂停窗口管理"),isOn:$prefs.paused)
            }
            helpers.card {
                Toggle(L("登录时启动 SnapKit"),isOn:Binding(get:{login},set:{ v in
                    do { if v { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; login=SMAppService.mainApp.status == .enabled; loginError="" }
                    catch { loginError=error.localizedDescription }
                }))
                if SMAppService.mainApp.status == .requiresApproval { Text(L("请在系统设置 → 通用 → 登录项中允许启动。")).font(.caption).foregroundStyle(.secondary) }
                if !loginError.isEmpty { Text(loginError).font(.caption).foregroundStyle(.red) }
                Divider(); Toggle(L("在菜单栏显示图标"),isOn:$prefs.showIcon)
                Text(L("隐藏图标后，再次打开 SnapKit 即可进入设置。")).font(.caption).foregroundStyle(.secondary)
            }
            helpers.card {
                helpers.adjustment(L("窗口间距"),value:$prefs.gap,range:0...40,unit:"pt")
                Divider(); helpers.adjustment(L("屏幕外边距"),value:$prefs.margin,range:0...60,unit:"pt")
            }
        }.onReceive(Timer.publish(every:2,on:.main,in:.common).autoconnect()) { _ in login=SMAppService.mainApp.status == .enabled }
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    var id: String
    @ObservedObject var prefs: Preferences
    func makeNSView(context:Context) -> RecorderButton { let b=RecorderButton(); b.bezelStyle = .rounded; return b }
    func updateNSView(_ b:RecorderButton,context:Context) {
        b.commandID=id; b.prefs=prefs
        if !b.listening { b.title=prefs.shortcut(for:id)?.label ?? L("录制快捷键") }
    }
}
final class RecorderButton: NSButton {
    var commandID=""
    weak var prefs: Preferences?
    var listening=false
    override var acceptsFirstResponder: Bool { true }
    override init(frame:NSRect) { super.init(frame:frame); target=self; action=#selector(record) }
    required init?(coder:NSCoder) { fatalError() }
    @objc private func record() {
        window?.makeFirstResponder(self); listening=true; prefs?.recording=true; title=L("请按快捷键…")
    }
    override func keyDown(with event:NSEvent) {
        guard listening else { super.keyDown(with:event); return }
        if event.keyCode == 53 { finish(); return }
        if event.keyCode == 51 && event.modifierFlags.intersection([.command,.control,.option,.shift]).isEmpty { _=prefs?.assign(nil,to:commandID); finish(); return }
        var flags: UInt32=0
        if event.modifierFlags.contains(.control) { flags |= UInt32(controlKey) }
        if event.modifierFlags.contains(.option) { flags |= UInt32(optionKey) }
        if event.modifierFlags.contains(.command) { flags |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.shift) { flags |= UInt32(shiftKey) }
        guard flags & UInt32(controlKey|optionKey|cmdKey) != 0 else { title=L("请加 ⌃ / ⌥ / ⌘"); return }
        if let error=prefs?.assign(Shortcut(key:UInt32(event.keyCode),modifiers:flags),to:commandID) { prefs?.feedback=error; NSSound.beep() }
        finish()
    }
    override func performKeyEquivalent(with event:NSEvent) -> Bool { if listening { keyDown(with:event); return true }; return super.performKeyEquivalent(with:event) }
    override func resignFirstResponder() -> Bool { finish(); return super.resignFirstResponder() }
    private func finish() { if listening { listening=false; prefs?.recording=false }; title=prefs?.shortcut(for:commandID)?.label ?? L("录制快捷键") }
}
