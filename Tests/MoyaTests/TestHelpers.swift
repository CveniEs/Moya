import Moya

#if canImport(UIKit)
    import UIKit
    import Foundation
#elseif canImport(AppKit)
    import AppKit
#endif

// MARK: - Mock Services
enum GitHub {
    case zen
    case userProfile(String)
}

extension GitHub: TargetType {
    var baseURL: URL { URL(string: "https://api.github.com")! }
    var path: String {
        switch self {
        case .zen:
            return "/zen"
        case .userProfile(let name):
            return "/users/\(name.urlEscaped)"
        }
    }

    var method: Moya.Method { .get }

    var task: Task { .requestPlain }

    var validationType: ValidationType { .successAndRedirectCodes }

    var headers: [String: String]? { nil }
}

extension GitHub: Equatable {
    static func == (lhs: GitHub, rhs: GitHub) -> Bool {
        switch (lhs, rhs) {
        case (.zen, .zen): return true
        case let (.userProfile(username1), .userProfile(username2)): return username1 == username2
        default: return false
        }
    }
}

func url(_ route: TargetType) -> String {
    route.baseURL.appendingPathComponent(route.path).absoluteString
}

enum HTTPBin: TargetType, AccessTokenAuthorizable {
    case basicAuth
    case bearer
    case post
    case upload(file: URL)
    case uploadMultipart([MultipartFormData], [String: Any]?)
    case validatedUploadMultipart([MultipartFormData], [String: Any]?, [Int])

    var baseURL: URL { URL(string: "http://httpbin.org")! }
    var path: String {
        switch self {
        case .basicAuth:
            return "/basic-auth/user/passwd"
        case .bearer:
            return "/bearer"
        case .post, .upload, .uploadMultipart, .validatedUploadMultipart:
            return "/post"
        }
    }

    var method: Moya.Method {
        switch self {
        case .basicAuth, .bearer:
            return .get
        case .post, .upload, .uploadMultipart, .validatedUploadMultipart:
            return .post
        }
    }

    var task: Task {
        switch self {
        case .basicAuth, .post, .bearer:
            return .requestParameters(parameters: [:], encoding: URLEncoding.default)
        case .upload(let fileURL):
            return .uploadFile(fileURL)
        case .uploadMultipart(let data, let urlParameters), .validatedUploadMultipart(let data, let urlParameters, _):
            if let urlParameters = urlParameters {
                return .uploadCompositeMultipart(data, urlParameters: urlParameters)
            } else {
                return .uploadMultipart(data)
            }
        }
    }

    var headers: [String: String]? { nil }

    var validationType: ValidationType {
        switch self {
        case .validatedUploadMultipart(_, _, let codes):
            return .customCodes(codes)
        default:
            return .none
        }
    }

    var authorizationType: AuthorizationType? {
        switch self {
        case .bearer:
            return  .bearer
        default:
            return nil
        }
    }
}

public enum GitHubUserContent {
    case downloadMoyaWebContent(String)
    case requestMoyaWebContent(String)
}

extension GitHubUserContent: TargetType {
    public var baseURL: URL { URL(string: "https://raw.githubusercontent.com")! }
    public var path: String {
        switch self {
        case .downloadMoyaWebContent(let contentPath), .requestMoyaWebContent(let contentPath):
            return "/Moya/Moya/master/web/\(contentPath)"
        }
    }
    public var method: Moya.Method {
        switch self {
        case .downloadMoyaWebContent, .requestMoyaWebContent:
            return .get
        }
    }
    public var parameters: [String: Any]? {
        switch self {
        case .downloadMoyaWebContent, .requestMoyaWebContent:
            return nil
        }
    }
    public var parameterEncoding: ParameterEncoding { URLEncoding.default }
    public var task: Task {
        switch self {
        case .downloadMoyaWebContent:
            return .downloadDestination(defaultDownloadDestination)
        case .requestMoyaWebContent:
            return .requestPlain
        }
    }

    public var headers: [String: String]? { nil }
}

// MARK: - Upload Multipart Helpers

extension HTTPBin {
    static func createTestMultipartFormData() -> [MultipartFormData] {
        let url = testImageUrl
        let string = "some data"
        guard let data = string.data(using: .utf8) else {
            fatalError("Failed creating Data from String \(string)")
        }
        return [
            MultipartFormData(provider: .file(url), name: "file", fileName: "testImage"),
            MultipartFormData(provider: .data(data), name: "data")
        ]
    }
}

// MARK: - String Helpers
extension String {
    var urlEscaped: String {
        self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
    }
}

// MARK: - DispatchQueue Test Helpers
// https://lists.swift.org/pipermail/swift-users/Week-of-Mon-20160613/002280.html
extension DispatchQueue {
    class var currentLabel: String? {
        String(validatingUTF8: __dispatch_queue_get_label(nil))
    }
}

private let defaultDownloadDestination: DownloadDestination = { temporaryURL, response in
    let directoryURLs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)

    if !directoryURLs.isEmpty {
        return (directoryURLs.first!.appendingPathComponent(response.suggestedFilename!), [])
    }

    return (temporaryURL, [])
}

extension URL {
    static func random(withExtension extension: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
        let name = UUID().uuidString + "." + `extension`
        return directory.appendingPathComponent(name, isDirectory: false)
    }
}

// MARK: - Image Test Helpers
// Necessary since Image(named:) doesn't work correctly in the test bundle
extension ImageType {
    class TestClass { }

    static var testImage: ImageType {
        Image(data: testImageData)!
    }

    #if canImport(UIKit)
        func asJPEGRepresentation(_ compression: CGFloat) -> Data? {
            jpegData(compressionQuality: compression)
        }
    #elseif canImport(AppKit)
        func asJPEGRepresentation(_ compression: CGFloat) -> Data? {
            var imageRect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
            let imageRep = NSBitmapImageRep(cgImage: self.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)!)
            return imageRep.representation(using: .jpeg, properties: [:])
        }
    #endif
}

// A fixture for testing Decodable mapping
struct Issue: Codable {
    let title: String
    let createdAt: Date
    let rating: Float?

    enum CodingKeys: String, CodingKey {
        case title
        case createdAt
        case rating
    }
}

// A fixture for testing optional Decodable mapping
struct OptionalIssue: Codable {
    let title: String?
    let createdAt: Date?
}

struct ImmediateStubPlugin: PluginType {
    var stubbedMessage: String? = "Half measures are as bad as nothing at all."

    func stubBehavior(for target: TargetType) -> StubBehavior? {
        guard let data = stubbedMessage?.data(using: .utf8) else { return nil }
        let response = Moya.Response(statusCode: 200, data: data)
        return StubBehavior(result: .success(response))
    }
}

struct StubPlugin: PluginType {
    var statusCode: Int = 200

    func stubBehavior(for target: TargetType) -> StubBehavior? {
        let response = Moya.Response(statusCode: statusCode, data: Data())
        return StubBehavior(result: .success(response))
    }
}

struct ErrorStubPlugin: PluginType {
    var error: Swift.Error = NSError(domain: "com.moya.moyaerror", code: 0, userInfo: [NSLocalizedDescriptionKey: "Houston, we have a problem"])

    func stubBehavior(for target: TargetType) -> StubBehavior? {
        return StubBehavior(result: .failure(MoyaError.underlying(error, nil)))
    }
}

struct DelayedStubPlugin: PluginType {
    var delay: TimeInterval = 0.5

    func stubBehavior(for target: TargetType) -> StubBehavior? {
        let response = Moya.Response(statusCode: 200, data: Data())
        return StubBehavior(delay: delay, result: .success(response))
    }
}
