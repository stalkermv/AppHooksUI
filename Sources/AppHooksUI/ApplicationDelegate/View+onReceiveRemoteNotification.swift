import SwiftUI

#if os(iOS)
/// Registers one SwiftUI handler for background APNs notifications.
extension View {
    /// Handles a remote notification and returns the result sent to UIKit.
    ///
    /// The library owns the system completion callback. If several views are
    /// mounted, the most recently mounted still-registered handler wins.
    /// Unmounting that handler restores the still-mounted predecessor. If no
    /// view handles the event, `.noData` is sent synchronously.
    @MainActor
    public func onReceiveRemoteNotification(
        _ handler: @escaping @MainActor (PushNotification) -> RemoteNotificationResult
    ) -> some View {
        modifier(ReceiveRemoteNotificationViewModifier(handler: handler))
    }
}

@MainActor
private struct ReceiveRemoteNotificationViewModifier: ViewModifier {
    @EnvironmentObject private var appDelegate: ApplicationDelegate
    @State private var registrationID: UUID?

    private let handlerRevision = UUID()
    let handler: @MainActor (PushNotification) -> RemoteNotificationResult

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard registrationID == nil else { return }
                registrationID = appDelegate.registerRemoteNotificationHandler(handler)
            }
            .onChange(of: handlerRevision) {
                guard let registrationID else { return }
                appDelegate.updateRemoteNotificationHandler(registrationID, handler)
            }
            .onDisappear {
                guard let registrationID else { return }
                appDelegate.unregisterRemoteNotificationHandler(registrationID)
                self.registrationID = nil
            }
    }
}
#endif
