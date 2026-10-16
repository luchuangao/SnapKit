import SwiftUI
import AppKit

struct ReferenceSettingsView: View {
    @ObservedObject var prefs: Preferences
    let manager: WindowManager
    @State private var page="commands"
    @State private var section="general"
    @State private var trusted=WindowManager.trusted
    private let timer=Timer.publish(every:1,on:.main,in:.common).autoconnect()
    private var helpers: SettingsPanels { SettingsPanels(prefs:prefs) }
    init(prefs:Preferences,manager:WindowManager) {
        self.prefs=prefs; self.manager=manager
        let scene=ScreenshotCapture.scene
        _page=State(initialValue:scene == "commands" ? "commands" : "preferences")
        _section=State(initialValue:scene == "appearance" ? "appearance" : "general")
    }
    var body: some View {
        HStack(spacing:0) {
            VStack(spacing:12) {
                rail("preferences",symbol:"switch.2",label:L("偏好设置"))
                rail("commands",symbol:"command",label:L("命令"))
                Spacer()
                Circle().fill(prefs.paused ? .orange : trusted ? .green : .orange).frame(width:7,height:7).help(trusted ? L("辅助功能已授权") : L("需要辅助功能权限"))
                rail("about",symbol:"info.circle",label:L("关于 SnapKit"))
            }.padding(.top,28).padding(.bottom,18).frame(width:58).background(Color.accentColor.opacity(0.09))
            Divider()
            if page == "commands" {
                CommandEditor(prefs:prefs,manager:manager)
            } else {
                VStack(alignment:.leading,spacing:0) {
                    HStack {
                        Text(page == "about" ? "SnapKit" : L("偏好设置")).font(.system(size:14,weight:.semibold))
                        Spacer()
                        if page == "preferences" {
                            Picker("",selection:$section) { Text(L("通用")).tag("general"); Text(L("触发区与外观")).tag("appearance"); Text(L("忽略的应用")).tag("ignored") }.labelsHidden().pickerStyle(.segmented).frame(width:440)
                        }
                    }.padding(.horizontal,25).frame(height:46).background(Color(nsColor:.controlBackgroundColor))
                    Divider()
                    ScrollView {
                        VStack(alignment:.leading,spacing:20) {
                            if !trusted { helpers.permissionCard }
                            if page == "about" { helpers.about }
                            else if section == "general" { helpers.general }
                            else if section == "ignored" { helpers.ignored }
                            else { appearance }
                        }.padding(24)
                    }
                }.frame(maxWidth:.infinity)
            }
        }.frame(width:840,height:720).background(Color(nsColor:.windowBackgroundColor)).tint(Color(red:0,green:0.58,blue:0.94)).onReceive(timer) { _ in trusted=WindowManager.trusted }
    }
    func rail(_ id:String,symbol:String,label:String) -> some View {
        Button { page=id } label: {
            Image(systemName:symbol).font(.system(size:23,weight:.regular)).frame(width:40,height:40)
                .foregroundStyle(page == id ? Color.white : Color.accentColor)
                .background(page == id ? Color.accentColor : .clear,in:RoundedRectangle(cornerRadius:8))
        }.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }
    var appearance: some View {
        VStack(alignment:.leading,spacing:20) {
            Text(L("触发区域")).font(.system(size:12,weight:.semibold))
            helpers.card {
                Toggle(L("拖拽时高亮触发区域"),isOn:$prefs.highlightTriggers).toggleStyle(.switch).controlSize(.small)
                Divider()
                helpers.adjustment(L("边缘触发区宽度"),value:$prefs.threshold,range:4...40,unit:"pt")
                Divider()
                HStack { Text(L("触发停留时间")); Spacer(); Slider(value:$prefs.dwell,in:0...0.8,step:0.05).frame(width:160); Text(String(format:"%.0f ms",prefs.dwell*1000)).font(.caption.monospacedDigit()).frame(width:55,alignment:.trailing) }
            }
            Text(L("目标区域")).font(.system(size:12,weight:.semibold))
            helpers.card {
                HStack { Text(L("预览不透明度")); Spacer(); Slider(value:$prefs.opacity,in:0.05...0.6,step:0.01).frame(width:160); Text("\(Int(prefs.opacity*100))%").font(.caption.monospacedDigit()).frame(width:55,alignment:.trailing) }
                Divider()
                helpers.adjustment(L("预览边框宽度"),value:$prefs.outline,range:1...8,unit:"pt")
            }
            Text(L("绿色窗口按钮")).font(.system(size:12,weight:.semibold))
            helpers.card {
                Toggle(L("显示绿色按钮菜单"),isOn:$prefs.greenButton).toggleStyle(.switch).controlSize(.small)
                Text(L("悬停绿色按钮，选择窗口布局。实验功能，可能与系统菜单同时出现。")).font(.caption).foregroundStyle(.secondary)
                Divider()
                HStack { Text(L("悬停延迟")); Spacer(); Slider(value:$prefs.greenDelay,in:0.1...1,step:0.05).frame(width:160); Text(String(format:"%.0f ms",prefs.greenDelay*1000)).font(.caption.monospacedDigit()).frame(width:55,alignment:.trailing) }
            }
            Text(L("间距")).font(.system(size:12,weight:.semibold))
            helpers.card {
                helpers.adjustment(L("窗口间距"),value:$prefs.gap,range:0...40,unit:"pt")
                Divider()
                helpers.adjustment(L("屏幕外边距"),value:$prefs.margin,range:0...60,unit:"pt")
                Text(L("拖拽时按住 Option 可临时取消吸附。竖屏的三等分沿纵向排列。")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct CommandEditor: View {
    @ObservedObject var prefs: Preferences
    let manager: WindowManager
    @State private var selection=Layout.left.rawValue
    private var standard: Layout? { Layout(rawValue:selection) }
    private var customIndex: Int? { prefs.custom.firstIndex(where:{$0.id == selection}) }
    private var name: String { standard?.title ?? customIndex.map { prefs.custom[$0].name } ?? L("命令") }
    private var canEdit: Bool { standard?.unitRect != nil || customIndex != nil }
    private var target: CustomLayout {
        if let c=prefs.commandOverrides[selection] { return c }
        if let i=customIndex { return prefs.custom[i] }
        let r=standard?.unitRect ?? CGRect(x:0.25,y:0.25,width:0.5,height:0.5)
        return CustomLayout(id:selection,name:name,x:r.minX*100,y:r.minY*100,width:r.width*100,height:r.height*100)
    }
    private func setTarget(_ layout:CustomLayout) {
        if let i=customIndex { var c=layout; c.name=prefs.custom[i].name; c.id=selection; prefs.custom[i]=c }
        else if canEdit { prefs.commandOverrides[selection]=layout }
    }
    var body: some View {
        HStack(spacing:0) {
            VStack(alignment:.leading,spacing:0) {
                HStack { Text(L("命令")).font(.system(size:14,weight:.semibold)); Spacer() }.padding(.horizontal,18).frame(height:46).background(Color(nsColor:.controlBackgroundColor))
                Divider()
                HStack { Text(L("横屏 · 自动适配竖屏")).font(.system(size:11,weight:.semibold)).foregroundStyle(Color.accentColor); Spacer(); Button { let c=CustomLayout(name:L("我的命令 #")+String(prefs.custom.count+1)); prefs.custom.append(c); selection=c.id } label: { Image(systemName:"plus.circle.fill").font(.system(size:14)) }.buttonStyle(.plain).help(L("添加命令")).accessibilityLabel(L("添加命令")) }.padding(.horizontal,16).padding(.top,18).padding(.bottom,10)
                ScrollView {
                    VStack(alignment:.leading,spacing:2) {
                        if !prefs.custom.isEmpty {
                            ForEach(prefs.custom) { custom in row(custom.id,custom.name,layout:nil) }
                            separator
                        }
                        ForEach(Array(Layout.groups.enumerated()),id:\.offset) { index,group in
                            if index>0 { separator }
                            ForEach(group,id:\.rawValue) { l in row(l.rawValue,l.title,layout:l) }
                        }
                    }.padding(.horizontal,9).padding(.bottom,12)
                }
                Divider()
                HStack { Text(String(format:L("%d 个命令"),Layout.allCases.count+prefs.custom.count)).font(.system(size:10)).foregroundStyle(.secondary); Spacer(); Button(L("重置")) { if let s=standard { prefs.commandOverrides.removeValue(forKey:s.rawValue); prefs.customTriggers.removeValue(forKey:s.rawValue); prefs.disabledTriggers.removeAll{$0 == s.rawValue}; prefs.shortcuts.removeValue(forKey:s.rawValue); prefs.disabledShortcuts.removeAll{$0 == s.rawValue} } }.font(.system(size:10)).buttonStyle(.borderless).disabled(standard == nil) }.padding(12)
            }.frame(width:218).background(Color.accentColor.opacity(0.035))
            Divider()
            VStack(alignment:.leading,spacing:0) {
                HStack {
                    if let i=customIndex {
                        TextField(L("命令名称"),text:$prefs.custom[i].name).textFieldStyle(.plain).font(.system(size:14,weight:.semibold))
                        Button { let id=selection; prefs.custom.removeAll{$0.id == id}; prefs.customTriggers.removeValue(forKey:id); prefs.shortcuts.removeValue(forKey:id); selection=Layout.left.rawValue } label: { Image(systemName:"trash") }.buttonStyle(.borderless).help(L("删除命令"))
                    } else { Text(name).font(.system(size:14,weight:.semibold)) }
                    Spacer()
                }.padding(.horizontal,24).frame(height:46).background(Color(nsColor:.controlBackgroundColor))
                Divider()
                ScrollView {
                    VStack(alignment:.leading,spacing:18) {
                        if !WindowManager.trusted {
                            HStack(alignment:.top,spacing:8) {
                                Image(systemName:"lock.fill").foregroundStyle(.orange)
                                VStack(alignment:.leading,spacing:5) { Text(L("需要辅助功能权限才能调整窗口")).font(.system(size:11,weight:.medium)); Button(L("打开授权设置…")) { WindowManager.requestAccess(); NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) }.font(.system(size:11)) }
                            }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(.orange.opacity(0.08),in:RoundedRectangle(cornerRadius:8))
                        }
                        editorCard {
                            HStack { Text(L("目标窗口尺寸与位置")).font(.system(size:11,weight:.medium)); Spacer(); if prefs.commandOverrides[selection] != nil { Button(L("恢复默认")) { prefs.commandOverrides.removeValue(forKey:selection) }.font(.system(size:10)).buttonStyle(.borderless) } }
                            if canEdit {
                                LayoutGrid(value:target,editable:true,triggerMode:false,onChange:setTarget).frame(height:190)
                                HStack(spacing:8) {
                                    numeric("X",value:target.x,keyPath:\.x,max:99)
                                    numeric("Y",value:target.y,keyPath:\.y,max:99)
                                    numeric(L("宽"),value:target.width,keyPath:\.width,max:100)
                                    numeric(L("高"),value:target.height,keyPath:\.height,max:100)
                                }
                                Text(L("拖选网格定义区域；也可以输入精确百分比。")).font(.system(size:10)).foregroundStyle(.secondary)
                            } else {
                                Image(systemName:standard == .restore ? "arrow.uturn.backward" : standard == .center ? "dot.scope" : "display.2").font(.system(size:45,weight:.ultraLight)).foregroundStyle(Color.accentColor).frame(maxWidth:.infinity).frame(height:140)
                                Text(standard == .restore ? L("恢复此窗口第一次分屏前的尺寸和位置。") : standard == .center ? L("保留当前窗口尺寸，在显示器可用区域内居中。") : L("按屏幕排列顺序，将窗口移到相邻显示器并按比例调整。 ")).font(.system(size:11)).foregroundStyle(.secondary)
                            }
                        }
                        editorCard {
                            HStack { Text(L("键盘快捷键")).font(.system(size:11,weight:.medium)); Spacer(); Toggle("",isOn:Binding(get:{prefs.shortcut(for:selection) != nil},set:{ enabled in
                                if enabled { prefs.disabledShortcuts.removeAll{$0 == selection} }
                                else { _=prefs.assign(nil,to:selection) }
                            })).labelsHidden().toggleStyle(.switch).controlSize(.mini) }
                            ShortcutRecorder(id:selection,prefs:prefs).frame(height:27)
                            Text(L("点击录制 · Delete 清除 · Esc 取消")).font(.system(size:10)).foregroundStyle(.secondary)
                        }
                        if canEdit {
                            editorCard {
                                HStack { Text(L("拖拽触发区域")).font(.system(size:11,weight:.medium)); Spacer(); Toggle("",isOn:Binding(get:{!prefs.disabledTriggers.contains(selection) && (standard != nil || prefs.customTriggers[selection] != nil)},set:{ enabled in
                                    if enabled { prefs.disabledTriggers.removeAll{$0 == selection}; if standard == nil && prefs.customTriggers[selection] == nil { prefs.customTriggers[selection]=CustomLayout(id:selection,name:name,x:0,y:40,width:4,height:20) } } else if !prefs.disabledTriggers.contains(selection) { prefs.disabledTriggers.append(selection) }
                                })).labelsHidden().toggleStyle(.switch).controlSize(.mini) }
                                LayoutGrid(value:triggerRegion,editable:!prefs.disabledTriggers.contains(selection),triggerMode:true) { prefs.customTriggers[selection]=$0 }.frame(height:145).opacity(prefs.disabledTriggers.contains(selection) ? 0.35 : 1)
                                HStack { Text(L("拖选触发位置，经过该区域时吸附。")).font(.system(size:10)).foregroundStyle(.secondary); Spacer(); if prefs.customTriggers[selection] != nil { Button(L("恢复默认")) { prefs.customTriggers.removeValue(forKey:selection) }.font(.system(size:10)).buttonStyle(.borderless) } }
                            }
                        }
                        if !prefs.feedback.isEmpty { Text(prefs.feedback).font(.system(size:11)).foregroundStyle(.secondary) }
                        ForEach(prefs.hotkeyErrors,id:\.self) { Text($0).font(.system(size:11)).foregroundStyle(.orange) }
                    }.padding(18)
                }
            }.frame(maxWidth:.infinity).id(selection)
        }
    }
    var separator: some View { RoundedRectangle(cornerRadius:2).fill(Color.accentColor.opacity(0.3)).frame(width:23,height:3).padding(.leading,9).padding(.vertical,7) }
    func row(_ id:String,_ text:String,layout:Layout?) -> some View {
        Button { selection=id } label: {
            HStack(spacing:8) {
                if let layout { LayoutGlyph(layout:layout).scaleEffect(0.8).frame(width:24,height:20) }
                else { Image(systemName:"rectangle.inset.filled").frame(width:24,height:20) }
                Text(text).font(.system(size:11)).lineLimit(1)
                Spacer(minLength:0)
                if prefs.disabledTriggers.contains(id) { Image(systemName:"cursorarrow.slash").font(.system(size:10)).opacity(0.5) }
            }.padding(.horizontal,8).padding(.vertical,4).foregroundStyle(selection == id ? Color.white : Color.primary)
                .background(selection == id ? Color.accentColor : .clear,in:RoundedRectangle(cornerRadius:5))
        }.buttonStyle(.plain)
    }
    func editorCard<Content:View>(@ViewBuilder _ content:() -> Content) -> some View {
        VStack(alignment:.leading,spacing:12,content:content).padding(12).frame(maxWidth:.infinity,alignment:.leading)
            .background(Color.accentColor.opacity(0.035),in:RoundedRectangle(cornerRadius:6))
            .overlay(RoundedRectangle(cornerRadius:6).stroke(Color.accentColor.opacity(0.16)))
    }
    func numeric(_ label:String,value:Double,keyPath:WritableKeyPath<CustomLayout,Double>,max:Double) -> some View {
        HStack(spacing:3) { Text(label).font(.system(size:10)).foregroundStyle(.secondary); TextField("",value:Binding(get:{value},set:{ v in var t=target; t[keyPath:keyPath]=min(Swift.max(v,keyPath == \.x || keyPath == \.y ? 0 : 1),max); setTarget(t) }),format:.number.precision(.fractionLength(0))).textFieldStyle(.roundedBorder).font(.system(size:11,design:.monospaced)); Text("%").font(.system(size:9)).foregroundStyle(.secondary) }
    }
    var triggerRegion:CustomLayout {
        if let r=prefs.customTriggers[selection] { return r }
        let layout=standard
        let r: CGRect
        switch layout {
        case .left: r=CGRect(x:0,y:0.2,width:0.025,height:0.6)
        case .right: r=CGRect(x:0.975,y:0.2,width:0.025,height:0.6)
        case .topLeft: r=CGRect(x:0,y:0,width:0.04,height:0.1)
        case .topRight: r=CGRect(x:0.96,y:0,width:0.04,height:0.1)
        case .bottomLeft: r=CGRect(x:0,y:0.9,width:0.04,height:0.1)
        case .bottomRight: r=CGRect(x:0.96,y:0.9,width:0.04,height:0.1)
        case .leftThird,.leftTwoThirds: r=CGRect(x:0.17,y:0.96,width:0.16,height:0.04)
        case .centerThird,.centerTwoThirds: r=CGRect(x:0.34,y:0.96,width:0.32,height:0.04)
        case .rightThird,.rightTwoThirds: r=CGRect(x:0.67,y:0.96,width:0.16,height:0.04)
        case .maximize: r=CGRect(x:0.16,y:0,width:0.68,height:0.04)
        default: r = .zero
        }
        return CustomLayout(id:selection,name:name,x:r.minX*100,y:r.minY*100,width:r.width*100,height:r.height*100)
    }
}

struct LayoutGrid: View {
    var value:CustomLayout
    var editable:Bool
    var triggerMode:Bool
    var onChange:(CustomLayout) -> Void
    @State private var anchor:CGPoint?
    private let columns=24, rows=12
    var body: some View {
        GeometryReader { proxy in
            let frame=CGRect(x:18,y:18,width:proxy.size.width-30,height:proxy.size.height-28)
            Canvas { context,size in
                let cw=frame.width/CGFloat(columns), ch=frame.height/CGFloat(rows)
                for row in 0..<rows { for col in 0..<columns {
                    let x=(Double(col)+0.5)/Double(columns)*100, y=(Double(row)+0.5)/Double(rows)*100
                    let active=x>=value.x && x<value.x+value.width && y>=value.y && y<value.y+value.height
                    let r=CGRect(x:frame.minX+CGFloat(col)*cw+1,y:frame.minY+CGFloat(row)*ch+1,width:cw-2,height:ch-2)
                    context.fill(Path(roundedRect:r,cornerRadius:triggerMode ? 3 : 2),with:.color(Color.accentColor.opacity(active ? 0.95 : triggerMode ? 0.17 : 0.22)))
                } }
                if triggerMode {
                    let region=CGRect(x:frame.minX+frame.width*value.x/100,y:frame.minY+frame.height*value.y/100,width:frame.width*value.width/100,height:frame.height*value.height/100)
                    if region.width>0 && region.height>0 { context.fill(Path(roundedRect:region,cornerRadius:5),with:.color(Color.accentColor.opacity(0.6))) }
                    context.stroke(Path(roundedRect:frame,cornerRadius:6),with:.color(Color.accentColor.opacity(0.25)),lineWidth:5)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance:0).onChanged { gesture in
                guard editable else { return }
                let p=CGPoint(x:min(max(gesture.location.x-frame.minX,0),frame.width-0.01),y:min(max(gesture.location.y-frame.minY,0),frame.height-0.01))
                if anchor == nil { let s=gesture.startLocation; anchor=CGPoint(x:min(max(s.x-frame.minX,0),frame.width-0.01),y:min(max(s.y-frame.minY,0),frame.height-0.01)) }
                guard let anchor else { return }
                let c1=Int(anchor.x/frame.width*CGFloat(columns)), c2=Int(p.x/frame.width*CGFloat(columns))
                let r1=Int(anchor.y/frame.height*CGFloat(rows)), r2=Int(p.y/frame.height*CGFloat(rows))
                var next=value
                next.x=Double(min(c1,c2))/Double(columns)*100; next.y=Double(min(r1,r2))/Double(rows)*100
                next.width=Double(abs(c1-c2)+1)/Double(columns)*100; next.height=Double(abs(r1-r2)+1)/Double(rows)*100
                onChange(next)
            }.onEnded { _ in anchor=nil })
            if !triggerMode {
                Text(fraction(value.width)).font(.system(size:10,weight:.medium)).foregroundStyle(.white).padding(.horizontal,4).padding(.vertical,2).background(Color.accentColor,in:RoundedRectangle(cornerRadius:3)).position(x:frame.minX+frame.width*(value.x+value.width/2)/100,y:8)
            }
        }.accessibilityLabel(triggerMode ? L("拖拽触发区域网格") : L("窗口尺寸与位置网格"))
    }
    func fraction(_ number:Double) -> String { if abs(number-50)<0.1 { return "½" }; if abs(number-100/3)<0.1 { return "⅓" }; if abs(number-200/3)<0.1 { return "⅔" }; return String(format:"%.0f%%",number) }
}
