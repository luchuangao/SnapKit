import AppKit

/// Exports the actual rendered settings window for documentation, in either language.
/// No screen recording or access to other applications is used.
enum ScreenshotCapture {
    static func argument(_ key:String) -> String? {
        let args=CommandLine.arguments
        guard let i=args.firstIndex(of:key), args.indices.contains(i+1) else { return nil }
        return args[i+1]
    }
    static var outputDirectory:String? { argument("--capture-directory") }
    static var scene:String { argument("--capture-scene") ?? "commands" }
    static func capture(_ window:NSWindow) {
        DispatchQueue.main.asyncAfter(deadline:.now()+1) {
            guard let outputDirectory, let view=window.contentView?.superview else { NSApp.terminate(nil); return }
            view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
            guard let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) else { NSApp.terminate(nil); return }
            view.cacheDisplay(in:view.bounds,to:bitmap)
            do {
                let dir=URL(fileURLWithPath:outputDirectory,isDirectory:true)
                try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
                let suffix=L10n.language == "en" ? "en" : "zh"
                let filename="snapkit-\(scene)-\(suffix).png"
                guard let png=bitmap.representation(using:.png,properties:[:]) else { throw CocoaError(.fileWriteUnknown) }
                try png.write(to:dir.appendingPathComponent(filename))
                let record:[String:Any] = ["file":filename,"language":suffix,"scene":scene,"width":bitmap.pixelsWide,"height":bitmap.pixelsHigh,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "","capture":"NSWindow rendered view","accessibilityGranted":WindowManager.trusted]
                let metadata=try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys])
                try metadata.write(to:dir.appendingPathComponent(filename+".json"))
                print("Exported \(filename): \(bitmap.pixelsWide) × \(bitmap.pixelsHigh)")
            } catch { fputs("Screenshot export failed: \(error)\n",stderr) }
            NSApp.terminate(nil)
        }
    }
}
