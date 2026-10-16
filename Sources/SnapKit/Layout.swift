import Foundation

enum Layout: String, CaseIterable, Codable {
    case left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird, leftTwoThirds, centerTwoThirds, rightTwoThirds
    case maximize, center, restore, nextDisplay, previousDisplay
    var title: String {
        switch self {
        case .left: return L("左半屏"); case .right: return L("右半屏")
        case .top: return L("上半屏"); case .bottom: return L("下半屏")
        case .topLeft: return L("左上角"); case .topRight: return L("右上角")
        case .bottomLeft: return L("左下角"); case .bottomRight: return L("右下角")
        case .leftThird: return L("左侧三分之一"); case .centerThird: return L("中间三分之一")
        case .rightThird: return L("右侧三分之一"); case .leftTwoThirds: return L("左侧三分之二")
        case .centerTwoThirds: return L("中间三分之二"); case .rightTwoThirds: return L("右侧三分之二")
        case .maximize: return L("最大化"); case .center: return L("居中")
        case .restore: return L("恢复原始尺寸"); case .nextDisplay: return L("下一个显示器")
        case .previousDisplay: return L("上一个显示器")
        }
    }
    static let groups: [[Layout]] = [[.left,.right,.top,.bottom],[.topLeft,.topRight,.bottomLeft,.bottomRight],[.leftThird,.centerThird,.rightThird,.leftTwoThirds,.centerTwoThirds,.rightTwoThirds],[.maximize,.center,.restore],[.nextDisplay,.previousDisplay]]
    // Normalized top-left coordinates, shared by AX geometry and the preview glyphs.
    var unitRect: CGRect? {
        switch self {
        case .left: return CGRect(x: 0,y: 0,width: 0.5,height: 1)
        case .right: return CGRect(x: 0.5,y: 0,width: 0.5,height: 1)
        case .top: return CGRect(x: 0,y: 0,width: 1,height: 0.5)
        case .bottom: return CGRect(x: 0,y: 0.5,width: 1,height: 0.5)
        case .topLeft: return CGRect(x: 0,y: 0,width: 0.5,height: 0.5)
        case .topRight: return CGRect(x: 0.5,y: 0,width: 0.5,height: 0.5)
        case .bottomLeft: return CGRect(x: 0,y: 0.5,width: 0.5,height: 0.5)
        case .bottomRight: return CGRect(x: 0.5,y: 0.5,width: 0.5,height: 0.5)
        case .leftThird: return CGRect(x: 0,y: 0,width: 1.0/3,height: 1)
        case .centerThird: return CGRect(x: 1.0/3,y: 0,width: 1.0/3,height: 1)
        case .rightThird: return CGRect(x: 2.0/3,y: 0,width: 1.0/3,height: 1)
        case .leftTwoThirds: return CGRect(x: 0,y: 0,width: 2.0/3,height: 1)
        case .centerTwoThirds: return CGRect(x: 1.0/6,y: 0,width: 2.0/3,height: 1)
        case .rightTwoThirds: return CGRect(x: 1.0/3,y: 0,width: 2.0/3,height: 1)
        case .maximize: return CGRect(x: 0,y: 0,width: 1,height: 1)
        default: return nil
        }
    }
    func frame(in screen: CGRect, current: CGRect, gap: CGFloat = 0, margin: CGFloat = 0) -> CGRect {
        let usable = screen.insetBy(dx: margin, dy: margin)
        guard let r = unitRect else {
            return Geometry.clamp(CGRect(x: usable.midX-current.width/2,y: usable.midY-current.height/2,width: current.width,height: current.height), to: usable)
        }
        // Round shared boundaries, rather than widths, to avoid seams on odd-sized screens.
        let x1 = (usable.minX+r.minX*usable.width).rounded()
        let x2 = (usable.minX+r.maxX*usable.width).rounded()
        let y1 = (usable.minY+r.minY*usable.height).rounded()
        let y2 = (usable.minY+r.maxY*usable.height).rounded()
        let left = r.minX > 0 ? gap/2 : 0, right = r.maxX < 1 ? gap/2 : 0
        let top = r.minY > 0 ? gap/2 : 0, bottom = r.maxY < 1 ? gap/2 : 0
        return CGRect(x:x1+left,y:y1+top,width:max(1,x2-x1-left-right),height:max(1,y2-y1-top-bottom))
    }
}

struct Geometry {
    static func clamp(_ frame: CGRect, to bounds: CGRect) -> CGRect {
        let w = min(frame.width,bounds.width), h = min(frame.height,bounds.height)
        return CGRect(x:min(max(frame.minX,bounds.minX),bounds.maxX-w),y:min(max(frame.minY,bounds.minY),bounds.maxY-h),width:w,height:h)
    }
    static func screenIndex(for frame: CGRect, screens: [CGRect]) -> Int? {
        screens.indices.max { a,b in
            let x = screens[a].intersection(frame), y = screens[b].intersection(frame)
            return (x.isNull ? 0 : x.width*x.height) < (y.isNull ? 0 : y.width*y.height)
        }
    }
    static func transfer(_ window: CGRect, from: CGRect, to: CGRect) -> CGRect {
        guard from.width > 0, from.height > 0 else { return clamp(window,to:to) }
        return clamp(CGRect(x:to.minX+(window.minX-from.minX)/from.width*to.width,y:to.minY+(window.minY-from.minY)/from.height*to.height,width:window.width/from.width*to.width,height:window.height/from.height*to.height),to:to)
    }
    static func trigger(at p: CGPoint, screen: CGRect, threshold: CGFloat, portrait: Bool) -> Layout? {
        guard screen.insetBy(dx:-2,dy:-2).contains(p) else { return nil }
        let left = p.x <= screen.minX+threshold, right = p.x >= screen.maxX-threshold
        let top = p.y <= screen.minY+threshold, bottom = p.y >= screen.maxY-threshold
        let x = (p.x-screen.minX)/screen.width, y = (p.y-screen.minY)/screen.height
        let corner: CGFloat = 0.16
        if (left && y < corner) || (top && x < corner) { return .topLeft }
        if (right && y < corner) || (top && x > 1-corner) { return .topRight }
        if (left && y > 1-corner) || (bottom && x < corner) { return .bottomLeft }
        if (right && y > 1-corner) || (bottom && x > 1-corner) { return .bottomRight }
        if portrait {
            if left || right { return y < 1.0/3 ? .leftThird : y > 2.0/3 ? .rightThird : .centerThird }
            if top { return .maximize }
            if bottom { return x < 0.5 ? .top : .bottom }
        } else {
            if left { return .left }; if right { return .right }; if top { return .maximize }
            if bottom { return x < 1.0/3 ? .leftThird : x > 2.0/3 ? .rightThird : .centerThird }
        }
        return nil
    }
    static func portraitFrame(_ layout: Layout, in screen: CGRect, current: CGRect, gap: CGFloat, margin: CGFloat) -> CGRect {
        // On portrait monitors, thirds run along the long axis.
        guard [.leftThird,.centerThird,.rightThird,.leftTwoThirds,.centerTwoThirds,.rightTwoThirds].contains(layout), let r = layout.unitRect else {
            return layout.frame(in:screen,current:current,gap:gap,margin:margin)
        }
        let usable = screen.insetBy(dx:margin,dy:margin)
        let y1 = (usable.minY+r.minX*usable.height).rounded(), y2 = (usable.minY+r.maxX*usable.height).rounded()
        let t = r.minX > 0 ? gap/2 : 0, b = r.maxX < 1 ? gap/2 : 0
        return CGRect(x:usable.minX,y:y1+t,width:usable.width,height:max(1,y2-y1-t-b))
    }
}
