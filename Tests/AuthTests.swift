import XCTest
@testable import MailSwipe

final class AuthTests: XCTestCase {
    private func callback(_ query: String) -> URL {
        URL(string: "com.googleusercontent.apps.123:/oauth2redirect?\(query)")!
    }

    func testValidCallbackReturnsCode() throws {
        let code = try AuthManager.authorizationCode(from: callback("code=abc&state=xyz"), expectedState: "xyz")
        XCTAssertEqual(code, "abc")
    }

    func testStateMismatchIsRejected() {
        XCTAssertThrowsError(try AuthManager.authorizationCode(from: callback("code=abc&state=evil"), expectedState: "xyz")) {
            XCTAssertEqual($0 as? AuthFlowError, .stateMismatch)
        }
    }

    func testMissingStateIsRejected() {
        XCTAssertThrowsError(try AuthManager.authorizationCode(from: callback("code=abc"), expectedState: "xyz")) {
            XCTAssertEqual($0 as? AuthFlowError, .stateMismatch)
        }
    }

    func testGoogleErrorIsSurfaced() {
        XCTAssertThrowsError(try AuthManager.authorizationCode(from: callback("error=access_denied&state=xyz"), expectedState: "xyz")) {
            XCTAssertEqual($0 as? AuthFlowError, .denied("access_denied"))
        }
    }

    func testMissingCodeIsRejected() {
        XCTAssertThrowsError(try AuthManager.authorizationCode(from: callback("state=xyz"), expectedState: "xyz")) {
            XCTAssertEqual($0 as? AuthFlowError, .missingCode)
        }
    }
}

final class GmailErrorTests: XCTestCase {
    private func response(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://gmail.googleapis.com")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    func testSuccessDoesNotThrow() {
        XCTAssertNoThrow(try GmailError.validate(response(200), data: Data()))
    }

    func testUnauthorizedMeansSessionExpired() {
        XCTAssertThrowsError(try GmailError.validate(response(401), data: Data())) {
            XCTAssertEqual($0 as? GmailError, .sessionExpired)
        }
    }

    func testGoogleMessageIsExtractedFromJSON() {
        let body = Data(#"{"error":{"code":403,"message":"Quota exceeded"}}"#.utf8)
        XCTAssertThrowsError(try GmailError.validate(response(403), data: body)) {
            XCTAssertEqual($0 as? GmailError, .api(status: 403, message: "Quota exceeded"))
            XCTAssertEqual(($0 as? GmailError)?.errorDescription, "Quota exceeded")
        }
    }

    func testRawBodyIsNeverShownToUser() {
        XCTAssertThrowsError(try GmailError.validate(response(500), data: Data("<html>oops</html>".utf8))) {
            XCTAssertEqual(($0 as? GmailError)?.errorDescription, String(localized: "Gmail a répondu avec une erreur (\(500))."))
        }
    }
}
