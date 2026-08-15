import SwiftUI

public struct DiscoverTabView: View {
    public init() {}

    @State private var appeared = false

    public var body: some View {
        NavigationStack {
            ZStack {
                QuotesColor.surfacePrimary.ignoresSafeArea()

                VStack(spacing: QuotesSpacing.xl) {
                    // Brand glyph: sparkles over magnifying glass
                    ZStack {
                        Circle()
                            .fill(QuotesColor.accentSubtle)
                            .frame(width: 96, height: 96)
                        Image(systemName: "sparkles.magnifyingglass")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(QuotesColor.accent)
                    }
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.1), value: appeared)

                    VStack(spacing: QuotesSpacing.sm) {
                        Text("둘러보기")
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(QuotesColor.inkPrimary)

                        Text("편집자 추천과 새로운 작품을\n곧 소개해 드립니다.")
                            .font(.subheadline)
                            .foregroundStyle(QuotesColor.inkSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .offset(y: appeared ? 0 : 16)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.22), value: appeared)

                    // Teaser: small preview cards in a mini grid
                    HStack(spacing: QuotesSpacing.sm) {
                        ForEach(0..<3, id: \.self) { i in
                            VStack(spacing: QuotesSpacing.xs) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(QuotesColor.accentTint.opacity(0.6 - Double(i) * 0.15))
                                    .frame(width: 72, height: 96)
                                    .overlay(
                                        Image(systemName: "book.closed")
                                            .font(.system(size: 18))
                                            .foregroundStyle(QuotesColor.accent.opacity(0.4))
                                    )
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(QuotesColor.cardStroke)
                                    .frame(width: 56, height: 8)
                            }
                            .opacity(1 - Double(i) * 0.25)
                        }
                    }
                    .opacity(0.6)
                    .offset(y: appeared ? 0 : 24)
                    .opacity(appeared ? 0.6 : 0)
                    .animation(.easeOut(duration: 0.45).delay(0.34), value: appeared)
                }
                .padding(QuotesSpacing.xl)
            }
            .navigationTitle("둘러보기")
            .onAppear { appeared = true }
        }
    }
}
