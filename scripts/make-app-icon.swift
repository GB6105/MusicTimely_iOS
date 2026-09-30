// 앱 아이콘 생성기: 피그마 토큰(배경 #ECECEC, 검은 레코드, sunset 라벨)으로 1024px PNG를 만든다.
// 사용: swift scripts/make-app-icon.swift <출력 경로>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"
// App Store 아이콘은 알파 채널이 없어야 한다 (noneSkipLast).
guard
    let cg = CGContext(
        data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fatalError("context") }

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

cg.setFillColor(color(0xECECEC))
cg.fill(CGRect(x: 0, y: 0, width: size, height: size))

let center = CGPoint(x: size / 2, y: size / 2)
let radius: CGFloat = 400
// 레코드 그림자
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -40), blur: 70, color: color(0x000000, 0.28))
cg.setFillColor(color(0x0B0B0D))
cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
cg.restoreGState()
// 홈
cg.setLineWidth(2)
var r = radius - 14
while r > 150 {
    cg.setStrokeColor(color(0xFFFFFF, Int(r) % 3 == 0 ? 0.07 : 0.04))
    cg.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    r -= 9
}
// sunset 라벨
let label: CGFloat = 140
cg.saveGState()
cg.addEllipse(in: CGRect(x: center.x - label, y: center.y - label, width: label * 2, height: label * 2))
cg.clip()
let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [color(0xFF9C3F), color(0xFF7544), color(0xFF3B4D)] as CFArray, locations: [0, 0.48, 1])!
cg.drawLinearGradient(
    gradient, start: CGPoint(x: center.x - label, y: center.y), end: CGPoint(x: center.x + label, y: center.y), options: [])
cg.restoreGState()
cg.setFillColor(color(0x0B0B0D))
cg.fillEllipse(in: CGRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36))

guard let image = cg.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("image") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("write") }
print("wrote \(output)")
