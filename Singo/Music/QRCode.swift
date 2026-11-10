import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Makes QR code images, e.g. for the playlist link on the game screen.
enum QRCode {
    static func image(for text: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        // Scale up so each module is a crisp block of pixels.
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }
}
