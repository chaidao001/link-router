import AppKit
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let assets = root.appendingPathComponent("Assets", isDirectory: true)
let iconset = root.appendingPathComponent("build/AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: alpha)
}

let white = color(247, 250, 255)
let teal = color(102, 227, 208)
let lavender = color(175, 181, 255)

func routingPath() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 356, y: 512))
    path.addLine(to: CGPoint(x: 424, y: 512))
    path.addCurve(to: CGPoint(x: 614, y: 316), control1: CGPoint(x: 530, y: 512), control2: CGPoint(x: 500, y: 316))
    path.addLine(to: CGPoint(x: 664, y: 316))
    path.move(to: CGPoint(x: 424, y: 512))
    path.addCurve(to: CGPoint(x: 614, y: 708), control1: CGPoint(x: 530, y: 512), control2: CGPoint(x: 500, y: 708))
    path.addLine(to: CGPoint(x: 664, y: 708))
    return path
}

let nodes: [(CGPoint, CGColor)] = [
    (CGPoint(x: 268, y: 512), white),
    (CGPoint(x: 752, y: 316), teal),
    (CGPoint(x: 752, y: 708), lavender),
]

func nodePath(_ center: CGPoint) -> CGPath {
    CGPath(ellipseIn: CGRect(x: center.x - 66, y: center.y - 66, width: 132, height: 132), transform: nil)
}

func mark(_ context: CGContext) {
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineWidth(62)
    context.setStrokeColor(white)
    context.addPath(routingPath())
    context.strokePath()
    context.setLineWidth(44)
    for (center, tint) in nodes {
        context.setStrokeColor(tint)
        context.addPath(nodePath(center))
        context.strokePath()
    }
}

func render(size: Int, destination: URL) throws {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(size) / 1024
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)
    context.saveGState()
    let tile = CGPath(roundedRect: CGRect(x: 64, y: 64, width: 896, height: 896), cornerWidth: 204, cornerHeight: 204, transform: nil)
    context.addPath(tile)
    context.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(38, 63, 104), color(16, 27, 50)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 64, y: 64), end: CGPoint(x: 870, y: 960), options: [])
    context.restoreGState()
    context.setStrokeColor(color(255, 255, 255, alpha: 0.12))
    context.setLineWidth(3)
    context.addPath(CGPath(roundedRect: CGRect(x: 65.5, y: 65.5, width: 893, height: 893), cornerWidth: 202.5, cornerHeight: 202.5, transform: nil))
    context.strokePath()
    mark(context)
    guard let image = context.makeImage(),
          let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw NSError(domain: "IconGeneration", code: 1) }
    CGImageDestinationAddImage(output, image, nil)
    guard CGImageDestinationFinalize(output) else { throw NSError(domain: "IconGeneration", code: 2) }
}

for size in [16, 32, 128, 256, 512] {
    try render(size: size, destination: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size: size * 2, destination: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(size: 1024, destination: assets.appendingPathComponent("link-router.png"))
try render(size: 256, destination: assets.appendingPathComponent("preview.png"))

// Write this small vector PDF directly so Quartz cannot attach the machine's
// OS version, producer details, or creation timestamps to the shared asset.
func pdfPath(_ path: CGPath) -> String {
    var commands = ""
    func point(_ point: CGPoint) -> String { "\(Double(point.x)) \(Double(point.y))" }
    path.applyWithBlock { pointer in
        let element = pointer.pointee
        switch element.type {
        case .moveToPoint: commands += "\(point(element.points[0])) m\n"
        case .addLineToPoint: commands += "\(point(element.points[0])) l\n"
        case .addCurveToPoint:
            commands += "\(point(element.points[0])) \(point(element.points[1])) \(point(element.points[2])) c\n"
        case .closeSubpath: commands += "h\n"
        case .addQuadCurveToPoint: preconditionFailure("Icon paths must use cubic curves")
        @unknown default: preconditionFailure("Unsupported icon path element")
        }
    }
    return commands
}

var stream = "q\n1 0 0 1 0 18 cm\n\(20.0 / 684) 0 0 \(-18.0 / 616) 0 0 cm\n1 0 0 1 -158 -204 cm\n0 G\n1 J\n1 j\n62 w\n"
stream += pdfPath(routingPath()) + "S\n44 w\n"
for (center, _) in nodes { stream += pdfPath(nodePath(center)) + "S\n" }
stream += "Q\n"
let objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 20 18] /Resources << >> /Contents 4 0 R >>",
    "<< /Length \(stream.utf8.count) >>\nstream\n\(stream)endstream",
]
var pdf = Data("%PDF-1.3\n".utf8)
var offsets: [Int] = []
for (index, object) in objects.enumerated() {
    offsets.append(pdf.count)
    pdf.append(Data("\(index + 1) 0 obj\n\(object)\nendobj\n".utf8))
}
let xrefOffset = pdf.count
pdf.append(Data("xref\n0 5\n0000000000 65535 f \n".utf8))
for offset in offsets { pdf.append(Data(String(format: "%010d 00000 n \n", offset).utf8)) }
pdf.append(Data("trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n\(xrefOffset)\n%%EOF\n".utf8))
try pdf.write(to: assets.appendingPathComponent("MenuBarIcon.pdf"))
print("Generated application icons and menu bar mark")
