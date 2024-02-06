//
//  WKWebViewConfigurationExtension.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 11/01/24.
//

import UIKit
import WebKit

extension WKWebViewConfiguration {
    
    internal func set(cookies: [HTTPCookie], completion: (() -> Void)?) {
        if #available(iOS 11.0, *) {
            let waitGroup = DispatchGroup()
            for cookie in cookies {
                waitGroup.enter()
                websiteDataStore.httpCookieStore.setCookie(cookie) { waitGroup.leave() }
            }
            waitGroup.notify(queue: DispatchQueue.main) { completion?() }
        } else {
            cookies.forEach { HTTPCookieStorage.shared.setCookie($0) }
            self.createCookiesInjectionJS(cookies: cookies) {
                let script = WKUserScript(source: $0, injectionTime: .atDocumentStart, forMainFrameOnly: false)
                self.userContentController.addUserScript(script)
                DispatchQueue.main.async { completion?() }
            }
        }
    }

    private func createCookiesInjectionJS(cookies: [HTTPCookie],  completion: ((String) -> Void)?) {
        var scripts: [String] = ["var cookieNames = document.cookie.split('; ').map(function(cookie) { return cookie.split('=')[0] } )"]
        let now = Date()

        for cookie in cookies {
            if let expiresDate = cookie.expiresDate, now.compare(expiresDate) == .orderedDescending { continue }
            scripts.append("if (cookieNames.indexOf('\(cookie.name)') == -1) { document.cookie='\(cookie.javaScriptString)'; }")
        }
        completion?(scripts.joined(separator: ";\n"))
    }
}
