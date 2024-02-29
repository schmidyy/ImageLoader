import XCTest
@testable import ImageLoader

final class ImageLoaderTests: XCTestCase {
	static var imageUrl = URL(string: "https://via.placeholder.com/350x150")!
	
	var imageLoader: ImageLoader!
	
	override func setUp() {
		super.setUp()
		imageLoader = ImageLoader()
	}
	
	override func tearDown() {
		super.tearDown()
		imageLoader = nil
	}
	
    func testImageFetch() async throws {
		let image = try await imageLoader.fetch(Self.imageUrl)
		XCTAssertNotNil(image)
		XCTAssertNoThrow(image)
    }
}
