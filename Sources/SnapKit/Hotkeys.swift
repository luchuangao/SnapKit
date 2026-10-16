import AppKit
import Carbon

final class Hotkeys {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var actions: [UInt32:() -> Void] = [:]
    var enabled = true
    init() {
        var type = EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),{ _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue()
            var id = EventHotKeyID()
            let status = GetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),nil,MemoryLayout<EventHotKeyID>.size,nil,&id)
            guard status == noErr, owner.enabled, !Preferences.shared.recording else { return OSStatus(eventNotHandledErr) }
            owner.actions[id.id]?()
            return noErr
        },1,&type,Unmanaged.passUnretained(self).toOpaque(),&handler)
    }
    func register(prefs: Preferences, manager: WindowManager) {
        unregister()
        var errors: [String] = []
        guard prefs.shortcutsEnabled, !prefs.recording else { prefs.hotkeyErrors=[]; return }
        let commands: [(String,String,() -> Void)] = Layout.allCases.map { l in (l.rawValue,l.title,{ manager.apply(l) }) } + prefs.custom.map { c in (c.id,c.name,{ manager.apply(c) }) }
        for (index,command) in commands.enumerated() {
            guard let shortcut=prefs.shortcut(for:command.0) else { continue }
            let id = UInt32(index+1)
            var ref: EventHotKeyRef?
            let result = RegisterEventHotKey(shortcut.key,shortcut.modifiers,EventHotKeyID(signature:0x534E4150,id:id),GetApplicationEventTarget(),0,&ref)
            if result == noErr, let ref { refs.append(ref); actions[id]=command.2 }
            else { errors.append(command.1+": "+shortcut.label+L(" 已被其他程序占用")+" (\(result))") }
        }
        prefs.hotkeyErrors=errors
    }
    func unregister() { refs.forEach { UnregisterEventHotKey($0) }; refs=[]; actions=[:] }
    deinit { refs.forEach { UnregisterEventHotKey($0) }; if let handler { RemoveEventHandler(handler) } }
}
