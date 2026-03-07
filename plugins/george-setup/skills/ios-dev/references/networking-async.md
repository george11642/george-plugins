# Networking and Async Data

## URLSession async/await (Native — Preferred)

```swift
// Simple GET request
func fetchUser(id: Int) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    let (data, response) = try await URLSession.shared.data(from: url)

    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw NetworkError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    return try JSONDecoder().decode(User.self, from: data)
}

// POST with body
func createUser(_ user: UserCreate) async throws -> User {
    var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(user)

    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(User.self, from: data)
}

// Download to file
func downloadFile(url: URL, destination: URL) async throws {
    let (tempURL, _) = try await URLSession.shared.download(from: url)
    try FileManager.default.moveItem(at: tempURL, to: destination)
}

// Upload multipart
func uploadImage(_ image: UIImage) async throws -> String {
    let boundary = UUID().uuidString
    var request = URLRequest(url: URL(string: "https://api.example.com/upload")!)
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    body.append(image.jpegData(compressionQuality: 0.8)!)
    body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

    let (data, _) = try await URLSession.shared.upload(for: request, from: body)
    return try JSONDecoder().decode(UploadResponse.self, from: data).url
}
```

## Codable — Custom Decoding Patterns

```swift
// Custom CodingKeys (snake_case API)
struct User: Codable {
    let id: Int
    let firstName: String
    let lastName: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case createdAt = "created_at"
    }
}

// Automatic snake_case conversion (cleaner)
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
decoder.dateDecodingStrategy = .iso8601

let encoder = JSONEncoder()
encoder.keyEncodingStrategy = .convertToSnakeCase
encoder.dateEncodingStrategy = .iso8601

// Custom date format
let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
decoder.dateDecodingStrategy = .formatted(formatter)

// Nested containers
struct APIResponse<T: Decodable>: Decodable {
    let data: T
    let meta: Meta?

    struct Meta: Decodable {
        let total: Int
        let page: Int
    }
}

// Dynamic keys / heterogeneous JSON
struct FlexibleModel: Decodable {
    let type: String
    let payload: Any

    enum CodingKeys: String, CodingKey { case type, payload }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        // Decode payload based on type
        switch type {
        case "text": payload = try container.decode(String.self, forKey: .payload)
        case "number": payload = try container.decode(Double.self, forKey: .payload)
        default: payload = try container.decode(String.self, forKey: .payload)
        }
    }
}
```

## Custom URLProtocol for Testing

```swift
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else { return }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// Usage in tests
let config = URLSessionConfiguration.ephemeral
config.protocolClasses = [MockURLProtocol.self]
let session = URLSession(configuration: config)
// Inject session into your NetworkClient
```

## URLCache Strategy

```swift
// Configure shared cache
URLCache.shared = URLCache(
    memoryCapacity: 50 * 1024 * 1024,   // 50 MB
    diskCapacity: 200 * 1024 * 1024,     // 200 MB
    directory: nil
)

// Per-request cache policy
var request = URLRequest(url: url)
request.cachePolicy = .returnCacheDataElseLoad  // Use cache, fallback to network
// .useProtocolCachePolicy — honor Cache-Control headers (default)
// .reloadIgnoringLocalCacheData — always network
// .returnCacheDataDontLoad — offline mode
```

## Background URLSession

For downloads that should continue when app is backgrounded:

```swift
class DownloadManager: NSObject, URLSessionDownloadDelegate {
    lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.myapp.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func startDownload(_ url: URL) {
        session.downloadTask(with: url).resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Move file from temp location — must be synchronous
        let dest = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(downloadTask.originalRequest!.url!.lastPathComponent)
        try? FileManager.default.moveItem(at: location, to: dest)
    }
}

// Handle background session completion in AppDelegate
func application(_ application: UIApplication,
                 handleEventsForBackgroundURLSession identifier: String,
                 completionHandler: @escaping () -> Void) {
    DownloadManager.shared.backgroundCompletionHandler = completionHandler
}
```

## Certificate Pinning

```swift
final class PinningDelegate: NSObject, URLSessionDelegate {
    private let pinnedHashes = Set(["sha256/BASE64_ENCODED_HASH"])

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let cert = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let data = SecCertificateCopyData(cert) as Data
        let hash = "sha256/" + data.sha256().base64EncodedString()

        if pinnedHashes.contains(hash) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
```

## Alamofire (When to Use)

Use Alamofire over URLSession when: multipart uploads, request retry logic, EventMonitor logging, response serialization pipelines.

```swift
import Alamofire

// Basic request
AF.request("https://api.example.com/users")
    .validate()
    .responseDecodable(of: [User].self) { response in
        switch response.result {
        case .success(let users): print(users)
        case .failure(let error): print(error)
        }
    }

// Async/await
let users = try await AF.request("https://api.example.com/users")
    .validate()
    .serializingDecodable([User].self)
    .value

// Parallel requests
async let first = AF.request("https://api.example.com/users").serializingDecodable([User].self).value
async let second = AF.request("https://api.example.com/posts").serializingDecodable([Post].self).value
let (users2, posts) = try await (first, second)

// RequestInterceptor — auth token refresh
final class AuthInterceptor: RequestInterceptor {
    func adapt(_ urlRequest: URLRequest, for session: Session,
               completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        if let token = AuthService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        completion(.success(request))
    }

    func retry(_ request: Request, for session: Session, dueTo error: Error,
               completion: @escaping (RetryResult) -> Void) {
        guard request.retryCount < 1,
              let response = request.task?.response as? HTTPURLResponse,
              response.statusCode == 401 else {
            completion(.doNotRetry)
            return
        }
        Task {
            do {
                try await AuthService.shared.refreshToken()
                completion(.retry)
            } catch {
                completion(.doNotRetryWithError(error))
            }
        }
    }
}

let session = Session(interceptor: AuthInterceptor())

// EventMonitor for logging
final class NetworkLogger: EventMonitor {
    func requestDidResume(_ request: Request) {
        print(">>> \(request.request?.httpMethod ?? "") \(request.request?.url?.absoluteString ?? "")")
    }
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        print("<<< \(response.response?.statusCode ?? 0)")
    }
}
```

## NetworkClient Architecture

```swift
// Protocol-first for testability
protocol NetworkClientProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

struct Endpoint {
    let method: HTTPMethod
    let path: String
    let body: Encodable?
    let headers: [String: String]

    enum HTTPMethod: String { case get = "GET", post = "POST", put = "PUT", delete = "DELETE" }

    static func get(_ path: String) -> Endpoint { Endpoint(method: .get, path: path, body: nil, headers: [:]) }
}

final class NetworkClient: NetworkClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        urlRequest.httpMethod = endpoint.method.rawValue
        if let body = endpoint.body {
            urlRequest.httpBody = try JSONEncoder().encode(body)
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        endpoint.headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.httpError(http.statusCode, data)
        }
        return try decoder.decode(T.self, from: data)
    }
}
```
