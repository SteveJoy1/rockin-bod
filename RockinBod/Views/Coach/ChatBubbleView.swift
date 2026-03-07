import SwiftUI

struct ChatBubbleView: View {
    let message: CoachMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(isUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary.opacity(0.2)),
                        in: bubbleShape
                    )

                Text(message.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !isUser { Spacer(minLength: 48) }
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if isUser {
            // User: more rounding on the right side, sharp bottom-right corner
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 4,
                topTrailingRadius: 16
            )
        } else {
            // Coach: more rounding on the left side, sharp bottom-left corner
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: 16,
                topTrailingRadius: 16
            )
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ChatBubbleView(message: CoachMessage(
            role: .user,
            content: "How much protein should I eat per day?"
        ))

        ChatBubbleView(message: CoachMessage(
            role: .assistant,
            content: "Based on your current weight and goals, I recommend aiming for around 160g of protein daily. This supports muscle protein synthesis while staying in a moderate caloric range."
        ))
    }
    .padding()
}
