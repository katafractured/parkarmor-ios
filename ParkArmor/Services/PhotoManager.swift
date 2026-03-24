import Foundation
import PhotosUI
import UIKit
import Observation
import SwiftUI

@Observable final class PhotoManager {
    var isLoading = false

    func loadImage(from item: PhotosPickerItem) async throws -> Data {
        isLoading = true
        defer { isLoading = false }

        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw PhotoError.loadFailed
        }
        return compressImage(data)
    }

    func loadImages(from items: [PhotosPickerItem]) async throws -> [Data] {
        var results: [Data] = []
        for item in items {
            let data = try await loadImage(from: item)
            results.append(data)
        }
        return results
    }

    func compressImage(_ data: Data, maxDimension: CGFloat = 1200) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size

        let scale: CGFloat
        if size.width > maxDimension || size.height > maxDimension {
            scale = maxDimension / max(size.width, size.height)
        } else {
            scale = 1.0
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }

    enum PhotoError: LocalizedError {
        case loadFailed
        var errorDescription: String? { "Could not load the selected photo." }
    }
}
