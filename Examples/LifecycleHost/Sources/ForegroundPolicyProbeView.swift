import Foundation
import SwiftUI
import UserNotifications
import AppHooksUI

struct ForegroundPolicyProbeView: View {
    @State private var authorization = "starting"
    @State private var primaryMounted = true
    @State private var secondaryMounted = false
    @State private var tertiaryMounted = false
    @State private var inFlightMounted = false
    @State private var primaryOptions: UNNotificationPresentationOptions = [.banner]
    @State private var secondaryOptions: UNNotificationPresentationOptions = [.banner, .sound]
    @State private var tertiaryOptions: UNNotificationPresentationOptions = [.list]
    @State private var inFlightOptions: UNNotificationPresentationOptions = [.banner]
    @State private var invocationCount = 0
    @State private var selectedHandler = "none"
    @State private var lastRequestID = "none"
    @State private var scheduledRequestID = "none"
    @State private var replayOptionsRawValue: UInt = 0
    @State private var replayRequestID = "none"
    @State private var replayCount = 0
    @State private var status = "starting"
    @State private var inFlightStartCount = 0
    @State private var requestNumber = 0
    @State private var probeGate = ForegroundPolicyProbeGate()

    var body: some View {
        let currentPrimaryOptions = primaryOptions
        let currentSecondaryOptions = secondaryOptions
        let currentTertiaryOptions = tertiaryOptions
        let currentInFlightOptions = inFlightOptions

        ScrollView {
            VStack(spacing: 8) {
                Text(authorization)
                    .accessibilityLabel(authorization)
                    .accessibilityIdentifier("foregroundProbeAuthorization")
                Text(status)
                    .accessibilityLabel(status)
                    .accessibilityIdentifier("foregroundProbeStatus")
                Text(selectedHandler)
                    .accessibilityLabel(selectedHandler)
                    .accessibilityIdentifier("foregroundSelectedHandler")
                Text("\(invocationCount)")
                    .accessibilityLabel("\(invocationCount)")
                    .accessibilityIdentifier("foregroundInvocationCount")
                Text(lastRequestID)
                    .accessibilityLabel(lastRequestID)
                    .accessibilityIdentifier("foregroundLastRequestID")
                Text(scheduledRequestID)
                    .accessibilityLabel(scheduledRequestID)
                    .accessibilityIdentifier("foregroundScheduledRequestID")
                Text("\(replayOptionsRawValue)")
                    .accessibilityLabel("\(replayOptionsRawValue)")
                    .accessibilityIdentifier("foregroundReplayOptionsRawValue")
                Text(replayRequestID)
                    .accessibilityLabel(replayRequestID)
                    .accessibilityIdentifier("foregroundReplayRequestID")
                Text("\(replayCount)")
                    .accessibilityLabel("\(replayCount)")
                    .accessibilityIdentifier("foregroundReplayCount")
                Text("\(inFlightStartCount)")
                    .accessibilityLabel("\(inFlightStartCount)")
                    .accessibilityIdentifier("foregroundInFlightStartCount")

                Button("Toggle primary") { primaryMounted.toggle() }
                    .accessibilityIdentifier("foregroundTogglePrimary")
                Button("Toggle secondary") { secondaryMounted.toggle() }
                    .accessibilityIdentifier("foregroundToggleSecondary")
                Button("Toggle tertiary") { tertiaryMounted.toggle() }
                    .accessibilityIdentifier("foregroundToggleTertiary")
                Button("Toggle in flight") { inFlightMounted.toggle() }
                    .accessibilityIdentifier("foregroundToggleInFlight")
                Button("Refresh primary") {
                    primaryOptions = primaryOptions == [.banner] ? [.list] : [.banner]
                }
                .accessibilityIdentifier("foregroundRefreshPrimary")
                Button("Refresh secondary") {
                    secondaryOptions = secondaryOptions == [.banner] ? [.list] : [.banner]
                }
                .accessibilityIdentifier("foregroundRefreshSecondary")
                Button("Refresh in flight") {
                    inFlightOptions = inFlightOptions == [.banner] ? [.list] : [.banner]
                }
                .accessibilityIdentifier("foregroundRefreshInFlight")
                Button("Arm in flight") { Task { await probeGate.arm() } }
                    .accessibilityIdentifier("foregroundArmInFlight")
                Button("Release in flight") { Task { await probeGate.release() } }
                    .accessibilityIdentifier("foregroundReleaseInFlight")
                Button("Send notification") { sendNotification() }
                    .accessibilityIdentifier("foregroundSendNotification")
                Button("Replay latest") { replayLatest() }
                    .accessibilityIdentifier("foregroundReplayLatest")

                if primaryMounted {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .userNotificationPresentationOptions { [currentPrimaryOptions] notification in
                            await recordInvocation(
                                identity: "primary", requestID: notification.request.identifier
                            )
                            return currentPrimaryOptions
                        }
                }
                if secondaryMounted {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .userNotificationPresentationOptions { [currentSecondaryOptions] notification in
                            await recordInvocation(
                                identity: "secondary", requestID: notification.request.identifier
                            )
                            return currentSecondaryOptions
                        }
                }
                if tertiaryMounted {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .userNotificationPresentationOptions { [currentTertiaryOptions] notification in
                            await recordInvocation(
                                identity: "tertiary", requestID: notification.request.identifier
                            )
                            return currentTertiaryOptions
                        }
                }
                if inFlightMounted {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .userNotificationPresentationOptions { [currentInFlightOptions] notification in
                            await recordInvocation(
                                identity: "inFlight", requestID: notification.request.identifier
                            )
                            let waitsForRelease = await probeGate.markStarted()
                            if waitsForRelease {
                                await MainActor.run { inFlightStartCount += 1 }
                                await probeGate.waitForRelease()
                            }
                            return currentInFlightOptions
                        }
                }
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
        .task { await prepare() }
        .onDisappear { Task { await probeGate.release(); await cleanupOwnedNotifications() } }
    }

    @MainActor
    private func recordInvocation(identity: String, requestID: String) {
        invocationCount += 1
        selectedHandler = identity
        lastRequestID = requestID
    }

    private func prepare() async {
        let center = UNUserNotificationCenter.current()
        await cleanupOwnedNotifications()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                authorization = granted ? "authorized" : "authorization denied"
                status = granted ? "ready" : "authorization denied"
            }
        } catch {
            await MainActor.run {
                authorization = "authorization error"
                status = "error: \(error.localizedDescription)"
            }
        }
    }

    private func sendNotification() {
        requestNumber += 1
        let identifier = "apphooks.foreground.\(requestNumber).\(UUID().uuidString)"
        scheduledRequestID = identifier
        status = "scheduling"
        Task {
            do {
                let content = UNMutableNotificationContent()
                content.title = "AppHooksUI foreground probe"
                content.body = identifier
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                try await UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                )
                await MainActor.run { status = "scheduled" }
            } catch {
                await MainActor.run { status = "error: \(error.localizedDescription)" }
            }
        }
    }

    private func replayLatest() {
        let expectedID = lastRequestID
        Task {
            do {
                guard expectedID != "none" else {
                    throw ForegroundPolicyProbeError.noObservedRequest
                }
                let replay = try await UNUserNotificationCenter.current()
                    .replayForegroundNotification(withID: expectedID)
                await MainActor.run {
                    replayRequestID = replay.requestID
                    replayOptionsRawValue = replay.optionsRawValue
                    replayCount += 1
                    status = "replayed"
                }
            } catch {
                await MainActor.run { status = "error: \(error.localizedDescription)" }
            }
        }
    }

    private func deliveredNotificationIDs() async -> [String] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getDeliveredNotifications {
                continuation.resume(returning: $0.map { $0.request.identifier })
            }
        }
    }

    private func cleanupOwnedNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pendingIDs = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests {
                continuation.resume(returning: $0.map(\.identifier))
            }
        }
        let deliveredIDs = await deliveredNotificationIDs()
            .filter { $0.hasPrefix("apphooks.foreground.") }
        let ownedPendingIDs = pendingIDs.filter { $0.hasPrefix("apphooks.foreground.") }
        center.removePendingNotificationRequests(withIdentifiers: ownedPendingIDs)
        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
    }
}
