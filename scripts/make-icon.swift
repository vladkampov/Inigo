import AppKit
let root = CommandLine.arguments[1]
func mark() -> NSBezierPath {
 let p = NSBezierPath()
 p.move(to:NSPoint(x:500,y:570)); p.curve(to:NSPoint(x:640,y:800),controlPoint1:NSPoint(x:630,y:580),controlPoint2:NSPoint(x:650,y:690))
 p.curve(to:NSPoint(x:585,y:850),controlPoint1:NSPoint(x:640,y:830),controlPoint2:NSPoint(x:620,y:850))
 p.line(to:NSPoint(x:495,y:850)); p.curve(to:NSPoint(x:440,y:795),controlPoint1:NSPoint(x:460,y:850),controlPoint2:NSPoint(x:440,y:830))
 p.line(to:NSPoint(x:440,y:730)); p.curve(to:NSPoint(x:475,y:700),controlPoint1:NSPoint(x:440,y:710),controlPoint2:NSPoint(x:450,y:700))
 p.line(to:NSPoint(x:545,y:700)); p.curve(to:NSPoint(x:500,y:570),controlPoint1:NSPoint(x:535,y:650),controlPoint2:NSPoint(x:525,y:600)); p.close()
 p.move(to:NSPoint(x:355,y:510)); p.curve(to:NSPoint(x:450,y:555),controlPoint1:NSPoint(x:380,y:540),controlPoint2:NSPoint(x:410,y:555)); p.line(to:NSPoint(x:585,y:555))
 p.curve(to:NSPoint(x:500,y:260),controlPoint1:NSPoint(x:530,y:450),controlPoint2:NSPoint(x:470,y:300))
 p.curve(to:NSPoint(x:565,y:250),controlPoint1:NSPoint(x:510,y:230),controlPoint2:NSPoint(x:540,y:230))
 p.curve(to:NSPoint(x:410,y:170),controlPoint1:NSPoint(x:530,y:195),controlPoint2:NSPoint(x:460,y:160))
 p.curve(to:NSPoint(x:330,y:255),controlPoint1:NSPoint(x:335,y:170),controlPoint2:NSPoint(x:315,y:210))
 p.curve(to:NSPoint(x:420,y:480),controlPoint1:NSPoint(x:355,y:320),controlPoint2:NSPoint(x:430,y:445))
 p.curve(to:NSPoint(x:355,y:510),controlPoint1:NSPoint(x:435,y:515),controlPoint2:NSPoint(x:410,y:515)); p.close(); return p
}
func render(_ size:Int, symbol:Bool = false) -> Data {
 let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:rep)
 let ctx = NSGraphicsContext.current!.cgContext; ctx.scaleBy(x:CGFloat(size)/1024,y:CGFloat(size)/1024)
 if !symbol {
  let tile = NSBezierPath(roundedRect:NSRect(x:62,y:62,width:900,height:900),xRadius:200,yRadius:200)
  NSGradient(starting:NSColor(calibratedRed:0.66,green:0.65,blue:0.94,alpha:1),ending:NSColor(calibratedRed:0.87,green:0.89,blue:1,alpha:1))!.draw(in:tile,angle:45)
  NSColor(calibratedRed:0.08,green:0.07,blue:0.12,alpha:1).setFill()
 } else { ctx.translateBy(x:-170,y:-130); ctx.scaleBy(x:1.35,y:1.35); NSColor.black.setFill() }
 mark().fill(); NSGraphicsContext.restoreGraphicsState(); return rep.representation(using:.png,properties:[:])!
}
let fm = FileManager.default
let folder = root + "/Inigo.iconset"
try fm.createDirectory(atPath:folder,withIntermediateDirectories:true)
for size in [16,32,128,256,512] {
 try render(size).write(to:URL(fileURLWithPath:folder+"/icon_\(size)x\(size).png"))
 try render(size*2).write(to:URL(fileURLWithPath:folder+"/icon_\(size)x\(size)@2x.png"))
}
try render(1024).write(to:URL(fileURLWithPath:root+"/Inigo.png"))
try render(36,symbol:true).write(to:URL(fileURLWithPath:root+"/InigoMenu.png"))
