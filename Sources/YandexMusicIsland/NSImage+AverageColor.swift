import Cocoa
import CoreImage

extension NSImage {
    func averageColor() -> NSColor? {
        guard let tiffData = self.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        guard let cgImage = bitmap.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        
        let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmapPixels = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &bitmapPixels, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return NSColor(red: CGFloat(bitmapPixels[0]) / 255.0, green: CGFloat(bitmapPixels[1]) / 255.0, blue: CGFloat(bitmapPixels[2]) / 255.0, alpha: 1.0)
    }
}
