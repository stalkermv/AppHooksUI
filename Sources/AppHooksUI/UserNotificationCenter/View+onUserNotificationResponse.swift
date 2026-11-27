import SwiftUI
import UserNotifications

extension View {
    /// Handles a user interaction with a delivered notification.
    ///
    /// A response that arrives before any view subscribes, for example when a
    /// tap launches the app, is kept and delivered once, to the first
    /// subscriber. The action runs on the main actor.
    @MainActor
    public func onUserNotificationResponse(
        perform action: @escaping @Sendable @MainActor (UNNotificationResponse) -> Void
    ) -> some View {
        modifier(UserNotificationResponseViewModifier(action: action))
    }
}

@MainActor
private struct UserNotificationResponseViewModifier: ViewModifier {
    @EnvironmentObject private var appDelegate: ApplicationDelegate
    let action: @Sendable @MainActor (UNNotificationResponse) -> Void

    func body(content: Content) -> some View {
        content.onReceive(
            appDelegate.userNotificationCenter.responseSubject
                .receive(on: RunLoop.main)
        ) { response in
            action(response)
        }
    }
}
