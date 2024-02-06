//
//  URLRequestExtensions.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 11/01/24.
//

import Foundation

extension URLRequest {

    private static var cookieHeaderKey: String { "Cookie" }
    private static var noAppliedcookieHeaderKey: String { "No-Applied-Cookies" }

    internal var hasCookies: Bool {
        let headerKeys = (allHTTPHeaderFields ?? [:]).keys
        var hasCookies = false
        if headerKeys.contains(URLRequest.cookieHeaderKey) { hasCookies = true }
        if !hasCookies && headerKeys.contains(URLRequest.noAppliedcookieHeaderKey) { hasCookies = true }
        return hasCookies
    }

    internal mutating func setCookies() {
        if #available(iOS 11.0, *) { return }
        var cookiesApplied = false
        if let url = self.url, let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            for (name, value) in headers { setValue(value, forHTTPHeaderField: name) }
            cookiesApplied = allHTTPHeaderFields?.keys.contains(URLRequest.cookieHeaderKey) ?? false
        }
        if !cookiesApplied { setValue("true", forHTTPHeaderField: URLRequest.noAppliedcookieHeaderKey) }
    }
}
