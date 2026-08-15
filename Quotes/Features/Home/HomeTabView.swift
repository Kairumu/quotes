import SwiftUI

public struct HomeTabView: View {
    public init() {}

    @State private var appeared = false

    public var body: some View {
        NavigationStack {
            ZStack {
                QuotesColor.surfacePrimary.ignoresSafeArea()

                VStack(spacing: QuotesSpacing.xl) {
                    // Brand glyph composition
                    ZStack {
                        Circle()
                            .fill(QuotesColor.accentSubtle)
                            .frame(width: 96, height: 96)
                        Image(systemName: "book.closed")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(QuotesColor.accent)
                    }
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.1), value: appeared)

                    VStack(spacing: QuotesSpacing.sm) {
                        Text("홈 화면")
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(QuotesColor.inkPrimary)

                        Text("곧 만나요 — 읽기 이력과 추천이\n이 곳에 채워집니다.")
                            .font(.subheadline)
                            .foregroundStyle(QuotesColor.inkSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .offset(y: appeared ? 0 : 16)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.22), value: appeared)

                    // Teaser preview card
                    VStack(alignment: .leading, spacing: QuotesSpacing.sm) {
                        HStack(spacing: QuotesSpacing.sm) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption)
                                .foregroundStyle(QuotesColor.accent)
                            Text("최근 읽은 책")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(QuotesColor.inkSecondary)
                        }
                        HStack(spacing: QuotesSpacing.sm) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(QuotesColor.accentTint)
                                .frame(width: 36, height: 48)
                                .overlay(
                                    Image(systemName: "text.book.closed")
                                        .font(.system(size: 14))
                                        .foregroundStyle(QuotesColor.accent.opacity(0.5))
                                )
                            VStack(alignment: .leading, spacing: 3) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(QuotesColor.cardStroke)
                                    .frame(width: 120, height: 12)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(QuotesColor.cardStroke)
                                    .frame(width: 80, height: 10)
                            }
                        }
                        .redacted(reason: .placeholder)
                    }
                    .padding(QuotesSpacing.md)
                    .quotesCard()
                    .frame(maxWidth: 280)
                    .opacity(0.55)
                    .offset(y: appeared ? 0 : 24)
                    .opacity(appeared ? 0.55 : 0)
                    .animation(.easeOut(duration: 0.45).delay(0.34), value: appeared)
                }
                .padding(QuotesSpacing.xl)
            }
            .navigationTitle("홈")
            .onAppear { appeared = true }
        }
    }
}
