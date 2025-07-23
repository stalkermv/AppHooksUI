//
//  ApplicationDelegate.swift
//
//  Created by Valeriy Malishevskyi on 12.11.2024.
//

import SwiftUI
import Combine

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

import Combine

public final class ApplicationDelegate: AppDelegateBase, ObservableObject {

    public typealias Subject = PassthroughSubject

    #if os(iOS)
    public struct LaunchOptions {
        public let application: PlatformApplication
        public let launchOptions: [LaunchOptionsKey: Any]?
    }

    public struct RemoteNotificationRegistration {
        public let application: PlatformApplication
        public let deviceToken: Data
    }

    public struct ReceiveRemoteNotification {
        public let application: PlatformApplication
        public let userInfo: [AnyHashable: Any]
        public let completionHandler: (UIBackgroundFetchResult) -> Void
    }

    public struct ShortcutAction {
        public let application: PlatformApplication
        public let shortcutItem: UIApplicationShortcutItem
        public let completionHandler: (Bool) -> Void
    }
    #else
    public struct LaunchOptions {
        public let application: PlatformApplication
        public let launchOptions: [String: Any]?
    }
    #endif

    // Shared Subjects
    public let willFinishLaunching = Subject<LaunchOptions, Never>()
    public let didFinishLaunching = Subject<LaunchOptions, Never>()
    public let didBecomeActive = Subject<PlatformApplication, Never>()
    public let willResignActive = Subject<PlatformApplication, Never>()
    public let willTerminate = Subject<PlatformApplication, Never>()

    #if os(iOS)
    public let didReceiveMemoryWarning = Subject<PlatformApplication, Never>()
    public let significantTimeChange = Subject<PlatformApplication, Never>()
    public let didRegisterForRemoteNotifications = Subject<Result<RemoteNotificationRegistration, Error>, Never>()
    public let didReceiveRemoteNotification = Subject<ReceiveRemoteNotification, Never>()
    public let didRequireShortcutAction = Subject<ShortcutAction, Never>()
    public let didEnterBackground = Subject<PlatformApplication, Never>()
    public let willEnterForeground = Subject<PlatformApplication, Never>()
    public let protectedDataWillBecomeUnavailable = Subject<PlatformApplication, Never>()
    public let protectedDataDidBecomeAvailable = Subject<PlatformApplication, Never>()
    #endif

    let userNotificationCenter = UserNotificationCenter()
    
    #if os(iOS)
    public func application(_ application: PlatformApplication, willFinishLaunchingWithOptions launchOptions: [LaunchOptionsKey : Any]? = nil) -> Bool {
        willFinishLaunching.send(LaunchOptions(application: application, launchOptions: launchOptions))
        UNUserNotificationCenter.current().delegate = userNotificationCenter
        return true
    }

    public func application(_ application: PlatformApplication, didFinishLaunchingWithOptions launchOptions: [LaunchOptionsKey : Any]? = nil) -> Bool {
        didFinishLaunching.send(LaunchOptions(application: application, launchOptions: launchOptions))
        return true
    }

    public func applicationDidBecomeActive(_ application: PlatformApplication) {
        didBecomeActive.send(application)
    }

    public func applicationWillResignActive(_ application: PlatformApplication) {
        willResignActive.send(application)
    }

    public func applicationDidReceiveMemoryWarning(_ application: PlatformApplication) {
        didReceiveMemoryWarning.send(application)
    }

    public func applicationWillTerminate(_ application: PlatformApplication) {
        willTerminate.send(application)
    }

    public func applicationSignificantTimeChange(_ application: PlatformApplication) {
        significantTimeChange.send(application)
    }

    public func application(_ application: PlatformApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        didRegisterForRemoteNotifications.send(.success(RemoteNotificationRegistration(application: application, deviceToken: deviceToken)))
    }

    public func application(_ application: PlatformApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        didRegisterForRemoteNotifications.send(.failure(error))
    }

    public func application(_ application: PlatformApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        didReceiveRemoteNotification.send(ReceiveRemoteNotification(application: application, userInfo: userInfo, completionHandler: completionHandler))
    }

    public func application(_ application: PlatformApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        didRequireShortcutAction.send(ShortcutAction(application: application, shortcutItem: shortcutItem, completionHandler: completionHandler))
    }

    public func applicationDidEnterBackground(_ application: PlatformApplication) {
        didEnterBackground.send(application)
    }

    public func applicationWillEnterForeground(_ application: PlatformApplication) {
        willEnterForeground.send(application)
    }

    public func applicationProtectedDataWillBecomeUnavailable(_ application: PlatformApplication) {
        protectedDataWillBecomeUnavailable.send(application)
    }

    public func applicationProtectedDataDidBecomeAvailable(_ application: PlatformApplication) {
        protectedDataDidBecomeAvailable.send(application)
    }

    #elseif os(macOS)
    public func applicationWillFinishLaunching(_ notification: Notification) {
        if let app = notification.object as? PlatformApplication {
            willFinishLaunching.send(LaunchOptions(application: app, launchOptions: nil))
        }
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        if let app = notification.object as? PlatformApplication {
            didFinishLaunching.send(LaunchOptions(application: app, launchOptions: nil))
        }
    }

    public func applicationDidBecomeActive(_ notification: Notification) {
        if let app = notification.object as? PlatformApplication {
            didBecomeActive.send(app)
        }
    }

    public func applicationWillResignActive(_ notification: Notification) {
        if let app = notification.object as? PlatformApplication {
            willResignActive.send(app)
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        if let app = notification.object as? PlatformApplication {
            willTerminate.send(app)
        }
    }
    #endif
}
