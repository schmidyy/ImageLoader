import Foundation
import UIKit

/// Responsible for providing an image from the given URL.
/// Uses a mix of both in-memory cache and on device storage in order to minimize network usage wherever possible.
actor ImageLoader {
	// MARK: Public properties
	
	public enum ImageRequestError: Error {
		case unableToDecodeImage
		case unableToEncodeImage
		case unableToGenerateStoragePath
	}
	
	/// The file manager to use, defaults to `FileManager.default`
	/// Can be overriden with a mocked `FileManager` implementation.
	public var fileManager: FileManager = .default
	
	// MARK: Private properties
	
	private enum LoaderStatus {
		case inProgress(Task<UIImage, Error>)
		case fetched(UIImage)
	}
	
	/// Used as an in-memory cache of recently loaded image, and also keep track of in-flight requests.
	/// The latter is to prevent duplicate outgoing requests for the same request.
	private var cache: [URL: LoaderStatus] = [:]
	
	// MARK: Public API
	
	/// Fetches an image at the given URL.
	/// This is use a mix of both in-memory cache and on device storage in order to minimize network usage wherever possible.
	/// A customer `URLSession` can be provided in order to stub results.
	public func fetch(_ url: URL, session: URLSession = .shared) async throws -> UIImage {
		// Check if we have a cached image or in progress request for this URL.
		if let status = cache[url] {
			switch status {
			case .fetched(let image):
				return image
			case .inProgress(let task):
				return try await task.value
			}
		}
		
		// Check if we have an image stored on the device for this URL.
		if let image = try? imageFromFileSystem(for: url) {
			cache[url] = .fetched(image)
			return image
		}
		
		// Create an async task that will fetch the image data from the network.
		let task: Task<UIImage, Error> = Task {
			let (data, _) = try await session.data(from: url)
			
			guard let image = UIImage(data: data) else {
				throw ImageRequestError.unableToDecodeImage
			}
			
			try persist(image, for: url)
			return image
		}
		
		// Update cache with current status
		cache[url] = .inProgress(task)
		let image = try await task.value
		cache[url] = .fetched(image)
		
		return image
	}
	
	// MARK: Private helper methods
	
	/// Writes the data for the provided image to the device storage, using its URL as a file name.
	private func persist(_ image: UIImage, for url: URL) throws {
		guard let data = image.jpegData(compressionQuality: 0.8) else {
			throw ImageRequestError.unableToEncodeImage
		}
		
		let storagePath = try devicePath(for: url)
		fileManager.createFile(atPath: storagePath.path(percentEncoded: false), contents: data)
	}
	
	/// Attempts to fetch the requested image from the filesystem.
	private func imageFromFileSystem(for url: URL) throws -> UIImage? {
		let path = try devicePath(for: url)
		let data = try Data(contentsOf: path)
		return UIImage(data: data)
	}
	
	/// Creates a filename for the provided URL, and returns the path to this file on the device.
	private func devicePath(for url: URL) throws -> URL {
		guard let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
			throw ImageRequestError.unableToGenerateStoragePath
		}
		
		guard let fileName = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
			throw ImageRequestError.unableToGenerateStoragePath
		}
		
		return directory.appendingPathComponent(fileName)
	}
}
