import SwiftUI

/// The four top-level tabs of the app.
///
/// Each feature view provides its own `NavigationStack`, so tabs are not
/// double-wrapped here.
struct RootTabView: View {
    var body: some View {
        TabView {
            HomeTabView()
                .tabItem { Label("홈", systemImage: "house") }

            DiscoverTabView()
                .tabItem { Label("둘러보기", systemImage: "sparkles") }

            BooksTabView()
                .tabItem { Label("서재", systemImage: "books.vertical") }

            MyTabView()
                .tabItem { Label("마이", systemImage: "person.crop.circle") }
        }
        .tint(QuotesColor.accent)
    }
}

#Preview {
    RootTabView()
        .environment(AppEnvironment.placeholder())
}
