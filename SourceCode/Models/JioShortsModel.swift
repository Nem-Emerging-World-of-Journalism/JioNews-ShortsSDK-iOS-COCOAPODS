//
//  JioShortsModel.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 11/01/24.
//

import Foundation

internal struct JioShortsModel {
    public let language: String
    public let platform: String
    public let theme: JioShortsTheme
    public let localisation: JioShortsLocalisation
    public let analyticsValue: JioShortsAnalyticsValue
    
    internal init(
        language: String = Constants.language,
        platform: String = Constants.platform,
        theme: JioShortsTheme,
        localisation: JioShortsLocalisation,
        analyticsValue: JioShortsAnalyticsValue
    ) {
        self.language = language
        self.platform = platform
        self.theme = theme
        self.localisation = localisation
        self.analyticsValue = analyticsValue
    }
    
    internal func asParameters() -> [String: Any] {
        return [
            "language": self.language,
            "platform": self.platform,
            "theme": self.theme,
            "localization": "",
            "extraAnalyticsValue": self.analyticsValue.asString()
        ]
    }
}

internal struct JioShortsLocalisation {
    internal let endFeedMessage: String
    internal let exploreVideoTitle: String
    
    internal init(endFeedMessage: String, exploreVideoTitle: String) {
        self.endFeedMessage = endFeedMessage
        self.exploreVideoTitle = exploreVideoTitle
    }
    
    internal func asParameters() -> [String: Any] {
        return [
            "END_FEED_MESSAGE": self.endFeedMessage,
            "EXPLORE_VIDEO": self.exploreVideoTitle
        ]
    }
    
    internal func asString() -> String {
        if let jsonDara = try? JSONSerialization.data(withJSONObject: self.asParameters()),
           let data = String(data: jsonDara, encoding: .utf8) {
            return data
        }
        return ""
    }
}

internal struct JioShortsAnalyticsValue {
    public let source: String
    public let language: String
    public let platform: String
    public let theme: JioShortsTheme
    public let section: String
    public let contentType: String
    
    internal init(
        source: String = Constants.source,
        language: String = Constants.language,
        platform: String = Constants.platform,
        theme: JioShortsTheme,
        section: String = Constants.contentType,
        contentType: String = Constants.contentType
    ) {
        self.source = source
        self.language = language
        self.platform = platform
        self.theme = theme
        self.section = section
        self.contentType = contentType
    }
    
    internal func asParameters() -> [String: Any] {
        return [
            "source": self.source,
            "language": self.language,
            "platform": self.platform,
            "dark_mode": (theme == .dark) ? "True" : "False",
            "theme": theme.rawValue,
            "section": self.section,
            "content_type": self.contentType
        ]
    }
    
    internal func asString() -> String {
        if let jsonDara = try? JSONSerialization.data(withJSONObject: self.asParameters()),
           let data = String(data: jsonDara, encoding: .utf8) {
            return data
        }
        return ""
    }
}
