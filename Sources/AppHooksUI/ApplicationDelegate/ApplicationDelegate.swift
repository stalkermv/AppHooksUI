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
public typealias App = UIApplication
public typealias LaunchOptionsKey = UIApplication.LaunchOptionsKey
#elseif os(macOS)
import AppKit
public typealias AppDelegateBase = NSObject & NSApplicationDelegate
public typealias App = NSApplication
#endif

import Combine

public final class ApplicationDelegate: AppDelegateBase, ObservableObject {

    public typealias Subject = PassthroughSubject

    #if os(iOS)
    public struct LaunchOptions {
        public let application: App
        public let launchOptions: [LaunchOptionsKey: Any]?
    }

    public struct RemoteNotificationRegistration {
        public let application: App
        public let deviceToken: Data
    }

    public struct ReceiveRemoteNotification {
        public let application: App
        public let userInfo: [AnyHashable: Any]
        public let completionHandler: (UIBackgroundFetchResult) -> Void
    }

    public struct ShortcutAction {
        public let application: App
        public let shortcutItem: UIApplicationShortcutItem
        public let completionHandler: (Bool) -> Void
    }
    #else
    public struct LaunchOptions {
        public let application: App
        public let launchOptions: [String: Any]?
    }
    #endif

    // Shared Subjects
    public let willFinishLaunching = Subject<LaunchOptions, Never>()
    public let didFinishLaunching = Subject<LaunchOptions, Never>()
    public let didBecomeActive = Subject<App, Never>()
    public let willResignActive = Subject<App, Never>()
    public let willTerminate = Subject<App, Never>()

    #if os(iOS)
    public let didReceiveMemoryWarning = Subject<App, Never>()
    public let significantTimeChange = Subject<App, Never>()
    public let didRegisterForRemoteNotifications = Subject<Result<RemoteNotificationRegistration, Error>, Never>()
    public let didReceiveRemoteNotification = Subject<ReceiveRemoteNotification, Never>()
    public let didRequireShortcutAction = Subject<ShortcutAction, Never>()
    public let didEnterBackground = Subject<App, Never>()
    public let willEnterForeground = Subject<App, Never>()
    public let protectedDataWillBecomeUnavailable = Subject<App, Never>()
    public let protectedDataDidBecomeAvailable = Subject<App, Never>()
    #endif

    #if os(iOS)
    public func application(_ application: App, willFinishLaunchingWithOptions launchOptions: [LaunchOptionsKey : Any]? = nil) -> Bool {
        willFinishLaunching.send(LaunchOptions(application: application, launchOptions: launchOptions))
        return true
    }

    public func application(_ application: App, didFinishLaunchingWithOptions launchOptions: [LaunchOptionsKey : Any]? = nil) -> Bool {
        didFinishLaunching.send(LaunchOptions(application: application, launchOptions: launchOptions))
        return true
    }

    public func applicationDidBecomeActive(_ application: App) {
        didBecomeActive.send(application)
    }

    public func applicationWillResignActive(_ application: App) {
        willResignActive.send(application)
    }

    public func applicationDidReceiveMemoryWarning(_ application: App) {
        didReceiveMemoryWarning.send(application)
    }

    public func applicationWillTerminate(_ application: App) {
        willTerminate.send(application)
    }

    public func applicationSignificantTimeChange(_ application: App) {
        significantTimeChange.send(application)
    }

    public func application(_ application: App, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        didRegisterForRemoteNotifications.send(.success(RemoteNotificationRegistration(application: application, deviceToken: deviceToken)))
    }

    public func application(_ application: App, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        didRegisterForRemoteNotifications.send(.failure(error))
    }

    public func application(_ application: App, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        didReceiveRemoteNotification.send(ReceiveRemoteNotification(application: application, userInfo: userInfo, completionHandler: completionHandler))
    }

    public func application(_ application: App, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        didRequireShortcutAction.send(ShortcutAction(application: application, shortcutItem: shortcutItem, completionHandler: completionHandler))
    }

    public func applicationDidEnterBackground(_ application: App) {
        didEnterBackground.send(application)
    }

    public func applicationWillEnterForeground(_ application: App) {
        willEnterForeground.send(application)
    }

    public func applicationProtectedDataWillBecomeUnavailable(_ application: App) {
        protectedDataWillBecomeUnavailable.send(application)
    }

    public func applicationProtectedDataDidBecomeAvailable(_ application: App) {
        protectedDataDidBecomeAvailable.send(application)
    }

    #elseif os(macOS)
    public func applicationWillFinishLaunching(_ notification: Notification) {
        if let app = notification.object as? App {
            willFinishLaunching.send(LaunchOptions(application: app, launchOptions: nil))
        }
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        if let app = notification.object as? App {
            didFinishLaunching.send(LaunchOptions(application: app, launchOptions: nil))
        }
    }

    public func applicationDidBecomeActive(_ notification: Notification) {
        if let app = notification.object as? App {
            didBecomeActive.send(app)
        }
    }

    public func applicationWillResignActive(_ notification: Notification) {
        if let app = notification.object as? App {
            willResignActive.send(app)
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        if let app = notification.object as? App {
            willTerminate.send(app)
        }
    }
    #endif
}
