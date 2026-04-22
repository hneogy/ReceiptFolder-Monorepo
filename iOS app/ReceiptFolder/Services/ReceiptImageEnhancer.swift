import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum ReceiptImageEnhancer {
    private static let context = CIContext()

    /// Enhances a receipt photo for better OCR accuracy.
    /// Applies: perspective correction, contrast boost, sharpening, grayscale.
    static func enhance(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        var processed = ciImage

        // 1. Auto-adjust levels (exposure, contrast, saturation)
        processed = autoAdjust(processed)

        // 2. Convert to grayscale for cleaner OCR
        processed = grayscale(processed)

        // 3. Boost contrast to make text stand out
        processed = adjustContrast(processed, amount: 1.3)

        // 4. Sharpen to crisp up text edges
        processed = sharpen(processed, amount: 0.5)

        // 5. Reduce noise
        processed = reduceNoise(processed)

        guard let cgImage = context.createCGImage(processed, from: processed.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Filters

    private static func autoAdjust(_ image: CIImage) -> CIImage {
        var result = image
        let adjustments = result.autoAdjustmentFilters()
        for filter in adjustments {
            filter.setValue(result, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                result = output
            }
        }
        return result
    }

    private static func grayscale(_ image: CIImage) -> CIImage {
        let filter = CIFilter.colorMonochrome()
        filter.inputImage = image
        filter.color = CIColor(red: 0.7, green: 0.7, blue: 0.7)
        filter.intensity = 1.0
        return filter.outputImage ?? image
    }

    private static func adjustContrast(_ image: CIImage, amount: Float) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.contrast = amount
        filter.brightness = 0.02 // Slight brightness boost
        return filter.outputImage ?? image
    }

    private static func sharpen(_ image: CIImage, amount: Float) -> CIImage {
        let filter = CIFilter.unsharpMask()
        filter.inputImage = image
        filter.radius = 2.0
        filter.intensity = amount
        return filter.outputImage ?? image
    }

    private static func reduceNoise(_ image: CIImage) -> CIImage {
        let filter = CIFilter.noiseReduction()
        filter.inputImage = image
        filter.noiseLevel = 0.02
        filter.sharpness = 0.4
        return filter.outputImage ?? image
    }
}
