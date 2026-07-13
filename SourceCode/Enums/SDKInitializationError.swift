//
//  SDKInitializationError.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 15/01/24.
//

import Foundation

enum SDKInitializationError: Error {
    case missingRequiredData
    case invalidClient

    var message: String {
        switch self {
        case .missingRequiredData:
            return "One or more required initial data properties are blank. Call initData() with all mandatory params (hid, redirectSource)."
        case .invalidClient:
            return "Invalid client, to enable shorts library for your client, contact JioNews Team!!"
        }
    }
}
