import SwiftUI

// MARK: - HomeRoute
//
// Value-based routes pushed from the 홈 tab root. A SINGLE enum wraps every
// destination (reader + collection detail) so the stack registers exactly one
// value type — the single-source discipline that avoids the double-push/overlap
// bug class documented in `MyTabView` / `BookmarkManagementView`. Reuses the
// shared `BookDestination` type for reader deep links.
enum HomeRoute: Hashable {
    case reader(BookDestination)
    case collection(BookCollection)
}

// MARK: - HomeTabView
//
// The 홈 tab: a heterogeneous editorial feed built from ONE shared `HomeModel`
// loader (A3) — 이어 읽기 hero, 오늘의 문장, 컬렉션 carousel, 내 하이라이트 carousel.
// The hero is re-resolved on every `.onAppear` because the position store is not
// observable and `TabView` keeps 홈 alive (A2).

public struct HomeTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: HomeModel?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                QuotesColor.surfacePrimary.ignoresSafeArea()
                content
            }
            .navigationTitle("홈")
            // Single value type registered at the stack ROOT (never on a pushed
            // child) — the routing discipline that prevents screen overlap.
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .reader(let dest):
                    ReaderScreen(book: dest.book, initialSentenceId: dest.sentenceId)
                case .collection(let collection):
                    CollectionDetailView(collection: collection)
                }
            }
            .task {
                guard model == nil else { return }
                let created = HomeModel(
                    contentRepository: env.contentRepository,
                    positionStore: env.positionStore
                )
                model = created
                await created.load()
            }
            // A2: re-read positions every time 홈 appears so the hero never goes
            // stale after the user reads and returns to the tab.
            .onAppear { model?.refreshContinueReading() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let model, model.isLoaded {
            feed(model: model)
        } else if let model, model.loadError != nil {
            BrandedEmptyState(
                headline: "불러오기 실패",
                subtext: model.loadError?.localizedDescription ?? "잠시 후 다시 시도해 주세요",
                systemImage: "exclamationmark.triangle",
                action: { Task { await model.load() } },
                actionLabel: "재시도"
            )
        } else {
            VStack(spacing: QuotesSpacing.md) {
                ProgressView().tint(QuotesColor.accent)
                Text("불러오는 중…")
                    .font(.subheadline)
                    .foregroundStyle(QuotesColor.inkSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func feed(model: HomeModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QuotesSpacing.xl) {
                // 이어 읽기 hero leads for returning readers; hidden for new users
                // (오늘의 문장 becomes the lead instead — plan 2.2).
                if let target = model.continueReading {
                    ContinueReadingHero(target: target)
                        .padding(.horizontal, QuotesSpacing.md)
                }

                if let daily = model.dailyQuote {
                    DailyQuoteCard(pooled: daily)
                        .padding(.horizontal, QuotesSpacing.md)
                }

                if !model.collections.isEmpty {
                    CollectionCarousel(collections: model.collections)
                }

                let highlights = env.bookmarks.all.filter { $0.kind == .highlight }
                if !highlights.isEmpty {
                    HighlightCarousel(highlights: highlights, model: model)
                }
            }
            .padding(.vertical, QuotesSpacing.lg)
        }
    }
}
