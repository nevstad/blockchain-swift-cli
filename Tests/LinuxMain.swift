import XCTest

import blockchain_cliTests

var tests = [XCTestCaseEntry]()
tests += blockchain_cliTests.allTests()
XCTMain(tests)