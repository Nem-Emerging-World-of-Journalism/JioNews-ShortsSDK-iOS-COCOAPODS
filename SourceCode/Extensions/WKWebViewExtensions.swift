//
//  WKWebViewExtensions.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 11/01/24.
//

import WebKit

extension WKWebView {
    internal func loadWithCookies(request: URLRequest) {
        if #available(iOS 11.0, *) {
            load(request)
        } else {
            var _request = request
            _request.setCookies()
            load(_request)
        }
    }
}
