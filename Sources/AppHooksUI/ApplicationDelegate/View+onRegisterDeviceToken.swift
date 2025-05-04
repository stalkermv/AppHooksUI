//
//  View+onRegisterDeviceToken.swift
//
//  Created by Valeriy Malishevskyi on 17.11.2024.
//

import SwiftUI

extension View {

    /// Registers a handler to receive the device token or registration error from APNs.
    ///
    /// This view modifier connects your SwiftUI view to the application's delegate via
    /// the `ApplicationDelegate` environment object. When the device token is registered
    /// (or if registration fails), the provided handler is invoked with a `Result`.
    ///
    /// ```swift
    /// struct ContentView: View {
    ///     var body: some View {
    ///         Text("Push Enabled")
    ///             .onRegisterDeviceToken { result in
    ///                 switch result {
    ///                 case .success(let token):
    ///                     print("Device token: \(token)")
    ///                 case .failure(let error):
    ///                     print("Failed to register: \(error)")
    ///                 }
    ///             }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter handler: A closure that receives a `Result<Data, Error>` containing the device token or an error.
    /// - Returns: A view that observes device token registration events.
    /// On macOS, this is a no-op unless customized to simulate registration.
    public func onRegisterDeviceToken(_ handler: @escaping (Result<Data, Error>) -> Void) -> some View {
        #if os(iOS)
        return modifier(ReceiveDeviceTokenViewModifier(handler))
        #else
        return self // No-op on macOS
        #endif
    }
}

#if os(iOS)
struct ReceiveDeviceTokenViewModifier: ViewModifier {
    @EnvironmentObject var appDelegate: ApplicationDelegate
    let handler: (Result<Data, Error>) -> Void

    init(_ handler: @escaping (Result<Data, Error>) -> Void) {
        self.handler = handler
    }

    func body(content: Content) -> some View {
        content
            .onReceive(appDelegate.didRegisterForRemoteNotifications) { result in
                let tokenResult = result.map(\.deviceToken)
                handler(tokenResult)
            }
    }
}
#endif
