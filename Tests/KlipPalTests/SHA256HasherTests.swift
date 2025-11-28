import XCTest
@testable import KlipPal

final class SHA256HasherTests: XCTestCase {
    func testHashString() {
        let input = "Hello, World!"
        let hash = SHA256Hasher.hash(string: input)

        // SHA256 produces 64 character hex string
        XCTAssertEqual(hash.count, 64)

        // Same input should produce same hash
        let hash2 = SHA256Hasher.hash(string: input)
        XCTAssertEqual(hash, hash2)
    }

    func testHashData() {
        let data = Data("Hello, World!".utf8)
        let hash = SHA256Hasher.hash(data: data)

        XCTAssertEqual(hash.count, 64)

        // Same data should produce same hash
        let hash2 = SHA256Hasher.hash(data: data)
        XCTAssertEqual(hash, hash2)
    }

    func testDifferentInputsDifferentHashes() {
        let hash1 = SHA256Hasher.hash(string: "Hello")
        let hash2 = SHA256Hasher.hash(string: "World")

        XCTAssertNotEqual(hash1, hash2)
    }
}
