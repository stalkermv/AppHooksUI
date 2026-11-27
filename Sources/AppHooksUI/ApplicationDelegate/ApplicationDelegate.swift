//
//  ApplicationDelegate.swift
//  AppHooksUI
//

import Combine
import Foundation
import SwiftUI
import UserNotifications

#if os(iOS)
import UIKit
public typealias AppDelegateBase = UIResponder & UIApplicationDelegate
public typealias PlatformApplication = UIApplication
public typealias LaunchOptionsKey = UIApplication.LaunchOptionsKey
#elseif os(macOS)
import AppKit
public typealias AppDelegateBase = NSObject & NSApplicationDelegate
public typealias PlatformApplication = NSApplication
#endif

/// Bridges platform notification callbacks into SwiftUI.
///
/// Install exactly one instance with the platform adaptor in the app entry
/// point. SwiftUI automatically injects this `ObservableObject` into the
/// environment. For lifecycle state, use SwiftUI's `scenePhase` and `onChange`.
@MainActor
public final class ApplicationDelegate: AppDelegateBase, ObservableObject {
    let userNotificationCenter = UserNotificationCenter()

    #if os(iOS)
    let deviceTokenEvents = BufferedPassthroughSubject<Result<Data, Error>, Never>()

    typealias RemoteNotificationHandler =
        @MainActor (PushNotification) -> RemoteNotificationResult

    private var remoteNotificationHandlers: [UUID: RemoteNotificationHandler] = [:]
    private var remoteNotificationOrder: [UUID] = []
    #endif

    public override init() {
        super.init()
    }

    #if os(iOS)
    public func application(
        _ application: PlatformApplication,
        willFinishLaunchingWithOptions launchOptions: [LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        installUserNotificationDelegate()
        return true
    }

    public func application(
        _ application: PlatformApplication,
        didFinishLaunchingWithOptions launchOptions: [LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        installUserNotificationDelegate()
        return true
    }

    public func application(
        _ application: PlatformApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        deviceTokenEvents.send(.success(deviceToken))
    }

    public func application(
        _ application: PlatformApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        deviceTokenEvents.send(.failure(error))
    }

    public func application(
        _ application: PlatformApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let result = remoteNotificationOrder.last
            .flatMap { remoteNotificationHandlers[$0] }?(
                PushNotification(userInfo: userInfo)
            ) ?? .noData
        completionHandler(result)
    }

    func registerRemoteNotificationHandler(
        _ handler: @escaping RemoteNotificationHandler
    ) -> UUID {
        let id = UUID()
        remoteNotificationHandlers[id] = handler
        remoteNotificationOrder.append(id)
        return id
    }

    func updateRemoteNotificationHandler(
        _ id: UUID,
        _ handler: @escaping RemoteNotificationHandler
    ) {
        guard remoteNotificationHandlers[id] != nil else { return }
        remoteNotificationHandlers[id] = handler
    }

    func unregisterRemoteNotificationHandler(_ id: UUID) {
        remoteNotificationHandlers.removeValue(forKey: id)
        remoteNotificationOrder.removeAll { $0 == id }
    }

    #elseif os(macOS)
    public func applicationWillFinishLaunching(_ notification: Notification) {
        guard notification.object is PlatformApplication else { return }
        installUserNotificationDelegate()
    }
    #endif

    private func installUserNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = userNotificationCenter
    }
}
