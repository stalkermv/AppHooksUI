//
//  EnvironmentValues+UserNotificationCenter.swift
//
//  Created by Valeriy Malishevskyi on 10.10.2024.
//

import SwiftUI

extension EnvironmentValues {
    var userNotificationCenter: UserNotificationCenter {
        get { self[UserNotificationCenterKey.self] }
        set { self[UserNotificationCenterKey.self] = newValue }
    }
}

private struct UserNotificationCenterKey: EnvironmentKey {
    static let defaultValue = UserNotificationCenter()
}
