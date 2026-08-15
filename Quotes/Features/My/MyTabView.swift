import SwiftUI

/// Value-based routes pushed from the 마이 tab root.
enum MyRoute: Hashable {
    case bookmarkManagement
}

/// The "마이" tab: user profile, reading settings, bookmark shortcut, and app info.
public struct MyTabView: View {
    @Environment(AppEnvironment.self) private var env
    @AppStorage("userDisplayName") private var displayName: String = ""

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    public init() {}

    public var body: some View {
        @Bindable var env = env
        NavigationStack {
            ZStack {
                QuotesColor.surfacePrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: 프로필 헤더
                        profileHeader

                        // MARK: 섹션들
                        VStack(spacing: QuotesSpacing.md) {
                            readingSettingsSection(env: $env)
                            bookmarkSection
                            infoSection
                        }
                        .padding(.horizontal, QuotesSpacing.md)
                        .padding(.bottom, QuotesSpacing.xl)
                    }
                }
            }
            .navigationTitle("마이")
            .navigationBarTitleDisplayMode(.large)
            // Navigation destinations MUST live at the stack root: registering
            // them on a pushed child (BookmarkManagementView) breaks the push
            // transition when that child re-renders — the old screen stays in
            // the render tree, visually overlapping the new one.
            //
            // All pushes in this stack are VALUE-based. Mixing a label-based
            // NavigationLink (마이 → 북마크 관리) with value-based pushes deeper in
            // the stack made the label link re-fire during the reader push,
            // stacking a second bookmark screen on top of the reader.
            .navigationDestination(for: MyRoute.self) { route in
                switch route {
                case .bookmarkManagement: BookmarkManagementView()
                }
            }
            .navigationDestination(for: Bookmark.self) { bookmark in
                CaptureDetailView(bookmark: bookmark)
            }
            .navigationDestination(for: BookDestination.self) { dest in
                ReaderScreen(book: dest.book, initialSentenceId: dest.sentenceId)
            }
            .navigationDestination(for: BookCollection.self) { collection in
                CollectionDetailView(collection: collection)
            }
        }
    }

    // MARK: Profile Header

    private var profileHeader: some View {
        VStack(spacing: QuotesSpacing.md) {
            ZStack {
                Circle()
                    .fill(QuotesColor.accentTint)
                    .frame(width: 76, height: 76)
                Circle()
                    .strokeBorder(QuotesColor.accent.opacity(0.4), lineWidth: 2)
                    .frame(width: 76, height: 76)
                Image(systemName: "person.fill")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(QuotesColor.accent)
            }

            VStack(spacing: QuotesSpacing.xs) {
                if displayName.isEmpty {
                    Text("이름을 입력하세요")
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(QuotesColor.inkSecondary)
                } else {
                    Text(displayName)
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(QuotesColor.inkPrimary)
                }

                if env.bookmarks.count > 0 {
                    Text("북마크 \(env.bookmarks.count)개")
                        .font(.caption)
                        .foregroundStyle(QuotesColor.inkSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, QuotesSpacing.xl)
        .padding(.horizontal, QuotesSpacing.md)
    }

    // MARK: Reading Settings Section

    private func readingSettingsSection(env: Bindable<AppEnvironment>) -> some View {
        QuotesSectionCard(title: "읽기 설정") {
            VStack(spacing: 0) {
                QuotesSettingsRow(icon: "text.bubble", label: "이름") {
                    TextField("이름", text: $displayName)
                        .textContentType(.name)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(QuotesColor.inkSecondary)
                }
                Divider().padding(.leading, 52)
                QuotesSettingsRow(icon: "character.bubble", label: "번역 표시") {
                    Toggle("", isOn: env.showTranslation)
                        .labelsHidden()
                        .tint(QuotesColor.accent)
                }
                Divider().padding(.leading, 52)
                QuotesSettingsRow(icon: "globe", label: "번역 언어") {
                    Text("한국어")
                        .foregroundStyle(QuotesColor.inkSecondary)
                }
            }
        }
    }

    // MARK: Bookmark Section

    private var bookmarkSection: some View {
        QuotesSectionCard(title: "북마크") {
            NavigationLink(value: MyRoute.bookmarkManagement) {
                QuotesSettingsRow(icon: "bookmark.fill", label: "북마크 관리") {
                    HStack(spacing: QuotesSpacing.sm) {
                        if env.bookmarks.count > 0 {
                            Text("\(env.bookmarks.count)")
                                .font(.subheadline)
                                .foregroundStyle(QuotesColor.inkSecondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(QuotesColor.inkSecondary.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Info Section

    private var infoSection: some View {
        QuotesSectionCard(title: "정보") {
            QuotesSettingsRow(icon: "info.circle", label: "버전") {
                Text(appVersion)
                    .foregroundStyle(QuotesColor.inkSecondary)
            }
        }
    }
}

// MARK: - QuotesSectionCard

private struct QuotesSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: QuotesSpacing.sm) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(QuotesColor.inkSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, QuotesSpacing.xs)

            VStack(spacing: 0) {
                content
            }
            .quotesCard()
        }
    }
}

// MARK: - QuotesSettingsRow

private struct QuotesSettingsRow<Trailing: View>: View {
    let icon: String
    let label: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: QuotesSpacing.md) {
            AccentIconBox(systemName: icon, size: 30)

            Text(label)
                .font(.body)
                .foregroundStyle(QuotesColor.inkPrimary)

            Spacer()

            trailing
        }
        .padding(.horizontal, QuotesSpacing.md)
        .padding(.vertical, QuotesSpacing.sm + 2)
        .contentShape(Rectangle())
    }
}

#Preview {
    MyTabView()
        .environment(AppEnvironment.placeholder())
}
