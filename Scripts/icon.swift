import AppKit
// Export the approved icon at a requested size; never regenerate a different logo.
// Usage: swift Scripts/icon.swift OUTPUT_PNG [PIXEL_SIZE]
let output=CommandLine.arguments[1]
let pixels=CommandLine.arguments.count>2 ? Int(CommandLine.arguments[2])! : 1024
let source=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/AppIcon.png")
guard let image=NSImage(contentsOf:source), let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0), let context=NSGraphicsContext(bitmapImageRep:bitmap) else { fatalError("Cannot load approved icon") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current=context; context.imageInterpolation = .high
image.draw(in:NSRect(x:0,y:0,width:pixels,height:pixels),from:.zero,operation:.copy,fraction:1)
context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output))
