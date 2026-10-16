import AppKit

// Opt-in integration check uses only a disposable window owned by this process.
// It never resizes a user's existing windows.
enum SmokeTest {
    static var window: NSWindow?
    static func run(manager:WindowManager) {
        DispatchQueue.main.asyncAfter(deadline:.now()+1) {
            let w=NSWindow(contentRect:CGRect(x:200,y:220,width:460,height:340),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
            w.title="SnapKit Integration Test"; w.isReleasedWhenClosed=false
            w.contentView=NSTextField(labelWithString:"SnapKit disposable test window")
            w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true); window=w
            DispatchQueue.main.asyncAfter(deadline:.now()+0.5) {
                var result: [String:Any] = ["trusted":WindowManager.trusted]
                if WindowManager.trusted {
                    let app=AXUIElementCreateApplication(getpid()); var value: CFTypeRef?
                    AXUIElementCopyAttributeValue(app,kAXFocusedWindowAttribute as CFString,&value)
                    if let value, CFGetTypeID(value)==AXUIElementGetTypeID(), let screen=WindowManager.visibleScreens.first {
                        let target=ManagedWindow(element:value as! AXUIElement,pid:getpid(),appID:Bundle.main.bundleIdentifier ?? "")
                        let original=target.frame!
                        var checks: [[String:Any]]=[]
                        for l in [Layout.left,.right,.topLeft,.bottomRight,.centerThird,.maximize,.center,.restore] {
                            let expected=l == .restore ? original : manager.targetFrame(l,screen:screen,current:target.frame ?? original)
                            let applied=manager.apply(l,to:target,on:screen)
                            let actual=target.frame ?? .zero
                            let tolerance: CGFloat=3
                            checks.append(["layout":l.rawValue,"applied":applied,"expected":NSStringFromRect(expected),"actual":NSStringFromRect(actual),"matches":abs(actual.minX-expected.minX)<tolerance && abs(actual.minY-expected.minY)<tolerance && abs(actual.width-expected.width)<tolerance && abs(actual.height-expected.height)<tolerance])
                        }
                        result["checks"]=checks; result["passed"]=checks.allSatisfy{$0["matches"] as? Bool == true}
                    } else { result["error"]="No test window AX element" }
                }
                if let data=try? JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]) {
                    try? data.write(to:URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("snapkit-smoke-test.json"))
                }
                w.close(); window=nil; NSApp.terminate(nil)
            }
        }
    }
}
