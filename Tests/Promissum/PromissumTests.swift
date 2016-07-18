import XCTest
@testable import Promissum

class PromissumTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(Promissum().text, "Hello, World!")
    }


    static var allTests : [(String, (PromissumTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
