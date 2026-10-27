import SwiftUI

/// The whole app, dressed like Spotify: four plain tabs under a mini player. Used only while the player look is Spotify.
struct SpotifyShell: View {
    @Environment(Router.self) private var router
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerModel.self) private var player
    var playerNS: Namespace.ID
    @State private var createOpen = false
    @State private var blendOpen = false

    static let green = Color(hex: "#1ED760")
    static let ground = Color(hex: "#121212")

    private var store: SpotifyTabStore { SpotifyTabStore.shared }

    /// The tab on screen: the one asked for if it is in the bar, otherwise the first one.
    private var selected: AppTab {
        let want: AppTab
        switch router.tab {
        case .home, .search, .custom: want = router.tab
        default: want = .library
        }
        let bar = store.shown.filter { $0.id != "create" }.map(\.appTab)
        return bar.contains(want) ? want : (bar.first ?? .home)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    ZStack {
                        ForEach(store.shown.filter { $0.id != "create" }) { tab in
                            page(tab.appTab) {
                                switch tab.id {
                                case "home": HomePage()
                                case "search": SpotifySearchPage()
                                case "library": SpotifyLibraryPage(createOpen: $createOpen)
                                default: SpotifyRoutePage(tab: tab)
                                }
                            }
                        }
                    }
                    if player.current != nil {
                        SpotifyMiniPlayer().matchedTransitionSource(id: "miniPlayer", in: playerNS)
                            .padding(.horizontal, 8).padding(.bottom, 6)
                    }
                }
                if createOpen {
                    Color.black.opacity(0.72).ignoresSafeArea().onTapGesture { withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { createOpen = false } }
                        .transition(.opacity)
                    createCard.padding(.horizontal, 8).padding(.bottom, 8)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .scale(scale: 0.92, anchor: .bottom)).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)))
                }
            }
            tabBar
        }
        .background(Self.ground.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $blendOpen) { BlendSheet() }
    }

    /// Every tab stays alive (so scroll positions survive); only the chosen one is seen.
    private func page<C: View>(_ tab: AppTab, @ViewBuilder _ content: () -> C) -> some View {
        content()
            .opacity(selected == tab ? 1 : 0)
            .allowsHitTesting(selected == tab)
            .accessibilityHidden(selected != tab)
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(store.shown) { tab in
                switch tab.id {
                case "home": tabItem(tab.title, tab: .home) { on in tabImage(on ? "SPTabHomeOn" : "SPTabHomeOff") }
                case "search": tabItem(tab.title, tab: .search) { on in tabImage(on ? "SPTabSearchOn" : "SPTabSearch") }
                case "library": tabItem(tab.title, tab: .library) { on in tabImage(on ? "SPTabLibraryOn" : "SPTabLibraryOff") }
                case "create": createTab(tab.title)
                default: tabItem(tab.title, tab: tab.appTab) { _ in Image(systemName: tab.symbol).font(.system(size: 21)) }
                }
            }
        }
        .padding(.horizontal, 6)
        .background(Self.ground.opacity(0.98).ignoresSafeArea(edges: .bottom))
    }

    private func createTab(_ title: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { createOpen.toggle() }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 34, height: 34)
                        .scaleEffect(createOpen ? 1 : 0.3).opacity(createOpen ? 1 : 0)
                    tabImage("SPTabCreate")
                        .foregroundStyle(createOpen ? Color.black : Color.white.opacity(0.62))
                        .rotationEffect(.degrees(createOpen ? 45 : 0))
                        .scaleEffect(createOpen ? 0.62 : 1)
                }
                .frame(height: 34)
                Text(title).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .opacity(createOpen ? 0 : 1)
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The icons are the reference's own pixels (Assets › SPTab…), tinted by the tab's state.
    private func tabImage(_ name: String) -> some View {
        Image(name).renderingMode(.template).resizable().aspectRatio(contentMode: .fit).frame(width: 26, height: 26)
    }

    private func tabItem<I: View>(_ title: String, tab: AppTab, @ViewBuilder icon: (Bool) -> I) -> some View {
        let on = selected == tab && !createOpen
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { createOpen = false }
            if router.tab == tab, tab == .library { router.libraryPath = [] }
            else if router.tab == tab { router.paths[router.tabKey(tab)] = [] }
            router.tab = tab
        } label: {
            VStack(spacing: 3) {
                icon(on).frame(height: 28)
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(on ? Color.white : Color.white.opacity(createOpen ? 0.3 : 0.62))
            .frame(maxWidth: .infinity).frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Create card

    private var createCard: some View {
        VStack(spacing: 0) {
            createRow("music.note", "Playlist", "Create a playlist with your songs") { newPlaylist() }
            createRow("circle.lefthalf.filled", "Blend", "Combine your playlists into one") { createOpen = false; blendOpen = true }
        }
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: "#282828")))
    }

    private func createRow(_ symbol: String, _ title: String, _ subtitle: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(Color.white.opacity(0.9))
                    .frame(width: 44, height: 44).background(Circle().fill(Color.white.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .bold))
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.65))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func newPlaylist() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { createOpen = false }
        let p = library.createPlaylist(name: "My playlist #\(library.playlists.count + 1)")
        router.open(.playlist(p.id))
    }
}

// MARK: - Home

/// Home built from your own music: quick picks, then shelves of albums.
private struct HomePage: View {
    @Environment(Router.self) private var router
    @Environment(LibraryStore.self) private var library

    private var quick: [(String, LibraryEntry?, Route)] {
        var out: [(String, LibraryEntry?, Route)] = [("Liked Songs", nil, .favorites)]
        for e in library.playlistEntries.prefix(3) { out.append((e.title, e, e.route)) }
        for e in library.albumsByRecent.prefix(8 - out.count) { out.append((e.title, e, e.route)) }
        return Array(out.prefix(8))
    }

    /// Albums of the artists you play most.
    private var followed: [LibraryEntry] {
        let top = library.mostPlayed.map(\.artist)
        var seen = Set<String>(), order: [String] = []
        for a in top where seen.insert(a).inserted { order.append(a) }
        for e in library.artistEntries where seen.insert(e.title).inserted { order.append(e.title) }
        return order.flatMap { a in library.albumEntries.filter { $0.tracks.first?.artist == a } }
    }

    /// A different pick every day, the same all day.
    private var today: [LibraryEntry] {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        var gen = SeededGenerator(seed: UInt64(day))
        return library.albumEntries.shuffled(using: &gen)
    }

    private var moreLikeArtist: (String, [LibraryEntry])? {
        guard let artist = library.mostPlayed.first?.artist ?? library.artistEntries.first?.title else { return nil }
        let genre = library.tracks.first { $0.artist == artist }?.genre
        let like = library.albumEntries.filter { e in
            guard let t = e.tracks.first, t.artist != artist else { return false }
            return genre != nil && t.genre == genre
        }
        let list = like.isEmpty ? library.albumEntries.filter { $0.tracks.first?.artist != artist } : like
        return list.isEmpty ? nil : (artist, list)
    }

    var body: some View {
        NavigationStack(path: Binding(get: { router.paths["home"] ?? [] }, set: { router.paths["home"] = $0 })) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(Array(quick.enumerated()), id: \.offset) { _, q in
                            NavigationLink(value: q.2) {
                                HStack(spacing: 10) {
                                    Group {
                                        if let e = q.1 { ArtworkView(entry: e, radius: 0).thumbnail() }
                                        else { Rectangle().fill(LinearGradient(colors: [Color(hex: "#4F2BFF"), Color(hex: "#A6B4FF")], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay { Image(systemName: "heart.fill").foregroundStyle(Color.white) } }
                                    }
                                    .frame(width: 52, height: 52)
                                    Text(q.0).font(.system(size: 13, weight: .bold)).lineLimit(2).multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .frame(height: 52)
                                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.white.opacity(0.1)))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)

                    shelf("Albums by artists you follow", followed, style: .artist)
                    shelf("Recommended for today", today, style: .kind)
                    shelf("Recents", library.albumsByRecent, style: .artist)
                    if let more = moreLikeArtist { shelf("More like \(more.0)", more.1, style: .artist) }
                    shelf("Your playlists", library.playlistEntries, style: .count)
                    shelf("Your artists", library.artistEntries, style: .circle)
                    if library.tracks.isEmpty {
                        Text("Add music to fill your Home.").foregroundStyle(Color.white.opacity(0.65)).padding(.horizontal, 12)
                    }
                }
                .padding(.top, 6).padding(.bottom, 16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack { SpotifyAvatar(); Spacer() }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(SpotifyShell.ground)
            }
            .navigationDestination(for: Route.self) { RouteView(route: $0) }
        }
        .background(SpotifyShell.ground)
    }

    enum ShelfStyle { case artist, kind, count, circle }

    @ViewBuilder private func shelf(_ title: String, _ entries: [LibraryEntry], style: ShelfStyle) -> some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.system(size: 22, weight: .bold)).padding(.horizontal, 12)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(entries.prefix(24)) { e in
                            NavigationLink(value: e.route) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ArtworkView(entry: e, radius: style == .circle ? 0 : 3).thumbnail(360).frame(width: 145, height: 145)
                                    switch style {
                                    case .kind:
                                        Text(kind(e)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.white.opacity(0.62))
                                        Text(e.title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                                        Text(e.subtitle).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.white.opacity(0.62)).lineLimit(1)
                                    case .artist:
                                        Text(e.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                        Text(e.tracks.first?.artist ?? e.subtitle).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.white.opacity(0.62)).lineLimit(1)
                                    case .count:
                                        Text(e.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                        Text(songCount(e.tracks.count)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.white.opacity(0.62))
                                    case .circle:
                                        Text(e.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                        Text("Artist").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.white.opacity(0.62))
                                    }
                                }
                                .frame(width: 145, alignment: .leading)
                                .multilineTextAlignment(.leading)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }

    private func kind(_ e: LibraryEntry) -> String {
        switch e.tracks.count { case 1: "Single"; case 2...6: "EP"; default: "Album" }
    }
}

/// Same shuffle for the same seed, so "Recommended for today" holds still all day.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Blend: pick playlists and get one new playlist with songs from each, interleaved.
private struct BlendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var library
    @Environment(Router.self) private var router
    @State private var picked: Set<String> = []

    var body: some View {
        NavigationStack {
            List(library.playlistEntries) { e in
                Button {
                    if picked.contains(e.id) { picked.remove(e.id) } else { picked.insert(e.id) }
                } label: {
                    HStack {
                        ArtworkView(entry: e, radius: 4).thumbnail().frame(width: 44, height: 44)
                        Text(e.title)
                        Spacer()
                        if picked.contains(e.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(SpotifyShell.green) }
                    }
                }
                .buttonStyle(.plain)
            }
            .overlay { if library.playlistEntries.count < 2 { Text("Make at least two playlists to blend them.").foregroundStyle(.secondary).padding() } }
            .navigationTitle("Blend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }.disabled(picked.count < 2)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .environment(\.colorScheme, .dark)
    }

    private func create() {
        let lists = library.playlistEntries.filter { picked.contains($0.id) }.map { $0.tracks.shuffled() }
        var ids: [UUID] = []
        var seen = Set<UUID>()
        var i = 0
        while ids.count < lists.reduce(0, { $0 + $1.count }) {
            var added = false
            for l in lists where i < l.count { added = true; if seen.insert(l[i].id).inserted { ids.append(l[i].id) } }
            if !added { break }
            i += 1
        }
        let p = library.createPlaylist(name: "Blend", trackIDs: ids)
        dismiss()
        router.open(.playlist(p.id))
    }
}

// MARK: - Search

private struct SpotifySearchPage: View {
    @Environment(Router.self) private var router
    @Environment(LibraryStore.self) private var library
    @FocusState private var focused: Bool

    /// Name, tile colour. The first ten are the reference's.
    private static let cats: [(String, String)] = [
        ("Made For You", "#8D67AB"), ("Upcoming Releases", "#006450"), ("New Releases", "#E13300"), ("Pop", "#477D95"),
        ("Hip-Hop", "#477D95"), ("Rock", "#006450"), ("Latin", "#0D73EC"), ("Charts", "#8D67AB"),
        ("Educational", "#477D95"), ("Documentary", "#503750"), ("Comedy", "#8D67AB"), ("Dance/Electronic", "#477D95"),
        ("Mood", "#E8115B"), ("Indie", "#E91429"), ("Workout", "#777777"), ("Discover", "#8D67AB"),
        ("Radio", "#E8115B"), ("Fresh Finds", "#E8115B"), ("Country", "#D84000"), ("R&B", "#BA5D07"),
        ("K-pop", "#E91429"), ("Chill", "#AF2896"), ("Sleep", "#1E3264"), ("Party", "#8D67AB"),
        ("Decades", "#BA5D07"), ("Love", "#E8115B"), ("Metal", "#E91429"), ("Jazz", "#8D67AB"),
        ("Gaming", "#E8115B"), ("Folk & Acoustic", "#BA5D07"), ("Focus", "#BA5D07"), ("Soul", "#E8115B"),
        ("Classical", "#BA5D07"), ("Instrumental", "#477D95"), ("Ambient", "#148A08"), ("Blues", "#0D73EC"),
        ("Alternative", "#E13300"), ("Travel", "#0D73EC")
    ]

    private var query: String { router.searchText.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: Binding(get: { router.paths["search"] ?? [] }, set: { router.paths["search"] = $0 })) {
            VStack(spacing: 0) {
                field
                if query.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(Array(Self.cats.enumerated()), id: \.offset) { _, c in tile(c.0, c.1) }
                        }
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 16)
                    }
                    .scrollDismissesKeyboard(.immediately)
                } else {
                    SearchView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { RouteView(route: $0) }
        }
        .background(SpotifyShell.ground)
    }

    private var field: some View {
        @Bindable var router = router
        return HStack(spacing: 12) {
            Image("SPFieldSearch").renderingMode(.template).resizable().aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24).foregroundStyle(Color.black)
            TextField("", text: $router.searchText, prompt: Text("What do you want to listen to?").foregroundColor(Color.black))
                .font(.system(size: 18, weight: .bold)).foregroundStyle(Color.black).tint(Color.black)
                .focused($focused).submitLabel(.search).autocorrectionDisabled().textInputAutocapitalization(.never)
            if !router.searchText.isEmpty {
                Button { router.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(Color.black.opacity(0.5))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white))
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 4)
        .background(SpotifyShell.ground)
    }

    private func art(for name: String, _ i: Int) -> Track? {
        let key = name.lowercased()
        if let t = library.tracks.first(where: { ($0.genre ?? "").lowercased().contains(key) && $0.hasArtwork }) { return t }
        let withArt = library.tracks.filter(\.hasArtwork)
        return withArt.isEmpty ? nil : withArt[Int(stableHash(name) % UInt64(withArt.count))]
    }

    private func tile(_ name: String, _ hex: String) -> some View {
        let color = Color(hex: hex)
        let i = Self.cats.firstIndex { $0.0 == name } ?? 0
        return Button {
            switch name {
            case "Made For You", "Radio", "Discover": router.open(.radio)
            case "New Releases", "Upcoming Releases": router.open(.recentlyPlayed)
            default: router.searchText = name
            }
        } label: {
            ZStack(alignment: .topLeading) {
                color
                Text(name).font(.system(size: 20, weight: .bold)).foregroundStyle(Color.white).padding(14).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                if let t = art(for: name, i) {
                    ArtworkView(track: t, radius: 4).thumbnail()
                        .frame(width: 84, height: 84)
                        .rotationEffect(.degrees(25))
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        .offset(x: 112, y: 40)
                }
            }
            .frame(height: 106)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Your Library

private struct SpotifyLibraryPage: View {
    @Environment(Router.self) private var router
    @Environment(LibraryStore.self) private var library
    @Binding var createOpen: Bool
    @State private var kind = "Playlists"

    private var entries: [LibraryEntry] {
        switch kind { case "Artists": library.artistEntries; case "Albums": library.albumEntries; default: library.playlistEntries }
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.libraryPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        ForEach(["Playlists", "Artists", "Albums"], id: \.self) { c in
                            Button { withAnimation(.smooth(duration: 0.2)) { kind = kind == c ? "Playlists" : c } } label: {
                                Text(c).font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(kind == c ? Color.black : Color.white)
                                    .padding(.horizontal, 14).frame(height: 34)
                                    .background(Capsule().fill(kind == c ? SpotifyShell.green : Color.white.opacity(0.12)))
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12).padding(.top, 6)
                    HStack {
                        Image(systemName: "arrow.up.arrow.down").font(.system(size: 14, weight: .semibold))
                        Text("Recents").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: "square.grid.2x2").font(.system(size: 16))
                    }
                    .padding(.horizontal, 14).padding(.top, 18).padding(.bottom, 10)

                    NavigationLink(value: Route.downloads) {
                        row(AnyView(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(SpotifyShell.green)
                            .overlay { Image(systemName: "arrow.down").font(.system(size: 26, weight: .bold)).foregroundStyle(Color.black) }),
                            "Downloaded", pin: false, "Playlist • \(songCount(library.tracks.filter(\.isDownloaded).count))")
                    }.buttonStyle(.plain)
                    NavigationLink(value: Route.favorites) {
                        row(AnyView(SPLibraryHeart()), "Liked Songs", pin: true, "Playlist • \(songCount(library.tracks.filter(\.isFavorite).count))")
                    }.buttonStyle(.plain)
                    ForEach(entries) { entry in
                        NavigationLink(value: entry.route) {
                            row(AnyView(ArtworkView(entry: entry, radius: 4).thumbnail().frame(width: 64, height: 64)), entry.title, pin: false, "\(kind == "Artists" ? "Artist" : kind == "Albums" ? "Album" : "Playlist") • \(songCount(entry.tracks.count))")
                        }.buttonStyle(.plain)
                    }
                    NavigationLink(value: Route.artists) { addRow("Add artists", circle: true) }.buttonStyle(.plain)
                    Button { router.openAddMusic() } label: { addRow("Add podcasts", circle: false) }.buttonStyle(.plain)
                    NavigationLink { SpotifyEventsView() } label: { addRow("Add events & venues", circle: false) }.buttonStyle(.plain)
                    Button { router.showSongListImport = true } label: { addRow("Import your music", circle: false, symbol: "square.and.arrow.down") }.buttonStyle(.plain)
                }
                .padding(.bottom, 16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 12) {
                    SpotifyAvatar()
                    Text("Your Library").font(.system(size: 24, weight: .bold))
                    Spacer()
                    Image(systemName: "magnifyingglass").font(.system(size: 22))
                    Button { withAnimation(.smooth(duration: 0.28)) { createOpen.toggle() } } label: {
                        Image(systemName: "plus").font(.system(size: 24, weight: .light)).frame(width: 36, height: 36)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(SpotifyShell.ground)
            }
            .navigationDestination(for: Route.self) { RouteView(route: $0) }
        }
        .background(SpotifyShell.ground)
    }

    private func row(_ art: AnyView, _ title: String, pin: Bool, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            art.frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .bold)).lineLimit(1)
                HStack(spacing: 5) {
                    if pin { Image(systemName: "pin.fill").font(.system(size: 11)).foregroundStyle(SpotifyShell.green).rotationEffect(.degrees(45)) }
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.65)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func addRow(_ title: String, circle: Bool, symbol: String = "plus") -> some View {
        HStack(spacing: 14) {
            ZStack {
                if circle { Circle().fill(Color.white.opacity(0.1)) }
                else { RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.white.opacity(0.1)) }
                Image(systemName: symbol).font(.system(size: symbol == "plus" ? 26 : 20, weight: .light)).foregroundStyle(Color.white.opacity(0.7))
            }
            .frame(width: 64, height: 64)
            Text(title).font(.system(size: 16, weight: .bold))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private struct SPLibraryHeart: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: "#4F2BFF"), Color(hex: "#A6B4FF")], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { Image(systemName: "heart.fill").font(.system(size: 26)).foregroundStyle(Color.white) }
    }
}

/// Spotify's profile bubble.
struct SpotifyAvatar: View {
    @Environment(Router.self) private var router
    var body: some View {
        Button { router.showSettings = true } label: {
            Image(systemName: "gearshape.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.black)
                .frame(width: 34, height: 34).background(Circle().fill(SpotifyShell.green))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }
}

// MARK: - Mini player

/// Spotify's mini player: the cover, the song, connect, add, play; a thin progress line along the bottom.
/// Nothing in it fades or animates except the like pop.
struct SpotifyMiniPlayer: View {
    @Environment(PlayerModel.self) private var player
    @Environment(Router.self) private var router
    @Environment(LibraryStore.self) private var library
    @State private var airplay = AirPlayTrigger()

    var body: some View {
        if let track = player.current {
            let live = library.trackByID[track.id] ?? track
            let tint = ArtworkCache.tint(for: track)
            HStack(spacing: 10) {
                SpotifyMiniInfo(track: track)
                Button { airplay.fire() } label: {
                    Image("ConnectGlyph").renderingMode(.template).resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24).foregroundStyle(Color.white.opacity(0.9))
                        .frame(width: 40, height: 40).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(AirPlayLauncher(trigger: airplay).frame(width: 40, height: 40).opacity(0.02).allowsHitTesting(false))
                SPLikeButton(on: live.isFavorite, accent: SpotifyShell.green, size: 26) { library.toggleFavorite(live) }
                    .frame(width: 40, height: 40)
                Button { player.togglePlay() } label: {
                    SPPlayPause(isPlaying: player.isPlaying, color: Color.white).frame(width: 22, height: 22)
                        .frame(width: 40, height: 40).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transaction { $0.animation = nil }
            }
            .padding(.leading, 6).padding(.trailing, 6).frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.mix(with: Color.black, by: 0.25)))
            .overlay(alignment: .bottom) { SpotifyMiniProgress().padding(.horizontal, 8).padding(.bottom, 3) }
            .contentShape(Rectangle())
            .onTapGesture { router.showPlayer = true }
        }
    }
}

private struct SpotifyMiniProgress: View {
    @Environment(PlayerModel.self) private var player
    var body: some View {
        let f = player.duration > 0 ? min(1, max(0, player.position / player.duration)) : 0
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.28))
                Capsule().fill(Color.white).frame(width: g.size.width * f)
            }
        }
        .frame(height: 2)
    }
}

// MARK: - Events & venues (your own notes)

struct SpotifyEvent: Codable, Identifiable, Hashable {
    var id = UUID()
    var artist: String
    var venue: String
    var date: Date
    var note = ""
}

/// Shows you want to remember. The app has no ticket service, so this is your own list.
struct SpotifyEventsView: View {
    @AppStorage("spotifyEvents") private var raw = Data()
    @Environment(LibraryStore.self) private var library
    @State private var adding = false
    @State private var artist = ""
    @State private var venue = ""
    @State private var date = Date().addingTimeInterval(86400 * 14)
    @State private var note = ""

    private var events: [SpotifyEvent] {
        ((try? JSONDecoder().decode([SpotifyEvent].self, from: raw)) ?? []).sorted { $0.date < $1.date }
    }
    private func save(_ list: [SpotifyEvent]) { raw = (try? JSONEncoder().encode(list)) ?? Data() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Keep track of shows and venues for the artists you listen to. Add one and it stays here with its date.")
                    .font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.65))
                    .padding(.horizontal, 16)
                if events.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "ticket").font(.system(size: 34)).foregroundStyle(SpotifyShell.green)
                        Text("No events yet").font(.system(size: 18, weight: .bold))
                        Text("Tap Add event to save your first show.").font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity).padding(.top, 50)
                }
                ForEach(events) { e in
                    HStack(spacing: 14) {
                        VStack(spacing: 0) {
                            Text(e.date.formatted(.dateTime.month(.abbreviated))).font(.system(size: 12, weight: .bold)).foregroundStyle(SpotifyShell.green)
                            Text(e.date.formatted(.dateTime.day())).font(.system(size: 22, weight: .bold))
                        }
                        .frame(width: 54, height: 54)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.1)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.artist).font(.system(size: 16, weight: .bold)).lineLimit(1)
                            Text(e.venue).font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.65)).lineLimit(1)
                            if !e.note.isEmpty { Text(e.note).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.5)).lineLimit(2) }
                        }
                        Spacer(minLength: 0)
                        Button { save(events.filter { $0.id != e.id }) } label: {
                            Image(systemName: "trash").font(.system(size: 16)).foregroundStyle(Color.white.opacity(0.6)).frame(width: 40, height: 40)
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .background(SpotifyShell.ground)
        .navigationTitle("Events & venues")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Add event") { adding = true } } }
        .sheet(isPresented: $adding) {
            NavigationStack {
                Form {
                    Section("Artist") {
                        TextField("Artist", text: $artist)
                        if artist.isEmpty, !library.artistEntries.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack { ForEach(library.artistEntries.prefix(12)) { a in
                                    Button(a.title) { artist = a.title }.buttonStyle(.bordered).tint(SpotifyShell.green)
                                } }
                            }
                        }
                    }
                    Section("Venue") { TextField("Venue and city", text: $venue) }
                    Section { DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute]) }
                    Section("Note") { TextField("Tickets, who's coming…", text: $note) }
                }
                .navigationTitle("Add event").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { adding = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            save(events + [SpotifyEvent(artist: artist, venue: venue, date: date, note: note)])
                            artist = ""; venue = ""; note = ""; adding = false
                        }.disabled(artist.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .presentationDetents([.large])
            .environment(\.colorScheme, .dark)
        }
    }
}

/// Cover and title. Drag it sideways: the next or previous song slides in under your finger, and lets go into place.
private struct SpotifyMiniInfo: View {
    @Environment(PlayerModel.self) private var player
    @Environment(Router.self) private var router
    @Environment(LibraryStore.self) private var library
    let track: Track
    @State private var dx: CGFloat = 0

    private func neighbor(_ forward: Bool) -> Track? {
        if forward { return player.upcoming.first.flatMap { library.trackByID[$0.trackID] } }
        return player.history.last.flatMap { library.trackByID[$0.trackID] }
    }

    private func content(_ t: Track, label: String?) -> some View {
        HStack(spacing: 10) {
            ArtworkView(track: t, radius: 4).thumbnail().frame(width: 44, height: 44)
            if let label {
                Text(label).font(.system(size: 14, weight: .bold)).frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title).font(.system(size: 14, weight: .bold)).lineLimit(1)
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(SpotifyShell.green).frame(width: 13, height: 13)
                            .overlay { Image(systemName: "sparkle").font(.system(size: 7, weight: .black)).foregroundStyle(Color.black.opacity(0.8)) }
                        Text(t.artist).font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.7)).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .leading) {
                if dx != 0, let n = neighbor(dx < 0) {
                    content(n, label: dx < 0 ? "Next Track" : "Previous Track")
                        .frame(width: w).offset(x: dx + (dx < 0 ? w : -w))
                }
                content(track, label: nil).frame(width: w, alignment: .leading).offset(x: dx)
            }
            .frame(width: w, height: g.size.height, alignment: .leading)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { router.showPlayer = true }
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { v in
                        guard abs(v.translation.width) > abs(v.translation.height) else { return }
                        // Nothing to go to on that side: it only gives a little.
                        dx = neighbor(v.translation.width < 0) == nil ? v.translation.width / 6 : v.translation.width
                    }
                    .onEnded { v in
                        let forward = v.translation.width < 0
                        let far = abs(v.translation.width) > 60 || abs(v.predictedEndTranslation.width) > 160
                        guard far, neighbor(forward) != nil else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { dx = 0 }
                            return
                        }
                        withAnimation(.easeOut(duration: 0.18)) { dx = forward ? -w : w }
                        Task {
                            try? await Task.sleep(for: .milliseconds(190))
                            if forward { player.next() } else { player.previous(always: true) }
                            var t = Transaction(); t.disablesAnimations = true
                            withTransaction(t) { dx = 0 }
                        }
                    }
            )
        }
        .frame(height: 44)
    }
}
