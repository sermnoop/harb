import SwiftUI
import AVKit

// MARK: - 9. Root Harbor iOS Navigation Shell

enum HarborRoomTab: String, CaseIterable, Identifiable {
    case home = "الرئيسية"
    case discover = "الكتالوج"
    case music = "الموسيقى"
    case books = "الكتب"
    case addons = "الإضافات"
    case settings = "الإعدادات"

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .home: return "sparkles.tv.fill"
        case .discover: return "film.stack.fill"
        case .music: return "waveform.circle.fill"
        case .books: return "books.vertical.fill"
        case .addons: return "puzzlepiece.extension.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

public struct HarborIOSRootView: View {
    @StateObject private var store = HarborStore()
    @StateObject private var audioManager = HarborAudioPlayerManager()
    @State private var selectedTab: HarborRoomTab = .home

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HarborHomeRoomView()
                    .tabItem {
                        Label(HarborRoomTab.home.rawValue, systemImage: HarborRoomTab.home.systemIcon)
                    }
                    .tag(HarborRoomTab.home)

                HarborCatalogRoomView()
                    .tabItem {
                        Label(HarborRoomTab.discover.rawValue, systemImage: HarborRoomTab.discover.systemIcon)
                    }
                    .tag(HarborRoomTab.discover)

                HarborMusicRoomView()
                    .tabItem {
                        Label(HarborRoomTab.music.rawValue, systemImage: HarborRoomTab.music.systemIcon)
                    }
                    .tag(HarborRoomTab.music)

                HarborBooksRoomView()
                    .tabItem {
                        Label(HarborRoomTab.books.rawValue, systemImage: HarborRoomTab.books.systemIcon)
                    }
                    .tag(HarborRoomTab.books)

                HarborAddonsRoomView()
                    .tabItem {
                        Label(HarborRoomTab.addons.rawValue, systemImage: HarborRoomTab.addons.systemIcon)
                    }
                    .tag(HarborRoomTab.addons)

                HarborSettingsRoomView()
                    .tabItem {
                        Label(HarborRoomTab.settings.rawValue, systemImage: HarborRoomTab.settings.systemIcon)
                    }
                    .tag(HarborRoomTab.settings)
            }
            .tint(store.theme.accent)

            // Persistent Floating Mini Audio Player Bar
            if audioManager.currentTrack != nil {
                HarborMiniAudioPlayerBar()
                    .padding(.bottom, 54)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environmentObject(store)
        .environmentObject(audioManager)
        .preferredColorScheme(.dark)
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $audioManager.isShowingFullPlayer) {
            HarborFullMusicPlayerSheet()
                .environmentObject(store)
                .environmentObject(audioManager)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - 10. Home Room (Rotating Hero, Continue Watching, Top 10 Numerals, Rails)

struct HarborHomeRoomView: View {
    @EnvironmentObject var store: HarborStore
    @State private var activeHeroIndex: Int = 0
    @State private var selectedItem: StremioMetaPreview? = nil

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    // Rotating Hero Carousel with Halo Glow
                    if !store.heroItems.isEmpty {
                        TabView(selection: $activeHeroIndex) {
                            ForEach(Array(store.heroItems.enumerated()), id: \.element.id) { index, item in
                                HarborHeroBannerCard(item: item) {
                                    selectedItem = item
                                }
                                .tag(index)
                            }
                        }
                        .frame(height: 430)
                        .tabViewStyle(.page(indexDisplayMode: .automatic))
                    }

                    // Continue Watching Rail (Polled & synced at 85% completion)
                    if !store.continueWatching.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HarborSectionHeader(title: "متابعة المشاهدة (Continue Watching)", icon: "play.circle.fill")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(store.continueWatching) { progress in
                                        ContinueWatchingCard(item: progress) {
                                            selectedItem = StremioMetaPreview(
                                                id: progress.id,
                                                type: progress.mediaType,
                                                name: progress.title,
                                                poster: progress.poster,
                                                background: progress.backdrop,
                                                logo: nil,
                                                description: progress.subtitle,
                                                releaseInfo: nil,
                                                imdbRating: nil,
                                                genres: nil
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    // Top 10 Today Numerals Row
                    VStack(alignment: .leading, spacing: 12) {
                        HarborSectionHeader(title: "أفضل 10 اليوم (Top 10 Today)", icon: "chart.bar.fill")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 18) {
                                ForEach(Array(store.trendingMovies.prefix(10).enumerated()), id: \.element.id) { idx, item in
                                    TopTenNumeralPosterCard(rank: idx + 1, item: item) {
                                        selectedItem = item
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // Trending Movies Rail
                    HarborPosterRail(
                        title: "الأفلام الرائجة (Cinemeta & TMDB)",
                        icon: "film.fill",
                        items: store.trendingMovies
                    ) { item in
                        selectedItem = item
                    }

                    // Trending Series Rail
                    HarborPosterRail(
                        title: "المسلسلات الأكثر مشاهدة",
                        icon: "tv.fill",
                        items: store.trendingSeries
                    ) { item in
                        selectedItem = item
                    }

                    // Anime First-Class Rail
                    HarborPosterRail(
                        title: "غرفة الأنمي (Anime Award Winners)",
                        icon: "sparkles",
                        items: store.animeCatalog
                    ) { item in
                        selectedItem = item
                    }

                    Spacer(minLength: 90)
                }
            }
            .background(store.theme.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Harbor iOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: "sailboat.fill")
                            .foregroundStyle(store.theme.accent)
                        Text("Harbor")
                            .font(.headline.weight(.bold))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refreshAllCatalogs() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .navigationDestination(item: $selectedItem) { item in
                HarborMediaDetailView(preview: item)
            }
        }
    }
}

struct HarborHeroBannerCard: View {
    @EnvironmentObject var store: HarborStore
    let item: StremioMetaPreview
    let onSelect: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: item.background ?? item.poster ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    LinearGradient(
                        colors: [store.theme.backgroundSecondary, store.theme.accent.opacity(0.35), store.theme.backgroundPrimary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(height: 430)
            .clipped()

            LinearGradient(
                colors: [.clear, store.theme.backgroundPrimary.opacity(0.65), store.theme.backgroundPrimary],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(item.type.uppercased())
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(store.theme.accent.opacity(0.25))
                        .foregroundStyle(store.theme.accent)
                        .clipShape(Capsule())

                    if let rating = item.imdbRating {
                        Label(rating, systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }

                    if !item.displayYear.isEmpty {
                        Text(item.displayYear)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(item.name)
                    .font(.title.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let desc = item.description {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Button(action: onSelect) {
                        Label("تشغيل ومصادر البث", systemImage: "play.fill")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(store.theme.accent)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }

                    Button {
                        store.toggleWatchlist(item)
                    } label: {
                        Label(
                            store.isInWatchlist(item) ? "في قائمتي" : "إضافة للقائمة",
                            systemImage: store.isInWatchlist(item) ? "checkmark" : "plus"
                        )
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(.ultraThinMaterial)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }
}

struct HarborSectionHeader: View {
    @EnvironmentObject var store: HarborStore
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(store.theme.accent)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

struct HarborPosterRail: View {
    let title: String
    let icon: String
    let items: [StremioMetaPreview]
    let onSelect: (StremioMetaPreview) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HarborSectionHeader(title: title, icon: icon)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        HarborPosterCard(item: item) {
                            onSelect(item)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct HarborPosterCard: View {
    @EnvironmentObject var store: HarborStore
    let item: StremioMetaPreview
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: item.poster ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            ZStack {
                                store.theme.backgroundSecondary
                                Image(systemName: "film")
                                    .font(.title)
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                    }
                    .frame(width: 132, height: 196)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if let rating = item.imdbRating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                            Text(rating)
                                .font(.caption2.weight(.bold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.75))
                        .foregroundStyle(.yellow)
                        .clipShape(Capsule())
                        .padding(6)
                    }
                }

                Text(item.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: 132, alignment: .leading)

                Text(item.displayYear)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct TopTenNumeralPosterCard: View {
    @EnvironmentObject var store: HarborStore
    let rank: Int
    let item: StremioMetaPreview
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .bottom, spacing: -14) {
                Text("\(rank)")
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [store.theme.accent, store.theme.accent.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .zIndex(1)

                HarborPosterCard(item: item, onTap: onTap)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ContinueWatchingCard: View {
    @EnvironmentObject var store: HarborStore
    let item: WatchProgressItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottom) {
                    AsyncImage(url: URL(string: item.backdrop ?? item.poster ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            store.theme.backgroundSecondary
                        }
                    }
                    .frame(width: 220, height: 124)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(spacing: 0) {
                        Spacer()
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.caption)
                                .padding(8)
                                .background(store.theme.accent)
                                .foregroundStyle(.black)
                                .clipShape(Circle())
                            if item.isCompleted {
                                Text("مكتمل 85%+")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.green.opacity(0.85))
                                    .foregroundStyle(.black)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                        }
                        .padding(8)

                        ProgressView(value: item.progressFraction)
                            .tint(store.theme.accent)
                            .background(.black.opacity(0.6))
                    }
                }
                .frame(width: 220, height: 124)

                Text(item.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 11. Discover & Catalog Room (Movies, Series, Anime, Watchlist, Search)

struct HarborCatalogRoomView: View {
    @EnvironmentObject var store: HarborStore
    @State private var selectedCategory: MediaType = .movie
    @State private var searchText: String = ""
    @State private var selectedGenre: String = "الكل"
    @State private var selectedItem: StremioMetaPreview? = nil

    private let genres = ["الكل", "Action", "Sci-Fi", "Drama", "Adventure", "Crime", "Animation", "Fantasy"]

    private var activeList: [StremioMetaPreview] {
        let base: [StremioMetaPreview]
        switch selectedCategory {
        case .movie: base = store.trendingMovies
        case .series: base = store.trendingSeries
        case .anime: base = store.animeCatalog
        }
        return base.filter { item in
            let matchesSearch = searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText)
            let matchesGenre = selectedGenre == "الكل" || (item.genres?.contains(where: { $0.caseInsensitiveCompare(selectedGenre) == .orderedSame }) ?? true)
            return matchesSearch && matchesGenre
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 115, maximum: 150), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Media Type Picker
                Picker("الفئة", selection: $selectedCategory) {
                    ForEach(MediaType.allCases) { type in
                        Text(type.arabicTitle).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                // Genre Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(genres, id: \.self) { genre in
                            Button {
                                selectedGenre = genre
                            } label: {
                                Text(genre)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedGenre == genre ? store.theme.accent : store.theme.backgroundSecondary)
                                    .foregroundStyle(selectedGenre == genre ? .black : .white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Poster Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(activeList) { item in
                            HarborPosterCard(item: item) {
                                selectedItem = item
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
            }
            .background(store.theme.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("استكشاف الكتالوج")
            .searchable(text: $searchText, prompt: "ابحث عن فيلم، مسلسل، أو أنمي...")
            .navigationDestination(item: $selectedItem) { item in
                HarborMediaDetailView(preview: item)
            }
        }
    }
}

// MARK: - 12. Media Detail View + Harbor Stream Engine Ranking & Debrid Playback

struct HarborMediaDetailView: View {
    @EnvironmentObject var store: HarborStore
    let preview: StremioMetaPreview

    @State private var detail: StremioMetaDetail? = nil
    @State private var rankedStreams: [HarborRankedStream] = []
    @State private var isLoadingStreams: Bool = false
    @State private var selectedEpisode: StremioEpisodeVideo? = nil
    @State private var activePlayerConfig: ActiveVideoPlaybackConfig? = nil
    @State private var errorAlertMessage: String? = nil
    @State private var isResolvingDebrid: Bool = false

    struct ActiveVideoPlaybackConfig: Identifiable {
        let id = UUID()
        let url: URL
        let title: String
        let subtitle: String?
        let allStreams: [HarborRankedStream]
        let previewItem: StremioMetaPreview
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero Backdrop Header
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: detail?.background ?? preview.background ?? preview.poster ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            store.theme.backgroundSecondary
                        }
                    }
                    .frame(height: 280)
                    .clipped()

                    LinearGradient(
                        colors: [.clear, store.theme.backgroundPrimary],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        if let awards = detail?.awards, !awards.isEmpty {
                            Label(awards, systemImage: "laurel.leading")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.yellow.opacity(0.2))
                                .foregroundStyle(.yellow)
                                .clipShape(Capsule())
                        }

                        Text(detail?.name ?? preview.name)
                            .font(.title.weight(.heavy))
                            .foregroundStyle(.white)

                        HStack(spacing: 12) {
                            if let rating = detail?.imdbRating ?? preview.imdbRating {
                                Label("IMDb \(rating)", systemImage: "star.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.yellow)
                            }
                            if let year = detail?.releaseInfo ?? preview.releaseInfo {
                                Text(year)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let runtime = detail?.runtime {
                                Text(runtime)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(16)
                }

                // Synopsis & Metadata
                VStack(alignment: .leading, spacing: 12) {
                    if let desc = detail?.description ?? preview.description {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.88))
                            .lineSpacing(4)
                    }

                    if let genres = detail?.genres ?? preview.genres, !genres.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(genres, id: \.self) { g in
                                    Text(g)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(store.theme.backgroundSecondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Episodes Picker (if Series / Anime)
                    if let videos = detail?.videos, !videos.isEmpty {
                        Divider().overlay(.white.opacity(0.1))
                        Text("الحلقات (Episodes)")
                            .font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(videos.prefix(30)) { ep in
                                    let isSelected = selectedEpisode?.id == ep.id
                                    Button {
                                        selectedEpisode = ep
                                        Task { await reloadStreams(episodeId: ep.id) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(ep.displayTitle)
                                                .font(.caption.weight(.bold))
                                                .lineLimit(1)
                                            if let overview = ep.overview {
                                                Text(overview)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }
                                        }
                                        .frame(width: 170, alignment: .leading)
                                        .padding(10)
                                        .background(isSelected ? store.theme.accent.opacity(0.25) : store.theme.backgroundSecondary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(isSelected ? store.theme.accent : .clear, lineWidth: 1.5)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Harbor Stream Engine Section (Parse -> Trust -> Score -> Rank)
                    Divider().overlay(.white.opacity(0.1))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("مصادر البث المصنفة (Harbor Stream Engine)")
                                .font(.headline)
                            Text("Pipeline: Parse → Trust (\(store.safetyFilter.rawValue)) → Score → Rank • \(store.debridProvider.rawValue)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isLoadingStreams || isResolvingDebrid {
                            ProgressView()
                                .tint(store.theme.accent)
                        }
                    }

                    if rankedStreams.isEmpty && !isLoadingStreams {
                        Text("لم يتم العثور على مصادر بث متوافقة مع إعدادات الأمان الحالية.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(rankedStreams) { stream in
                            HarborRankedStreamRow(stream: stream) {
                                Task { await launchStream(stream) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
            }
        }
        .background(store.theme.backgroundPrimary.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            self.detail = await store.fetchMetaDetail(for: preview)
            if let firstEp = detail?.videos?.first {
                selectedEpisode = firstEp
                await reloadStreams(episodeId: firstEp.id)
            } else {
                await reloadStreams(episodeId: nil)
            }
        }
        .fullScreenCover(item: $activePlayerConfig) { config in
            HarborNativeVideoPlayerModal(
                url: config.url,
                title: config.title,
                subtitle: config.subtitle,
                availableStreams: config.allStreams,
                previewItem: config.previewItem
            )
            .environmentObject(store)
        }
        .alert("تنبيه البث (Debrid / Stream)", isPresented: Binding(
            get: { errorAlertMessage != nil },
            set: { if !$0 { errorAlertMessage = nil } }
        )) {
            Button("حسناً", role: .cancel) { errorAlertMessage = nil }
        } message: {
            Text(errorAlertMessage ?? "")
        }
    }

    private func reloadStreams(episodeId: String?) async {
        isLoadingStreams = true
        rankedStreams = await store.fetchAndRankStreams(for: preview, episodeId: episodeId)
        isLoadingStreams = false
    }

    private func launchStream(_ stream: HarborRankedStream) async {
        isResolvingDebrid = true
        defer { isResolvingDebrid = false }
        do {
            let playableURL = try await DebridService.shared.resolvePlayableURL(
                for: stream,
                provider: store.debridProvider,
                realDebridToken: store.realDebridToken,
                torBoxKey: store.torBoxKey
            )
            activePlayerConfig = ActiveVideoPlaybackConfig(
                url: playableURL,
                title: preview.name,
                subtitle: selectedEpisode?.displayTitle ?? stream.tier.rawValue,
                allStreams: rankedStreams,
                previewItem: preview
            )
        } catch {
            errorAlertMessage = error.localizedDescription
        }
    }
}

struct HarborRankedStreamRow: View {
    @EnvironmentObject var store: HarborStore
    let stream: HarborRankedStream
    let onSelect: () -> Void
    @State private var showScoreDetails: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    // Quality Tier Badge
                    VStack(spacing: 4) {
                        Text(stream.tier.rawValue)
                            .font(.caption.weight(.black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(stream.isCachedDebrid ? store.theme.accent : Color.gray.opacity(0.3))
                            .foregroundStyle(stream.isCachedDebrid ? .black : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("نقاط \(stream.score)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(store.theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            if let badge = stream.debridBadge {
                                Text(badge)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.green.opacity(0.25))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                            }
                            Text(stream.addonName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                            if let size = stream.fileSizeDisplay {
                                Text("• \(size)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(stream.raw.title ?? stream.raw.name ?? "Stream")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        // Parsed technical tags
                        HStack(spacing: 6) {
                            if let hdr = stream.hdrFlavor {
                                TechnicalBadge(text: hdr, color: .purple)
                            }
                            if let codec = stream.videoCodec {
                                TechnicalBadge(text: codec, color: .blue)
                            }
                            if let audio = stream.audioTag {
                                TechnicalBadge(text: audio, color: .orange)
                            }
                            if let src = stream.sourceType {
                                TechnicalBadge(text: src, color: .teal)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(store.theme.accent)
                }
            }
            .buttonStyle(.plain)

            // Inspectable Score Breakdown Toggle
            if !stream.scoreReasons.isEmpty {
                Button {
                    withAnimation { showScoreDetails.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text(showScoreDetails ? "إخفاء تفاصيل التقييم" : "عرض أسباب الترتيب (Harbor Score)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                if showScoreDetails {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(stream.scoreReasons, id: \.self) { reason in
                            Text("• \(reason)")
                                .font(.caption2)
                                .foregroundStyle(store.theme.accent.opacity(0.9))
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(12)
        .background(store.theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TechnicalBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - 13. Native iOS Video Player (AVKit + Skip Intro/Outro + Stream Switcher)

struct HarborNativeVideoPlayerModal: View {
    @EnvironmentObject var store: HarborStore
    @Environment(\.dismiss) private var dismiss

    @State var url: URL
    let title: String
    let subtitle: String?
    let availableStreams: [HarborRankedStream]
    let previewItem: StremioMetaPreview

    @State private var player: AVPlayer = AVPlayer()
    @State private var currentSeconds: Double = 0
    @State private var durationSeconds: Double = 1
    @State private var showStreamSwitcher: Bool = false
    @State private var showSkipIntroBanner: Bool = false

    // Simulated AniSkip / Intro segment window (15s to 85s)
    private let introStart: Double = 15
    private let introEnd: Double = 85

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            VideoPlayer(player: player)
                .ignoresSafeArea()

            // Top HUD Overlay
            HStack(spacing: 14) {
                Button {
                    saveProgressAndDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                Spacer()

                // In-Player Stream Switcher Button (Harbor Feature)
                Button {
                    showStreamSwitcher.toggle()
                } label: {
                    Label("تغيير المصدر", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .background(
                LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom)
            )

            // Skip Intro Button (AniSkip / Chapter Marker Integration)
            if showSkipIntroBanner {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            let target = CMTime(seconds: introEnd, preferredTimescale: 600)
                            player.seek(to: target)
                            showSkipIntroBanner = false
                        } label: {
                            Label("تخطي المقدمة (Skip Intro)", systemImage: "forward.end.fill")
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(store.theme.accent)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                                .shadow(radius: 8)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 90)
                    }
                }
            }
        }
        .onAppear {
            startPlayback(with: url)
        }
        .onDisappear {
            player.pause()
        }
        .sheet(isPresented: $showStreamSwitcher) {
            NavigationStack {
                List(availableStreams) { candidate in
                    Button {
                        if let nextURL = candidate.playableHTTPURL {
                            url = nextURL
                            startPlayback(with: nextURL)
                            showStreamSwitcher = false
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(candidate.tier.rawValue) • \(candidate.addonName)")
                                    .font(.subheadline.weight(.bold))
                                Text(candidate.raw.title ?? candidate.raw.name ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if candidate.playableHTTPURL == url {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(store.theme.accent)
                            }
                        }
                    }
                }
                .navigationTitle("تبديل مصدر البث الفوري")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
    }

    private func startPlayback(with streamURL: URL) {
        let item = AVPlayerItem(url: streamURL)
        player.replaceCurrentItem(with: item)
        player.play()

        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let secs = CMTimeGetSeconds(time)
            guard secs.isFinite else { return }
            currentSeconds = secs
            if let d = player.currentItem?.duration, CMTimeGetSeconds(d).isFinite && CMTimeGetSeconds(d) > 0 {
                durationSeconds = CMTimeGetSeconds(d)
            }
            showSkipIntroBanner = (secs >= introStart && secs <= introEnd)
        }
    }

    private func saveProgressAndDismiss() {
        player.pause()
        store.updateWatchProgress(
            item: previewItem,
            subtitle: subtitle,
            streamURL: url.absoluteString,
            position: currentSeconds,
            duration: max(durationSeconds, 1)
        )
        dismiss()
    }
}

// MARK: - 14. Harbor Music & Audio Room (iTunes Catalog + Live Stations + LRCLIB Synced Lyrics)

struct HarborMusicRoomView: View {
    @EnvironmentObject var store: HarborStore
    @EnvironmentObject var audioManager: HarborAudioPlayerManager
    @State private var searchQuery: String = ""
    @State private var customStreamTitle: String = ""
    @State private var customStreamURL: String = ""
    @State private var showAddCustomStreamSheet: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Live Radio & Ambient Soundscapes
                    VStack(alignment: .leading, spacing: 12) {
                        HarborSectionHeader(title: "إذاعات Harbor المباشرة (24/7 Audio Streams)", icon: "dot.radiowaves.left.and.right")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(store.featuredStations) { station in
                                    Button {
                                        audioManager.play(track: station, queue: store.featuredStations)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ZStack {
                                                LinearGradient(
                                                    colors: [store.theme.accent.opacity(0.6), store.theme.backgroundSecondary],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                                Image(systemName: "waveform.badge.magnifyingglass")
                                                    .font(.largeTitle)
                                                    .foregroundStyle(.white)
                                            }
                                            .frame(width: 170, height: 110)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))

                                            Text(station.title)
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            Text(station.genre ?? "Live Radio")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(width: 170)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // Search Results / Music Tracks List
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HarborSectionHeader(title: "مكتبة الموسيقى والمقاطع الصوتية", icon: "music.note.list")
                            if store.isLoadingMusic {
                                ProgressView().padding(.trailing, 16)
                            }
                        }

                        VStack(spacing: 10) {
                            ForEach(store.musicTracks) { track in
                                HarborMusicTrackRow(
                                    track: track,
                                    isCurrent: audioManager.currentTrack?.id == track.id,
                                    isPlaying: audioManager.isPlaying
                                ) {
                                    audioManager.play(track: track, queue: store.musicTracks)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 110)
                }
                .padding(.top, 10)
            }
            .background(store.theme.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("موسيقى Harbor")
            .searchable(text: $searchQuery, prompt: "ابحث عن أغنية، فنان، أو موسيقى تصويرية...")
            .onSubmit(of: .search) {
                Task { await store.searchMusic(query: searchQuery) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCustomStreamSheet = true
                    } label: {
                        Label("إضافة رابط صوتي", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddCustomStreamSheet) {
                NavigationStack {
                    Form {
                        Section("إضافة بث صوتي مباشر (MP3 / AAC / FLAC / M3U8)") {
                            TextField("اسم المقطع أو الإذاعة", text: $customStreamTitle)
                            TextField("https://example.com/stream.mp3", text: $customStreamURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                        }
                    }
                    .navigationTitle("إضافة مصدر صوتي")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("إلغاء") { showAddCustomStreamSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("تشغيل وإضافة") {
                                guard !customStreamURL.isEmpty else { return }
                                let newTrack = HarborMusicTrack(
                                    id: UUID().uuidString,
                                    title: customStreamTitle.isEmpty ? "Custom Audio Stream" : customStreamTitle,
                                    artist: "Direct URL",
                                    album: "Harbor Audio",
                                    artworkURL: nil,
                                    streamURL: customStreamURL,
                                    durationSeconds: 180,
                                    genre: "Custom",
                                    isLiveStream: false
                                )
                                store.musicTracks.insert(newTrack, at: 0)
                                audioManager.play(track: newTrack, queue: store.musicTracks)
                                customStreamTitle = ""
                                customStreamURL = ""
                                showAddCustomStreamSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

struct HarborMusicTrackRow: View {
    @EnvironmentObject var store: HarborStore
    let track: HarborMusicTrack
    let isCurrent: Bool
    let isPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: track.artworkURL ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        ZStack {
                            store.theme.backgroundSecondary
                            Image(systemName: "music.note")
                                .foregroundStyle(store.theme.accent)
                        }
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isCurrent ? store.theme.accent : .white)
                        .lineLimit(1)
                    Text("\(track.artist) • \(track.album)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isCurrent {
                    Image(systemName: isPlaying ? "waveform" : "pause.fill")
                        .foregroundStyle(store.theme.accent)
                } else {
                    Image(systemName: "play.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(store.theme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct HarborMiniAudioPlayerBar: View {
    @EnvironmentObject var store: HarborStore
    @EnvironmentObject var audioManager: HarborAudioPlayerManager

    var body: some View {
        if let track = audioManager.currentTrack {
            HStack(spacing: 12) {
                Button {
                    audioManager.isShowingFullPlayer = true
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(store.theme.accent.opacity(0.2))
                            Image(systemName: "music.note")
                                .foregroundStyle(store.theme.accent)
                        }
                        .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    audioManager.togglePlayPause()
                } label: {
                    Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(store.theme.accent)
                }

                Button {
                    audioManager.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 12)
            .shadow(radius: 10)
        }
    }
}

struct HarborFullMusicPlayerSheet: View {
    @EnvironmentObject var store: HarborStore
    @EnvironmentObject var audioManager: HarborAudioPlayerManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                if let track = audioManager.currentTrack {
                    AsyncImage(url: URL(string: track.artworkURL ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            ZStack {
                                store.theme.backgroundSecondary
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 72))
                                    .foregroundStyle(store.theme.accent)
                            }
                        }
                    }
                    .frame(width: 240, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(radius: 16)

                    VStack(spacing: 6) {
                        Text(track.title)
                            .font(.title3.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundStyle(store.theme.accent)
                    }

                    // Progress Slider
                    if !track.isLiveStream {
                        VStack(spacing: 4) {
                            Slider(
                                value: Binding(
                                    get: { audioManager.currentTime },
                                    set: { audioManager.seek(to: $0) }
                                ),
                                in: 0...max(audioManager.duration, 1)
                            )
                            .tint(store.theme.accent)

                            HStack {
                                Text(formatTime(audioManager.currentTime))
                                Spacer()
                                Text(formatTime(audioManager.duration))
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Transport Controls
                    HStack(spacing: 38) {
                        Button { audioManager.playPrevious() } label: {
                            Image(systemName: "backward.fill").font(.title2)
                        }
                        Button { audioManager.togglePlayPause() } label: {
                            Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(store.theme.accent)
                        }
                        Button { audioManager.playNext() } label: {
                            Image(systemName: "forward.fill").font(.title2)
                        }
                    }
                    .foregroundStyle(.white)

                    // Synced Lyrics View (LRCLIB integration)
                    VStack(alignment: .leading, spacing: 8) {
                        Label("كلمات الأغنية المتزامنة (LRCLIB)", systemImage: "quote.bubble.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(store.theme.accent)

                        ScrollView {
                            if !audioManager.syncedLyrics.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(audioManager.syncedLyrics) { line in
                                        let isActive = abs(line.timestampSeconds - audioManager.currentTime) < 3.0
                                        Text(line.text)
                                            .font(isActive ? .headline.weight(.bold) : .subheadline)
                                            .foregroundStyle(isActive ? store.theme.accent : .white.opacity(0.65))
                                            .onTapGesture {
                                                audioManager.seek(to: line.timestampSeconds)
                                            }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else if let plain = audioManager.plainLyrics {
                                Text(plain)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                            } else {
                                Text("لا تتوفر كلمات متزامنة لهذا المقطع حالياً.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxHeight: 180)
                    }
                    .padding()
                    .background(store.theme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                }
                Spacer()
            }
            .padding(.top, 16)
            .background(store.theme.backgroundPrimary.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("إغلاق") { dismiss() }
                }
            }
        }
    }

    private func formatTime(_ secs: Double) -> String {
        let total = max(Int(secs), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - 15. Harbor Books & Ebooks Room (Open Library / Gutendex + Native eBook Reader)

struct HarborBooksRoomView: View {
    @EnvironmentObject var store: HarborStore
    @State private var searchQuery: String = ""
    @State private var selectedBook: HarborBookItem? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        HarborSectionHeader(title: "مكتبة الكتب المفتوحة (Open Library & Gutenberg)", icon: "book.closed.fill")
                        if store.isLoadingBooks {
                            ProgressView().padding(.trailing, 16)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(store.booksCatalog) { book in
                            Button {
                                selectedBook = book
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    AsyncImage(url: URL(string: book.coverURL ?? "")) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        default:
                                            ZStack {
                                                store.theme.backgroundSecondary
                                                Image(systemName: "book.fill")
                                                    .font(.largeTitle)
                                                    .foregroundStyle(store.theme.accent)
                                            }
                                        }
                                    }
                                    .frame(height: 210)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                    Text(book.title)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)

                                    Text(book.authorLine)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 90)
                }
                .padding(.top, 10)
            }
            .background(store.theme.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("كتب Harbor")
            .searchable(text: $searchQuery, prompt: "ابحث عن كتاب أو مؤلف في المكتبة المفتوحة...")
            .onSubmit(of: .search) {
                Task { await store.loadBooksCatalog(query: searchQuery) }
            }
            .sheet(item: $selectedBook) { book in
                HarborBookReaderView(book: book)
                    .environmentObject(store)
            }
        }
    }
}

enum ReaderPaperTheme: String, CaseIterable, Identifiable {
    case harborDark = "Harbor Dark"
    case sepia = "Sepia"
    case nightOLED = "OLED Night"
    case paperLight = "Paper"

    var id: String { rawValue }

    var backgroundColor: Color {
        switch self {
        case .harborDark: return Color(red: 0.06, green: 0.08, blue: 0.13)
        case .sepia:      return Color(red: 0.95, green: 0.91, blue: 0.82)
        case .nightOLED:  return Color.black
        case .paperLight: return Color(red: 0.98, green: 0.98, blue: 0.97)
        }
    }

    var textColor: Color {
        switch self {
        case .harborDark, .nightOLED: return Color.white.opacity(0.92)
        case .sepia:                  return Color(red: 0.24, green: 0.18, blue: 0.12)
        case .paperLight:             return Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }
}

struct HarborBookReaderView: View {
    @EnvironmentObject var store: HarborStore
    @Environment(\.dismiss) private var dismiss

    let book: HarborBookItem
    @State private var currentChapterIndex: Int = 0
    @State private var fontSize: CGFloat = 19
    @State private var paperTheme: ReaderPaperTheme = .harborDark
    @State private var fetchedFullText: String? = nil
    @State private var isLoadingFullText: Bool = false

    private var activeChapter: HarborBookChapter {
        let chapters = book.sampleChapters
        guard chapters.indices.contains(currentChapterIndex) else {
            return HarborBookChapter(number: 1, title: book.title, body: book.description ?? "")
        }
        return chapters[currentChapterIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Reader Customization Bar
                HStack(spacing: 12) {
                    Picker("المظهر", selection: $paperTheme) {
                        ForEach(ReaderPaperTheme.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper("", value: $fontSize, in: 14...28, step: 2)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(store.theme.backgroundSecondary)

                // Book Text Canvas
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(book.title)
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(paperTheme.textColor)

                        Text(book.authorLine)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Divider()

                        if let fullText = fetchedFullText {
                            Text(fullText)
                                .font(.system(size: fontSize, design: .serif))
                                .foregroundStyle(paperTheme.textColor)
                                .lineSpacing(8)
                        } else {
                            Text(activeChapter.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(paperTheme.textColor)

                            Text(activeChapter.body)
                                .font(.system(size: fontSize, design: .serif))
                                .foregroundStyle(paperTheme.textColor)
                                .lineSpacing(8)
                        }

                        if let txtURL = book.textContentURL, fetchedFullText == nil {
                            Button {
                                Task { await downloadFullGutenbergText(from: txtURL) }
                            } label: {
                                HStack {
                                    if isLoadingFullText {
                                        ProgressView().tint(.black)
                                    }
                                    Text("تحميل النص الكامل للكتاب من Gutenberg")
                                        .font(.subheadline.weight(.bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(store.theme.accent)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.top, 12)
                        }
                    }
                    .padding(22)
                }
                .background(paperTheme.backgroundColor.ignoresSafeArea())

                // Chapter Navigation Footer
                if fetchedFullText == nil && book.sampleChapters.count > 1 {
                    HStack {
                        Button {
                            if currentChapterIndex > 0 { currentChapterIndex -= 1 }
                        } label: {
                            Label("الفصل السابق", systemImage: "chevron.right")
                        }
                        .disabled(currentChapterIndex == 0)

                        Spacer()
                        Text("فصل \(currentChapterIndex + 1) من \(book.sampleChapters.count)")
                            .font(.caption.weight(.semibold))
                        Spacer()

                        Button {
                            if currentChapterIndex + 1 < book.sampleChapters.count { currentChapterIndex += 1 }
                        } label: {
                            Label("الفصل التالي", systemImage: "chevron.left")
                        }
                        .disabled(currentChapterIndex + 1 >= book.sampleChapters.count)
                    }
                    .padding(14)
                    .background(store.theme.backgroundSecondary)
                }
            }
            .navigationTitle("قارئ الكتب")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("إغلاق") { dismiss() }
                }
            }
        }
    }

    private func downloadFullGutenbergText(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        isLoadingFullText = true
        defer { isLoadingFullText = false }
        if let (data, _) = try? await URLSession.shared.data(from: url),
           let str = String(data: data, encoding: .utf8) {
            // Trim to first 25,000 characters for smooth mobile rendering
            fetchedFullText = String(str.prefix(25_000))
        }
    }
}

// MARK: - 16. Stremio Addons Room (Install by URL / Deep Link, Browse Community Index)

struct HarborAddonsRoomView: View {
    @EnvironmentObject var store: HarborStore
    @State private var addonURLInput: String = ""
    @State private var isInstalling: Bool = false
    @State private var errorMsg: String? = nil

    private let communityFeaturedAddons: [(name: String, desc: String, url: String)] = [
        ("Cinemeta Official", "الكتالوج الرسمي للأفلام والمسلسلات في Stremio", "https://v3-cinemeta.strem.io/manifest.json"),
        ("OpenSubtitles v3", "ترجمات متعددة اللغات للأفلام والمسلسلات", "https://opensubtitles-v3.strem.io/manifest.json"),
        ("WatchHub", "روابط المشاهدة الرسمية عبر المنصات العالمية", "https://watchhub.strem.io/manifest.json")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("إضافة Stremio Addon عبر الرابط (URL / manifest.json)") {
                    HStack {
                        TextField("https://.../manifest.json أو stremio://", text: $addonURLInput)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button {
                            Task { await installFromInput() }
                        } label: {
                            if isInstalling {
                                ProgressView()
                            } else {
                                Text("تثبيت")
                                    .fontWeight(.bold)
                            }
                        }
                        .disabled(addonURLInput.trimmingCharacters(in: .whitespaces).isEmpty || isInstalling)
                    }

                    if let err = errorMsg {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("الإضافات المثبتة حالياً (\(store.installedAddons.count))") {
                    ForEach(store.installedAddons) { addon in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(addon.name)
                                    .font(.headline)
                                Spacer()
                                Text("v\(addon.version)")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(store.theme.accent.opacity(0.2))
                                    .foregroundStyle(store.theme.accent)
                                    .clipShape(Capsule())
                            }
                            if let desc = addon.description {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let types = addon.types, !types.isEmpty {
                                Text("الأنواع المدعومة: \(types.joined(separator: "، "))")
                                    .font(.caption2)
                                    .foregroundStyle(store.theme.accent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        store.installedAddons.remove(atOffsets: offsets)
                    }
                }

                Section("دليل إضافات المجتمع (stremio-addons.net)") {
                    ForEach(communityFeaturedAddons, id: \.url) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).font(.subheadline.weight(.bold))
                                Text(item.desc).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("إضافة") {
                                addonURLInput = item.url
                                Task { await installFromInput() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(store.theme.accent)
                            .foregroundStyle(.black)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(store.theme.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("إضافات Stremio")
        }
    }

    private func installFromInput() async {
        errorMsg = nil
        isInstalling = true
        defer { isInstalling = false }
        do {
            try await store.installAddon(from: addonURLInput)
            addonURLInput = ""
        } catch {
            errorMsg = "تعذر تحميل ملف manifest.json من الرابط المدخل."
        }
    }
}

// MARK: - 17. Settings & Theme Studio Room (Debrid Keys, TMDB, Safety Filter, Themes)

struct HarborSettingsRoomView: View {
    @EnvironmentObject var store: HarborStore

    var body: some View {
        NavigationStack {
            Form {
                Section("استوديو الثيمات (Harbor Theme Engine)") {
                    Picker("الثيم النشط", selection: $store.selectedThemeRaw) {
                        ForEach(HarborThemePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset.rawValue)
                        }
                    }
                }

                Section("خدمات البث المباشر (Debrid HTTP/HLS Integration)") {
                    Picker("مزود Debrid الافتراضي", selection: $store.debridProviderRaw) {
                        ForEach(DebridProviderType.allCases) { provider in
                            Text(provider.rawValue).tag(provider.rawValue)
                        }
                    }

                    SecureField("مفتاح Real-Debrid API Token", text: $store.realDebridToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("مفتاح TorBox API Key", text: $store.torBoxKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("يتم حفظ المفاتيح محلياً على جهازك فقط دون إرسالها لأي خادم خارجي، وتُستخدم لتحويل ملفات التورنت إلى روابط HTTP/HLS مباشرة تعمل داخل مشغل نظام iOS (AVPlayer).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("محرك الأمان والترتيب (Harbor Stream Engine)") {
                    Picker("فلتر أمان البث (Stream Safety)", selection: $store.safetyFilterRaw) {
                        ForEach(StreamSafetyFilter.allCases) { filter in
                            Text(filter.localizedTitle).tag(filter.rawValue)
                        }
                    }
                }

                Section("مفاتيح البيانات الوصفية (TMDB & RPDB)") {
                    SecureField("مفتاح TMDB API Key (اختياري)", text: $store.tmdbAPIKey)
                        .textInputAutocapitalization(.never)
                    SecureField("مفتاح RPDB API Key (اختياري)", text: $store.rpdbKey)
                        .textInputAutocapitalization(.never)
                }

                Section("حول Harbor لنظام iOS") {
                    LabeledContent("المعمارية", value: "SwiftUI + AVKit + HarborStreamEngine")
                    LabeledContent("البروتوكول", value: "Stremio Addon Protocol v3")
                    LabeledContent("المشغل", value: "Native iOS AVPlayer (HLS / HTTP / PiP)")
                    LabeledContent("الترخيص", value: "MIT Open Source")
                }
            }
            .scrollContentBackground(.hidden)
            .background(store.theme.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("الإعدادات")
        }
    }
}

// MARK: - 18. App Entry Point

@main
struct HarborIOSApp: App {
    var body: some Scene {
        WindowGroup {
            HarborIOSRootView()
        }
    }
}

#Preview {
    HarborIOSRootView()
}
