import XCTest
@testable import SnapKit

final class GeometryTests: XCTestCase {
    let screen=CGRect(x:0,y:25,width:1513,height:947)
    func testThirdsSharePixelBoundariesOnOddWidth() {
        let a=Layout.leftThird.frame(in:screen,current:.zero), b=Layout.centerThird.frame(in:screen,current:.zero), c=Layout.rightThird.frame(in:screen,current:.zero)
        XCTAssertEqual(a.minX,screen.minX); XCTAssertEqual(a.maxX,b.minX); XCTAssertEqual(b.maxX,c.minX); XCTAssertEqual(c.maxX,screen.maxX)
    }
    func testAllLayoutsStayWithinOffsetScreen() {
        let secondary=CGRect(x:-1800,y:-400,width:1800,height:1100)
        for layout in Layout.allCases where layout.unitRect != nil {
            let frame=layout.frame(in:secondary,current:.zero,gap:14,margin:8)
            XCTAssertTrue(secondary.contains(frame),"\(layout)")
            XCTAssertGreaterThan(frame.width,0); XCTAssertGreaterThan(frame.height,0)
        }
    }
    func testGapAndMargins() {
        let a=Layout.left.frame(in:screen,current:.zero,gap:12,margin:10)
        let b=Layout.right.frame(in:screen,current:.zero,gap:12,margin:10)
        XCTAssertEqual(b.minX-a.maxX,12); XCTAssertEqual(a.minX,10); XCTAssertEqual(b.maxX,screen.maxX-10)
    }
    func testPortraitThirdsCoverLongAxis() {
        let s=CGRect(x:1920,y:-300,width:900,height:1600)
        let a=Geometry.portraitFrame(.leftThird,in:s,current:.zero,gap:0,margin:0)
        let b=Geometry.portraitFrame(.centerThird,in:s,current:.zero,gap:0,margin:0)
        let c=Geometry.portraitFrame(.rightThird,in:s,current:.zero,gap:0,margin:0)
        XCTAssertEqual(a.width,900); XCTAssertEqual(a.minY,s.minY); XCTAssertEqual(a.maxY,b.minY); XCTAssertEqual(b.maxY,c.minY); XCTAssertEqual(c.maxY,s.maxY)
    }
    func testCornerPrecedenceAndCancellation() {
        let s=CGRect(x:0,y:0,width:1200,height:800)
        XCTAssertEqual(Geometry.trigger(at:CGPoint(x:1,y:1),screen:s,threshold:12,portrait:false),.topLeft)
        XCTAssertEqual(Geometry.trigger(at:CGPoint(x:1199,y:799),screen:s,threshold:12,portrait:false),.bottomRight)
        XCTAssertEqual(Geometry.trigger(at:CGPoint(x:600,y:799),screen:s,threshold:12,portrait:false),.centerThird)
        XCTAssertEqual(Geometry.trigger(at:CGPoint(x:600,y:1),screen:s,threshold:12,portrait:false),.maximize)
        XCTAssertNil(Geometry.trigger(at:CGPoint(x:600,y:400),screen:s,threshold:12,portrait:false))
        XCTAssertNil(Geometry.trigger(at:CGPoint(x:-100,y:400),screen:s,threshold:12,portrait:false))
    }
    func testDisplaySelectionUsesLargestOverlap() {
        let screens=[CGRect(x:-1200,y:0,width:1200,height:800),CGRect(x:0,y:0,width:1920,height:1080)]
        XCTAssertEqual(Geometry.screenIndex(for:CGRect(x:-300,y:100,width:900,height:600),screens:screens),1)
        XCTAssertNil(Geometry.screenIndex(for:.zero,screens:[]))
    }
    func testTransferClampsToSmallerMonitor() {
        let from=CGRect(x:0,y:0,width:1920,height:1080), to=CGRect(x:-900,y:-200,width:900,height:1600)
        let result=Geometry.transfer(CGRect(x:960,y:0,width:960,height:1080),from:from,to:to)
        XCTAssertEqual(result,CGRect(x:-450,y:-200,width:450,height:1600))
        XCTAssertTrue(to.contains(Geometry.transfer(CGRect(x:1000,y:1000,width:2000,height:1500),from:from,to:to)))
    }
    func testCenterRespectsVisibleBounds() {
        let result=Layout.center.frame(in:screen,current:CGRect(x:-500,y:-300,width:500,height:400))
        XCTAssertEqual(result.midX,screen.midX); XCTAssertEqual(result.midY,screen.midY)
        XCTAssertEqual(result.size,CGSize(width:500,height:400))
    }
}
