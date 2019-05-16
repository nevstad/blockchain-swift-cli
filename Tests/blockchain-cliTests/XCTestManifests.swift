import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(blockchain_cliTests.allTests),
    ]
}
#endif