import Foundation
import UIKit
import CryptoKit

/// Handles image compression and storage for receipt and item photos.
///
/// **Post-CloudKit architecture**: Images are stored as `Data` directly on `ReceiptItem`
/// via `@Attribute(.externalStorage)`, which CloudKit syncs as CKAssets.
/// Legacy file-based storage (with encryption) is retained only for migration reads.
final class ImageStorageService {
    static let shared = ImageStorageService()

    private let fileManager = FileManager.default

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var receiptsDirectory: URL {
        documentsDirectory.appendingPathComponent("receipts", isDirectory: true)
    }

    private var itemsDirectory: URL {
        documentsDirectory.appendingPathComponent("items", isDirectory: true)
    }

    private init() {
        createDirectories()
    }

    private func createDirectories() {
        do {
            try fileManager.createDirectory(at: receiptsDirectory, withIntermediateDirectories: true)
        } catch {
            RFLogger.storage.error("Failed to create receipts directory: \(error)")
        }
        do {
            try fileManager.createDirectory(at: itemsDirectory, withIntermediateDirectories: true)
        } catch {
            RFLogger.storage.error("Failed to create items directory: \(error)")
        }
    }

    enum ImageType: Sendable {
        case receipt
        case item
    }

    // MARK: - New Model-Based API (CloudKit-compatible)

    /// Compress an image for storage in the SwiftData model.
    /// Returns compressed JPEG data ready to assign to `item.receiptImageData` or `item.itemImageData`.
    func compressForModelStorage(image: UIImage) -> Data? {
        ImageCompressionService.adaptiveCompress(image: image)
    }

    /// Load the receipt image for an item, checking model data first, then falling back to legacy file path.
    func loadReceiptImage(for item: ReceiptItem) async -> UIImage? {
        // Primary: model data (CloudKit-synced)
        if let data = item.receiptImageData {
            return UIImage(data: data)
        }
        // Fallback: legacy encrypted file
        if !item.receiptImagePath.isEmpty {
            return await loadImage(relativePath: item.receiptImagePath)
        }
        return nil
    }

    /// Load the item photo for an item, checking model data first, then falling back to legacy file path.
    func loadItemImage(for item: ReceiptItem) async -> UIImage? {
        // Primary: model data (CloudKit-synced)
        if let data = item.itemImageData {
            return UIImage(data: data)
        }
        // Fallback: legacy encrypted file
        if let path = item.itemImagePath, !path.isEmpty {
            return await loadImage(relativePath: path)
        }
        return nil
    }

    /// Synchronous receipt image load for non-async contexts (e.g., mail composer).
    /// Caller must provide pre-extracted values to avoid actor-isolation issues.
    func loadReceiptImageSync(for item: ReceiptItem) -> UIImage? {
        if let data = item.receiptImageData {
            return UIImage(data: data)
        }
        if !item.receiptImagePath.isEmpty {
            return loadImageSync(relativePath: item.receiptImagePath)
        }
        return nil
    }

    // MARK: - Legacy File-Based API (for migration only)

    /// Load image from a legacy file path (supports encrypted and unencrypted files).
    func loadImage(relativePath: String) async -> UIImage? {
        guard !relativePath.isEmpty else { return nil }
        let url = documentsDirectory.appendingPathComponent(relativePath)
        guard let encryptedData = try? Data(contentsOf: url) else { return nil }
        // Try decrypted first, fall back to unencrypted for legacy images
        if let decryptedData = try? decrypt(encryptedData) {
            return UIImage(data: decryptedData)
        }
        // Fallback: image was saved before encryption was enabled
        return UIImage(data: encryptedData)
    }

    /// Synchronous load from legacy file path.
    nonisolated func loadImageSync(relativePath: String) -> UIImage? {
        guard !relativePath.isEmpty else { return nil }
        let url = documentsDirectory.appendingPathComponent(relativePath)
        guard let encryptedData = try? Data(contentsOf: url) else { return nil }
        if let decryptedData = try? decrypt(encryptedData) {
            return UIImage(data: decryptedData)
        }
        return UIImage(data: encryptedData)
    }

    /// Delete a legacy image file from disk.
    func deleteImage(relativePath: String) {
        guard !relativePath.isEmpty else { return }
        let url = documentsDirectory.appendingPathComponent(relativePath)
        try? fileManager.removeItem(at: url)
    }

    /// Clean up empty legacy directories after migration.
    func cleanupLegacyDirectories() {
        let receiptContents = (try? fileManager.contentsOfDirectory(atPath: receiptsDirectory.path)) ?? []
        let itemContents = (try? fileManager.contentsOfDirectory(atPath: itemsDirectory.path)) ?? []
        if receiptContents.isEmpty {
            try? fileManager.removeItem(at: receiptsDirectory)
        }
        if itemContents.isEmpty {
            try? fileManager.removeItem(at: itemsDirectory)
        }
    }

    // MARK: - Legacy Encryption (read-only, for migration)

    private static let encryptionKeyTag = "com.receiptfolder.imagekey"

    private var encryptionKey: SymmetricKey? {
        loadKeyFromKeychain()
    }

    private func loadKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.encryptionKeyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return SymmetricKey(data: data)
    }

    private func decrypt(_ data: Data) throws -> Data {
        guard let key = encryptionKey else { throw ImageError.encryptionFailed }
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
}

enum ImageError: Error, LocalizedError {
    case compressionFailed
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed: "Failed to compress image."
        case .encryptionFailed: "Failed to encrypt image data."
        }
    }
}
