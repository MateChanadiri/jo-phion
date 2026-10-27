import SwiftUI

// MARK: - Album / playlist / Liked Songs

/// Spotify's collection page: the cover on a colour that fades into the dark, an action row, then plain song rows.
struct SpotifyCollectionView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerModel.self) private var player
    @Environment(Router.self) private var router
    @Environment(DownloadManager.self) private var downloads
    @Environment(\.dismiss) private var dismiss

    /// nil = Liked Songs.
    var kind: LibraryEntry.Kind?
    var key = ""
    @State private var offset: CGFloat = 0
    @State private var pickerTrack: Track?

    private var entry: LibraryEntry? { kind.flatMap { library.entry($0, key) } }
    private var tracks: [Track] {
        if kind == nil { return library.tracks.filter(\.isFavorite).sorted { $0.addedAt > $1.addedAt } }
        return entry?.tracks ?? []
    }
    private var title: String { kind == nil ? "Liked Songs" : (entry?.title ?? "") }
    private var artist: String? { kind == .album ? tracks.first?.artist : nil }
    private var tint: Color { kind == nil ? Color(hex: "#4F2BFF").mix(with: .black, by: 0.35) : ArtworkCache.tint(for: tracks.first) }

    private var meta: String {
        let mins = Int(tracks.reduce(0) { $0 + $1.duration } / 60)
        let base: String
        switch kind {
        case .album:
            if let y = tracks.compactMap(\.year).first { base = "Album • \(y)" } else { base = "Album" }
        case .playlist: base = "Playlist"
        default: base = "Playlist"
        }
        return "\(base) • \(songCount(tracks.count)) • \(mins) min"
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpotifyShell.ground.ignoresSafeArea()
            LinearGradient(colors: [tint.opacity(0.95), SpotifyShell.ground], startPoint: .top, endPoint: .bottom)
                .frame(height: 460).frame(maxHeight: .infinity, alignment: .top)
                .offset(y: -max(0, offset) * 0.6).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    cover.frame(maxWidth: .infinity).padding(.top, 52)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title).font(.system(size: 24, weight: .bold)).lineLimit(3)
                        if let artist {
                            Button { router.open(.artist(artist)) } label: {
                                HStack(spacing: 8) {
                                    if let t = tracks.first { ArtworkView(track: t, radius: 0).thumbnail(60).frame(width: 22, height: 22).clipShape(Circle()) }
                                    Text(artist).font(.system(size: 14, weight: .bold))
                                }
                            }.buttonStyle(.plain)
                        } else if kind == nil {
                            HStack(spacing: 8) {
                                SpotifyAvatarDot()
                                Text("You").font(.system(size: 14, weight: .bold))
                            }
                        }
                        Text(meta).font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.65))
                    }
                    .padding(.horizontal, 16).padding(.top, 18)
                    actionRow.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)

                    LazyVStack(spacing: 0) {
                        ForEach(tracks) { t in row(t) }
                    }
                    .padding(.top, 4)

                    if tracks.isEmpty {
                        Text(kind == nil ? "Songs you like show up here." : "Nothing in here yet.")
                            .foregroundStyle(Color.white.opacity(0.65)).padding(24)
                    }
                    extras
                }
                .padding(.bottom, 24)
            }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, new in offset = new }

            topBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .sheet(item: $pickerTrack) { t in PlaylistPicker(trackIDs: [t.id]).environment(\.colorScheme, .dark) }
    }

    // MARK: Pieces

    @ViewBuilder private var cover: some View {
        Group {
            if let entry {
                ArtworkView(entry: entry, radius: 0).thumbnail(700)
            } else {
                Rectangle().fill(LinearGradient(colors: [Color(hex: "#4F2BFF"), Color(hex: "#A6B4FF")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { Image(systemName: "heart.fill").font(.system(size: 84)).foregroundStyle(Color.white) }
            }
        }
        .frame(width: 236, height: 236)
        .shadow(color: .black.opacity(0.45), radius: 22, y: 10)
        .opacity(Double(1 - min(1, max(0, offset) / 260)))
    }

    private var topBar: some View {
        let shown = offset > 250
        return HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.white)
                    .frame(width: 36, height: 36).background(Circle().fill(Color.black.opacity(0.45)))
            }.buttonStyle(.plain)
            if shown {
                Text(title).font(.system(size: 15, weight: .bold)).lineLimit(1)
                Spacer(minLength: 0)
                Button { playAll(shuffled: false) } label: {
                    Image(systemName: "play.fill").font(.system(size: 16)).foregroundStyle(Color.black)
                        .frame(width: 38, height: 38).background(Circle().fill(SpotifyShell.green))
                }.buttonStyle(.plain)
            } else { Spacer(minLength: 0) }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(shown ? tint.mix(with: SpotifyShell.ground, by: 0.4) : Color.clear)
    }

    private var actionRow: some View {
        HStack(spacing: 18) {
            if let t = tracks.first {
                ArtworkView(track: t, radius: 3).thumbnail(90).frame(width: 30, height: 30)
            }
            if let entry {
                Button { library.togglePin(entry) } label: {
                    Image(systemName: library.isPinned(entry) ? "checkmark.circle.fill" : "plus.circle").font(.system(size: 26, weight: .light))
                        .foregroundStyle(library.isPinned(entry) ? SpotifyShell.green : Color.white.opacity(0.75))
                }.buttonStyle(.plain)
            }
            Button { downloads.download(tracks.filter { $0.isRemote && !$0.isDownloaded }) } label: {
                Image(systemName: "arrow.down.circle").font(.system(size: 26, weight: .light)).foregroundStyle(Color.white.opacity(0.75))
            }.buttonStyle(.plain)
            if let entry {
                Menu { EntryMenuItems(entry: entry) } label: {
                    Image(systemName: "ellipsis").font(.system(size: 20, weight: .bold)).foregroundStyle(Color.white.opacity(0.75))
                }
            }
            Spacer(minLength: 0)
            Button { playAll(shuffled: true) } label: {
                Image(systemName: "shuffle").font(.system(size: 22, weight: .semibold)).foregroundStyle(SpotifyShell.green)
            }.buttonStyle(.plain)
            Button { playAll(shuffled: false) } label: {
                Image(systemName: "play.fill").font(.system(size: 24)).foregroundStyle(Color.black)
                    .frame(width: 56, height: 56).background(Circle().fill(SpotifyShell.green))
            }.buttonStyle(.plain)
        }
    }

    private func playAll(shuffled: Bool) {
        guard !tracks.isEmpty else { return }
        player.play(tracks, title: title, shuffled: shuffled)
    }

    private func row(_ t: Track) -> some View {
        let current = player.current?.id == t.id
        return HStack(spacing: 4) {
            Button { player.play(tracks, startAt: tracks.firstIndex(of: t) ?? 0, title: title) } label: {
                HStack(spacing: 12) {
                    if kind != .album { ArtworkView(track: t, radius: 3).thumbnail(110).frame(width: 48, height: 48) }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t.title).font(.system(size: 16, weight: .bold)).foregroundStyle(current ? SpotifyShell.green : Color.white).lineLimit(1)
                        Text(t.artist).font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.65)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 16).padding(.vertical, 8).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Menu {
                Button { player.playNext([t]) } label: { Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward") }
                Button { player.playAfter([t]) } label: { Label("Add to queue", systemImage: "text.line.last.and.arrowtriangle.forward") }
                Button { library.toggleFavorite(t) } label: { Label(t.isFavorite ? "Remove from Liked Songs" : "Add to Liked Songs", systemImage: t.isFavorite ? "heart.slash" : "heart") }
                Button { pickerTrack = t } label: { Label("Add to playlist", systemImage: "plus.circle") }
                if t.isRemote, !t.isDownloaded { Button { downloads.download([t]) } label: { Label("Download", systemImage: "arrow.down.circle") } }
                Divider()
                Button { router.open(.artist(t.artist)) } label: { Label("Go to artist", systemImage: "music.mic") }
                Button { router.open(.album("\(t.artist)|\(t.album)")) } label: { Label("Go to album", systemImage: "opticaldisc") }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 16)).foregroundStyle(Color.white.opacity(0.65)).frame(width: 44, height: 48)
            }
        }
    }

    @ViewBuilder private var extras: some View {
        if kind == .album, let artist {
            let more = library.albumEntries.filter { $0.tracks.first?.artist == artist && $0.key != key }
            if !more.isEmpty { SpotifyShelf(title: "More by \(artist)", entries: more, style: .kind).padding(.top, 26) }
            NavigationLink { SpotifyEventsView() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "ticket").font(.system(size: 20)).foregroundStyle(SpotifyShell.green).frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Concerts").font(.system(size: 17, weight: .bold))
                        Text("Your saved shows and venues").font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.65))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Color.white.opacity(0.5))
                }
                .padding(12).background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.08)))
                .padding(.horizontal, 16).padding(.top, 22)
            }.buttonStyle(.plain)
            let genre = tracks.first?.genre
            let like = library.albumEntries.filter { e in e.tracks.first?.artist != artist && genre != nil && e.tracks.first?.genre == genre }
            if !like.isEmpty { SpotifyShelf(title: "You might also like", entries: like, style: .artist).padding(.top, 22) }
            if let c = tracks.first?.copyright ?? tracks.first.map({ "© \($0.year.map(String.init) ?? "") \($0.artist)" }) {
                Text(c).font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.55)).padding(.horizontal, 16).padding(.top, 20)
            }
        }
    }
}

private struct SpotifyAvatarDot: View {
    var body: some View {
        Image(systemName: "person.fill").font(.system(size: 11)).foregroundStyle(Color.black)
            .frame(width: 22, height: 22).background(Circle().fill(SpotifyShell.green))
    }
}

// MARK: - Shelf

/// A horizontal row of covers with a bold heading.
struct SpotifyShelf: View {
    enum Style { case kind, artist, count, circle }
    var title: String
    var entries: [LibraryEntry]
    var style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 22, weight: .bold)).padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(entries.prefix(24)) { e in
                        NavigationLink(value: e.route) {
                            VStack(alignment: style == .circle ? .center : .leading, spacing: 8) {
                                ArtworkView(entry: e, radius: style == .circle ? 0 : 3).thumbnail(360).frame(width: 145, height: 145)
                                Text(e.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                Text(sub(e)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.white.opacity(0.62)).lineLimit(1)
                            }
                            .frame(width: 145, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func sub(_ e: LibraryEntry) -> String {
        switch style {
        case .kind: (e.tracks.count == 1 ? "Single" : e.tracks.count <= 6 ? "EP" : "Album") + " • " + (e.tracks.first?.year.map(String.init) ?? e.subtitle)
        case .artist: e.tracks.first?.artist ?? e.subtitle
        case .count: songCount(e.tracks.count)
        case .circle: "Artist"
        }
    }
}

// MARK: - Artist

struct SpotifyArtistView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerModel.self) private var player
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    var name: String
    @State private var offset: CGFloat = 0
    @State private var tab = 0
    @State private var more = false
    @State private var allReleases = false
    @State private var info: SPArtistInfo?
    @State private var bioOpen = false

    private var entry: LibraryEntry? { library.artistEntries.first { $0.key == name } ?? library.entry(.artist, name) }
    private var tracks: [Track] { entry?.tracks ?? library.tracks.filter { $0.artist == name } }
    private var albums: [LibraryEntry] { library.albumEntries.filter { $0.tracks.first?.artist == name } }
    private var popular: [Track] { tracks.sorted { ($0.playCount ?? 0) > ($1.playCount ?? 0) } }
    private var playlists: [LibraryEntry] { library.playlistEntries.filter { p in p.tracks.contains { $0.artist == name } } }
    private var fans: [LibraryEntry] {
        let genre = tracks.compactMap(\.genre).first
        let same = library.artistEntries.filter { $0.key != name && genre != nil && $0.tracks.first?.genre == genre }
        return same.isEmpty ? library.artistEntries.filter { $0.key != name } : same
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpotifyShell.ground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    banner
                    controls.padding(.horizontal, 16).padding(.top, 12)
                    tabs.padding(.top, 14)
                    switch tab {
                    case 1: events
                    case 2: Text("No merch here yet.").foregroundStyle(Color.white.opacity(0.65)).padding(24)
                    default: music
                    }
                }
                .padding(.bottom, 24)
            }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, new in offset = new }
            topBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .task(id: name) { info = await SPArtistInfoCache.shared.info(for: SPArtistInfoCache.mainName(name)) }
    }

    private var topBar: some View {
        let shown = offset > 250
        return ZStack {
            if shown { Text(name).font(.system(size: 15, weight: .bold)) }
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.white)
                        .frame(width: 36, height: 36).background(Circle().fill(Color.black.opacity(0.45)))
                }.buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(shown ? SpotifyShell.ground : Color.clear)
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let t = tracks.first(where: \.hasArtwork) ?? tracks.first {
                    ArtworkView(track: t, radius: 0).thumbnail(900)
                } else { Color(white: 0.2) }
            }
            .frame(maxWidth: .infinity).aspectRatio(1.1, contentMode: .fit).clipped()
            LinearGradient(colors: [.clear, SpotifyShell.ground.opacity(0.95)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.system(size: 38, weight: .bold)).lineLimit(2).minimumScaleFactor(0.6)
                Text("\(songCount(tracks.count)) in your library").font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.75))
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            if let t = tracks.first { ArtworkView(track: t, radius: 3).thumbnail(90).frame(width: 32, height: 32) }
            if let entry {
                Button { library.togglePin(entry) } label: {
                    Text(library.isPinned(entry) ? "Following" : "Follow").font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14).frame(height: 30)
                        .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
                }.buttonStyle(.plain)
                Menu { EntryMenuItems(entry: entry) } label: {
                    Image(systemName: "ellipsis").font(.system(size: 20, weight: .bold)).foregroundStyle(Color.white.opacity(0.75))
                }
            }
            Spacer(minLength: 0)
            Button { if !tracks.isEmpty { player.play(tracks, title: name, shuffled: true) } } label: {
                Image(systemName: "shuffle").font(.system(size: 22, weight: .semibold)).foregroundStyle(SpotifyShell.green)
            }.buttonStyle(.plain)
            Button { if !popular.isEmpty { player.play(popular, title: name) } } label: {
                Image(systemName: "play.fill").font(.system(size: 24)).foregroundStyle(Color.black)
                    .frame(width: 56, height: 56).background(Circle().fill(SpotifyShell.green))
            }.buttonStyle(.plain)
        }
    }

    private var tabs: some View {
        HStack(spacing: 22) {
            ForEach(Array(["Music", "Events", "Merch"].enumerated()), id: \.offset) { i, t in
                Button { tab = i } label: {
                    VStack(spacing: 6) {
                        Text(t).font(.system(size: 14, weight: .semibold)).foregroundStyle(tab == i ? Color.white : Color.white.opacity(0.62))
                        Rectangle().fill(tab == i ? SpotifyShell.green : Color.clear).frame(height: 2)
                    }.fixedSize()
                }.buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
    }

    private var events: some View {
        NavigationLink { SpotifyEventsView() } label: {
            HStack {
                Image(systemName: "ticket").foregroundStyle(SpotifyShell.green)
                Text("See your saved events for \(name)").font(.system(size: 15, weight: .bold))
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(14).background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.08)))
            .padding(16)
        }.buttonStyle(.plain)
    }

    @ViewBuilder private var music: some View {
        Text("Popular").font(.system(size: 22, weight: .bold)).padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 6)
        ForEach(Array(popular.prefix(more ? 10 : 5).enumerated()), id: \.element.id) { i, t in
            let current = player.current?.id == t.id
            Button { player.play(popular, startAt: i, title: name) } label: {
                HStack(spacing: 12) {
                    Text("\(i + 1)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.white.opacity(0.65)).frame(width: 16)
                    ArtworkView(track: t, radius: 3).thumbnail(110).frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t.title).font(.system(size: 16, weight: .bold)).foregroundStyle(current ? SpotifyShell.green : Color.white).lineLimit(1)
                        Text((t.playCount ?? 0) > 0 ? "\(t.playCount ?? 0) plays" : t.album).font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.65)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "ellipsis").foregroundStyle(Color.white.opacity(0.55))
                }
                .padding(.horizontal, 16).padding(.vertical, 6).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
        if popular.count > 5 {
            Button { withAnimation(.smooth(duration: 0.25)) { more.toggle() } } label: { pill(more ? "Show less" : "Show more") }
                .buttonStyle(.plain).frame(maxWidth: .infinity).padding(.top, 8)
        }

        if !albums.isEmpty {
            HStack { Text("Popular Releases").font(.system(size: 22, weight: .bold)); Spacer() }
                .padding(.horizontal, 16).padding(.top, 26).padding(.bottom, 6)
            ForEach(albums.prefix(allReleases ? 50 : 4)) { a in
                NavigationLink(value: a.route) {
                    HStack(spacing: 12) {
                        ArtworkView(entry: a, radius: 3).thumbnail(160).frame(width: 60, height: 60)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(a.title).font(.system(size: 16, weight: .bold)).lineLimit(1)
                            Text("\(a.tracks.count == 1 ? "Single" : a.tracks.count <= 6 ? "EP" : "Album") • \(a.tracks.first?.year.map(String.init) ?? "")")
                                .font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.65))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 6).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            if albums.count > 4 {
                Button { withAnimation(.smooth(duration: 0.25)) { allReleases.toggle() } } label: { pill(allReleases ? "Show less" : "See discography") }
                    .buttonStyle(.plain).frame(maxWidth: .infinity).padding(.top, 8)
            }
        }

        if !playlists.isEmpty { SpotifyShelf(title: "Featuring \(name)", entries: playlists, style: .count).padding(.top, 26) }

        VStack(alignment: .leading, spacing: 12) {
            Text("About").font(.system(size: 22, weight: .bold))
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let t = tracks.first(where: \.hasArtwork) ?? tracks.first { ArtworkView(track: t, radius: 0).thumbnail(800) } else { Color(white: 0.2) }
                }
                .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                Text(name).font(.system(size: 20, weight: .bold)).padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            if let info, !info.bio.isEmpty {
                Text(info.bio).font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.8)).lineLimit(bioOpen ? nil : 4)
                Button { withAnimation(.smooth(duration: 0.25)) { bioOpen.toggle() } } label: {
                    Text(bioOpen ? "show less" : "show more").font(.system(size: 13, weight: .bold))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.top, 26)

        if !fans.isEmpty { SpotifyShelf(title: "Fans Also Like", entries: fans, style: .circle).padding(.top, 26) }
    }

    private func pill(_ title: String) -> some View {
        Text(title).font(.system(size: 13, weight: .bold)).padding(.horizontal, 18).frame(height: 32)
            .overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1))
    }
}
