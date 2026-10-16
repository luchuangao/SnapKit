import AppKit
import Carbon
import Combine

struct Shortcut: Codable, Equatable {
    var key: UInt32
    var modifiers: UInt32
    static let base = UInt32(controlKey | optionKey)
    var label: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + (Self.keys[key] ?? "[\(key)]")
    }
    static let keys: [UInt32:String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",36:"↩",37:"L",38:"J",39:"’",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",48:"⇥",49:"Space",50:"`",51:"⌫",53:"⎋",96:"F5",97:"F6",98:"F7",99:"F3",100:"F8",101:"F9",103:"F11",109:"F10",111:"F12",118:"F4",120:"F2",122:"F1",123:"←",124:"→",125:"↓",126:"↑"]
    static func defaultFor(_ layout: Layout) -> Shortcut {
        let codes: [Layout:UInt32] = [.left:123,.right:124,.top:126,.bottom:125,.topLeft:32,.topRight:34,.bottomLeft:38,.bottomRight:40,.leftThird:2,.centerThird:3,.rightThird:5,.leftTwoThirds:14,.centerTwoThirds:15,.rightTwoThirds:17,.maximize:36,.center:8,.restore:51,.nextDisplay:124,.previousDisplay:123]
        return Shortcut(key:codes[layout]!,modifiers:base | ([.nextDisplay,.previousDisplay].contains(layout) ? UInt32(cmdKey) : 0))
    }
}

struct CustomLayout: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var name: String = L("自定义布局")
    var x: Double = 10
    var y: Double = 10
    var width: Double = 80
    var height: Double = 80
    func frame(in bounds: CGRect) -> CGRect {
        Geometry.clamp(CGRect(x:bounds.minX+bounds.width*x/100,y:bounds.minY+bounds.height*y/100,width:bounds.width*width/100,height:bounds.height*height/100),to:bounds)
    }
}

final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard
    @Published var language = L10n.launchLanguage ?? UserDefaults.standard.string(forKey:"appLanguage") ?? "system" {
        didSet { defaults.set(language,forKey:"appLanguage"); onChange?() }
    }
    @Published var snapping = true { didSet { save() } }
    @Published var shortcutsEnabled = true { didSet { save() } }
    @Published var restoreOnDrag = true { didSet { save() } }
    @Published var greenButton = false { didSet { save() } }
    @Published var showIcon = true { didSet { save() } }
    @Published var gap: Double = 0 { didSet { save() } }
    @Published var margin: Double = 0 { didSet { save() } }
    @Published var threshold: Double = 12 { didSet { save() } }
    @Published var dwell: Double = 0.15 { didSet { save() } }
    @Published var opacity: Double = 0.22 { didSet { save() } }
    @Published var ignored: [String] = [] { didSet { save() } }
    @Published var shortcuts: [String:Shortcut] = [:] { didSet { save() } }
    @Published var disabledShortcuts: [String] = [] { didSet { save() } }
    @Published var custom: [CustomLayout] = [] { didSet { save() } }
    @Published var paused = false
    @Published var feedback = ""
    @Published var recording = false
    @Published var hotkeyErrors: [String] = []
    @Published var commandOverrides: [String:CustomLayout] = [:] { didSet { save() } }
    @Published var customTriggers: [String:CustomLayout] = [:] { didSet { save() } }
    @Published var disabledTriggers: [String] = [] { didSet { save() } }
    @Published var highlightTriggers = true { didSet { save() } }
    @Published var outline: Double = 2 { didSet { save() } }
    @Published var greenDelay: Double = 0.45 { didSet { save() } }
    var onChange: (() -> Void)?
    private var loading = true
    init() {
        if let data = defaults.data(forKey:"preferences"), let p = try? JSONDecoder().decode(State.self,from:data) {
            snapping=p.snapping; shortcutsEnabled=p.shortcutsEnabled; restoreOnDrag=p.restoreOnDrag
            greenButton=p.greenButton; showIcon=p.showIcon; gap=p.gap; margin=p.margin
            threshold=p.threshold; dwell=p.dwell; opacity=p.opacity; ignored=p.ignored
            shortcuts=p.shortcuts; disabledShortcuts=p.disabledShortcuts; custom=p.custom
        }
        if let data=defaults.data(forKey:"commandSettings"), let e=try? JSONDecoder().decode(Extras.self,from:data) {
            commandOverrides=e.overrides; customTriggers=e.triggers; disabledTriggers=e.disabled
            highlightTriggers=e.highlight; outline=e.outline; greenDelay=e.greenDelay
        }
        loading=false
    }
    private struct Extras: Codable {
        var overrides: [String:CustomLayout]; var triggers: [String:CustomLayout]; var disabled: [String]
        var highlight: Bool; var outline: Double; var greenDelay: Double
    }
    private struct State: Codable {
        var snapping: Bool; var shortcutsEnabled: Bool; var restoreOnDrag: Bool
        var greenButton: Bool; var showIcon: Bool; var gap: Double; var margin: Double
        var threshold: Double; var dwell: Double; var opacity: Double; var ignored: [String]
        var shortcuts: [String:Shortcut]; var disabledShortcuts: [String]; var custom: [CustomLayout]
    }
    private func save() {
        guard !loading else { return }
        let s = State(snapping:snapping,shortcutsEnabled:shortcutsEnabled,restoreOnDrag:restoreOnDrag,greenButton:greenButton,showIcon:showIcon,gap:gap,margin:margin,threshold:threshold,dwell:dwell,opacity:opacity,ignored:ignored,shortcuts:shortcuts,disabledShortcuts:disabledShortcuts,custom:custom)
        if let data = try? JSONEncoder().encode(s) { defaults.set(data,forKey:"preferences") }
        let extras=Extras(overrides:commandOverrides,triggers:customTriggers,disabled:disabledTriggers,highlight:highlightTriggers,outline:outline,greenDelay:greenDelay)
        if let data=try? JSONEncoder().encode(extras) { defaults.set(data,forKey:"commandSettings") }
        onChange?()
    }
    func shortcut(for id: String) -> Shortcut? {
        if disabledShortcuts.contains(id) { return nil }
        return shortcuts[id] ?? Layout(rawValue:id).map(Shortcut.defaultFor)
    }
    func assign(_ shortcut: Shortcut?, to id: String) -> String? {
        if let shortcut {
            for other in Layout.allCases.map(\.rawValue) + custom.map(\.id) where other != id {
                if self.shortcut(for:other) == shortcut { return L("该快捷键已用于：")+(Layout(rawValue:other)?.title ?? custom.first(where:{$0.id == other})?.name ?? other) }
            }
            shortcuts[id] = shortcut
            disabledShortcuts.removeAll { $0 == id }
        } else {
            if !disabledShortcuts.contains(id) { disabledShortcuts.append(id) }
        }
        feedback = shortcut == nil ? L("快捷键已停用。") : L("快捷键已保存。")
        return nil
    }
    func ignore(_ id: String) { if !ignored.contains(id) { ignored.append(id) } }
}
