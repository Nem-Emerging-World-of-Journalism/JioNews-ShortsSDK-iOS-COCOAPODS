//
//  Constants.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 11/01/24.
//

import Foundation

internal struct Constants {
    /// JioNews GraphQL endpoint backing the native `getSTBShorts` feed.
    static let graphQLEndpoint = URL(string: "https://stgmobileservice.jionews.com/graphql")!
    static let platform = "iOS"
    static let language = "English"
    static let source = "Direct"
    static let contentType = "Shorts"
}
