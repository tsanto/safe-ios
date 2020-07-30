//
//  SnackbarCenter.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 01.07.20.
//  Copyright © 2020 Gnosis Ltd. All rights reserved.
//

import SwiftUI
import Combine

class SnackbarCenter: ObservableObject {

    @Published
    var isPresented: Bool = false

    @Published
    var bottomEdgeSpacing: CGFloat = ScreenMetrics.aboveBottomEdge

    @Published
    private(set) var snackbarMessge: String?

    private var presentedMessage: Message?
    private var messageQueue: [Message] = []
    private var working = false
    private var pipeline = PassthroughSubject<Void, Never>()
    private var subscribers = Set<AnyCancellable>()
    private let displayDuration: TimeInterval = 4
    private var bottomPaddingStack: [CGFloat] = []

    private struct Message: Hashable, CustomStringConvertible {
        var id = UUID()
        var content: String
        var duration: TimeInterval

        var description: String {
            id.uuidString + " " + content
        }
    }

    init() {
        recreatePipeline()
    }

    func setBottomPadding(_ value: CGFloat = ScreenMetrics.aboveBottomEdge) {
        bottomPaddingStack.append(value)
        updateBottomEdgeSpacing()
    }

    func resetBottomPadding() {
        bottomPaddingStack.removeLast()
        updateBottomEdgeSpacing()
    }

    private func updateBottomEdgeSpacing() {
        withAnimation {
            bottomEdgeSpacing = bottomPaddingStack.last ?? ScreenMetrics.aboveBottomEdge
        }
    }

    func show(message: String, duration: TimeInterval? = nil) {
        messageQueue.append(Message(content: message, duration: duration ?? displayDuration))
        triggerMessagePresentation()
    }

    func hide() {
        if let message = presentedMessage {
            hide(message)
            recreatePipeline()
            triggerMessagePresentation()
        }
    }

    private func triggerMessagePresentation() {
        pipeline.send()
    }

    private func recreatePipeline() {
        // cancels all existing subscribers (on deinit)
        subscribers = []
        working = false

        // Pipeline overview:
        // dequeues the topmost message
        // presents it
        // hides it after delay (if message is still presented)
        // restarts this cycle if more messages pending

        pipeline
            // prevent starting pipeline if it is already displaying message
            .filter { !self.working }

            // dequeue
            .compactMap { _ -> Message? in
                if self.messageQueue.isEmpty {
                    return nil
                }
                self.working = true
                return self.messageQueue.removeFirst()
            }

            // in case of multiple messages, this gives time for the
            // hiding animation of the previous message to complete
            .delay(for: .seconds(0.1), scheduler: RunLoop.main)

            .map { message -> Message in
                self.present(message)
                return message
            }
            .flatMap { message in
                Just(message)
                    .delay(for: .seconds(message.duration), scheduler: RunLoop.main)
            }

            // check because user could hide the current message via `hide()`
            .filter { $0 == self.presentedMessage }

            .map { message -> Message in
                self.hide(message)
                return message
            }

            // restart the cycle if needed
            .sink { message in
                self.working = false
                if !self.messageQueue.isEmpty {
                    self.pipeline.send()
                }
            }
            .store(in: &subscribers)
    }

    private func present(_ message: Message) {
        presentedMessage = message
        snackbarMessge = message.content
        isPresented = true
    }

    private func hide(_ message: Message) {
        guard presentedMessage == message else { return }
        snackbarMessge = nil
        isPresented = false
        presentedMessage = nil
    }

}
