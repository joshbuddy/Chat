//
//  MessageView.swift
//  Chat
//
//  Created by Alex.M on 23.05.2022.
//

import SwiftUI

struct MessageView: View {

    @Environment(\.chatTheme) private var theme

    @ObservedObject var viewModel: ChatViewModel

    let message: Message
    let positionInGroup: PositionInGroup
    let avatarSize: CGFloat
    let messageUseMarkdown: Bool
    let isDisplayingMessageMenu: Bool

    @State var avatarViewSize: CGSize = .zero
    @State var statusSize: CGSize = .zero
    @State var timeSize: CGSize = .zero

    static let widthWithMedia: CGFloat = 204
    static let horizontalAvatarPadding: CGFloat = 8
    static let horizontalTextPadding: CGFloat = 12
    static let statusViewSize: CGFloat = 14
    static let horizontalStatusPadding: CGFloat = 8
    static let horizontalBubblePadding: CGFloat = 20

    let fontSize: CGFloat = 15

    enum DateArrangment {
        case hstack, vstack, overlay
    }

    var dateArrangment: DateArrangment {
        let timeWidth = timeSize.width + 10
        let textPaddings = MessageView.horizontalTextPadding * 2
        let widthWithoutMedia = UIScreen.main.bounds.width
        - avatarViewSize.width
        - statusSize.width
        - MessageView.horizontalBubblePadding
        - textPaddings
        let maxWidth = message.attachments.isEmpty ? widthWithoutMedia : MessageView.widthWithMedia - textPaddings
        let finalWidth = message.text.width(withConstrainedWidth: maxWidth, font: UIFont.systemFont(ofSize: fontSize), messageUseMarkdown: messageUseMarkdown)
        let lastLineWidth = message.text.lastLineWidth(labelWidth: maxWidth, font: UIFont.systemFont(ofSize: fontSize), messageUseMarkdown: messageUseMarkdown)

        if lastLineWidth + CGFloat(timeWidth) < finalWidth {
            return .overlay
        }
        if finalWidth + CGFloat(timeWidth) < maxWidth {
            return .hstack
        }
        return .vstack
    }

    var showAvatar: Bool {
        positionInGroup == .single || positionInGroup == .last
    }

    var topPadding: CGFloat {
        positionInGroup == .first || positionInGroup == .single ? 8 : 4
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if !message.user.isCurrentUser {
                avatarView
            } else {
                Spacer(minLength: 0)
            }

            VStack(alignment: message.user.isCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isDisplayingMessageMenu, let reply = message.replyMessage?.toMessage() {
                    HStack(spacing: 8) {
                        Capsule()
                            .foregroundColor(theme.colors.buttonBackground)
                            .frame(width: 2)
                        replyBubbleView(reply)
                    }
                }
                bubbleView(message)
            }
            .padding(message.user.isCurrentUser ? .leading : .trailing, MessageView.horizontalBubblePadding)

            if message.user.isCurrentUser, let status = message.status {
                MessageStatusView(status: status) {
                    viewModel.sendMessage(message.toDraft())
                }
                .sizeGetter($statusSize)
            }

            if !message.user.isCurrentUser {
                Spacer(minLength: 0)
            }
        }
        .padding(.top, topPadding)
    }

    @ViewBuilder
    func bubbleView(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !message.attachments.isEmpty {
                attachmentsView(message)
            }

            if !message.text.isEmpty {
                textWithTimeView(message)
                    .font(.system(size: fontSize))
            }

            if let recording = message.recording {
                VStack(alignment: .trailing, spacing: 0) {
                    recordingView(recording)
                    messageTimeView()
                }
            }
        }
        .bubbleBackground(message, theme: theme)
    }

    @ViewBuilder
    func replyBubbleView(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(message.user.name)
                .fontWeight(.semibold)
                .padding(.horizontal, MessageView.horizontalTextPadding)

            if !message.attachments.isEmpty {
                attachmentsView(message)
                    .padding(.top, 4)
                    .padding(.bottom, message.text.isEmpty ? 0 : 4)
            }

            if !message.text.isEmpty {
                MessageTextView(text: message.text, messageUseMarkdown: messageUseMarkdown)
                    .padding(.horizontal, MessageView.horizontalTextPadding)
            }

            if let recording = message.recording {
                recordingView(recording)
            }
        }
        .font(.caption2)
        .padding(.vertical, 8)
        .frame(width: message.attachments.isEmpty ? nil : MessageView.widthWithMedia)
        .bubbleBackground(message, theme: theme, isReply: true)
    }

    @ViewBuilder
    var avatarView: some View {
        Group {
            if showAvatar {
                AvatarView(url: message.user.avatarURL, avatarSize: avatarSize)
            } else {
                Color.clear.viewSize(avatarSize)
            }
        }
        .padding(.horizontal, MessageView.horizontalAvatarPadding)
        .sizeGetter($avatarViewSize)
    }

    @ViewBuilder
    func attachmentsView(_ message: Message) -> some View {
        AttachmentsGrid(attachments: message.attachments) {
            viewModel.presentAttachmentFullScreen($0)
        }
        .overlay(alignment: .bottomTrailing) {
            if message.text.isEmpty {
                messageTimeView(isOverlay: true)
                    .padding(4)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    func textWithTimeView(_ message: Message) -> some View {
        let messageView = MessageTextView(text: message.text, messageUseMarkdown: messageUseMarkdown)
            .padding(.horizontal, MessageView.horizontalTextPadding)
            .padding(.vertical, 8)

        Group {
            switch dateArrangment {
            case .vstack:
                VStack(alignment: .trailing, spacing: 4) {
                    messageView
                        .alignLeft(message)
                    messageTimeView()
                        .alignRight(message)
                }
            case .hstack:
                HStack(alignment: .bottom, spacing: 8) {
                    messageView
                    if !message.attachments.isEmpty {
                        Spacer()
                    }
                    messageTimeView()
                }
            case .overlay:
                messageView
                    .alignLeft(message)
                    .padding(.bottom, 8)
                    .overlay(alignment: .bottomTrailing) {
                        messageTimeView()
                            .alignRight(message)
                    }
            }
        }
    }

    @ViewBuilder
    func recordingView(_ recording: Recording) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            RecordWaveformWithButtons(
                recording: recording,
                colorButton: message.user.isCurrentUser ? theme.colors.myMessage : .white,
                colorButtonBg: message.user.isCurrentUser ? .white : theme.colors.myMessage,
                colorWaveform: message.user.isCurrentUser ? theme.colors.textDarkContext : theme.colors.textLightContext
            )
            .padding(.horizontal, MessageView.horizontalTextPadding)
            .padding(.top, 8)
        }
    }

    func messageTimeView(isOverlay: Bool = false) -> some View {
        MessageTimeView(
            text: message.time,
            isCurrentUser: message.user.isCurrentUser,
            isOverlay: isOverlay
        )
        .sizeGetter($timeSize)
    }
}

extension View {
    func bubbleBackground(_ message: Message, theme: ChatTheme, isReply: Bool = false) -> some View {
        self
            .frame(width: message.attachments.isEmpty ? nil : MessageView.widthWithMedia)
            .foregroundColor(message.user.isCurrentUser ? theme.colors.textDarkContext : theme.colors.textLightContext)
            .background {
                if isReply || !message.text.isEmpty || message.recording != nil {
                    RoundedRectangle(cornerRadius: 20)
                        .foregroundColor(message.user.isCurrentUser ? theme.colors.myMessage : theme.colors.friendMessage)
                        .opacity(isReply ? 0.5 : 1)
                }
            }
    }

    func alignLeft(_ message: Message) -> some View {
        HStack {
            self
            if !message.attachments.isEmpty {
                Spacer()
            }
        }
    }

    func alignRight(_ message: Message) -> some View {
        HStack {
            if !message.attachments.isEmpty {
                Spacer()
            }
            self
        }
    }
}

struct MessageView_Preview: PreviewProvider {
    static private var shortMessage = "Hi, buddy!"
    static private var longMessage = "Hello hello hello hello hello hello hello hello hello hello hello hello hello\n hello hello hello hello d d d d d d d d"

    static private var message = Message(
        id: UUID().uuidString,
        user: User(id: UUID().uuidString, name: "Stan", avatarURL: nil, isCurrentUser: false),
        status: .read,
        text: longMessage,
        attachments: [
            ImageAttachment.random(),
            ImageAttachment.random(),
            ImageAttachment.random(),
            ImageAttachment.random(),
            ImageAttachment.random(),
        ]
    )

    static var previews: some View {
        MessageView(
            viewModel: ChatViewModel(),
            message: message,
            positionInGroup: .single,
            avatarSize: 32,
            messageUseMarkdown: false,
            isDisplayingMessageMenu: false
        )
    }
}
