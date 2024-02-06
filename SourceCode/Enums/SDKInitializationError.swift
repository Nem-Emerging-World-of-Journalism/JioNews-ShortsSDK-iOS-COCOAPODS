//
//  SDKInitializationError.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 15/01/24.
//

import Foundation

enum SDKInitializationError: Error {
    case hidEmpty
    case invalidClient
    
    var message: String {
        switch self {
        case .hidEmpty:
            return "One or more required initial data properties are blank. call configure() method with all mandatory params"
        case .invalidClient:
            return "Invalid client, to enable shorts SDK for your client, contact JioNews Team!!"
        }
    }
}
