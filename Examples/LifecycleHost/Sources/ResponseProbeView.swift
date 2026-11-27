import SwiftUI
import UserNotifications
import AppHooksUI

@MainActor
struct ResponseProbeView: View {
    @State private var state = ResponseProbeState()
    @State private var acknowledgementFacts = ResponseAcknowledgementFacts()

    var body: some View {
        let delegateReady = UNUserNotificationCenter.current().delegate == nil
            ? "missing"
            : "installed"

        ScrollView {
            VStack(spacing: 8) {
                Text(state.authorization)
                    .accessibilityLabel(state.authorization)
                    .accessibilityIdentifier("responseAuthorization")
                Text(state.status)
                    .accessibilityLabel(state.status)
                    .accessibilityIdentifier("responseStatus")
                Text(delegateReady)
                    .accessibilityLabel(delegateReady)
                    .accessibilityIdentifier("responseDelegateReady")
                Text("ready")
                    .accessibilityLabel("ready")
                    .accessibilityIdentifier("responseReady")
                Text(state.scheduledRequestID)
                    .accessibilityLabel(state.scheduledRequestID)
                    .accessibilityIdentifier("responseScheduledRequestID")
                Text("\(state.capture.count)")
                    .accessibilityLabel("\(state.capture.count)")
                    .accessibilityIdentifier("responseCaptureCount")
                Text(state.capture.requestID)
                    .accessibilityLabel(state.capture.requestID)
                    .accessibilityIdentifier("responseCaptureRequestID")
                Text(state.capture.actionIdentifier)
                    .accessibilityLabel(state.capture.actionIdentifier)
                    .accessibilityIdentifier("responseCaptureAction")
                Text(state.capture.mainThread)
                    .accessibilityLabel(state.capture.mainThread)
                    .accessibilityIdentifier("responseCaptureMainThread")
                Text(state.capture.stage)
                    .accessibilityLabel(state.capture.stage)
                    .accessibilityIdentifier("responseCaptureStage")
                Text(state.primary.stage)
                    .accessibilityLabel(state.primary.stage)
                    .accessibilityIdentifier("responsePrimaryStage")
                Text("\(state.primary.count)")
                    .accessibilityLabel("\(state.primary.count)")
                    .accessibilityIdentifier("responsePrimaryCount")
                Text(state.primary.requestID)
                    .accessibilityLabel(state.primary.requestID)
                    .accessibilityIdentifier("responsePrimaryRequestID")
                Text(state.primary.actionIdentifier)
                    .accessibilityLabel(state.primary.actionIdentifier)
                    .accessibilityIdentifier("responsePrimaryAction")
                Text(state.primary.mainThread)
                    .accessibilityLabel(state.primary.mainThread)
                    .accessibilityIdentifier("responsePrimaryMainThread")
                Text(state.secondary.stage)
                    .accessibilityLabel(state.secondary.stage)
                    .accessibilityIdentifier("responseSecondaryStage")
                Text("\(state.secondary.count)")
                    .accessibilityLabel("\(state.secondary.count)")
                    .accessibilityIdentifier("responseSecondaryCount")
                Text(state.secondary.requestID)
                    .accessibilityLabel(state.secondary.requestID)
                    .accessibilityIdentifier("responseSecondaryRequestID")
                Text(state.secondary.actionIdentifier)
                    .accessibilityLabel(state.secondary.actionIdentifier)
                    .accessibilityIdentifier("responseSecondaryAction")
                Text(state.secondary.mainThread)
                    .accessibilityLabel(state.secondary.mainThread)
                    .accessibilityIdentifier("responseSecondaryMainThread")
                Text("\(state.acknowledgement.returnCount)")
                    .accessibilityLabel("\(state.acknowledgement.returnCount)")
                    .accessibilityIdentifier("responseAckReturnCount")
                Text("\(state.acknowledgement.observedCount)")
                    .accessibilityLabel("\(state.acknowledgement.observedCount)")
                    .accessibilityIdentifier("responseAckObservedCount")
                Text(state.acknowledgement.requestID)
                    .accessibilityLabel(state.acknowledgement.requestID)
                    .accessibilityIdentifier("responseAckRequestID")
                Text(state.acknowledgement.actionIdentifier)
                    .accessibilityLabel(state.acknowledgement.actionIdentifier)
                    .accessibilityIdentifier("responseAckAction")
                Text(state.acknowledgement.mainThread)
                    .accessibilityLabel(state.acknowledgement.mainThread)
                    .accessibilityIdentifier("responseAckMainThread")
                Text("\(state.acknowledgement.actionsBeforeReturn)")
                    .accessibilityLabel("\(state.acknowledgement.actionsBeforeReturn)")
                    .accessibilityIdentifier("responseActionsBeforeReturn")
                Text("\(state.acknowledgement.actionsAtReturn)")
                    .accessibilityLabel("\(state.acknowledgement.actionsAtReturn)")
                    .accessibilityIdentifier("responseActionsAtReturn")
                Text("\(state.consumerReceiptCount)")
                    .accessibilityLabel("\(state.consumerReceiptCount)")
                    .accessibilityIdentifier("responseConsumerReceiptCount")

                Button("Schedule response notification") { scheduleNotification() }
                    .accessibilityIdentifier("responseScheduleNotification")
                Button("Toggle capture") { state.captureMounted.toggle() }
                    .accessibilityIdentifier("responseToggleCapture")
                Button("Toggle primary") { state.primaryMounted.toggle() }
                    .accessibilityIdentifier("responseTogglePrimary")
                Button("Toggle secondary") { state.secondaryMounted.toggle() }
                    .accessibilityIdentifier("responseToggleSecondary")
                Button("Replay response R1") { replayResponse(at: 0) }
                    .accessibilityIdentifier("responseReplayR1")
                Button("Replay response R2") { replayResponse(at: 1) }
                    .accessibilityIdentifier("responseReplayR2")
                Button("Replay response R3") { replayResponse(at: 2) }
                    .accessibilityIdentifier("responseReplayR3")

                if state.captureMounted {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .onUserNotificationResponse { response in
                            capture(response)
                        }
                        .onAppear { state.capture.stage = "mounted" }
                        .onDisappear { state.capture.stage = "unmounted" }
                }
                if state.primaryMounted {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .onUserNotificationResponse { response in
                            receive(response, consumer: .primary)
                        }
                        .onAppear { state.primary.stage = "mounted" }
                        .onDisappear { state.primary.stage = "unmounted" }
                }
                if state.secondaryMounted {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .onUserNotificationResponse { response in
                            receive(response, consumer: .secondary)
                        }
                        .onAppear { state.secondary.stage = "mounted" }
                        .onDisappear { state.secondary.stage = "unmounted" }
                }
            }
            .padding()
            .accessibilityElement(children: .contain)
        }
        .task { await prepare() }
        .onDisappear { Task { await cleanupOwnedNotifications() } }
        .userNotificationPresentationOptions([.banner])
    }

    private enum Consumer { case primary, secondary }
}

extension ResponseProbeView {
    private func capture(_ response: UNNotificationResponse) {
        state.capturedResponses.append(response)
        state.capture.count += 1
        state.capture.requestID = response.notification.request.identifier
        state.capture.actionIdentifier = response.actionIdentifier
        state.capture.mainThread = Thread.isMainThread ? "true" : "false"
    }

    private func receive(_ response: UNNotificationResponse, consumer: Consumer) {
        state.consumerReceiptCount += 1
        let requestID = response.notification.request.identifier
        let action = response.actionIdentifier
        let mainThread = Thread.isMainThread ? "true" : "false"
        switch consumer {
        case .primary:
            state.primary.count += 1
            state.primary.requestID = requestID
            state.primary.actionIdentifier = action
            state.primary.mainThread = mainThread
        case .secondary:
            state.secondary.count += 1
            state.secondary.requestID = requestID
            state.secondary.actionIdentifier = action
            state.secondary.mainThread = mainThread
        }
        state.acknowledgement.observedCount = acknowledgementFacts.snapshot().count
    }

    private func prepare() async {
        let center = UNUserNotificationCenter.current()
        await cleanupOwnedNotifications()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            state.authorization = granted ? "authorized" : "authorization denied"
            state.status = granted ? "ready" : "authorization denied"
        } catch {
            state.authorization = "authorization error"
            state.status = "error: \(error.localizedDescription)"
        }
    }

    private func scheduleNotification() {
        state.requestNumber += 1
        let identifier = "apphooks.response.\(state.requestNumber).\(UUID().uuidString)"
        state.scheduledRequestID = identifier
        state.status = "scheduling"
        Task {
            do {
                let content = UNMutableNotificationContent()
                content.title = identifier
                content.body = identifier
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                try await UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                )
                await MainActor.run { state.status = "scheduled" }
            } catch {
                await MainActor.run { state.status = "error: \(error.localizedDescription)" }
            }
        }
    }

    private func replayResponse(at index: Int) {
        guard state.capturedResponses.indices.contains(index) else {
            state.status = "error: missing captured response R\(index + 1)"
            return
        }
        let center = UNUserNotificationCenter.current()
        guard let delegate = center.delegate else {
            state.status = "error: missing notification delegate"
            return
        }
        let callback: ((
            UNUserNotificationCenter,
            UNNotificationResponse,
            @escaping @Sendable () -> Void
        ) -> Void)? = delegate.userNotificationCenter(_:didReceive:withCompletionHandler:)
        guard let callback else {
            state.status = "error: missing response callback"
            return
        }
        let response = state.capturedResponses[index]
        let requestID = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier
        let before = state.consumerReceiptCount
        let completion: @Sendable () -> Void = { [acknowledgementFacts] in
            _ = acknowledgementFacts.record(
                requestID: requestID,
                actionIdentifier: actionIdentifier,
                isMainThread: Thread.isMainThread
            )
        }
        callback(center, response, completion)
        let snapshot = acknowledgementFacts.snapshot()
        state.acknowledgement.returnCount = snapshot.count
        state.acknowledgement.observedCount = snapshot.count
        state.acknowledgement.requestID = snapshot.requestID
        state.acknowledgement.actionIdentifier = snapshot.actionIdentifier
        state.acknowledgement.mainThread = snapshot.isMainThread ? "true" : "false"
        state.acknowledgement.actionsBeforeReturn = before
        state.acknowledgement.actionsAtReturn = state.consumerReceiptCount
        state.status = "replayed"
    }

    private func cleanupOwnedNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pendingIDs = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests {
                continuation.resume(returning: $0.map(\.identifier))
            }
        }
        let deliveredIDs = await withCheckedContinuation { continuation in
            center.getDeliveredNotifications {
                continuation.resume(returning: $0.map { $0.request.identifier })
            }
        }
        let prefix = "apphooks.response."
        center.removePendingNotificationRequests(
            withIdentifiers: pendingIDs.filter { $0.hasPrefix(prefix) }
        )
        center.removeDeliveredNotifications(
            withIdentifiers: deliveredIDs.filter { $0.hasPrefix(prefix) }
        )
    }
}
