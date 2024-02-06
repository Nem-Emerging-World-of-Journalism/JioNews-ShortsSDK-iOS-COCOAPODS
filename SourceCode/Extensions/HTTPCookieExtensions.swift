//
//  HTTPCookieExtensions.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 11/01/24.
//

import Foundation

extension HTTPCookie {

    internal var javaScriptString: String {
        if var properties = properties {
            properties.removeValue(forKey: .name)
            properties.removeValue(forKey: .value)

            return properties.reduce(into: ["\(name)=\(value)"]) { result, property in
                result.append("\(property.key.rawValue)=\(property.value)")
            }.joined(separator: "; ")
        }

        var script = [
            "\(name)=\(value)",
            "domain=\(domain)",
            "path=\(path)"
        ]

        if isSecure { script.append("secure=true") }

        if let expiresDate = expiresDate {
            script.append("expires=\(HTTPCookie.dateFormatter.string(from: expiresDate))")
        }

        return script.joined(separator: "; ")
    }

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return dateFormatter
    }()
}
