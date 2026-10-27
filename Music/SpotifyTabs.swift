import SwiftUI

/// One slot in the Spotify look's tab bar.
struct SpotifyTab: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var symbol: String
    /// For your own tabs: which page it opens (a key of `SpotifyTabStore.targets`).
    var target: String?
    var visible = true

    var isBuiltIn: Bool { ["home", "search", "library", "create"].contains(id) }
    var appTab: AppTab {
        switch id {
        case "home": .home
        case "search": .search
        case "library": .library
        default: .custom(id)
        }
    }
}

/// Which tabs the Spotify look shows, in which order, and the ones you build yourself.
@MainActor @Observable
final class SpotifyTabStore {
    static let shared = SpotifyTabStore()

    static let targets: [(key: String, title: String, symbol: String, route: Route)] = [
        ("songs", "Songs", "music.note", .songs), ("albums", "Albums", "square.stack", .albums),
        ("artists", "Artists", "music.mic", .artists), ("playlists", "Playlists", "music.note.list", .playlists),
        ("liked", "Liked Songs", "heart.fill", .favorites), ("downloads", "Downloads", "arrow.down.circle", .downloads),
        ("radio", "Radio", "dot.radiowaves.left.and.right", .radio), ("recent", "Recently Played", "clock", .recentlyPlayed),
        ("studio", "Studio", "waveform", .studio), ("files", "Files", "folder", .files)
    ]
    static let symbols = ["music.note", "heart.fill", "star.fill", "flame.fill", "headphones", "guitars.fill", "mic.fill", "radio",
                          "folder.fill", "waveform", "bolt.fill", "moon.fill", "sparkles", "leaf.fill", "bookmark.fill", "tray.full.fill"]

    static let defaults: [SpotifyTab] = [
        SpotifyTab(id: "home", title: "Home", symbol: "house"), SpotifyTab(id: "search", title: "Search", symbol: "magnifyingglass"),
        SpotifyTab(id: "library", title: "Your Library", symbol: "books.vertical"), SpotifyTab(id: "create", title: "Create", symbol: "plus")
    ]

    var tabs: [SpotifyTab] { didSet { save() } }
    private let key = "spotifyTabs.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key), let v = try? JSONDecoder().decode([SpotifyTab].self, from: data), !v.isEmpty { tabs = v }
        else { tabs = Self.defaults }
    }

    private func save() { if let d = try? JSONEncoder().encode(tabs) { UserDefaults.standard.set(d, forKey: key) } }

    /// What the bar shows: the visible ones, at most five, and always at least Home.
    var shown: [SpotifyTab] {
        let v = Array(tabs.filter(\.visible).prefix(5))
        return v.isEmpty ? [Self.defaults[0]] : v
    }

    func route(for tab: SpotifyTab) -> Route? { Self.targets.first { $0.key == tab.target }?.route }

    func reset() { tabs = Self.defaults }
}

/// A page for one of your own tabs.
struct SpotifyRoutePage: View {
    @Environment(Router.self) private var router
    var tab: SpotifyTab

    var body: some View {
        NavigationStack(path: Binding(get: { router.paths[tab.id] ?? [] }, set: { router.paths[tab.id] = $0 })) {
            Group {
                if let route = SpotifyTabStore.shared.route(for: tab) { RouteView(route: route) }
                else { Text("Pick a page for this tab in Customize.").foregroundStyle(Color.white.opacity(0.65)) }
            }
            .navigationDestination(for: Route.self) { RouteView(route: $0) }
        }
        .background(SpotifyShell.ground)
    }
}

/// Customize ▸ Spotify tabs: turn tabs on or off, drag them into the order you want, and add your own.
struct SpotifyTabsEditor: View {
    @State private var store = SpotifyTabStore.shared
    @State private var renaming: SpotifyTab?
    @State private var draft = ""

    private var visibleCount: Int { store.tabs.filter(\.visible).count }

    var body: some View {
        List {
            Section {
                ForEach($store.tabs) { $tab in
                    HStack(spacing: 12) {
                        Image(systemName: tab.symbol).frame(width: 26).foregroundStyle(SpotifyShell.green)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tab.title)
                            if !tab.isBuiltIn, let t = SpotifyTabStore.targets.first(where: { $0.key == tab.target }) {
                                Text(t.title).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Toggle("", isOn: $tab.visible).labelsHidden()
                    }
                    .contextMenu {
                        if !tab.isBuiltIn {
                            Button("Rename") { draft = tab.title; renaming = tab }
                            Menu("Icon") {
                                ForEach(SpotifyTabStore.symbols, id: \.self) { s in Button { tab.symbol = s } label: { Label(s, systemImage: s) } }
                            }
                        }
                    }
                }
                .onMove { store.tabs.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { offsets in
                    let keep = offsets.filter { !store.tabs[$0].isBuiltIn }
                    store.tabs.remove(atOffsets: IndexSet(keep))
                }
            } header: { Text("Tab bar") } footer: {
                Text("Drag to reorder. The bar shows up to five tabs\(visibleCount > 5 ? " (the first five are used right now)" : ""). Press and hold one of your own tabs to rename it or change its icon.")
            }
            Section("Add your own tab") {
                ForEach(SpotifyTabStore.targets, id: \.key) { t in
                    Button {
                        store.tabs.append(SpotifyTab(id: "custom.\(UUID().uuidString.prefix(6))", title: t.title, symbol: t.symbol, target: t.key))
                    } label: { Label("\(t.title)", systemImage: t.symbol) }
                }
            }
            Section {
                Button("Reset tabs", role: .destructive) { store.reset() }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Tabs")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename tab", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $draft)
            Button("Save") { if let r = renaming, let i = store.tabs.firstIndex(where: { $0.id == r.id }) { store.tabs[i].title = draft }
                renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }
}
