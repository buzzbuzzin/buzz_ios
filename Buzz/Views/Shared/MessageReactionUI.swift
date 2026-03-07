//
//  MessageReactionUI.swift
//  Buzz
//
//  Shared message reaction UI for chat surfaces.
//

import SwiftUI

enum MessageReactionOverlayLayout {
    static let coordinateSpaceName = "MessageReactionOverlaySpace"
    static let horizontalPadding: CGFloat = 16
    static let pickerHeight: CGFloat = 56
    static let pickerWidth: CGFloat = 320
}

struct MessageBubbleFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

extension View {
    func captureMessageBubbleFrame(messageId: UUID) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: MessageBubbleFramePreferenceKey.self,
                    value: [messageId: geometry.frame(in: .named(MessageReactionOverlayLayout.coordinateSpaceName))]
                )
            }
        )
    }
}

struct MessageReactionBadges: View {
    let reactions: [MessageReactionRecord]
    let currentUserId: UUID?

    private var aggregates: [MessageReactionAggregate] {
        reactions.aggregateSummaries(currentUserId: currentUserId)
    }

    var body: some View {
        if !aggregates.isEmpty {
            HStack(spacing: 6) {
                ForEach(aggregates) { aggregate in
                    HStack(spacing: 4) {
                        Text(aggregate.reaction.emoji)
                            .font(.caption)

                        if aggregate.count > 1 {
                            Text("\(aggregate.count)")
                                .font(.caption2.weight(.semibold))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        aggregate.includesCurrentUser ? Color.blue.opacity(0.16) : Color(.systemGray6),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                aggregate.includesCurrentUser ? Color.blue.opacity(0.35) : Color(.systemGray4),
                                lineWidth: 0.8
                            )
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(badgeAccessibilityLabel(for: aggregate))
                }
            }
        }
    }

    private func badgeAccessibilityLabel(for aggregate: MessageReactionAggregate) -> String {
        let count = aggregate.count
        let label = "\(aggregate.reaction.label), \(count) reaction\(count == 1 ? "" : "s")"
        return aggregate.includesCurrentUser ? "\(label), including yours" : label
    }
}

struct MessageReactionPickerOverlay: View {
    let currentReaction: MessageReactionType?
    let targetFrame: CGRect
    let containerSize: CGSize
    let onSelect: (MessageReactionType) -> Void
    let onClear: (() -> Void)?
    let onDismiss: () -> Void

    private var pickerWidth: CGFloat {
        min(
            MessageReactionOverlayLayout.pickerWidth,
            max(236, containerSize.width - (MessageReactionOverlayLayout.horizontalPadding * 2))
        )
    }

    private var pickerX: CGFloat {
        let halfWidth = pickerWidth / 2
        return min(
            max(targetFrame.midX, halfWidth + MessageReactionOverlayLayout.horizontalPadding),
            containerSize.width - halfWidth - MessageReactionOverlayLayout.horizontalPadding
        )
    }

    private var pickerY: CGFloat {
        let halfHeight = MessageReactionOverlayLayout.pickerHeight / 2
        let above = targetFrame.minY - halfHeight - 12
        if above > MessageReactionOverlayLayout.horizontalPadding {
            return above
        }

        return min(
            targetFrame.maxY + halfHeight + 12,
            containerSize.height - halfHeight - MessageReactionOverlayLayout.horizontalPadding
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            picker
                .frame(width: pickerWidth)
                .position(x: pickerX, y: pickerY)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }

    private var picker: some View {
        HStack(spacing: 10) {
            ForEach(MessageReactionType.allCases) { reaction in
                Button {
                    onSelect(reaction)
                } label: {
                    Text(reaction.emoji)
                        .font(.system(size: 28))
                        .frame(width: 38, height: 38)
                        .background(
                            currentReaction == reaction ? Color.blue.opacity(0.14) : Color.clear,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(reaction.label)
            }

            if let onClear {
                Divider()
                    .frame(height: 28)

                Button("Clear") {
                    onClear()
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.red)
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}
