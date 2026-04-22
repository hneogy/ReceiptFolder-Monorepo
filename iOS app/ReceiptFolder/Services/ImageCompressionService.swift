import Foundation
import UIKit

enum ImageCompressionService {
    /// Saves an image with adaptive quality — lower quality for larger images.
    /// Returns (imageData, originalSize) tuple for storage.
    static func adaptiveCompress(image: UIImage, maxDimension: CGFloat = 2048) -> Data? {
        // Resize if too large
        let resized = resizeIfNeeded(image, maxDimension: maxDimension)

        // Choose JPEG quality based on image size
        let pixelCount = resized.size.width * resized.size.height * resized.scale * resized.scale
        let quality: CGFloat
        if pixelCount > 8_000_000 {
            quality = 0.6
        } else if pixelCount > 4_000_000 {
            quality = 0.7
        } else {
            quality = 0.8
        }

        return resized.jpegData(compressionQuality: quality)
    }

    private static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }

        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
