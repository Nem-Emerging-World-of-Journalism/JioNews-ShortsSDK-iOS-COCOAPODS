//
//  Copyright SkeletonView. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  Notification+Extensions.swift
//
//  Created by Juanpe Catalán on 18/8/21.

import UIKit

extension Notification.Name {
    
    static let applicationDidBecomeActiveNotification = Notification.Name.UIApplicationDidEnterBackground
    static let applicationWillTerminateNotification = Notification.Name.UIApplicationWillTerminate
    static let applicationDidEnterForegroundNotification = Notification.Name.UIApplicationWillEnterForeground
    
}
