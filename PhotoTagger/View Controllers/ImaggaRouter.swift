import Alamofire

public enum ImaggaRouter: URLRequestConvertible {
  
  // 1 Declare constants to hold the Imagga base URL and your Basic xxx with your actual authorization header.
  enum Constants {
    static let baseURLPath = "http://api.imagga.com/v1"
    static let authenticationToken = "Basic YWNjXzUwMThkMmI5YjUyNmQ2Zjo3ODVjZjg2YWMxYmIwOTdjYjAyZGI3YTEzZjRlM2YwZg=="
  }
  
  // 2 Declare the enum cases. Each case corresponds to an api endpoint.
  case content
  case tags(String)
  case colors(String)
  
  // 3 Return the HTTP method for each api endpoint.
  var method: HTTPMethod {
    switch self {
    case .content:
      return .post
    case .tags, .colors:
      return .get
    }
  }
  
  // 4 Return the path for each api endpoint.
  var path: String {
    switch self {
    case .content:
      return "/content"
    case .tags:
      return "/tagging"
    case .colors:
      return "/colors"
    }
  }
  
  // 5 Return the parameters for each api endpoint.
  var parameters: [String: Any] {
    switch self {
    case .tags(let contentID):
      return ["content": contentID]
    case .colors(let contentID):
      return ["content": contentID, "extract_object_colors": 0]
    default:
      return [:]
    }
  }
  
  // 6 Use all of the above components to create a URLRequest for the requested endpoint.
  public func asURLRequest() throws -> URLRequest {
    let url = try Constants.baseURLPath.asURL()
    
    var request = URLRequest(url: url.appendingPathComponent(path))
    request.httpMethod = method.rawValue
    request.setValue(Constants.authenticationToken, forHTTPHeaderField: "Authorization")
    request.timeoutInterval = TimeInterval(10 * 1000) // 10 seconds.
    
    return try URLEncoding.default.encode(request, with: parameters)
  }

}
