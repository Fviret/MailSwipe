import Foundation
@testable import MailSwipe

/// URLProtocol qui répond à la place du réseau et garde la trace des requêtes.
final class StubURLProtocol: URLProtocol {
    struct Recorded { let method: String; let url: URL; let body: Data? }

    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var recorded: [Recorded] = []

    static func reset() { handler = nil; recorded = [] }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: 4096)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            buffer.deallocate()
            stream.close()
            body = data
        }
        Self.recorded.append(Recorded(method: request.httpMethod ?? "GET", url: request.url!, body: body))
        let (status, data) = Self.handler?(request) ?? (200, Data("{}".utf8))
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class FakeTokenProvider: AccessTokenProviding, @unchecked Sendable {
    var token = "token-1"
    var failWith: Error?
    private(set) var invalidated = 0
    private(set) var expired = 0

    func validAccessToken() async throws -> String {
        if let failWith { throw failWith }
        return token
    }
    func invalidateAccessToken() async { invalidated += 1; token = "token-2" }
    func handleSessionExpired() async { expired += 1 }
}
