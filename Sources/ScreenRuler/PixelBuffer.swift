import CoreGraphics

struct PixelPoint: Equatable {
    var x: Int
    var y: Int
}

/// RGBA8 copy of a screenshot, row 0 at the top.
final class PixelBuffer {
    let width: Int
    let height: Int
    private let data: [UInt8]

    init?(image: CGImage) {
        let w = image.width, h = image.height
        guard w > 0, h > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let ok = bytes.withUnsafeMutableBytes { ptr -> Bool in
            guard let ctx = CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .none
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        width = w
        height = h
        data = bytes
    }

    private func isSimilar(_ a: Int, _ b: Int, tolerance: Int, perChannel: Bool) -> Bool {
        let dr = abs(Int(data[a]) - Int(data[b]))
        let dg = abs(Int(data[a + 1]) - Int(data[b + 1]))
        let db = abs(Int(data[a + 2]) - Int(data[b + 2]))
        return perChannel ? max(dr, dg, db) <= tolerance : dr + dg + db <= tolerance
    }

    /// Walks from `start` in direction (dx, dy) while pixels stay similar to the start pixel.
    /// Returns the last similar coordinate along the walked axis.
    func edge(from start: PixelPoint, dx: Int, dy: Int, tolerance: Int, perChannel: Bool) -> Int {
        let origin = (start.y * width + start.x) * 4
        var x = start.x, y = start.y
        while true {
            let nx = x + dx, ny = y + dy
            guard nx >= 0, ny >= 0, nx < width, ny < height,
                  isSimilar(origin, (ny * width + nx) * 4, tolerance: tolerance, perChannel: perChannel) else { break }
            x = nx
            y = ny
        }
        return dx != 0 ? x : y
    }
}
