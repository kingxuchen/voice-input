#!/usr/bin/env swift
// ==============================================================================
// scripts/make-icon.swift — 源 PNG → 符合 macOS 规范的 AppIcon.icns
// ==============================================================================
// 用法：swift scripts/make-icon.swift <source.png> <output.icns>
//
// 处理链路：
//   1. 检测与图片边缘连通的近白像素（源图为白底、无 alpha），用邻居颜色逐层向内
//      填充 —— 只抹掉画布外的白边和四角白楔，不会碰熊猫自身的白色面部。
//   2. 缩放到 Apple 图标网格：1024 画布、824×824 内容区（四周 100pt 留白）。
//   3. 套用 macOS squircle 遮罩（圆角半径 216，超椭圆指数 2.42），得到透明圆角，
//      杜绝白边/黑边。
//   4. 输出全套尺寸并交给 iconutil 打成 .icns。
//
// 只依赖系统 CoreGraphics / ImageIO，无需第三方库。
// ==============================================================================

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let canvasSize = 1024
let bodySize = 824
let margin = (canvasSize - bodySize) / 2
let cornerRadius = 216.0
let cornerExponent = 2.42

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let args = CommandLine.arguments
guard args.count == 3 else {
    fail("用法: swift scripts/make-icon.swift <source.png> <output.icns>")
}
let sourceURL = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func makeImage(_ pixels: [UInt8], _ width: Int, _ height: Int) -> CGImage {
    guard let provider = CGDataProvider(data: Data(pixels) as CFData),
          let image = CGImage(
              width: width, height: height,
              bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
              space: colorSpace,
              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
              provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
          ) else { fail("无法创建 CGImage") }
    return image
}

// CGImage/CGBitmapContext 的数据缓冲区本身就是第 0 行在顶部，默认坐标系下绘制不需要翻转；
// 额外翻转会把图像上下颠倒。
func makeContext(_ pixels: inout [UInt8], _ width: Int, _ height: Int) -> CGContext {
    pixels.withUnsafeMutableBytes { buffer in
        guard let ctx = CGContext(
            data: buffer.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { fail("无法创建位图上下文") }
        ctx.interpolationQuality = .high
        return ctx
    }
}

func render(_ image: CGImage, size: Int) -> [UInt8] {
    var pixels = [UInt8](repeating: 0, count: size * size * 4)
    let ctx = makeContext(&pixels, size, size)
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return pixels
}

// --- 1. 读入源图（top-down RGBA）---------------------------------------------
guard let sourceRef = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let sourceImage = CGImageSourceCreateImageAtIndex(sourceRef, 0, nil) else {
    fail("无法读取源图: \(sourceURL.path)")
}

let srcW = sourceImage.width
let srcH = sourceImage.height
var src = [UInt8](repeating: 0, count: srcW * srcH * 4)
do {
    let ctx = makeContext(&src, srcW, srcH)
    ctx.draw(sourceImage, in: CGRect(x: 0, y: 0, width: srcW, height: srcH))
}

// --- 2. 抹掉与边框连通的白色 --------------------------------------------------
// 阈值：近白且低饱和。熊猫的白色面部被深色轮廓包住，与边框不连通，因此不会被误填。
let pixelCount = srcW * srcH
var isEdgeWhite = [Bool](repeating: false, count: pixelCount)

for i in 0..<pixelCount {
    let r = Int(src[i * 4]), g = Int(src[i * 4 + 1]), b = Int(src[i * 4 + 2])
    let lo = min(r, min(g, b)), hi = max(r, max(g, b))
    isEdgeWhite[i] = lo >= 195 && (hi - lo) <= 50
}

var visited = [Bool](repeating: false, count: pixelCount)
var queue = [Int32]()
queue.reserveCapacity(pixelCount / 8)
func enqueue(_ index: Int) {
    guard !visited[index] && isEdgeWhite[index] else { return }
    visited[index] = true
    queue.append(Int32(index))
}
for x in 0..<srcW {
    enqueue(x)
    enqueue((srcH - 1) * srcW + x)
}
for y in 0..<srcH {
    enqueue(y * srcW)
    enqueue(y * srcW + srcW - 1)
}

var head = 0
while head < queue.count {
    let index = Int(queue[head]); head += 1
    let y = index / srcW, x = index % srcW
    if x > 0 { enqueue(index - 1) }
    if x + 1 < srcW { enqueue(index + 1) }
    if y > 0 { enqueue(index - srcW) }
    if y + 1 < srcH { enqueue(index + srcW) }
}

var fillCount = 0
for i in 0..<pixelCount where visited[i] { fillCount += 1 }
guard fillCount < pixelCount else { fail("源图几乎全是白色，无法识别主体") }

// 逐层向内平均邻居颜色，让渐变背景自然延续到边缘。
// frontier 用 queued 去重，否则同一像素被多个邻居重复入队会重复累加。
var known = [Bool](repeating: true, count: pixelCount)
var queued = [Bool](repeating: false, count: pixelCount)
var frontier = [Int]()

func enqueueFrontier(_ i: Int) {
    guard !known[i], !queued[i] else { return }
    queued[i] = true
    frontier.append(i)
}

for i in 0..<pixelCount where visited[i] {
    known[i] = false
}
for i in 0..<pixelCount where !known[i] {
    let y = i / srcW, x = i % srcW
    if (x > 0 && known[i - 1]) || (x + 1 < srcW && known[i + 1])
        || (y > 0 && known[i - srcW]) || (y + 1 < srcH && known[i + srcW]) {
        enqueueFrontier(i)
    }
}

var remaining = fillCount
while !frontier.isEmpty {
    var sumsR = [Int](repeating: 0, count: pixelCount)
    var sumsG = [Int](repeating: 0, count: pixelCount)
    var sumsB = [Int](repeating: 0, count: pixelCount)
    var counts = [Int](repeating: 0, count: pixelCount)

    for i in frontier {
        let y = i / srcW, x = i % srcW
        func take(_ j: Int) {
            guard known[j] else { return }
            sumsR[i] += Int(src[j * 4])
            sumsG[i] += Int(src[j * 4 + 1])
            sumsB[i] += Int(src[j * 4 + 2])
            counts[i] += 1
        }
        if x > 0 { take(i - 1) }
        if x + 1 < srcW { take(i + 1) }
        if y > 0 { take(i - srcW) }
        if y + 1 < srcH { take(i + srcW) }
    }

    var next = [Int]()
    next.reserveCapacity(frontier.count * 2)

    for i in frontier {
        guard counts[i] > 0 else {
            queued[i] = false
            enqueueFrontier(i)
            continue
        }
        let n = counts[i]
        let r = min((sumsR[i] + n / 2) / n, 255)
        let g = min((sumsG[i] + n / 2) / n, 255)
        let b = min((sumsB[i] + n / 2) / n, 255)
        src[i * 4] = UInt8(r)
        src[i * 4 + 1] = UInt8(g)
        src[i * 4 + 2] = UInt8(b)
        src[i * 4 + 3] = 255
        known[i] = true
        remaining -= 1
    }

    for i in frontier where known[i] {
        let y = i / srcW, x = i % srcW
        if x > 0 && !known[i - 1] && !queued[i - 1] { queued[i - 1] = true; next.append(i - 1) }
        if x + 1 < srcW && !known[i + 1] && !queued[i + 1] { queued[i + 1] = true; next.append(i + 1) }
        if y > 0 && !known[i - srcW] && !queued[i - srcW] { queued[i - srcW] = true; next.append(i - srcW) }
        if y + 1 < srcH && !known[i + srcW] && !queued[i + srcW] { queued[i + srcW] = true; next.append(i + srcW) }
    }
    for i in next { queued[i] = false }  // 下轮它们是 frontier，本身尚未确定
    frontier = next
}
guard remaining == 0 else { fail("白色填充未能完成，剩余 \(remaining) 像素") }

// --- 3. 缩放到 824 内容区并居中到 1024 画布 -----------------------------------
let filledImage = makeImage(src, srcW, srcH)
var artwork = [UInt8](repeating: 0, count: canvasSize * canvasSize * 4)
do {
    let ctx = makeContext(&artwork, canvasSize, canvasSize)
    ctx.draw(filledImage, in: CGRect(x: margin, y: margin, width: bodySize, height: bodySize))
}

// --- 4. squircle 遮罩 ---------------------------------------------------------
// 有符号距离：直边取到最近边的距离，四角取超椭圆距离；+0.5 得到 1px 线性抗锯齿。
var alphaMask = [UInt8](repeating: 0, count: canvasSize * canvasSize)
let half = Double(bodySize) / 2
let cornerCenter = half - cornerRadius

for y in 0..<canvasSize {
    for x in 0..<canvasSize {
        let u = Double(x) + 0.5 - Double(margin)
        let v = Double(y) + 0.5 - Double(margin)

        let edgeDistance = min(min(u, Double(bodySize) - u), min(v, Double(bodySize) - v))

        let cx = abs(u - half) - cornerCenter
        let cy = abs(v - half) - cornerCenter
        let px = max(cx, 0), py = max(cy, 0)
        let rho = pow(pow(px, cornerExponent) + pow(py, cornerExponent), 1 / cornerExponent)

        var cornerDistance = Double.infinity
        if cx > 0 && cy > 0 {
            let gx = rho > 0 ? pow(px, cornerExponent - 1) * pow(rho, 1 - cornerExponent) : 0
            let gy = rho > 0 ? pow(py, cornerExponent - 1) * pow(rho, 1 - cornerExponent) : 0
            let gradient = max((gx * gx + gy * gy).squareRoot(), 1e-9)
            cornerDistance = (cornerRadius - rho) / gradient
        }

        let signedDistance = min(edgeDistance, cornerDistance)
        let coverage = min(max(signedDistance + 0.5, 0), 1)
        alphaMask[y * canvasSize + x] = UInt8((coverage * 255).rounded())
    }
}

for i in 0..<(canvasSize * canvasSize) {
    let a = Int(alphaMask[i])
    guard a < 255 else { continue }
    // 缓冲区是 premultipliedLast，乘 alpha 时四个通道要一起缩放
    for c in 0..<4 {
        artwork[i * 4 + c] = UInt8((Int(artwork[i * 4 + c]) * a + 127) / 255)
    }
}

let master = makeImage(artwork, canvasSize, canvasSize)

// --- 5. 输出 iconset 并打包成 icns -------------------------------------------
let fileManager = FileManager.default
let iconsetURL = fileManager.temporaryDirectory
    .appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let variants: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2),
    (128, 1), (128, 2), (256, 1), (256, 2),
    (512, 1), (512, 2),
]

for variant in variants {
    let pixels = variant.points * variant.scale
    let rendered = pixels == canvasSize ? artwork : render(master, size: pixels)
    let image = makeImage(rendered, pixels, pixels)
    let name = "icon_\(variant.points)x\(variant.points)\(variant.scale == 2 ? "@2x" : "").png"
    let fileURL = iconsetURL.appendingPathComponent(name)
    guard let dest = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fail("无法写出 \(name)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fail("无法写出 \(name)") }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fail("iconutil 打包失败") }

try? fileManager.removeItem(at: iconsetURL)

// 预览图便于肉眼验收：四角透明、无白边
let previewURL = outputURL.deletingLastPathComponent().appendingPathComponent("AppIcon-1024.png")
if let dest = CGImageDestinationCreateWithURL(previewURL as CFURL, UTType.png.identifier as CFString, 1, nil) {
    CGImageDestinationAddImage(dest, master, nil)
    CGImageDestinationFinalize(dest)
}

print("==> 图标已生成: \(outputURL.path)")
print("    画布 \(canvasSize)，内容区 \(bodySize)，圆角 \(Int(cornerRadius))")
print("    已抹除白边像素: \(fillCount)")
