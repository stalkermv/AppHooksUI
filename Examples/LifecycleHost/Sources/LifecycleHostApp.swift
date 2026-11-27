import Foundation
import SwiftUI
import UserNotifications
import AppHooksModules
import AppHooksUI

@main
struct LifecycleHostApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
    #else
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
    #endif

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-AppHooksUIForegroundPolicyProbe") {
                ForegroundPolicyProbeView()
            } else {
#if os(iOS)
                if ProcessInfo.processInfo.arguments.contains("-AppHooksUIDeviceTokenProbe") {
                    DeviceTokenProbeView()
                } else if ProcessInfo.processInfo.arguments.contains("-AppHooksUIResponseProbe") {
                    ResponseProbeView()
                } else {
                    LifecycleHostView()
                }
#else
                LifecycleHostView()
#endif
            }
        }
        .modules { HostModule() }
    }
}

private struct HostModule: ApplicationModule {
    func configure(application: AppHooksModules.PlatformApplication) throws {}
}

private struct LifecycleHostView: View {
    @EnvironmentObject private var delegate: ApplicationDelegate
    @Environment(\.scenePhase) private var phase
    @State private var phases: [ScenePhase] = []
    @State private var mounted = true
    @State private var initialStage = "unmounted"
    @State private var initialCount = 0
    @State private var bannerEnabled = true
    @State private var presentation = "pending"
    @State private var responses = 0
    @State private var scheduledNotificationID = "none"
    @State private var receivedResponseID = "none"

    var body: some View {
        VStack(spacing: 16) {
            Text(String(describing: phase))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(describing: phase))
                .accessibilityIdentifier("applicationPhase")
            Text(phases.map { String(describing: $0) }.joined(separator: ","))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(phases.map { String(describing: $0) }.joined(separator: ","))
                .accessibilityIdentifier("phaseHistory")
            Text(String(describing: type(of: delegate)))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(describing: type(of: delegate)))
                .accessibilityIdentifier("delegateReady")
            Text(UNUserNotificationCenter.current().delegate == nil ? "missing" : "installed")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    UNUserNotificationCenter.current().delegate == nil ? "missing" : "installed"
                )
                .accessibilityIdentifier("notificationDelegateReady")
            Text("\(initialCount)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(initialCount)")
                .accessibilityIdentifier("initialCount")
            Text(initialStage)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(initialStage)
                .accessibilityIdentifier("initialStage")
            Button("Toggle handler") { mounted.toggle() }
                .accessibilityIdentifier("toggleHandler")
            Text(presentation)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(presentation)
                .accessibilityIdentifier("presentationResult")
            Text("\(responses)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(responses)")
                .accessibilityIdentifier("responseCount")
            Text(scheduledNotificationID)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(scheduledNotificationID)
                .accessibilityIdentifier("scheduledNotificationID")
            Text(receivedResponseID)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(receivedResponseID)
                .accessibilityIdentifier("receivedResponseID")
            Button("Toggle presentation") { bannerEnabled.toggle() }
                .accessibilityIdentifier("togglePresentation")
            Button("Send notification") {
                Task {
                    do {
                        let center = UNUserNotificationCenter.current()
                        guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                            presentation = "authorization denied"
                            return
                        }
                        let requestID = UUID().uuidString
                        let content = UNMutableNotificationContent()
                        content.title = "AppHooksUI verification"
                        content.body = "Local notification callback check [\(requestID)]"
                        let request = UNNotificationRequest(
                            identifier: requestID,
                            content: content,
                            trigger: UNTimeIntervalNotificationTrigger(
                                timeInterval: 1, repeats: false
                            )
                        )
                        try await center.add(request)
                        scheduledNotificationID = requestID
                    } catch {
                        presentation = "error: \(error)"
                    }
                }
            }
            .accessibilityIdentifier("sendNotification")
            if mounted {
                Text("Mounted")
                    .onAppear { initialStage = "mounted" }
                    .onDisappear { initialStage = "unmounted" }
                    .onChange(of: phase, initial: true) {
                        initialCount += 1
                    }
            }
            #if os(iOS)
            RemoteNotificationProbeView()
            #endif
        }
        .padding()
        .onChange(of: phase, initial: true) { phases.append(phase) }
        .userNotificationPresentationOptions { [bannerEnabled] _ in
            let options: UNNotificationPresentationOptions = bannerEnabled ? [.banner] : []
            await MainActor.run {
                presentation = bannerEnabled ? "shown" : "hidden"
            }
            return options
        }
        .onUserNotificationResponse { response in
            responses += 1
            receivedResponseID = response.notification.request.identifier
        }
    }
}
