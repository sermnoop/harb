import SwiftUI
import UIKit
import AVKit
import WebKit
import PDFKit
import UniformTypeIdentifiers

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
    @State private var isTabBarHidden: Bool = false

    public init() { HarborFontRegistry.registerCustomFontIfNeeded() }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea(.all)
            if audioManager.isUsingWebAudioFallback, let vid = audioManager.activeYouTubeVideoID {
                HarborHiddenWebAudioBridge(videoID: vid, isPlaying: audioManager.isPlaying)
                    .frame(width: 48, height: 48)
                    .opacity(0.02)
            }
            Group {
                switch selectedTab {
                case .home:
                    HarborHomeRoomView(onAvatarTap: { selectedTab = .settings })
                case .discover:
                    HarborCatalogRoomView()
                case .music:
                    HarborMusicRoomView()
                case .books:
                    HarborBooksRoomView()
                case .addons:
                    HarborAddonsRoomView()
                case .settings:
                    HarborSettingsRoomView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        let dy = value.translation.height
                        if dy < -20 && !isTabBarHidden {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                                isTabBarHidden = true
                            }
                        } else if dy > 15 && isTabBarHidden {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                                isTabBarHidden = false
                            }
                        }
                    }
            )

            VStack(spacing: 10) {
                if audioManager.currentTrack != nil {
                    HStack(spacing: 10) {
                        if isTabBarHidden {
                            Button {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                                    selectedTab = .discover
                                    isTabBarHidden = false
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.harbor(size: 17, weight: .bold))
                                    .foregroundStyle(store.theme.accent)
                                    .frame(width: 46, height: 46)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                            }
                            .buttonStyle(SmoothPressButtonStyle())
                            .transition(.scale.combined(with: .opacity))
                        }

                        HarborMiniAudioPlayerBar()

                        if isTabBarHidden {
                            Button {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                                    isTabBarHidden = false
                                }
                            } label: {
                                Image(systemName: "house.fill")
                                    .font(.harbor(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 46, height: 46)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                            }
                            .buttonStyle(SmoothPressButtonStyle())
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, isTabBarHidden ? 14 : 0)
                }

                if !isTabBarHidden {
                    HarborFloatingTabBar(selectedTab: $selectedTab)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 6)
            .animation(.spring(response: 0.36, dampingFraction: 0.82), value: isTabBarHidden)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environmentObject(store)
        .environmentObject(audioManager)
        .environment(\.font, Font.custom(HarborFontRegistry.postScriptName, size: 16))
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $audioManager.isShowingFullPlayer) {
            HarborFullMusicPlayerSheet()
                .environmentObject(store)
                .environmentObject(audioManager)
                .environment(\.font, Font.custom(HarborFontRegistry.postScriptName, size: 16))
        .preferredColorScheme(.dark)
        }
    }
}

struct HarborHomeRoomView: View {
    @EnvironmentObject var store: HarborStore
    var onAvatarTap: () -> Void = {}
    @State private var activeHeroIndex: Int = 0
    @State private var selectedItem: StremioMetaPreview? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if !store.heroItems.isEmpty {
                            VStack(spacing: 0) {
                                TabView(selection: $activeHeroIndex) {
                                    ForEach(Array(store.heroItems.enumerated()), id: \.element.id) { index, item in
                                        HarborHeroBannerCard(item: item) {
                                            selectedItem = item
                                        }
                                        .tag(index)
                                    }
                                }
                                .frame(maxWidth: .infinity).frame(height: 500)
                                .tabViewStyle(.page(indexDisplayMode: .never))

                                HarborCurvedWaveDivider()
                                    .offset(y: -10)

                                HStack(spacing: 6) {
                                    ForEach(0..<store.heroItems.count, id: \.self) { idx in
                                        Capsule()
                                            .fill(idx == activeHeroIndex ? Color.white : Color.white.opacity(0.25))
                                            .frame(width: idx == activeHeroIndex ? 22 : 6, height: 3)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: activeHeroIndex)
                                    }
                                }
                                .padding(.top, 2)
                                .padding(.bottom, 8)
                            }
                        }

                        if !store.continueWatching.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HarborSectionHeader(title: "Continue Watching · متابعة المشاهدة", icon: "play.circle.fill")
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

                        HarborPosterRail(
                            title: "Latest Movies · Movies",
                            icon: "film.fill",
                            items: store.trendingMovies
                        ) { item in
                            selectedItem = item
                        }

                        HarborPosterRail(
                            title: "Latest Series · TV Shows",
                            icon: "tv.fill",
                            items: store.trendingSeries
                        ) { item in
                            selectedItem = item
                        }

                        HarborPosterRail(
                            title: "Top Anime · غرفة الأنمي",
                            icon: "sparkles",
                            items: store.animeCatalog
                        ) { item in
                            selectedItem = item
                        }

                        Spacer(minLength: 120)
                    }
                    .frame(maxWidth: .infinity)
                }
                .ignoresSafeArea(edges: [.top, .horizontal])

                HStack {
                    Button(action: onAvatarTap) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.55))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(SmoothPressButtonStyle())

                    Spacer()

                    HStack(spacing: 8) {
                        Text("Harbor")
                            .font(.harbor(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Image(systemName: "sailboat.fill")
                            .font(.harbor(size: 19, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .environment(\.layoutDirection, .leftToRight)
            }
            .toolbar(.hidden, for: .navigationBar)
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
        GeometryReader { bannerGeo in
            let cardW = max(bannerGeo.size.width, 320)
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: item.background ?? item.poster ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: cardW, height: 500)
                            .clipped()
                    default:
                        LinearGradient(
                            colors: [Color(white: 0.20), Color(white: 0.07), Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: cardW, height: 500)
                    }
                }
                .frame(width: cardW, height: 500)
                .clipped()

                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.45), location: 0.0),
                        .init(color: Color.clear, location: 0.35),
                        .init(color: Color.black.opacity(0.78), location: 0.82),
                        .init(color: Color.black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: cardW, height: 500)

            VStack(alignment: .leading, spacing: 12) {
                let firstGenre = item.genres?.first ?? (item.type == "series" ? "Drama" : "Action")
                Text("\(item.type == "series" ? "Series" : "Movie") · \(firstGenre)")
                    .font(.harborSubheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))

                Text(item.name)
                    .font(.harbor(size: 38, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 22) {
                    Button(action: onSelect) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.harborSubheadline.weight(.black))
                            Text("Play")
                                .font(.harborHeadline.weight(.bold))
                        }
                        .frame(width: 132, height: 48)
                        .background(Color.white)
                        .foregroundStyle(Color.black)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(SmoothPressButtonStyle())

                    Button(action: onSelect) {
                        Text("Trailer")
                            .font(.harborHeadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(SmoothPressButtonStyle())
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
            .frame(width: cardW, alignment: .leading)
            .environment(\.layoutDirection, .leftToRight)
            }
            .frame(width: cardW, height: 500)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 500)
    }
}

struct HarborSectionHeader: View {
    @EnvironmentObject var store: HarborStore
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.harborTitle3.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 16)
        .environment(\.layoutDirection, .leftToRight)
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
                HStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        HarborPosterCard(item: item, rankBadge: "#\(idx + 1) Today") {
                            onSelect(item)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

struct HarborPosterCard: View {
    @EnvironmentObject var store: HarborStore
    let item: StremioMetaPreview
    var rankBadge: String? = "#1 Today"
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .top) {
                AsyncImage(url: URL(string: item.poster ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 126, height: 192)
                            .clipped()
                    default:
                        ZStack {
                            Color(white: 0.07)
                            Image(systemName: "film")
                                .font(.harborTitle)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .frame(width: 126, height: 192)
                    }
                }
                .frame(width: 126, height: 192)

                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 126, height: 192)

                if let badge = rankBadge {
                    Text(badge)
                        .font(.harbor(size: 10, weight: .bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Color(white: 0.12).opacity(0.92))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(.top, 6)
                }

                VStack(spacing: 3) {
                    Spacer()
                    Text(item.name.uppercased())
                        .font(.harbor(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)

                    let genre = item.genres?.first ?? (item.type == "series" ? "Drama" : "Action")
                    let rating = item.imdbRating ?? "7.8"
                    HStack(spacing: 3) {
                        Text("\(genre) ·")
                        Image(systemName: "star.fill")
                            .font(.harbor(size: 8))
                        Text(rating)
                    }
                    .font(.harbor(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.bottom, 8)
                }
                .frame(width: 126, height: 192)
            }
            .frame(width: 126, height: 192)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
        }
        .buttonStyle(SmoothPressButtonStyle())
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
                    .font(.harbor(size: 68, weight: .black, design: .rounded))
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
                                .font(.harborCaption)
                                .padding(8)
                                .background(store.theme.accent)
                                .foregroundStyle(.black)
                                .clipShape(Circle())
                            if item.isCompleted {
                                Text("مكتمل 85%+")
                                    .font(.harborCaption2.weight(.bold))
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
                    .font(.harborCaption.weight(.bold))
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
                                    .font(.harborCaption.weight(.semibold))
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
            .background(LinearGradient(colors: [Color(white: 0.14).opacity(0.45), Color.black, Color.black], startPoint: .top, endPoint: .bottom).ignoresSafeArea(.all))
            .navigationTitle("استكشاف الكتالوج")
            .searchable(text: $searchText, prompt: "ابحث عن فيلم، مسلسل، أو أنمي...")
            .onSubmit(of: .search) { Task { await store.searchCatalogOnline(query: searchText) } }
            .onChange(of: searchText) { _, q in if q.count >= 3 { Task { await store.searchCatalogOnline(query: q) } } }
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
    @State private var selectedSeason: Int = 1
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
        let episodeId: String?
        let episodeList: [StremioEpisodeVideo]
        let initialPositionSeconds: Double
    }

    private var availableSeasons: [Int] {
        guard let videos = detail?.videos, !videos.isEmpty else { return [] }
        let seasons = Set(videos.map { max($0.season ?? 1, 1) })
        return seasons.sorted()
    }

    private var episodesForSelectedSeason: [StremioEpisodeVideo] {
        guard let videos = detail?.videos else { return [] }
        if availableSeasons.count <= 1 { return videos }
        return videos.filter { max($0.season ?? 1, 1) == selectedSeason }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero Backdrop Header
                ZStack(alignment: .bottomLeading) {
                    GeometryReader { heroGeo in
                        AsyncImage(url: URL(string: detail?.background ?? preview.background ?? preview.poster ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: max(heroGeo.size.width, 320), height: 300)
                                    .clipped()
                            default:
                                LinearGradient(
                                    colors: [Color(white: 0.18), Color.black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(width: max(heroGeo.size.width, 320), height: 300)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipped()

                    LinearGradient(
                        colors: [.clear, store.theme.backgroundPrimary],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        if let awards = detail?.awards, !awards.isEmpty {
                            Label(awards, systemImage: "laurel.leading")
                                .font(.harborCaption2.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.yellow.opacity(0.2))
                                .foregroundStyle(.yellow)
                                .clipShape(Capsule())
                        }

                        Text(detail?.name ?? preview.name)
                            .font(.harborTitle.weight(.heavy))
                            .foregroundStyle(.white)

                        HStack(spacing: 12) {
                            if let rating = detail?.imdbRating ?? preview.imdbRating {
                                Label("IMDb \(rating)", systemImage: "star.fill")
                                    .font(.harborCaption.weight(.bold))
                                    .foregroundStyle(.yellow)
                            }
                            if let year = detail?.releaseInfo ?? preview.releaseInfo {
                                Text(year)
                                    .font(.harborCaption)
                                    .foregroundStyle(.secondary)
                            }
                            if let runtime = detail?.runtime {
                                Text(runtime)
                                    .font(.harborCaption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                store.toggleWatchlist(preview)
                            } label: {
                                let inList = store.isInWatchlist(preview)
                                Label(inList ? "في قائمتي" : "أضف لقائمتي", systemImage: inList ? "bookmark.fill" : "bookmark")
                                    .font(.harborCaption.weight(.bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(inList ? store.theme.accent : Color.white.opacity(0.14))
                                    .foregroundStyle(inList ? Color.black : Color.white)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(SmoothPressButtonStyle())
                        }
                    }
                    .padding(16)
                }

                // Synopsis, Cast & Metadata
                VStack(alignment: .leading, spacing: 12) {
                    if let savedProg = store.savedWatchProgress(for: preview.id),
                       let savedURL = URL(string: savedProg.streamURL) {
                        Button {
                            activePlayerConfig = ActiveVideoPlaybackConfig(
                                url: savedURL,
                                title: preview.name,
                                subtitle: savedProg.subtitle,
                                allStreams: rankedStreams,
                                previewItem: preview,
                                episodeId: selectedEpisode?.id,
                                episodeList: detail?.videos ?? [],
                                initialPositionSeconds: savedProg.positionSeconds
                            )
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "play.circle.fill")
                                    .font(.harborTitle3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("استئناف المشاهدة من \(Int(savedProg.positionSeconds) / 60):\(String(format: "%02d", Int(savedProg.positionSeconds) % 60))")
                                        .font(.harborSubheadline.weight(.bold))
                                    Text("تقدم المحفوظ: \(Int(savedProg.progressFraction * 100))%")
                                        .font(.harborCaption2)
                                        .foregroundStyle(.black.opacity(0.75))
                                }
                                Spacer()
                                Image(systemName: "arrow.left")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(store.theme.accent)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(SmoothPressButtonStyle())
                    }

                    if let desc = detail?.description ?? preview.description {
                        Text(desc)
                            .font(.harborSubheadline)
                            .foregroundStyle(.white.opacity(0.88))
                            .lineSpacing(4)
                    }

                    if let cast = detail?.cast, !cast.isEmpty {
                        Text("البطولة: \(cast.prefix(5).joined(separator: " • "))")
                            .font(.harborCaption)
                            .foregroundStyle(.secondary)
                    }

                    if let genres = detail?.genres ?? preview.genres, !genres.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(genres, id: \.self) { g in
                                    Text(g)
                                        .font(.harborCaption2.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(store.theme.backgroundSecondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Season & Episodes Picker (if Series / Anime)
                    if let videos = detail?.videos, !videos.isEmpty {
                        Divider().overlay(.white.opacity(0.1))
                        HStack {
                            Text("المواسم والحلقات (\(videos.count) حلقة)")
                                .font(.harborHeadline)
                            Spacer()
                            if availableSeasons.count > 1 {
                                Picker("الموسم", selection: $selectedSeason) {
                                    ForEach(availableSeasons, id: \.self) { s in
                                        Text("الموسم \(s)").tag(s)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(store.theme.accent)
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(episodesForSelectedSeason.prefix(50)) { ep in
                                    let isSelected = selectedEpisode?.id == ep.id
                                    Button {
                                        selectedEpisode = ep
                                        Task { await reloadStreams(episodeId: ep.id) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(ep.displayTitle)
                                                .font(.harborCaption.weight(.bold))
                                                .lineLimit(1)
                                            if let overview = ep.overview {
                                                Text(overview)
                                                    .font(.harborCaption2)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }
                                        }
                                        .frame(width: 175, alignment: .leading)
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
                            if let firstStream = rankedStreams.first {
                                Button {
                                    Task { await launchStream(firstStream) }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "play.fill")
                                        Text("تشغيل فوري الآن (Play Best Server)")
                                            .font(.harborHeadline.weight(.bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .foregroundStyle(Color.black)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(SmoothPressButtonStyle())
                                .padding(.bottom, 8)
                            }
                            Text("مصادر البث المصنفة (Harbor Stream Engine)")
                                .font(.harborHeadline)
                            Text("Pipeline: Parse → Trust (\(store.safetyFilter.rawValue)) → Score → Rank • \(store.debridProvider.rawValue)")
                                .font(.harborCaption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isLoadingStreams || isResolvingDebrid {
                            ProgressView()
                                .tint(store.theme.accent)
                        }
                    }

                    if rankedStreams.isEmpty && !isLoadingStreams {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("لم يتم العثور على مصادر بث متوافقة مع إعدادات الأمان الحالية.")
                                .font(.harborSubheadline)
                                .foregroundStyle(.secondary)
                            Button("إعادة المحاولة") {
                                Task { await reloadStreams(episodeId: selectedEpisode?.id) }
                            }
                            .font(.harborCaption.weight(.bold))
                            .foregroundStyle(store.theme.accent)
                        }
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
        .background(LinearGradient(colors: [Color(white: 0.14).opacity(0.45), Color.black, Color.black], startPoint: .top, endPoint: .bottom).ignoresSafeArea(.all))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            self.detail = await store.fetchMetaDetail(for: preview)
            if let firstEp = detail?.videos?.first {
                selectedSeason = max(firstEp.season ?? 1, 1)
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
                previewItem: config.previewItem,
                episodeId: config.episodeId,
                episodeList: config.episodeList,
                initialPositionSeconds: config.initialPositionSeconds
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
            let resumeSecs = store.savedWatchProgress(for: preview.id)?.positionSeconds ?? 0
            activePlayerConfig = ActiveVideoPlaybackConfig(
                url: playableURL,
                title: preview.name,
                subtitle: selectedEpisode?.displayTitle ?? stream.tier.rawValue,
                allStreams: rankedStreams,
                previewItem: preview,
                episodeId: selectedEpisode?.id,
                episodeList: detail?.videos ?? [],
                initialPositionSeconds: resumeSecs
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
                            .font(.harborCaption.weight(.black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(stream.isCachedDebrid ? store.theme.accent : Color.gray.opacity(0.3))
                            .foregroundStyle(stream.isCachedDebrid ? .black : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("نقاط \(stream.score)")
                            .font(.harbor(size: 10, weight: .bold))
                            .foregroundStyle(store.theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            if let badge = stream.debridBadge {
                                Text(badge)
                                    .font(.harborCaption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.green.opacity(0.25))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                            }
                            Text(stream.addonName)
                                .font(.harborCaption.weight(.bold))
                                .foregroundStyle(.white)
                            if let size = stream.fileSizeDisplay {
                                Text("• \(size)")
                                    .font(.harborCaption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(stream.raw.title ?? stream.raw.name ?? "Stream")
                            .font(.harborCaption)
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
                        .font(.harborTitle2)
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
                    .font(.harborCaption2)
                    .foregroundStyle(.secondary)
                }

                if showScoreDetails {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(stream.scoreReasons, id: \.self) { reason in
                            Text("• \(reason)")
                                .font(.harborCaption2)
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
            .font(.harbor(size: 10, weight: .semibold))
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
    @State var subtitle: String?
    let availableStreams: [HarborRankedStream]
    let previewItem: StremioMetaPreview
    @State var episodeId: String? = nil
    var episodeList: [StremioEpisodeVideo] = []
    var initialPositionSeconds: Double = 0

    @State private var player: AVPlayer = AVPlayer()
    @State private var timeObserverToken: Any? = nil
    @State private var statusObservation: NSKeyValueObservation? = nil
    @State private var currentSeconds: Double = 0
    @State private var durationSeconds: Double = 1
    @State private var isPlaying: Bool = true
    @State private var isBuffering: Bool = false
    @State private var playbackSpeed: Float = 1.0
    @State private var showControlsHUD: Bool = true
    @State private var showStreamSwitcher: Bool = false
    @State private var showSubtitleSheet: Bool = false
    @State private var showSubtitleFileImporter: Bool = false
    @State private var showSkipIntroBanner: Bool = false
    @State private var streamErrorBanner: String? = nil

    @StateObject private var subtitleController = HarborSubtitleController()
    @State private var subtitlePrefs: HarborSubtitlePreferences = HarborSubtitlePreferences.load()

    private let introStart: Double = 15
    private let introEnd: Double = 85

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HarborSmartVideoContainer(url: url, player: player)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showControlsHUD.toggle()
                    }
                }

            // Synchronized Subtitle Overlay (External SRT / WebVTT / ASS-SSA with RTL & 12 Customization Options)
            HarborSubtitleOverlayView(
                cue: subtitleController.activeCue,
                preferences: subtitlePrefs
            )

            if isBuffering {
                ProgressView("جاري التحميل والمزامنة...")
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if let err = streamErrorBanner {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.harborTitle2)
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.harborCaption)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Button("تبديل لمصدر بث آخر") {
                        showStreamSwitcher = true
                    }
                    .font(.harborCaption.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(store.theme.accent)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
                }
                .padding(18)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(24)
            }

            VStack(spacing: 0) {
                // Top HUD Overlay
                if showControlsHUD {
                    HStack(spacing: 12) {
                        Button {
                            saveProgressAndDismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.harborTitle2)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.harborHeadline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if let subtitle = subtitle {
                                Text(subtitle)
                                    .font(.harborCaption)
                                    .foregroundStyle(.white.opacity(0.75))
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        HarborAirPlayRoutePicker()
                            .frame(width: 34, height: 34)

                        Button {
                            showSubtitleSheet = true
                        } label: {
                            Label("الترجمة", systemImage: "captions.bubble.fill")
                                .font(.harborCaption.weight(.bold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(subtitlePrefs.isEnabled ? store.theme.accent : Color.white.opacity(0.18))
                                .foregroundStyle(subtitlePrefs.isEnabled ? .black : .white)
                                .clipShape(Capsule())
                        }

                        Button {
                            showStreamSwitcher.toggle()
                        } label: {
                            Label("المصدر", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.harborCaption.weight(.bold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(.ultraThinMaterial)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(colors: [.black.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom)
                    )
                }

                Spacer()

                // Skip Intro Button
                if showSkipIntroBanner {
                    HStack {
                        Spacer()
                        Button {
                            let target = CMTime(seconds: introEnd, preferredTimescale: 600)
                            player.seek(to: target)
                            showSkipIntroBanner = false
                        } label: {
                            Label("تخطي المقدمة (Skip Intro)", systemImage: "forward.end.fill")
                                .font(.harborSubheadline.weight(.bold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 11)
                                .background(store.theme.accent)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                                .shadow(radius: 8)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 12)
                    }
                }

                // Bottom Custom Transport Controls HUD (Seek Bar, +-10s, Speed, Audio Track, Next Episode)
                if showControlsHUD && !HarborSmartVideoContainer.isEmbedURL(url) {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Text(formatVideoTime(currentSeconds))
                                .font(.harbor(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))

                            Slider(
                                value: Binding(
                                    get: { min(max(currentSeconds, 0), max(durationSeconds, 1)) },
                                    set: { newSec in
                                        currentSeconds = newSec
                                        let target = CMTime(seconds: newSec, preferredTimescale: 600)
                                        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
                                        subtitleController.updatePlaybackTime(newSec, preferences: subtitlePrefs)
                                    }
                                ),
                                in: 0...max(durationSeconds, 1)
                            )
                            .tint(store.theme.accent)

                            Text(formatVideoTime(durationSeconds))
                                .font(.harbor(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .environment(\.layoutDirection, .leftToRight)

                        HStack(spacing: 18) {
                            // Playback Speed Menu
                            Menu {
                                ForEach([Float(0.5), 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                                    Button("\(String(format: "%.2gx", rate))") {
                                        playbackSpeed = rate
                                        if isPlaying { player.rate = rate }
                                    }
                                }
                            } label: {
                                Text("\(String(format: "%.2gx", playbackSpeed))")
                                    .font(.harbor(size: 12, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.14))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }

                            // Audio Track Selector (if HLS/media exposes multiple audible tracks)
                            if !subtitleController.availableAudioTracks.isEmpty {
                                Menu {
                                    ForEach(subtitleController.availableAudioTracks, id: \.id) { track in
                                        Button(track.name) {
                                            subtitleController.selectAudioTrack(track.id, in: player.currentItem)
                                        }
                                    }
                                } label: {
                                    Label("الصوت", systemImage: "waveform")
                                        .font(.harborCaption.weight(.bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.14))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                            }

                            Spacer()

                            Button {
                                let target = max(currentSeconds - 10, 0)
                                player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
                            } label: {
                                Image(systemName: "gobackward.10")
                                    .font(.harborTitle3)
                                    .foregroundStyle(.white)
                            }

                            Button {
                                if isPlaying {
                                    player.pause()
                                    isPlaying = false
                                } else {
                                    player.play()
                                    player.rate = playbackSpeed
                                    isPlaying = true
                                }
                            } label: {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.harbor(size: 40))
                                    .foregroundStyle(store.theme.accent)
                            }

                            Button {
                                let target = min(currentSeconds + 10, max(durationSeconds, 1))
                                player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
                            } label: {
                                Image(systemName: "goforward.10")
                                    .font(.harborTitle3)
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            if let nextEp = nextEpisodeInList {
                                Button {
                                    Task { await switchToNextEpisode(nextEp) }
                                } label: {
                                    Label("الحلقة التالية", systemImage: "forward.end.alt.fill")
                                        .font(.harborCaption.weight(.bold))
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 6)
                                        .background(store.theme.accent)
                                        .foregroundStyle(.black)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                    )
                }
            }
        }
        .onAppear {
            startPlayback(with: url, resumeFromSeconds: initialPositionSeconds)
            Task {
                await subtitleController.fetchOpenSubtitles(
                    imdbID: previewItem.id,
                    type: previewItem.type,
                    episodeID: episodeId,
                    preferences: subtitlePrefs,
                    playerItem: player.currentItem
                )
            }
        }
        .onDisappear {
            cleanupPlayerObservers()
            player.pause()
        }
        .sheet(isPresented: $showSubtitleSheet) {
            HarborSubtitleCustomizationSheet(
                controller: subtitleController,
                preferences: $subtitlePrefs,
                playerItem: player.currentItem,
                onImportFileTapped: {
                    showSubtitleSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showSubtitleFileImporter = true
                    }
                }
            )
            .preferredColorScheme(.dark)
        }
        .fileImporter(
            isPresented: $showSubtitleFileImporter,
            allowedContentTypes: [.plainText, .data, .item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let pickedURL = urls.first {
                subtitleController.importSubtitleFile(from: pickedURL, playerItem: player.currentItem)
                subtitlePrefs.isEnabled = true
            }
        }
        .sheet(isPresented: $showStreamSwitcher) {
            NavigationStack {
                List(availableStreams) { candidate in
                    Button {
                        if let nextURL = candidate.playableHTTPURL {
                            let savedTime = currentSeconds
                            url = nextURL
                            startPlayback(with: nextURL, resumeFromSeconds: savedTime)
                            showStreamSwitcher = false
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(candidate.tier.rawValue) • \(candidate.addonName)")
                                    .font(.harborSubheadline.weight(.bold))
                                Text(candidate.raw.title ?? candidate.raw.name ?? "")
                                    .font(.harborCaption)
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
                .navigationTitle("تبديل مصدر البث (مع حفظ الموضع)")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
    }

    private var nextEpisodeInList: StremioEpisodeVideo? {
        guard let curID = episodeId,
              let idx = episodeList.firstIndex(where: { $0.id == curID }),
              idx + 1 < episodeList.count else { return nil }
        return episodeList[idx + 1]
    }

    private func switchToNextEpisode(_ nextEp: StremioEpisodeVideo) async {
        episodeId = nextEp.id
        subtitle = nextEp.displayTitle
        let nextStreams = await store.fetchAndRankStreams(for: previewItem, episodeId: nextEp.id)
        if let first = nextStreams.first,
           let nextURL = try? await DebridService.shared.resolvePlayableURL(
               for: first,
               provider: store.debridProvider,
               realDebridToken: store.realDebridToken,
               torBoxKey: store.torBoxKey
           ) {
            url = nextURL
            startPlayback(with: nextURL, resumeFromSeconds: 0)
            await subtitleController.fetchOpenSubtitles(
                imdbID: previewItem.id,
                type: previewItem.type,
                episodeID: nextEp.id,
                preferences: subtitlePrefs,
                playerItem: player.currentItem
            )
        }
    }

    private func cleanupPlayerObservers() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
    }

    private func startPlayback(with streamURL: URL, resumeFromSeconds: Double) {
        cleanupPlayerObservers()
        streamErrorBanner = nil
        if HarborSmartVideoContainer.isEmbedURL(streamURL) { player.pause(); return }

        let item = AVPlayerItem(url: streamURL)
        player.replaceCurrentItem(with: item)
        isBuffering = true

        statusObservation = item.observe(\.status, options: [.new, .initial]) { observedItem, _ in
            Task { @MainActor in
                switch observedItem.status {
                case .readyToPlay:
                    isBuffering = false
                    subtitleController.inspectEmbeddedTracks(in: observedItem)
                    if resumeFromSeconds > 3 {
                        let target = CMTime(seconds: resumeFromSeconds, preferredTimescale: 600)
                        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                case .failed:
                    isBuffering = false
                    streamErrorBanner = observedItem.error?.localizedDescription ?? "تعذر تشغيل هذا المصدر. يرجى اختيار خادم بث بديل."
                default:
                    break
                }
            }
        }

        player.play()
        player.rate = playbackSpeed
        isPlaying = true

        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let secs = CMTimeGetSeconds(time)
            guard secs.isFinite else { return }
            currentSeconds = secs
            if let d = player.currentItem?.duration, CMTimeGetSeconds(d).isFinite && CMTimeGetSeconds(d) > 0 {
                durationSeconds = CMTimeGetSeconds(d)
            }
            showSkipIntroBanner = (secs >= introStart && secs <= introEnd)
            subtitleController.updatePlaybackTime(secs, preferences: subtitlePrefs)
        }
    }

    private func saveProgressAndDismiss() {
        cleanupPlayerObservers()
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

    private func formatVideoTime(_ seconds: Double) -> String {
        let total = max(Int(seconds), 0)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - 14. Harbor Music & Audio Room (iTunes Catalog + Live Stations + LRCLIB Synced Lyrics)

struct HarborHiddenWebAudioBridge: UIViewRepresentable {
    let videoID: String
    let isPlaying: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var loadedID: String = "" }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 48, height: 48), configuration: cfg)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        loadVideo(in: wv, id: videoID, context: context)
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if context.coordinator.loadedID != videoID {
            loadVideo(in: wv, id: videoID, context: context)
            return
        }
        let js = isPlaying
            ? "var v=document.querySelector('video'); if(v){v.muted=false;v.play();}"
            : "var v=document.querySelector('video'); if(v){v.pause();}"
        wv.evaluateJavaScript(js, completionHandler: nil)
    }

    private func loadVideo(in wv: WKWebView, id: String, context: Context) {
        context.coordinator.loadedID = id
        let html = """
        <!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>body,html{margin:0;padding:0;background:#000;}</style></head>
        <body><iframe width="48" height="48" src="https://www.youtube.com/embed/\(id)?autoplay=1&playsinline=1&enablejsapi=1&origin=https://www.reddit.com" frameborder="0" allow="autoplay; encrypted-media" allowfullscreen></iframe></body></html>
        """
        wv.loadHTMLString(html, baseURL: URL(string: "https://www.reddit.com"))
    }
}

// MARK: - Self-Healing Live Artist Portrait Avatar View (Fetches Real Artist Photos via Deezer + Apple Catalog)

struct HarborArtistAvatarView: View {
    let artistName: String
    let initialURL: String?
    let size: CGFloat
    var borderColor: Color = Color.white.opacity(0.22)
    var isCurrentlyPlayingArtist: Bool = false

    @State private var loadedImage: UIImage? = nil

    var body: some View {
        ZStack {
            if isCurrentlyPlayingArtist {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: size + 8, height: size + 8)
                    .blur(radius: 6)
            }

            ZStack {
                if let img = loadedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipped()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [Color(white: 0.14), Color(white: 0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Text(String(artistName.prefix(1)).uppercased())
                            .font(.harbor(size: size * 0.36, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .frame(width: size, height: size)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(
                    LinearGradient(
                        colors: isCurrentlyPlayingArtist
                            ? [Color.white, Color.white.opacity(0.4)]
                            : [borderColor, Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isCurrentlyPlayingArtist ? 2.0 : 1.2
                )
            )
        }
        .task(id: artistName) {
            if let img = await HarborArtworkService.shared.resolveArtistImage(artistName: artistName, initialURL: initialURL) {
                withAnimation(.easeInOut(duration: 0.22)) {
                    self.loadedImage = img
                }
            }
        }
    }
}

// MARK: - Featured Sonic Spotlight Hero Card (Adds Visual Luxury to Music Home)

struct HarborMusicSpotlightCard: View {
    @EnvironmentObject var store: HarborStore
    @EnvironmentObject var audioManager: HarborAudioPlayerManager
    let track: HarborMusicTrack
    let isCurrentPlayingTrack: Bool

    var body: some View {
        ZStack {
            // Blurred Artwork Ambient Backdrop (Edge-to-Edge in Portrait & Landscape)
            GeometryReader { cardGeo in
                AsyncImage(url: URL(string: track.artworkURL ?? "")) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: cardGeo.size.width, height: cardGeo.size.height)
                            .blur(radius: 34)
                            .opacity(0.38)
                    } else {
                        LinearGradient(
                            colors: [Color(white: 0.22).opacity(0.45), Color(white: 0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: cardGeo.size.width, height: cardGeo.size.height)
                    }
                }
            }
            .frame(height: 156)
            .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.68),
                    Color.black.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 16) {
                // Crisp Cover Art with Subtle Glow
                Button {
                    if audioManager.currentTrack?.id != track.id {
                        audioManager.play(track: track, queue: store.musicTracks)
                    }
                    audioManager.isShowingFullPlayer = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        AsyncImage(url: URL(string: track.artworkURL ?? "")) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .scaledToFill()
                                    .frame(width: 112, height: 112)
                                    .clipped()
                            default:
                                ZStack {
                                    Color(white: 0.12)
                                    Image(systemName: "music.quarternote.3")
                                        .font(.harbor(size: 32, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                .frame(width: 112, height: 112)
                            }
                        }
                        .frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.24), lineWidth: 1.0)
                        )
                        .shadow(color: .black.opacity(0.55), radius: 12, y: 6)

                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                            Image(systemName: (isCurrentPlayingTrack && audioManager.isPlaying) ? "waveform" : "play.fill")
                                .font(.harbor(size: 13, weight: .black))
                                .foregroundStyle(.black)
                        }
                        .padding(7)
                    }
                }
                .buttonStyle(SmoothPressButtonStyle())

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(isCurrentPlayingTrack ? "يعمل الآن • LIVE STUDIO" : "مختارات الاستوديو • SPOTLIGHT")
                            .font(.harbor(size: 10, weight: .black, design: .monospaced))
                        Image(systemName: isCurrentPlayingTrack ? "waveform.badge.magnifyingglass" : "sparkles")
                            .font(.harbor(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.14))
                    .foregroundStyle(.white.opacity(0.92))
                    .clipShape(Capsule())

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(track.title)
                            .font(.harbor(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.harbor(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        Button {
                            if audioManager.currentTrack?.id != track.id {
                                audioManager.play(track: track, queue: store.musicTracks)
                            }
                            audioManager.isShowingLyricsSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "quote.bubble.fill")
                                    .font(.harbor(size: 10.5, weight: .bold))
                                Text("الكلمات")
                                    .font(.harbor(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 0.7))
                        }
                        .buttonStyle(SmoothPressButtonStyle())

                        Button {
                            audioManager.selectDSPPreset(.slowedReverb)
                            if audioManager.currentTrack?.id != track.id {
                                audioManager.play(track: track, queue: store.musicTracks)
                            }
                            audioManager.isShowingFullPlayer = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "water.waves")
                                    .font(.harbor(size: 10.5, weight: .bold))
                                Text("بطيء + صدى")
                                    .font(.harbor(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.14))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.7))
                        }
                        .buttonStyle(SmoothPressButtonStyle())

                        Button {
                            if isCurrentPlayingTrack {
                                audioManager.isShowingFullPlayer = true
                            } else {
                                audioManager.play(track: track, queue: store.musicTracks)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "play.fill")
                                    .font(.harbor(size: 10.5, weight: .black))
                                Text(isCurrentPlayingTrack ? "المشغل" : "تشغيل")
                                    .font(.harbor(size: 11.5, weight: .black))
                            }
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(Color.white)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(SmoothPressButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 156)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.24), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: .black.opacity(0.6), radius: 16, y: 8)
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct HarborMusicRoomView: View {
    @EnvironmentObject var store: HarborStore
    @EnvironmentObject var audioManager: HarborAudioPlayerManager
    @State private var searchQuery: String = ""
    @State private var smartResults = HarborSmartSearchResult()
    @State private var isSearchingSmart: Bool = false
    @State private var activeCategoryName: String = "مختاراتي الخاصة"
    @State private var selectedArtistForProfile: HarborArtistSummary? = nil
    @State private var selectedAlbumForDetail: HarborAlbumSummary? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    private let quickGridCols = [
        GridItem(.adaptive(minimum: 160, maximum: 260), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea(.all)

                LinearGradient(
                    colors: [
                        Color(white: 0.15).opacity(0.50),
                        Color(white: 0.05).opacity(0.35),
                        Color.black,
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

                // Seamless Unclipped Full-Screen Studio Ambient Backdrop (Portrait & Landscape)
                LinearGradient(
                    colors: [
                        Color(white: 0.16).opacity(0.55),
                        Color(white: 0.06).opacity(0.40),
                        Color.black,
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.09),
                        Color(white: 0.18).opacity(0.08),
                        Color.clear
                    ],
                    center: .init(x: 0.5, y: 0.08),
                    startRadius: 10,
                    endRadius: 520
                )
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

                if audioManager.isUsingWebAudioFallback, let vid = audioManager.activeYouTubeVideoID {
                    HarborHiddenWebAudioBridge(videoID: vid, isPlaying: audioManager.isPlaying)
                        .frame(width: 48, height: 48)
                        .opacity(0.03)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. Clean Noir Top Header + Instant DSP Mode Menu
                        HStack(alignment: .center, spacing: 10) {
                            Menu {
                                ForEach(HarborAudioDSPPreset.allCases) { preset in
                                    Button {
                                        audioManager.selectDSPPreset(preset)
                                    } label: {
                                        Label(preset.rawValue, systemImage: preset.iconName)
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: audioManager.dspPreset.iconName)
                                        .font(.harbor(size: 12, weight: .bold))
                                    Text(audioManager.dspPreset.shortBadge)
                                        .font(.harbor(size: 12, weight: .bold))
                                    Image(systemName: "chevron.down")
                                        .font(.harbor(size: 9, weight: .bold))
                                        .opacity(0.7)
                                }
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .background(
                                    audioManager.dspPreset == .normal
                                        ? Color(white: 0.10)
                                        : Color.white
                                )
                                .foregroundStyle(audioManager.dspPreset == .normal ? Color.white : Color.black)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 0.8))
                            }

                            if audioManager.currentTrack != nil {
                                Button {
                                    audioManager.isShowingFullPlayer = true
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "waveform")
                                            .font(.harbor(size: 11, weight: .bold))
                                            .symbolEffect(.variableColor.iterative, isActive: audioManager.isPlaying)
                                        Text("المشغل")
                                            .font(.harbor(size: 11.5, weight: .bold))
                                    }
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.10))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.7))
                                }
                                .buttonStyle(SmoothPressButtonStyle())
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("الموسيقى")
                                    .font(.harbor(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("BITCHORD × HARBOR SONIC STUDIO")
                                    .font(.harbor(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .environment(\.layoutDirection, .leftToRight)

                        // 2. Smart Instant Search Bar (True Noir Glass Surface)
                        HStack(spacing: 10) {
                            if !searchQuery.isEmpty {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        searchQuery = ""
                                        smartResults = HarborSmartSearchResult()
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            } else if isSearchingSmart {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            } else {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.white.opacity(0.8))
                            }

                            TextField("بحث ذكي: اكتب اسم أغنية، فنان، أو ألبوم...", text: $searchQuery)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.white)
                                .submitLabel(.search)
                                .onChange(of: searchQuery) { _, newValue in
                                    searchTask?.cancel()
                                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard trimmed.count >= 2 else {
                                        smartResults = HarborSmartSearchResult()
                                        isSearchingSmart = false
                                        return
                                    }
                                    searchTask = Task {
                                        try? await Task.sleep(nanoseconds: 260_000_000)
                                        guard !Task.isCancelled else { return }
                                        isSearchingSmart = true
                                        let res = await JioSaavnStreamCrypto.performSmartSearch(query: trimmed)
                                        guard !Task.isCancelled else { return }
                                        smartResults = res
                                        if !res.songs.isEmpty {
                                            store.musicTracks = res.songs
                                        }
                                        isSearchingSmart = false
                                    }
                                }
                                .onSubmit {
                                    Task {
                                        isSearchingSmart = true
                                        let res = await JioSaavnStreamCrypto.performSmartSearch(query: searchQuery)
                                        smartResults = res
                                        if !res.songs.isEmpty {
                                            store.musicTracks = res.songs
                                        }
                                        isSearchingSmart = false
                                    }
                                }

                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(white: 0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.8))
                        .padding(.horizontal, 16)
                        .environment(\.layoutDirection, .leftToRight)

                        // 3. Categorized Smart Search Results (Artists + Albums)
                        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            if !smartResults.artists.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("الفنانون المطابقون · اضغط لعرض الصفحة والألبومات")
                                        .font(.harborCaption.weight(.bold))
                                        .foregroundStyle(.white.opacity(0.75))
                                        .padding(.horizontal, 18)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 14) {
                                            ForEach(smartResults.artists) { artist in
                                                Button {
                                                    selectedArtistForProfile = artist
                                                } label: {
                                                    HStack(spacing: 10) {
                                                        HarborArtistAvatarView(
                                                            artistName: artist.name,
                                                            initialURL: artist.artworkURL,
                                                            size: 44
                                                        )

                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(artist.name)
                                                                .font(.harbor(size: 13.5, weight: .bold))
                                                                .foregroundStyle(.white)
                                                            Text("صفحة الفنان والألبومات ›")
                                                                .font(.harbor(size: 10.5, weight: .semibold))
                                                                .foregroundStyle(.white.opacity(0.65))
                                                        }
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(Color(white: 0.08))
                                                    .clipShape(Capsule())
                                                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                                                }
                                                .buttonStyle(SmoothPressButtonStyle())
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    .environment(\.layoutDirection, .leftToRight)
                                }
                            }

                            if !smartResults.albums.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("الألبومات الكاملة · Albums")
                                        .font(.harborCaption.weight(.bold))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .padding(.horizontal, 18)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 14) {
                                            ForEach(smartResults.albums.prefix(10)) { alb in
                                                Button {
                                                    selectedAlbumForDetail = alb
                                                } label: {
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        AsyncImage(url: URL(string: alb.artworkURL ?? "")) { phase in
                                                            switch phase {
                                                            case .success(let img):
                                                                img.resizable().scaledToFill()
                                                            default:
                                                                Color(white: 0.08)
                                                            }
                                                        }
                                                        .frame(width: 124, height: 124)
                                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                                        Text(alb.title)
                                                            .font(.harbor(size: 12.5, weight: .bold))
                                                            .foregroundStyle(.white)
                                                            .lineLimit(1)
                                                            .frame(width: 124, alignment: .leading)

                                                        Text("\(alb.artist) • \(alb.releaseYear)")
                                                            .font(.harbor(size: 10.5, weight: .medium))
                                                            .foregroundStyle(.white.opacity(0.6))
                                                            .lineLimit(1)
                                                            .frame(width: 124, alignment: .leading)
                                                    }
                                                }
                                                .buttonStyle(SmoothPressButtonStyle())
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    .environment(\.layoutDirection, .leftToRight)
                                }
                            }
                        } else {
                            // 3B. Featured Sonic Spotlight Hero Card (Visual Luxury in Music Home)
                            if let heroTrack = audioManager.currentTrack ?? store.musicTracks.first {
                                HarborMusicSpotlightCard(
                                    track: heroTrack,
                                    isCurrentPlayingTrack: audioManager.currentTrack?.id == heroTrack.id
                                )
                                .padding(.horizontal, 16)
                            }

                            // 4. Featured Artists Rail (Live Portraits + Halo Ring)
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                        Text("فنانون مميزون · Iconic Artists")
                                            .font(.harborHeadline.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                    Spacer()
                                    Text("اضغط لعرض الأغاني والألبومات")
                                        .font(.harborCaption2.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 18)
                                .environment(\.layoutDirection, .leftToRight)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(featuredHarborArtists) { artist in
                                            let isArtistActive = audioManager.currentTrack?.artist.localizedCaseInsensitiveContains(artist.name) == true
                                            Button {
                                                selectedArtistForProfile = artist
                                            } label: {
                                                VStack(spacing: 7) {
                                                    HarborArtistAvatarView(
                                                        artistName: artist.name,
                                                        initialURL: artist.artworkURL,
                                                        size: 76,
                                                        borderColor: Color.white.opacity(0.24),
                                                        isCurrentlyPlayingArtist: isArtistActive
                                                    )
                                                    .shadow(color: .black.opacity(0.65), radius: 8, y: 4)

                                                    Text(artist.name)
                                                        .font(.harbor(size: 12, weight: .bold))
                                                        .foregroundStyle(.white)
                                                        .lineLimit(1)
                                                        .frame(width: 86)

                                                    Text(artist.genre)
                                                        .font(.harbor(size: 9.5, weight: .semibold))
                                                        .foregroundStyle(.white.opacity(0.46))
                                                        .lineLimit(1)
                                                        .frame(width: 86)
                                                }
                                                .padding(.vertical, 4)
                                            }
                                            .buttonStyle(SmoothPressButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .environment(\.layoutDirection, .leftToRight)
                            }

                            // 5. Mood Filter Pills (True Noir Black & White Contrast)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(personalMusicMoods) { mood in
                                        let isSelected = (activeCategoryName == mood.title)
                                        Button {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                                activeCategoryName = mood.title
                                            }
                                            Task { await store.searchMusic(query: mood.query) }
                                        } label: {
                                            HStack(spacing: 7) {
                                                Image(systemName: mood.symbol)
                                                    .font(.harbor(size: 12.5, weight: .bold))
                                                Text(mood.title)
                                                    .font(.harbor(size: 13, weight: .bold))
                                            }
                                            .padding(.horizontal, 15)
                                            .padding(.vertical, 9)
                                            .background(isSelected ? Color.white : Color(white: 0.08))
                                            .foregroundStyle(isSelected ? Color.black : Color.white)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(Color.white.opacity(isSelected ? 0 : 0.12), lineWidth: 0.8))
                                        }
                                        .buttonStyle(SmoothPressButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .environment(\.layoutDirection, .leftToRight)
                        }

                        // 6. BitChord Quick-Pick Adaptive Grid (Adapts to Portrait & Landscape)
                        if store.musicTracks.count >= 4 && searchQuery.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bolt.fill")
                                            .font(.harbor(size: 11, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.8))
                                        Text("تشغيل فوري · Speed Dial")
                                            .font(.harborSubheadline.weight(.bold))
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                    Spacer()
                                    Button {
                                        if let randomTrack = store.musicTracks.randomElement() {
                                            audioManager.isShuffleEnabled = true
                                            audioManager.play(track: randomTrack, queue: store.musicTracks)
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "shuffle")
                                                .font(.harbor(size: 10.5, weight: .bold))
                                            Text("خلط ذكي")
                                                .font(.harbor(size: 11, weight: .bold))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.white.opacity(0.09))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(SmoothPressButtonStyle())
                                }
                                .padding(.horizontal, 18)
                                .environment(\.layoutDirection, .leftToRight)

                                LazyVGrid(columns: quickGridCols, spacing: 10) {
                                    ForEach(Array(store.musicTracks.prefix(6))) { item in
                                        let isCurrent = (audioManager.currentTrack?.id == item.id)
                                        Button {
                                            audioManager.play(track: item, queue: store.musicTracks)
                                        } label: {
                                            HStack(spacing: 10) {
                                                AsyncImage(url: URL(string: item.artworkURL ?? "")) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image.resizable().scaledToFill()
                                                            .frame(width: 52, height: 52).clipped()
                                                    default:
                                                        ZStack {
                                                            Color(white: 0.10)
                                                            Image(systemName: "music.note")
                                                                .foregroundStyle(.white.opacity(0.7))
                                                        }
                                                        .frame(width: 52, height: 52)
                                                    }
                                                }
                                                .frame(width: 52, height: 52)
                                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.title)
                                                        .font(.harbor(size: 12.5, weight: .bold))
                                                        .foregroundStyle(.white)
                                                        .lineLimit(1)
                                                    Text(item.artist)
                                                        .font(.harbor(size: 10.5, weight: .medium))
                                                        .foregroundStyle(.white.opacity(0.58))
                                                        .lineLimit(1)
                                                }
                                                Spacer(minLength: 4)

                                                if isCurrent {
                                                    Image(systemName: audioManager.isPlaying ? "waveform" : "pause.fill")
                                                        .font(.harbor(size: 11, weight: .bold))
                                                        .foregroundStyle(.white)
                                                        .padding(.trailing, 8)
                                                }
                                            }
                                            .frame(height: 52)
                                            .background(
                                                LinearGradient(
                                                    colors: isCurrent
                                                        ? [Color(white: 0.16), Color(white: 0.09)]
                                                        : [Color(white: 0.085), Color(white: 0.055)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                    .stroke(isCurrent ? Color.white.opacity(0.75) : Color.white.opacity(0.09), lineWidth: isCurrent ? 1.3 : 0.6)
                                            )
                                        }
                                        .buttonStyle(SmoothPressButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .environment(\.layoutDirection, .leftToRight)
                            }
                        }

                        // 7. Full Songs List
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(searchQuery.isEmpty ? activeCategoryName : "نتائج الأغاني الكاملة")
                                    .font(.harborTitle3.weight(.bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                if store.isLoadingMusic || isSearchingSmart {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("\(store.musicTracks.count) أغنية • FULL MASTER")
                                        .font(.harborCaption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 18)
                            .environment(\.layoutDirection, .leftToRight)

                            VStack(spacing: 9) {
                                ForEach(store.musicTracks) { track in
                                    HarborMusicTrackRow(
                                        track: track,
                                        isCurrent: audioManager.currentTrack?.id == track.id,
                                        isPlaying: audioManager.isPlaying,
                                        onTapTrack: {
                                            audioManager.play(track: track, queue: store.musicTracks)
                                        },
                                        onTapArtist: {
                                            let primary = track.artist.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? track.artist
                                            selectedArtistForProfile = HarborArtistSummary(
                                                id: "art-\(primary.lowercased())",
                                                name: primary,
                                                artworkURL: track.artworkURL,
                                                genre: track.genre ?? "Studio Artist"
                                            )
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 140)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedArtistForProfile) { artist in
                HarborArtistDetailView(artistSummary: artist)
                    .environmentObject(store)
                    .environmentObject(audioManager)
            }
            .navigationDestination(item: $selectedAlbumForDetail) { album in
                HarborAlbumDetailView(album: album)
                    .environmentObject(store)
                    .environmentObject(audioManager)
            }
            .sheet(isPresented: $audioManager.isShowingLyricsSheet) {
                HarborCleanLyricsSheet()
                    .environmentObject(store)
                    .environmentObject(audioManager)
                    .preferredColorScheme(.dark)
            }
        }
    }
}

// MARK: - Dedicated Artist Profile View (Responsive Across Portrait & Landscape)

struct HarborArtistDetailView: View {
    @EnvironmentObject var store: HarborStore
    @EnvironmentObject var audioManager: HarborAudioPlayerManager
    let artistSummary: HarborArtistSummary

    @State private var topSongs: [HarborMusicTrack] = []
    @State private var albums: [HarborAlbumSummary] = []
    @State private var artistPortrait: UIImage? = nil
    @State private var isLoadingProfile: Bool = true
    @State private var selectedAlbum: HarborAlbumSummary? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea(.all)

            LinearGradient(
                colors: [
                    Color(white: 0.16).opacity(0.52),
                    Color(white: 0.06).opacity(0.35),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)
            .allowsHitTesting(false)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    ZStack(alignment: .bottomLeading) {
                        GeometryReader { heroGeo in
                            if let img = artistPortrait {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: heroGeo.size.width, height: 290)
                                    .clipped()
                            } else {
                                AsyncImage(url: URL(string: albums.first?.artworkURL ?? topSongs.first?.artworkURL ?? artistSummary.artworkURL ?? "")) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable()
                                            .scaledToFill()
                                            .frame(width: heroGeo.size.width, height: 290)
                                            .clipped()
                                    default:
                                        LinearGradient(
                                            colors: [Color(white: 0.20), Color(white: 0.06), Color.black],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        .frame(width: heroGeo.size.width, height: 290)
                                    }
                                }
                            }
                        }
                        .frame(height: 290)

                        LinearGradient(
                            colors: [Color.black.opacity(0.18), .clear, Color.black.opacity(0.78), Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 290)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("OFFICIAL ARTIST PROFILE")
                                .font(.harbor(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))

                            Text(artistSummary.name)
                                .font(.harbor(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            HStack(spacing: 12) {
                                Button {
                                    if let first = topSongs.first {
                                        audioManager.selectDSPPreset(.normal)
                                        audioManager.play(track: first, queue: topSongs)
                                        audioManager.isShowingFullPlayer = true
                                    }
                                } label: {
                                    HStack(spacing: 7) {
                                        Image(systemName: "play.fill")
                                        Text("تشغيل الكل")
                                            .font(.harborSubheadline.weight(.bold))
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 11)
                                    .background(Color.white)
                                    .foregroundStyle(Color.black)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(SmoothPressButtonStyle())

                                Button {
                                    if let first = topSongs.first {
                                        audioManager.selectDSPPreset(.slowedReverb)
                                        audioManager.play(track: first, queue: topSongs)
                                        audioManager.isShowingFullPlayer = true
                                    }
                                } label: {
                                    HStack(spacing: 7) {
                                        Image(systemName: "water.waves")
                                        Text("بطيء + صدى 🌊")
                                            .font(.harborSubheadline.weight(.bold))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 11)
                                    .background(Color.white.opacity(0.14))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                }
                                .buttonStyle(SmoothPressButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                    .environment(\.layoutDirection, .leftToRight)

                    if isLoadingProfile {
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                ProgressView().tint(.white)
                                Text("جاري جلب أحدث أغاني وألبومات \(artistSummary.name)...")
                                    .font(.harborCaption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.vertical, 30)
                            Spacer()
                        }
                    } else {
                        if !albums.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("الألبومات والإصدارات · Albums & EPs (\(albums.count))")
                                        .font(.harborHeadline.weight(.bold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(.horizontal, 18)
                                .environment(\.layoutDirection, .leftToRight)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(albums) { alb in
                                            Button {
                                                selectedAlbum = alb
                                            } label: {
                                                VStack(alignment: .leading, spacing: 7) {
                                                    AsyncImage(url: URL(string: alb.artworkURL ?? "")) { phase in
                                                        switch phase {
                                                        case .success(let img):
                                                            img.resizable().scaledToFill()
                                                                .frame(width: 144, height: 144).clipped()
                                                        default:
                                                            Color(white: 0.08)
                                                                .frame(width: 144, height: 144)
                                                        }
                                                    }
                                                    .frame(width: 144, height: 144)
                                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                            .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                                                    )

                                                    Text(alb.title)
                                                        .font(.harbor(size: 13, weight: .bold))
                                                        .foregroundStyle(.white)
                                                        .lineLimit(1)
                                                        .frame(width: 144, alignment: .leading)

                                                    Text("\(alb.releaseYear) • \(alb.trackCount) أغاني")
                                                        .font(.harbor(size: 11, weight: .medium))
                                                        .foregroundStyle(.white.opacity(0.6))
                                                        .lineLimit(1)
                                                        .frame(width: 144, alignment: .leading)
                                                }
                                            }
                                            .buttonStyle(SmoothPressButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .environment(\.layoutDirection, .leftToRight)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("أحدث وأشهر الأغاني · Top Songs (\(topSongs.count))")
                                    .font(.harborHeadline.weight(.bold))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .environment(\.layoutDirection, .leftToRight)

                            VStack(spacing: 9) {
                                ForEach(topSongs) { track in
                                    HarborMusicTrackRow(
                                        track: track,
                                        isCurrent: audioManager.currentTrack?.id == track.id,
                                        isPlaying: audioManager.isPlaying,
                                        onTapTrack: {
                                            audioManager.play(track: track, queue: topSongs)
                                        },
                                        onTapArtist: {}
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer(minLength: 130)
                }
                .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedAlbum) { alb in
            HarborAlbumDetailView(album: alb)
                .environmentObject(store)
                .environmentObject(audioManager)
        }
        .task {
            isLoadingProfile = true
            async let portraitTask = HarborArtworkService.shared.resolveArtistImage(artistName: artistSummary.name, initialURL: artistSummary.artworkURL)
            async let profileTask = JioSaavnStreamCrypto.fetchArtistProfile(
                artistName: artistSummary.name,
                fallbackArtwork: artistSummary.artworkURL
            )
            let (portraitImg, profile) = await (portraitTask, profileTask)
            self.artistPortrait = portraitImg
            self.topSongs = profile.topSongs
            self.albums = profile.albums
            self.isLoadingProfile = false
        }
    }
}

// MARK: - Dedicated Album Detail View (Noir Black-on-Black)

struct HarborAlbumDetailView: View {
    @EnvironmentObject var store: HarborStore
    @EnvironmentObject var audioManager: HarborAudioPlayerManager
    let album: HarborAlbumSummary

    @State private var tracks: [HarborMusicTrack] = []
    @State private var isLoadingTracks: Bool = true

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 14) {
                        AsyncImage(url: URL(string: album.artworkURL ?? "")) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                                    .frame(width: 210, height: 210).clipped()
                            default:
                                Color(white: 0.08)
                                    .frame(width: 210, height: 210)
                            }
                        }
                        .frame(width: 210, height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.65), radius: 18, y: 8)

                        VStack(spacing: 4) {
                            Text(album.title)
                                .font(.harborTitle2.weight(.black))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            Text("\(album.artist) • \(album.releaseYear)")
                                .font(.harborSubheadline.weight(.bold))
                                .foregroundStyle(.white.opacity(0.68))
                        }
                        .padding(.horizontal, 20)

                        HStack(spacing: 12) {
                            Button {
                                if let first = tracks.first {
                                    audioManager.selectDSPPreset(.normal)
                                    audioManager.play(track: first, queue: tracks)
                                    audioManager.isShowingFullPlayer = true
                                }
                            } label: {
                                Label("تشغيل الألبوم", systemImage: "play.fill")
                                    .font(.harborSubheadline.weight(.bold))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 11)
                                    .background(Color.white)
                                    .foregroundStyle(Color.black)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(SmoothPressButtonStyle())

                            Button {
                                if let first = tracks.first {
                                    audioManager.selectDSPPreset(.slowedReverb)
                                    audioManager.play(track: first, queue: tracks)
                                    audioManager.isShowingFullPlayer = true
                                }
                            } label: {
                                Label("بطيء + صدى 🌊", systemImage: "water.waves")
                                    .font(.harborSubheadline.weight(.bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 11)
                                    .background(Color.white.opacity(0.12))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(SmoothPressButtonStyle())
                        }
                    }
                    .padding(.top, 16)

                    if isLoadingTracks {
                        ProgressView().tint(.white).padding(.top, 30)
                    } else {
                        VStack(spacing: 9) {
                            ForEach(tracks) { track in
                                HarborMusicTrackRow(
                                    track: track,
                                    isCurrent: audioManager.currentTrack?.id == track.id,
                                    isPlaying: audioManager.isPlaying,
                                    onTapTrack: {
                                        audioManager.play(track: track, queue: tracks)
                                    },
                                    onTapArtist: {}
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 130)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoadingTracks = true
            tracks = await JioSaavnStreamCrypto.fetchAlbumTracks(album: album)
            isLoadingTracks = false
        }
    }
}

struct HarborMusicTrackRow: View {
    @EnvironmentObject var store: HarborStore
    @EnvironmentObject var audioManager: HarborAudioPlayerManager
    let track: HarborMusicTrack
    let isCurrent: Bool
    let isPlaying: Bool
    let onTapTrack: () -> Void
    var onTapArtist: () -> Void = {}

    var body: some View {
        HStack(spacing: 13) {
            Button(action: onTapTrack) {
                ContainedArtworkGlow(
                    artworkURL: track.artworkURL,
                    isActive: isCurrent,
                    frameSize: 52,
                    glowBlur: 11
                ) {
                    AsyncImage(url: URL(string: track.artworkURL ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipped()
                        default:
                            ZStack {
                                Color(white: 0.10)
                                Image(systemName: "music.note")
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .frame(width: 52, height: 52)
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isCurrent ? Color.white : Color.white.opacity(0.12), lineWidth: isCurrent ? 1.5 : 0.6)
                    )
                }
                .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Button(action: onTapTrack) {
                    HStack(spacing: 6) {
                        Text(track.title)
                            .font(.harbor(size: 14.5, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if isCurrent {
                            Text("HI-FI")
                                .font(.harbor(size: 8.5, weight: .black, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                        }
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 5) {
                    Button(action: onTapArtist) {
                        HStack(spacing: 3) {
                            Text(track.artist)
                                .font(.harbor(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.harbor(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)

                    let durText = track.isLiveStream
                        ? "LIVE"
                        : String(format: "%d:%02d", Int(max(track.durationSeconds, 180)) / 60, Int(max(track.durationSeconds, 180)) % 60)
                    Text("· \(durText)")
                        .font(.harbor(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            Spacer()

            Button {
                if audioManager.currentTrack?.id != track.id {
                    audioManager.play(track: track, queue: store.musicTracks)
                }
                audioManager.isShowingLyricsSheet = true
            } label: {
                Image(systemName: "text.quote")
                    .font(.harbor(size: 13.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 34, height: 34)
                    .background(Color(white: 0.11))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button(action: onTapTrack) {
                if isCurrent {
                    Image(systemName: isPlaying ? "waveform" : "pause.circle.fill")
                        .font(.harborTitle3.weight(.bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                        .frame(width: 34, height: 34)
                } else {
                    Image(systemName: "play.fill")
                        .font(.harborCaption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 34, height: 34)
                        .background(Color(white: 0.11))
                        .clipShape(Circle())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 74)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isCurrent
                            ? [Color(white: 0.15), Color(white: 0.08)]
                            : [Color(white: 0.075), Color(white: 0.045)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isCurrent ? Color.white.opacity(0.50) : Color.white.opacity(0.08), lineWidth: isCurrent ? 1.2 : 0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - Redesigned Floating Mini-Player Bar (Full Right/Middle Tap Zone + Swipe Left/Right + Close `X` Button)

struct HarborMiniAudioPlayerBar: View {
    @EnvironmentObject var store: HarborStore
    @EnvironmentObject var audioManager: HarborAudioPlayerManager
    @State private var dragOffsetX: CGFloat = 0

    var body: some View {
        if let track = audioManager.currentTrack {
            HStack(spacing: 6) {
                // 0. Close / Stop Song Button (زر إغلاق وإيقاف الأغنية)
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        audioManager.stopAndCloseTrack()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.harbor(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.09))
                        .clipShape(Circle())
                }
                .buttonStyle(SmoothPressButtonStyle())

                // 1. Play / Pause
                Button {
                    audioManager.togglePlayPause()
                } label: {
                    if audioManager.isResolvingFullStream {
                        ProgressView().tint(.white).frame(width: 30, height: 30)
                    } else {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.harbor(size: 16.5, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                    }
                }
                .buttonStyle(SmoothPressButtonStyle())

                // 2. Next Track
                Button {
                    audioManager.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.harbor(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.84))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(SmoothPressButtonStyle())

                // 3. Replay Song Button (زر إعادة الأغنية من البداية)
                Button {
                    audioManager.replayCurrentTrack()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.harbor(size: 12.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(SmoothPressButtonStyle())

                // 4. Tiny Slowed+Reverb Icon Button
                Button {
                    let nextPreset: HarborAudioDSPPreset = (audioManager.dspPreset == .slowedReverb) ? .normal : .slowedReverb
                    audioManager.selectDSPPreset(nextPreset)
                } label: {
                    Image(systemName: "water.waves")
                        .font(.harbor(size: 9.5, weight: .bold))
                        .frame(width: 22, height: 22)
                        .background(audioManager.dspPreset == .normal ? Color.white.opacity(0.09) : Color.white)
                        .foregroundStyle(audioManager.dspPreset == .normal ? Color.white.opacity(0.75) : Color.black)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.6))
                }
                .buttonStyle(SmoothPressButtonStyle())

                // 5. Entire Middle + Right Zone (Empty Space + Title + Artist + Artwork) Opens Full Player!
                Button {
                    audioManager.isShowingFullPlayer = true
                } label: {
                    HStack(spacing: 10) {
                        Spacer(minLength: 4)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(track.title)
                                .font(.harbor(size: 13.5, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.harborCaption2)
                                .foregroundStyle(.white.opacity(0.68))
                                .lineLimit(1)
                        }

                        AsyncImage(url: URL(string: track.artworkURL ?? "")) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipped()
                            default:
                                ZStack {
                                    Color(white: 0.12)
                                    Image(systemName: "music.note")
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .frame(width: 40, height: 40)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(audioManager.isPlaying ? 0.45 : 0.14), lineWidth: 1.0)
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: 620)
            .frame(height: 58)
            .background(
                ZStack(alignment: .bottomLeading) {
                    Capsule(style: .continuous)
                        .fill(Color(white: 0.055).opacity(0.97))

                    GeometryReader { barGeo in
                        let progress = min(max(audioManager.currentTime / max(audioManager.duration, 1), 0), 1)
                        Rectangle()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: barGeo.size.width * progress, height: 2.0)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .clipShape(Capsule(style: .continuous))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.9)
            )
            .clipShape(Capsule(style: .continuous))
            .shadow(color: .black.opacity(0.75), radius: 14, y: 5)
            .offset(x: dragOffsetX)
            .simultaneousGesture(
                DragGesture(minimumDistance: 22, coordinateSpace: .local)
                    .onChanged { value in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            dragOffsetX = value.translation.width * 0.32
                        }
                    }
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            dragOffsetX = 0
                        }
                        guard abs(horizontal) > abs(vertical), abs(horizontal) > 36 else { return }
                        if horizontal > 36 {
                            // سحب لليمين -> الأغنية التي بعدها
                            audioManager.playNext()
                        } else if horizontal < -36 {
                            // سحب لليسار -> يعيد الأغنية أولاً ثم الأغنية التي قبلها
                            audioManager.playPrevious()
                        }
                    }
            )
            .padding(.horizontal, 16)
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

// MARK: - Bespoke Spotify × YouTube Music Signature Full-Screen Player (100% Unclipped Edge-to-Edge Aura + Beat-Reactive Rhythm + Pure Glowing Lyrics)

struct HarborFullMusicPlayerSheet: View {
    @EnvironmentObject var store: HarborStore
    @EnvironmentObject var audioManager: HarborAudioPlayerManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("harbor.player.animatedAura") private var isAnimatedAuraEnabled: Bool = true

    @State private var showInlineLyrics: Bool = false
    @State private var showCustomDSPSliders: Bool = false
    @State private var showDedicatedLyricsSheet: Bool = false
    @State private var showQueueAndPlaylistsSheet: Bool = false
    @State private var selectedArtistFromPlayer: HarborArtistSummary? = nil
    @State private var auraDriftPhase: Bool = false

    // Dominant Color Palette extracted from the current track's cover art (Defaults to sleek Neutral Grayscale)
    @State private var bgTopColor: Color = Color(white: 0.34)
    @State private var bgMidColor: Color = Color(white: 0.16)
    @State private var bgBotColor: Color = Color(white: 0.02)
    @State private var bgAccentGlow: Color = Color(white: 0.54)
    @State private var loadedCoverImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // 1. 100% FULL-BLEED UNCLIPPED LIVING AURA BACKGROUND (Covers All Safe Areas in Portrait & Landscape)
                playerAuraBackground()
                    .ignoresSafeArea(.all)

                // 2. RESPONSIVE FOREGROUND CONTENT (Portrait & Landscape on Any Device)
                GeometryReader { geo in
                    let viewW = max(geo.size.width, 300)
                    let viewH = max(geo.size.height, 260)
                    let isLandscape = viewW > viewH

                    ZStack {
                        if let track = audioManager.currentTrack {
                            if isLandscape {
                                // LANDSCAPE LAYOUT (Perfect Alignment on Any Device in Horizontal Orientation)
                                let landContentW = min(viewW - 44, 920)
                                let landArtSize = min(viewH * 0.68, viewW * 0.36, 300)
                                let rightColW = max(landContentW - landArtSize - 32, 260)

                                VStack(spacing: 8) {
                                    playerTopHeaderBar(width: landContentW)
                                        .padding(.top, 6)

                                    Spacer(minLength: 4)

                                    HStack(alignment: .center, spacing: 32) {
                                        playerCenterStage(track: track, artSize: landArtSize)

                                        VStack(spacing: 12) {
                                            playerTitleAndArtistRow(track: track, width: rightColW)
                                            playerDSPPillsStrip(width: rightColW)
                                            playerProgressScrubber(width: rightColW)
                                            playerTransportControls(width: rightColW)
                                        }
                                        .frame(width: rightColW)
                                    }
                                    .frame(width: landContentW)

                                    Spacer(minLength: 6)
                                }
                                .frame(width: viewW, height: viewH)
                                .task(id: track.id) {
                                    await updateArtworkAndDominantColor(for: track)
                                }
                            } else {
                                // PORTRAIT LAYOUT (100% Centered on Any iPhone/iPad Screen Width)
                                let contentW = min(viewW - 44, 500)
                                let artSize = min(contentW, max(viewH * 0.38, 220))

                                VStack(spacing: 0) {
                                    playerTopHeaderBar(width: contentW)
                                        .padding(.top, 10)

                                    Spacer(minLength: 12)

                                    playerCenterStage(track: track, artSize: artSize)

                                    Spacer(minLength: 16)

                                    playerTitleAndArtistRow(track: track, width: contentW)

                                    playerDSPPillsStrip(width: viewW)
                                        .padding(.top, 14)

                                    playerProgressScrubber(width: contentW)
                                        .padding(.top, 14)

                                    playerTransportControls(width: contentW)
                                        .padding(.top, 16)

                                    VStack(spacing: 6) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.26))
                                            .frame(width: 36, height: 4)
                                        Text("ميكس خاص بك • من موسيقى \(track.title)")
                                            .font(.harbor(size: 13, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.76))
                                            .lineLimit(1)
                                    }
                                    .frame(width: contentW)
                                    .padding(.top, 16)
                                    .padding(.bottom, 10)
                                }
                                .frame(width: viewW, height: viewH)
                                .task(id: track.id) {
                                    await updateArtworkAndDominantColor(for: track)
                                }
                            }
                        }

                        // Optional Floating Studio DSP Sliders Overlay
                        if showCustomDSPSliders {
                            dspSlidersOverlay(viewW: viewW)
                        }
                    }
                    .frame(width: viewW, height: viewH)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea(.all))
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if value.translation.height > 75 && abs(value.translation.width) < 90 {
                            dismiss()
                        }
                    }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedArtistFromPlayer) { artist in
                HarborArtistDetailView(artistSummary: artist)
                    .environmentObject(store)
                    .environmentObject(audioManager)
            }
            .sheet(isPresented: $showDedicatedLyricsSheet) {
                HarborCleanLyricsSheet()
                    .environmentObject(store)
                    .environmentObject(audioManager)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showQueueAndPlaylistsSheet) {
                HarborMusicQueueAndPlaylistsSheet()
                    .environmentObject(store)
                    .environmentObject(audioManager)
                    .preferredColorScheme(.dark)
            }
        }
    }

    @ViewBuilder
    private func playerAuraBackground() -> some View {
        GeometryReader { bgGeo in
            let fullW = max(bgGeo.size.width, 420)
            let fullH = max(bgGeo.size.height, 420)
            let beat = audioManager.beatPulseLevel
            let wave = audioManager.beatSecondaryWave

            ZStack {
                Color.black

                if isAnimatedAuraEnabled {
                    // Base full-screen smooth gradient (Never clipped)
                    LinearGradient(
                        colors: [
                            bgTopColor.opacity(0.95),
                            bgMidColor.opacity(0.84),
                            bgBotColor,
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Full-bleed oversized blurred cover art reacting to song beat & drift (No .clipped() seam!)
                    if let uiImg = loadedCoverImage {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFill()
                            .frame(width: fullW * 1.45, height: fullH * 1.45)
                            .scaleEffect(1.04 + beat * 0.15 + (auraDriftPhase ? 0.06 : -0.02))
                            .offset(
                                x: (auraDriftPhase ? 18 : -18) + wave * 16,
                                y: (auraDriftPhase ? -18 : 14) - beat * 14
                            )
                            .blur(radius: 76)
                            .opacity(audioManager.isPlaying ? (0.34 + Double(beat) * 0.24) : 0.20)
                    }

                    // Primary Beat-Reactive Rhythm Halo
                    RadialGradient(
                        colors: [
                            bgAccentGlow.opacity(audioManager.isPlaying ? (0.40 + Double(beat) * 0.38) : 0.20),
                            bgTopColor.opacity(0.24 + Double(beat) * 0.20),
                            Color.clear
                        ],
                        center: .init(
                            x: 0.50 + Double(wave) * 0.09,
                            y: fullW > fullH ? 0.44 : 0.34
                        ),
                        startRadius: 8,
                        endRadius: max(fullW, fullH) * (0.56 + beat * 0.20)
                    )

                    // Secondary Counter-Rhythm Floating Aura
                    RadialGradient(
                        colors: [
                            bgTopColor.opacity(0.36 + Double(beat) * 0.22),
                            bgMidColor.opacity(0.18),
                            Color.clear
                        ],
                        center: .init(
                            x: auraDriftPhase ? 0.24 : 0.76,
                            y: auraDriftPhase ? 0.22 : 0.46
                        ),
                        startRadius: 10,
                        endRadius: max(fullW, fullH) * (0.48 + beat * 0.14)
                    )

                    // Smooth Top-to-Bottom Cinema Vignette (Eliminates all seams)
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.10), location: 0.0),
                            .init(color: Color.clear, location: 0.32),
                            .init(color: Color.black.opacity(0.46), location: 0.72),
                            .init(color: Color.black.opacity(0.90), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    LinearGradient(
                        stops: [
                            .init(color: bgTopColor, location: 0.0),
                            .init(color: bgMidColor, location: 0.52),
                            .init(color: bgBotColor, location: 0.86),
                            .init(color: Color.black, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(width: fullW, height: fullH)
        }
        .ignoresSafeArea(.all)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.55), value: audioManager.currentTrack?.id)
        .animation(.easeInOut(duration: 0.35), value: isAnimatedAuraEnabled)
        .onAppear {
            withAnimation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true)) {
                auraDriftPhase = true
            }
        }
    }

    @ViewBuilder
    private func playerTopHeaderBar(width: CGFloat) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showCustomDSPSliders.toggle()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.harbor(size: 16, weight: .bold))
                    .rotationEffect(.degrees(90))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(SmoothPressButtonStyle())

            Button {
                audioManager.replayCurrentTrack()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.harbor(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(SmoothPressButtonStyle())

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    isAnimatedAuraEnabled.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isAnimatedAuraEnabled ? "sparkles" : "circle.lefthalf.filled")
                        .font(.harbor(size: 11, weight: .bold))
                    Text(isAnimatedAuraEnabled ? "حيّة" : "سادة")
                        .font(.harbor(size: 11, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(isAnimatedAuraEnabled ? Color.white.opacity(0.20) : Color.white.opacity(0.09))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.7))
            }
            .buttonStyle(SmoothPressButtonStyle())

            Spacer(minLength: 4)

            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showInlineLyrics = true
                    }
                } label: {
                    Image(systemName: "text.quote")
                        .font(.harbor(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 30)
                        .background(showInlineLyrics ? Color.white.opacity(0.24) : Color.clear)
                        .clipShape(Capsule())
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showInlineLyrics = false
                    }
                } label: {
                    Image(systemName: "headphones")
                        .font(.harbor(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 30)
                        .background(!showInlineLyrics ? Color.white.opacity(0.24) : Color.clear)
                        .clipShape(Capsule())
                }
            }
            .padding(3)
            .background(Color.black.opacity(0.32))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.7))

            Spacer(minLength: 4)

            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.harbor(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(SmoothPressButtonStyle())
        }
        .frame(width: width)
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func playerCenterStage(track: HarborMusicTrack, artSize: CGFloat) -> some View {
        if showInlineLyrics {
            HarborInlineLyricsCanvas()
                .frame(width: artSize, height: artSize)
        } else {
            let beat = isAnimatedAuraEnabled ? audioManager.beatPulseLevel : 0.0
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let uiImg = loadedCoverImage {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFill()
                            .frame(width: artSize, height: artSize)
                            .clipped()
                    } else {
                        AsyncImage(url: URL(string: track.artworkURL ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: artSize, height: artSize)
                                    .clipped()
                            default:
                                ZStack {
                                    Color.black.opacity(0.38)
                                    Image(systemName: "music.note")
                                        .font(.harbor(size: 64))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .frame(width: artSize, height: artSize)
                            }
                        }
                    }
                }
                .frame(width: artSize, height: artSize)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.24 + Double(beat) * 0.16), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                )
                .shadow(
                    color: isAnimatedAuraEnabled ? bgAccentGlow.opacity(0.38 + Double(beat) * 0.28) : .black.opacity(0.62),
                    radius: 22 + beat * 16,
                    y: 10
                )

                HStack(spacing: 6) {
                    Image(systemName: audioManager.isPlaying ? "waveform" : "sparkles")
                        .font(.harbor(size: 10, weight: .bold))
                        .symbolEffect(.variableColor.iterative, isActive: audioManager.isPlaying)
                    Text("\(audioManager.dspPreset.shortBadge) • NOIR")
                        .font(.harbor(size: 10.5, weight: .bold))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.6))
                .padding(12)
            }
            .frame(width: artSize, height: artSize)
            .scaleEffect(audioManager.isPlaying ? (1.0 + beat * 0.022) : 0.97)
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: audioManager.isPlaying)
            .onTapGesture {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                    showInlineLyrics = true
                }
            }
        }
    }

    @ViewBuilder
    private func playerTitleAndArtistRow(track: HarborMusicTrack, width: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                let next: HarborAudioDSPPreset = (audioManager.dspPreset == .slowedReverb) ? .normal : .slowedReverb
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    audioManager.selectDSPPreset(next)
                }
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: audioManager.dspPreset == .normal ? "sparkles" : "water.waves")
                            .font(.harbor(size: 11, weight: .bold))
                        Text(audioManager.dspPreset == .normal ? "صوتك الخاص" : "مفعّل الآن")
                            .font(.harbor(size: 10.5, weight: .bold))
                    }
                    .foregroundStyle(audioManager.dspPreset == .normal ? .white.opacity(0.85) : .black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(audioManager.dspPreset == .normal ? Color.white.opacity(0.12) : Color.white)
                    .clipShape(Capsule())

                    Text("طابع ليل هادئ • Noir")
                        .font(.harbor(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.52))
                        .padding(.leading, 4)
                }
            }
            .buttonStyle(SmoothPressButtonStyle())

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Button {
                    openArtistProfile(for: track)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.harbor(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.65))
                        Text(track.title)
                            .font(.harbor(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    openArtistProfile(for: track)
                } label: {
                    Text(track.artist)
                        .font(.harbor(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: width)
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func playerDSPPillsStrip(width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let current = audioManager.currentTrack {
                    Button {
                        audioManager.toggleFavorite(current)
                    } label: {
                        let fav = audioManager.isFavorite(current)
                        HStack(spacing: 5) {
                            Image(systemName: fav ? "heart.fill" : "heart")
                                .foregroundStyle(fav ? .red : .white)
                            Text(fav ? "مفضلة" : "أعجبني")
                                .font(.harbor(size: 12.5, weight: .bold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.14))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(SmoothPressButtonStyle())
                }

                Button {
                    showQueueAndPlaylistsSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.below.rectangle")
                            .font(.harbor(size: 12.5, weight: .bold))
                        Text("الطابور والقوائم (\(audioManager.queue.count))")
                            .font(.harbor(size: 12.5, weight: .bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.14))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(SmoothPressButtonStyle())

                HarborAirPlayRoutePicker()
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())

                Button {
                    showDedicatedLyricsSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Text("كلمات الأغنية")
                            .font(.harbor(size: 13, weight: .bold))
                        Image(systemName: "quote.bubble.fill")
                            .font(.harbor(size: 12.5, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.14))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.7))
                }
                .buttonStyle(SmoothPressButtonStyle())

                ForEach(HarborAudioDSPPreset.allCases) { preset in
                    let isSelected = (audioManager.dspPreset == preset)
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            audioManager.selectDSPPreset(preset)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: preset.iconName)
                                .font(.harbor(size: 12, weight: .bold))
                            Text(preset.shortBadge)
                                .font(.harbor(size: 12.5, weight: .bold))
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 9)
                        .background(isSelected ? Color.white : Color.white.opacity(0.12))
                        .foregroundStyle(isSelected ? Color.black : Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(isSelected ? 0 : 0.10), lineWidth: 0.7))
                    }
                    .buttonStyle(SmoothPressButtonStyle())
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showCustomDSPSliders.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.harbor(size: 12, weight: .bold))
                        Text("ضبط الصدى والسرعة")
                            .font(.harbor(size: 12.5, weight: .bold))
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(showCustomDSPSliders ? Color.white : Color.white.opacity(0.12))
                    .foregroundStyle(showCustomDSPSliders ? Color.black : Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(SmoothPressButtonStyle())
            }
            .padding(.horizontal, 22)
        }
        .frame(width: width)
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func playerProgressScrubber(width: CGFloat) -> some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { audioManager.currentTime },
                    set: { audioManager.seek(to: $0) }
                ),
                in: 0...max(audioManager.duration, 1)
            )
            .tint(.white)

            HStack {
                Text(formatTime(audioManager.currentTime))
                    .contentTransition(.numericText())
                Spacer()
                Text("\(audioManager.activeEngineLabel) • \(String(format: "%.2fx", audioManager.playbackSpeed))")
                    .font(.harbor(size: 9.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
                Spacer()
                Text(formatTime(audioManager.duration))
                    .contentTransition(.numericText())
            }
            .font(.harbor(size: 12.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.82))
        }
        .frame(width: width)
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func playerTransportControls(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Button {
                audioManager.isShuffleEnabled.toggle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.harbor(size: 20, weight: .semibold))
                    .foregroundStyle(audioManager.isShuffleEnabled ? Color.white : .white.opacity(0.65))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SmoothPressButtonStyle())

            Button {
                audioManager.playPrevious()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.harbor(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SmoothPressButtonStyle())

            Button {
                audioManager.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 68, height: 68)
                        .shadow(color: .white.opacity(0.22 + Double(audioManager.beatPulseLevel) * 0.20), radius: 14, y: 4)

                    if audioManager.isResolvingFullStream {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.harbor(size: 25, weight: .black))
                            .foregroundStyle(Color.black)
                            .offset(x: audioManager.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(SmoothPressButtonStyle())
            .padding(.horizontal, 8)

            Button {
                audioManager.playNext()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.harbor(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SmoothPressButtonStyle())

            Button {
                audioManager.isRepeatEnabled.toggle()
            } label: {
                Image(systemName: "repeat")
                    .font(.harbor(size: 20, weight: .semibold))
                    .foregroundStyle(audioManager.isRepeatEnabled ? Color.white : .white.opacity(0.65))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SmoothPressButtonStyle())
        }
        .frame(width: width)
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func dspSlidersOverlay(viewW: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showCustomDSPSliders = false
                    }
                }

            VStack(spacing: 14) {
                HStack {
                    Button {
                        withAnimation { showCustomDSPSliders = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.harborTitle3)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Text("استوديو السرعة والصدى (DSP Studio)")
                        .font(.harborSubheadline.weight(.bold))
                        .foregroundStyle(.white)
                }

                HStack {
                    Text(String(format: "%.2fx", audioManager.playbackSpeed))
                        .font(.harbor(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Slider(
                        value: Binding(
                            get: { audioManager.playbackSpeed },
                            set: { newSpeed in
                                audioManager.updateCustomDSP(
                                    speed: newSpeed,
                                    reverb: audioManager.reverbMix,
                                    varispeed: audioManager.useAnalogVarispeedPitch
                                )
                            }
                        ),
                        in: 0.65...1.35,
                        step: 0.01
                    )
                    .tint(.white)
                    Text("سرعة الصوت")
                        .font(.harborCaption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                HStack {
                    Text("\(Int(audioManager.reverbMix * 100))%")
                        .font(.harbor(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Slider(
                        value: Binding(
                            get: { audioManager.reverbMix },
                            set: { newRev in
                                audioManager.updateCustomDSP(
                                    speed: audioManager.playbackSpeed,
                                    reverb: newRev,
                                    varispeed: audioManager.useAnalogVarispeedPitch
                                )
                            }
                        ),
                        in: 0.0...1.0,
                        step: 0.02
                    )
                    .tint(.white)
                    Text("عمق الصدى (Reverb)")
                        .font(.harborCaption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Toggle(isOn: Binding(
                    get: { audioManager.useAnalogVarispeedPitch },
                    set: { newVal in
                        audioManager.updateCustomDSP(
                            speed: audioManager.playbackSpeed,
                            reverb: audioManager.reverbMix,
                            varispeed: newVal
                        )
                    }
                )) {
                    Text("تغيير طبقة الصوت مع السرعة (Analog Tape Pitch)")
                        .font(.harborCaption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .tint(.white)
            }
            .padding(20)
            .background(Color(white: 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .frame(width: min(viewW - 32, 480))
            .padding(.bottom, 28)
            .environment(\.layoutDirection, .leftToRight)
        }
        .frame(width: viewW)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func openArtistProfile(for track: HarborMusicTrack) {
        let primary = track.artist.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? track.artist
        selectedArtistFromPlayer = HarborArtistSummary(
            id: "art-\(primary.lowercased())",
            name: primary,
            artworkURL: track.artworkURL,
            genre: track.genre ?? "Studio Artist"
        )
    }

    private func updateArtworkAndDominantColor(for track: HarborMusicTrack) async {
        loadedCoverImage = nil
        if let img = await HarborArtworkService.shared.loadImage(from: track.artworkURL) {
            self.loadedCoverImage = img
            let palette = HarborArtworkService.shared.extractDominantColors(from: img)
            withAnimation(.easeInOut(duration: 0.45)) {
                self.bgTopColor = palette.top
                self.bgMidColor = palette.middle
                self.bgBotColor = palette.bottom
                self.bgAccentGlow = palette.accentGlow
            }
        } else {
            withAnimation(.easeInOut(duration: 0.35)) {
                self.bgTopColor = Color(white: 0.34)
                self.bgMidColor = Color(white: 0.16)
                self.bgBotColor = Color(white: 0.02)
                self.bgAccentGlow = Color(white: 0.54)
            }
        }
    }

    private func formatTime(_ secs: Double) -> String {
        let total = max(Int(secs), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Pure Glowing Active Lyrics Canvas (ZERO Translucent Box — Only the Words Illuminate!)

struct HarborInlineLyricsCanvas: View {
    @EnvironmentObject var store: HarborStore
    @EnvironmentObject var audioManager: HarborAudioPlayerManager
    @State private var isUserScrollingLyrics: Bool = false
    @State private var resumeAutoScrollTask: Task<Void, Never>? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .center, spacing: 18) {
                        // Synced vs Plain Lyrics Status Pill + Retry Button
                        HStack(spacing: 8) {
                            Image(systemName: audioManager.isTrueSyncedLyrics ? "waveform.badge.magnifyingglass" : "doc.text")
                                .font(.harbor(size: 11, weight: .bold))
                            Text(audioManager.isTrueSyncedLyrics ? "متزامنة بالوقت • \(audioManager.lyricsSourceBadge)" : "نصية غير متزامنة • \(audioManager.lyricsSourceBadge)")
                                .font(.harbor(size: 11, weight: .bold))
                            Button {
                                audioManager.retryLyrics()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.harbor(size: 11, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.10))
                        .foregroundStyle(.white.opacity(0.75))
                        .clipShape(Capsule())

                        if audioManager.isLoadingLyrics {
                            VStack(spacing: 10) {
                                ProgressView().tint(.white)
                                Text("جاري جلب كلمات الأغنية...")
                                    .font(.harborCaption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                            .padding(.top, 60)
                        } else if audioManager.isTrueSyncedLyrics && !audioManager.syncedLyrics.isEmpty {
                            ForEach(Array(audioManager.syncedLyrics.enumerated()), id: \.element.id) { idx, line in
                                let isActive = isLineActive(index: idx, in: audioManager.syncedLyrics, time: audioManager.currentTime)
                                let isPast = audioManager.currentTime >= line.timestampSeconds && !isActive
                                Button {
                                    isUserScrollingLyrics = false
                                    audioManager.seek(to: line.timestampSeconds)
                                } label: {
                                    Text(line.text)
                                        .font(.harbor(size: isActive ? 22 : 15.5, weight: isActive ? .heavy : .semibold, design: .rounded))
                                        .foregroundStyle(isActive ? Color.white : Color.white.opacity(isPast ? 0.24 : 0.38))
                                        .shadow(color: isActive ? Color.white : .clear, radius: 6, x: 0, y: 0)
                                        .shadow(color: isActive ? Color.white.opacity(0.85) : .clear, radius: 14, x: 0, y: 0)
                                        .shadow(color: isActive ? Color.white.opacity(0.48) : .clear, radius: 26, x: 0, y: 0)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, isActive ? 8 : 3)
                                        .padding(.horizontal, 8)
                                        .scaleEffect(isActive ? (1.04 + audioManager.beatPulseLevel * 0.018) : 0.96)
                                        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isActive)
                                }
                                .buttonStyle(.plain)
                                .id(line.id)
                            }
                        } else if let plain = audioManager.plainLyrics, !plain.isEmpty {
                            Text(plain)
                                .font(.harbor(size: 17.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.95))
                                .shadow(color: Color.white.opacity(0.45), radius: 8)
                                .multilineTextAlignment(.center)
                                .lineSpacing(8)
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "text.quote")
                                    .font(.harborTitle)
                                    .foregroundStyle(.white.opacity(0.6))
                                Text("لا تتوفر كلمات لهذا المقطع حالياً")
                                    .font(.harborSubheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.55))
                                Button("إعادة البحث عن الكلمات") {
                                    audioManager.retryLyrics()
                                }
                                .font(.harborCaption.weight(.bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.14))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                            }
                            .padding(.top, 50)
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 10)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { _ in
                            pauseAutoScrollTemporarily()
                        }
                )
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.09),
                            .init(color: .black, location: 0.91),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .onChange(of: audioManager.currentTime) { _, newTime in
                    guard audioManager.isTrueSyncedLyrics, !isUserScrollingLyrics else { return }
                    if let active = activeLine(in: audioManager.syncedLyrics, time: newTime) {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            proxy.scrollTo(active.id, anchor: .center)
                        }
                    }
                }

                if isUserScrollingLyrics && audioManager.isTrueSyncedLyrics {
                    Button {
                        isUserScrollingLyrics = false
                        if let active = activeLine(in: audioManager.syncedLyrics, time: audioManager.currentTime) {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                proxy.scrollTo(active.id, anchor: .center)
                            }
                        }
                    } label: {
                        Label("العودة للسطر الحالي", systemImage: "scope")
                            .font(.harbor(size: 11.5, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 10)
                }
            }
        }
    }

    private func pauseAutoScrollTemporarily() {
        isUserScrollingLyrics = true
        resumeAutoScrollTask?.cancel()
        resumeAutoScrollTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            isUserScrollingLyrics = false
        }
    }

    private func isLineActive(index: Int, in lines: [SyncedLyricLine], time: Double) -> Bool {
        guard index < lines.count else { return false }
        let start = lines[index].timestampSeconds
        let end = (index + 1 < lines.count) ? lines[index + 1].timestampSeconds : (start + 8.0)
        return time >= start && time < end
    }

    private func activeLine(in lines: [SyncedLyricLine], time: Double) -> SyncedLyricLine? {
        for i in 0..<lines.count {
            if isLineActive(index: i, in: lines, time: time) { return lines[i] }
        }
        return nil
    }
}

// MARK: - Dedicated Full-Screen Lyrics Sheet (Pure Glowing Words — Zero Translucent Box + Manual Scroll Override)

struct HarborCleanLyricsSheet: View {
    @EnvironmentObject var store: HarborStore
    @EnvironmentObject var audioManager: HarborAudioPlayerManager
    @Environment(\.dismiss) private var dismiss
    @State private var isUserScrollingLyrics: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea(.all)

            LinearGradient(
                colors: [
                    Color(white: 0.22).opacity(0.45),
                    Color(white: 0.08).opacity(0.35),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.harbor(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 34, height: 34)
                            .background(Color(white: 0.10))
                            .clipShape(Circle())
                    }

                    Spacer()

                    if let track = audioManager.currentTrack {
                        VStack(spacing: 2) {
                            Text(track.title)
                                .font(.harbor(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(track.artist) • \(audioManager.isTrueSyncedLyrics ? "Synced LRC" : "Plain Text")")
                                .font(.harbor(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button {
                        audioManager.retryLyrics()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.harbor(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color(white: 0.10))
                            .clipShape(Circle())
                    }

                    Button {
                        audioManager.togglePlayPause()
                    } label: {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.harbor(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color(white: 0.10))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .environment(\.layoutDirection, .leftToRight)

                Divider().overlay(Color.white.opacity(0.08))

                ScrollViewReader { proxy in
                    ZStack(alignment: .bottom) {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 20) {
                                if audioManager.isLoadingLyrics {
                                    HStack {
                                        Spacer()
                                        ProgressView().tint(.white)
                                        Spacer()
                                    }
                                    .padding(.top, 80)
                                } else if audioManager.isTrueSyncedLyrics && !audioManager.syncedLyrics.isEmpty {
                                    ForEach(Array(audioManager.syncedLyrics.enumerated()), id: \.element.id) { idx, line in
                                        let isActive = isCurrentLine(index: idx, in: audioManager.syncedLyrics, time: audioManager.currentTime)
                                        let isPast = audioManager.currentTime >= line.timestampSeconds && !isActive
                                        Button {
                                            isUserScrollingLyrics = false
                                            audioManager.seek(to: line.timestampSeconds)
                                        } label: {
                                            Text(line.text)
                                                .font(.harbor(size: isActive ? 25 : 19, weight: isActive ? .heavy : .semibold, design: .rounded))
                                                .foregroundStyle(isActive ? Color.white : Color.white.opacity(isPast ? 0.24 : 0.36))
                                                .shadow(color: isActive ? Color.white : .clear, radius: 7, x: 0, y: 0)
                                                .shadow(color: isActive ? Color.white.opacity(0.85) : .clear, radius: 16, x: 0, y: 0)
                                                .shadow(color: isActive ? Color.white.opacity(0.48) : .clear, radius: 28, x: 0, y: 0)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, isActive ? 10 : 4)
                                                .scaleEffect(isActive ? (1.03 + audioManager.beatPulseLevel * 0.015) : 0.97, anchor: .leading)
                                                .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isActive)
                                        }
                                        .buttonStyle(.plain)
                                        .id(line.id)
                                    }
                                } else if let plain = audioManager.plainLyrics, !plain.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("كلمات نصية غير متزامنة بالوقت")
                                            .font(.harborCaption.weight(.bold))
                                            .foregroundStyle(store.theme.accent)
                                        Text(plain)
                                            .font(.harbor(size: 20, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.94))
                                            .shadow(color: Color.white.opacity(0.40), radius: 8)
                                            .lineSpacing(10)
                                    }
                                } else {
                                    VStack(spacing: 12) {
                                        Text("لا تتوفر كلمات لهذا المقطع حالياً")
                                            .font(.harborHeadline)
                                            .foregroundStyle(.white.opacity(0.6))
                                        Button("إعادة المحاولة") {
                                            audioManager.retryLyrics()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(store.theme.accent)
                                        .foregroundStyle(.black)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 80)
                                }

                                Spacer(minLength: 90)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 26)
                            .environment(\.layoutDirection, .leftToRight)
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { _ in isUserScrollingLyrics = true }
                        )
                        .onChange(of: audioManager.currentTime) { _, newTime in
                            guard audioManager.isTrueSyncedLyrics, !isUserScrollingLyrics else { return }
                            if let active = currentActive(in: audioManager.syncedLyrics, time: newTime) {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    proxy.scrollTo(active.id, anchor: .center)
                                }
                            }
                        }

                        if isUserScrollingLyrics && audioManager.isTrueSyncedLyrics {
                            Button {
                                isUserScrollingLyrics = false
                                if let active = currentActive(in: audioManager.syncedLyrics, time: audioManager.currentTime) {
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        proxy.scrollTo(active.id, anchor: .center)
                                    }
                                }
                            } label: {
                                Label("العودة للسطر الحالي", systemImage: "scope")
                                    .font(.harborCaption.weight(.bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                                    .background(store.theme.accent)
                                    .foregroundStyle(.black)
                                    .clipShape(Capsule())
                            }
                            .padding(.bottom, 22)
                        }
                    }
                }
            }
        }
    }

    private func isCurrentLine(index: Int, in lines: [SyncedLyricLine], time: Double) -> Bool {
        guard index < lines.count else { return false }
        let currentStart = lines[index].timestampSeconds
        let nextStart = (index + 1 < lines.count) ? lines[index + 1].timestampSeconds : (currentStart + 8.0)
        return time >= currentStart && time < nextStart
    }

    private func currentActive(in lines: [SyncedLyricLine], time: Double) -> SyncedLyricLine? {
        for i in 0..<lines.count {
            if isCurrentLine(index: i, in: lines, time: time) {
                return lines[i]
            }
        }
        return nil
    }
}

// MARK: - Interactive Queue, Favorites, Recently Played & Playlists Sheet (Phase 4 Upgrade)

struct HarborMusicQueueAndPlaylistsSheet: View {
    @EnvironmentObject var store: HarborStore
    @EnvironmentObject var audioManager: HarborAudioPlayerManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: Int = 0
    @State private var newPlaylistName: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("القسم", selection: $selectedSection) {
                    Text("الطابور (\(audioManager.queue.count))").tag(0)
                    Text("المفضلة (\(audioManager.favoriteTracks.count))").tag(1)
                    Text("الأخيرة (\(audioManager.recentlyPlayedTracks.count))").tag(2)
                    Text("قوائمي (\(audioManager.userPlaylists.count))").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    if selectedSection == 0 {
                        Section("ترتيب التشغيل القادم (اسحب لإعادة الترتيب أو الحذف)") {
                            ForEach(audioManager.queue) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.harborSubheadline.weight(.bold))
                                            .foregroundStyle(item.id == audioManager.currentTrack?.id ? store.theme.accent : .white)
                                        Text(item.artist)
                                            .font(.harborCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if item.id == audioManager.currentTrack?.id {
                                        Image(systemName: "waveform")
                                            .foregroundStyle(store.theme.accent)
                                    } else {
                                        Button {
                                            audioManager.play(track: item, queue: audioManager.queue)
                                        } label: {
                                            Image(systemName: "play.circle.fill")
                                                .font(.harborTitle3)
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .onDelete(perform: audioManager.removeFromQueue)
                            .onMove(perform: audioManager.moveInQueue)
                        }
                    } else if selectedSection == 1 {
                        Section("الأغاني المفضلة") {
                            if audioManager.favoriteTracks.isEmpty {
                                Text("لم تضف أي أغنية للمفضلة بعد.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(audioManager.favoriteTracks) { track in
                                    Button {
                                        audioManager.play(track: track, queue: audioManager.favoriteTracks)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(track.title).font(.harborSubheadline.weight(.bold))
                                                Text(track.artist).font(.harborCaption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "heart.fill").foregroundStyle(.red)
                                        }
                                    }
                                }
                            }
                        }
                    } else if selectedSection == 2 {
                        Section("المشغلة مؤخراً") {
                            if audioManager.recentlyPlayedTracks.isEmpty {
                                Text("لا يوجد سجل استماع حتى الآن.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(audioManager.recentlyPlayedTracks) { track in
                                    Button {
                                        audioManager.play(track: track, queue: audioManager.recentlyPlayedTracks)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(track.title).font(.harborSubheadline.weight(.bold))
                                                Text(track.artist).font(.harborCaption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        Section("إنشاء قائمة تشغيل جديدة") {
                            HStack {
                                TextField("اسم القائمة الجديدة...", text: $newPlaylistName)
                                Button("إنشاء") {
                                    audioManager.createPlaylist(name: newPlaylistName)
                                    newPlaylistName = ""
                                }
                                .disabled(newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        ForEach(audioManager.userPlaylists) { pl in
                            Section("\(pl.name) (\(pl.tracks.count) أغنية)") {
                                if let cur = audioManager.currentTrack {
                                    Button {
                                        audioManager.addTrack(cur, toPlaylistID: pl.id)
                                    } label: {
                                        Label("إضافة الأغنية الحالية (\(cur.title))", systemImage: "plus.circle.fill")
                                            .foregroundStyle(store.theme.accent)
                                    }
                                }
                                ForEach(pl.tracks) { t in
                                    Button {
                                        audioManager.play(track: t, queue: pl.tracks)
                                    } label: {
                                        HStack {
                                            Text(t.title).font(.harborSubheadline)
                                            Spacer()
                                            Text(t.artist).font(.harborCaption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("إدارة الطابور والمكتبة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedSection == 0 { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("تم") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 15. Harbor Books & Native PDF Reader Room (Harbor Desktop Style — Local PDF Upload + PDFKit Engine)

struct HarborLocalPDFItem: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var author: String
    let fileName: String
    var pageCount: Int
    var lastReadPage: Int
    let fileSizeDisplay: String
    let addedAt: Date

    var progressFraction: Double {
        guard pageCount > 1 else { return 1.0 }
        return min(max(Double(lastReadPage) / Double(pageCount), 0.0), 1.0)
    }
}

enum HarborPDFDisplayModeOption: String, CaseIterable, Identifiable {
    case continuous = "تمرير مستمر"
    case singlePage = "صفحة مفردة"
    case twoUp = "صفحتان (Desktop)"

    var id: String { rawValue }
}

enum HarborPDFColorThemeOption: String, CaseIterable, Identifiable {
    case original = "أصلي (Original)"
    case sepia = "ورق دافئ (Sepia)"
    case darkNight = "ليلي (Dark)"

    var id: String { rawValue }
}

@MainActor
final class HarborPDFBookLibrary: ObservableObject {
    @Published var localPDFs: [HarborLocalPDFItem] = []
    @Published var importStatusMessage: String? = nil

    private let storageKey = "harbor.localPDFs.v24"

    init() {
        loadSavedPDFs()
    }

    var pdfDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let dir = docs.appendingPathComponent("HarborPDFs", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func fileURL(for item: HarborLocalPDFItem) -> URL {
        pdfDirectory.appendingPathComponent(item.fileName)
    }

    func loadSavedPDFs() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HarborLocalPDFItem].self, from: data) else {
            return
        }
        self.localPDFs = decoded.filter { FileManager.default.fileExists(atPath: fileURL(for: $0).path) }
    }

    func savePDFs() {
        if let encoded = try? JSONEncoder().encode(localPDFs) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    func updateLastPage(for itemID: String, pageIndex: Int) {
        guard let idx = localPDFs.firstIndex(where: { $0.id == itemID }) else { return }
        localPDFs[idx].lastReadPage = max(pageIndex, 1)
        savePDFs()
    }

    func deletePDF(_ item: HarborLocalPDFItem) {
        let url = fileURL(for: item)
        try? FileManager.default.removeItem(at: url)
        localPDFs.removeAll { $0.id == item.id }
        savePDFs()
    }

    func importPDFFiles(from urls: [URL]) {
        var importedCount = 0
        for sourceURL in urls {
            let accessed = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if accessed { sourceURL.stopAccessingSecurityScopedResource() }
            }

            let safeName = "\(UUID().uuidString.prefix(8))_\(sourceURL.lastPathComponent)"
            let destURL = pdfDirectory.appendingPathComponent(safeName)

            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)

                let ext = destURL.pathExtension.lowercased()
                let cleanFileName = sourceURL.deletingPathExtension().lastPathComponent
                var pages = 1
                var finalTitle = cleanFileName
                var rawAuthor = "ملف \(ext.uppercased()) محلي"

                if ext == "pdf", let pdfDoc = PDFDocument(url: destURL) {
                    pages = max(pdfDoc.pageCount, 1)
                    let rawTitle = (pdfDoc.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if let rt = rawTitle, !rt.isEmpty { finalTitle = rt }
                    if let ra = (pdfDoc.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines), !ra.isEmpty {
                        rawAuthor = ra
                    }
                } else if ext == "epub", let epubChapters = try? HarborEPUBParser.parseEPUB(at: destURL) {
                    pages = max(epubChapters.count, 1)
                    rawAuthor = "كتاب EPUB محلي قابل لإعادة التدفق"
                } else if let txtChapters = try? HarborEPUBParser.parsePlainTextFile(at: destURL) {
                    pages = max(txtChapters.count, 1)
                    rawAuthor = "وثيقة نصية محلية"
                }

                let attrs = try? FileManager.default.attributesOfItem(atPath: destURL.path)
                let byteSize = (attrs?[.size] as? Int64) ?? 0
                let mb = Double(byteSize) / 1_048_576.0
                let sizeStr = mb >= 1.0 ? String(format: "%.1f MB", mb) : String(format: "%.0f KB", max(Double(byteSize) / 1024.0, 12))

                let newItem = HarborLocalPDFItem(
                    id: UUID().uuidString,
                    title: finalTitle,
                    author: rawAuthor,
                    fileName: safeName,
                    pageCount: pages,
                    lastReadPage: 1,
                    fileSizeDisplay: sizeStr,
                    addedAt: Date()
                )
                localPDFs.insert(newItem, at: 0)
                importedCount += 1
            } catch {
                importStatusMessage = "تعذر استيراد الملف: \(error.localizedDescription)"
            }
        }
        if importedCount > 0 {
            savePDFs()
            importStatusMessage = "✅ تم رفع وإضافة \(importedCount) ملف PDF إلى مكتبتك بنجاح"
        }
    }
}

struct HarborPDFCoverThumbnailView: View {
    let fileURL: URL
    let accent: Color
    @State private var thumbnail: UIImage? = nil

    var body: some View {
        ZStack {
            if let img = thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(white: 0.09), Color(white: 0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 8) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.harbor(size: 34))
                        .foregroundStyle(accent)
                    Text("PDF")
                        .font(.harborCaption.weight(.black))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .onAppear {
            guard thumbnail == nil else { return }
            if let doc = PDFDocument(url: fileURL), let page = doc.page(at: 0) {
                thumbnail = page.thumbnail(of: CGSize(width: 240, height: 340), for: .cropBox)
            }
        }
    }
}

struct HarborPDFKitRepresentable: UIViewRepresentable {
    let fileURL: URL
    let displayModeOption: HarborPDFDisplayModeOption
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var zoomScaleFactor: CGFloat
    let searchQuery: String
    let searchTriggerID: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor.black
        pdfView.pageBreakMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        if let doc = PDFDocument(url: fileURL) {
            pdfView.document = doc
            DispatchQueue.main.async {
                self.totalPages = max(doc.pageCount, 1)
                if self.currentPage > 1, let targetPage = doc.page(at: self.currentPage - 1) {
                    pdfView.go(to: targetPage)
                }
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageDidChange(_:)),
            name: Notification.Name.PDFViewPageChanged,
            object: pdfView
        )
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        switch displayModeOption {
        case .continuous:
            if pdfView.displayMode != .singlePageContinuous {
                pdfView.usePageViewController(false)
                pdfView.displayMode = .singlePageContinuous
                pdfView.autoScales = true
            }
        case .singlePage:
            if pdfView.displayMode != .singlePage {
                pdfView.displayMode = .singlePage
                pdfView.usePageViewController(true)
                pdfView.autoScales = true
            }
        case .twoUp:
            if pdfView.displayMode != .twoUpContinuous {
                pdfView.usePageViewController(false)
                pdfView.displayMode = .twoUpContinuous
                pdfView.autoScales = true
            }
        }

        if let doc = pdfView.document {
            let currentIdx = (pdfView.currentPage.map { doc.index(for: $0) } ?? 0) + 1
            if currentIdx != currentPage, currentPage >= 1, currentPage <= doc.pageCount,
               let target = doc.page(at: currentPage - 1) {
                pdfView.go(to: target)
            }

            if context.coordinator.lastSearchTriggerID != searchTriggerID {
                context.coordinator.lastSearchTriggerID = searchTriggerID
                let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let matches = doc.findString(trimmed, withOptions: [.caseInsensitive])
                    if !matches.isEmpty {
                        let pickIdx = searchTriggerID % matches.count
                        let sel = matches[pickIdx]
                        sel.color = .systemYellow
                        pdfView.setCurrentSelection(sel, animate: true)
                        pdfView.go(to: sel)
                    }
                } else {
                    pdfView.clearSelection()
                }
            }
        }

        if abs(zoomScaleFactor - 1.0) > 0.05 {
            let base = pdfView.scaleFactorForSizeToFit
            if base > 0 {
                pdfView.scaleFactor = base * zoomScaleFactor
            }
        }
    }

    final class Coordinator: NSObject {
        var parent: HarborPDFKitRepresentable
        var lastSearchTriggerID: Int = 0

        init(_ parent: HarborPDFKitRepresentable) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func pageDidChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let doc = pdfView.document,
                  let page = pdfView.currentPage else { return }
            let idx = doc.index(for: page) + 1
            DispatchQueue.main.async {
                if self.parent.currentPage != idx {
                    self.parent.currentPage = idx
                }
            }
        }
    }
}

struct HarborDesktopPDFReaderModal: View {
    @EnvironmentObject var store: HarborStore
    @ObservedObject var pdfLibrary: HarborPDFBookLibrary
    let item: HarborLocalPDFItem
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1
    @State private var displayMode: HarborPDFDisplayModeOption = .continuous
    @State private var colorTheme: HarborPDFColorThemeOption = .original
    @State private var zoomScaleFactor: CGFloat = 1.0
    @State private var isShowingSearchBar: Bool = false
    @State private var searchText: String = ""
    @State private var searchTriggerID: Int = 0
    @State private var showHUD: Bool = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack {
                HarborPDFKitRepresentable(
                    fileURL: pdfLibrary.fileURL(for: item),
                    displayModeOption: displayMode,
                    currentPage: $currentPage,
                    totalPages: $totalPages,
                    zoomScaleFactor: $zoomScaleFactor,
                    searchQuery: searchText,
                    searchTriggerID: searchTriggerID
                )
                .ignoresSafeArea()
                .ifColorInvert(colorTheme == .darkNight)

                if colorTheme == .sepia {
                    Color(red: 0.94, green: 0.85, blue: 0.68)
                        .opacity(0.22)
                        .blendMode(.multiply)
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }
            }
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    zoomScaleFactor = (zoomScaleFactor > 1.1) ? 1.0 : 1.5
                }
            }

            VStack(spacing: 0) {
                if showHUD {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Button {
                                pdfLibrary.updateLastPage(for: item.id, pageIndex: currentPage)
                                dismiss()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "xmark")
                                        .font(.harbor(size: 14, weight: .bold))
                                    Text("إغلاق")
                                        .font(.harborCaption.weight(.bold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.12))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                            }

                            Menu {
                                Picker("نمط العرض", selection: $displayMode) {
                                    ForEach(HarborPDFDisplayModeOption.allCases) { opt in
                                        Text(opt.rawValue).tag(opt)
                                    }
                                }
                                Picker("مظهر الورق", selection: $colorTheme) {
                                    ForEach(HarborPDFColorThemeOption.allCases) { themeOpt in
                                        Text(themeOpt.rawValue).tag(themeOpt)
                                    }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "rectangle.split.2x1")
                                    Text(displayMode.rawValue)
                                        .font(.harborCaption.weight(.bold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.12))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                            }

                            HStack(spacing: 8) {
                                Button {
                                    zoomScaleFactor = max(zoomScaleFactor - 0.25, 0.75)
                                } label: {
                                    Image(systemName: "minus.magnifyingglass")
                                        .font(.harbor(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                Button {
                                    zoomScaleFactor = 1.0
                                } label: {
                                    Text("\(Int(zoomScaleFactor * 100))%")
                                        .font(.harbor(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(store.theme.accent)
                                }
                                Button {
                                    zoomScaleFactor = min(zoomScaleFactor + 0.25, 3.0)
                                } label: {
                                    Image(systemName: "plus.magnifyingglass")
                                        .font(.harbor(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Capsule())

                            Button {
                                withAnimation { isShowingSearchBar.toggle() }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.harbor(size: 14, weight: .bold))
                                    .foregroundStyle(isShowingSearchBar ? store.theme.accent : .white)
                                    .frame(width: 34, height: 34)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(Circle())
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.title)
                                    .font(.harbor(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text("Harbor PDF Reader • صفحة \(currentPage) من \(totalPages)")
                                    .font(.harbor(size: 10.5, weight: .semibold))
                                    .foregroundStyle(store.theme.accent)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                        .environment(\.layoutDirection, .leftToRight)

                        if isShowingSearchBar {
                            HStack(spacing: 10) {
                                Button {
                                    searchTriggerID += 1
                                } label: {
                                    Text("التالي")
                                        .font(.harborCaption.weight(.bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(store.theme.accent)
                                        .foregroundStyle(.black)
                                        .clipShape(Capsule())
                                }

                                TextField("ابحث عن كلمة داخل ملف PDF...", text: $searchText)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(.white)
                                    .submitLabel(.search)
                                    .onSubmit {
                                        searchTriggerID += 1
                                    }

                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundStyle(store.theme.accent)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                            .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                    .background(.ultraThinMaterial)
                }

                Spacer()

                if showHUD {
                    VStack(spacing: 10) {
                        HStack(spacing: 14) {
                            Button {
                                if currentPage > 1 { currentPage -= 1 }
                            } label: {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.harborTitle2)
                                    .foregroundStyle(currentPage > 1 ? .white : .white.opacity(0.3))
                            }
                            .disabled(currentPage <= 1)

                            Slider(
                                value: Binding(
                                    get: { Double(currentPage) },
                                    set: { currentPage = max(min(Int($0.rounded()), totalPages), 1) }
                                ),
                                in: 1...Double(max(totalPages, 2)),
                                step: 1
                            )
                            .tint(store.theme.accent)

                            Button {
                                if currentPage < totalPages { currentPage += 1 }
                            } label: {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.harborTitle2)
                                    .foregroundStyle(currentPage < totalPages ? .white : .white.opacity(0.3))
                            }
                            .disabled(currentPage >= totalPages)
                        }
                        .environment(\.layoutDirection, .leftToRight)

                        HStack {
                            Text("نمط القراءة العادي (بدون AI) • Harbor Desktop PDF Engine")
                                .font(.harbor(size: 10.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                            Spacer()
                            Text("صفحة \(currentPage) / \(totalPages)")
                                .font(.harbor(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .onAppear {
            currentPage = max(item.lastReadPage, 1)
            totalPages = max(item.pageCount, 1)
        }
        .onChange(of: currentPage) { _, newPage in
            pdfLibrary.updateLastPage(for: item.id, pageIndex: newPage)
        }
    }
}

extension View {
    @ViewBuilder
    func ifColorInvert(_ condition: Bool) -> some View {
        if condition {
            self.colorInvert()
        } else {
            self
        }
    }
}

struct HarborBooksRoomView: View {
    @EnvironmentObject var store: HarborStore
    @StateObject private var pdfLibrary = HarborPDFBookLibrary()
    @State private var searchQuery: String = ""
    @State private var selectedBook: HarborBookItem? = nil
    @State private var selectedPDFItem: HarborLocalPDFItem? = nil
    @State private var isShowingPDFFileImporter: Bool = false

    private let columns = [
        GridItem(.adaptive(minimum: 145, maximum: 185), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .center) {
                            Button {
                                isShowingPDFFileImporter = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.rectangle.on.folder.fill")
                                        .font(.harbor(size: 14, weight: .bold))
                                    Text("رفع ملف PDF")
                                        .font(.harborSubheadline.weight(.bold))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(store.theme.accent)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                                .shadow(color: store.theme.accent.opacity(0.45), radius: 10, y: 4)
                            }
                            .buttonStyle(SmoothPressButtonStyle())

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("مكتبة الكتب و PDF")
                                    .font(.harbor(size: 27, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("HARBOR DESKTOP PDF & EBOOK READER")
                                    .font(.harbor(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(store.theme.accent)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .environment(\.layoutDirection, .leftToRight)

                        Button {
                            isShowingPDFFileImporter = true
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(store.theme.accent.opacity(0.18))
                                        .frame(width: 64, height: 64)
                                    Image(systemName: "doc.viewfinder.fill")
                                        .font(.harbor(size: 30, weight: .bold))
                                        .foregroundStyle(store.theme.accent)
                                }

                                VStack(alignment: .trailing, spacing: 5) {
                                    Text("فتح ورفع ملف PDF من جهازك (iPhone Files)")
                                        .font(.harbor(size: 16, weight: .heavy))
                                        .foregroundStyle(.white)
                                    Text("يفتح بمشغل Harbor PDF الأصلي نفس نسخة الكمبيوتر (تمرير مستمر، صفحتان، بحث، ووضع ليلي/ورقي بدون AI)")
                                        .font(.harbor(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.68))
                                        .multilineTextAlignment(.trailing)
                                        .lineLimit(2)
                                }
                                Spacer()
                            }
                            .padding(16)
                            .background(
                                LinearGradient(
                                    colors: [Color(white: 0.08), Color(white: 0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(store.theme.accent.opacity(0.65), style: StrokeStyle(lineWidth: 1.4, dash: [6, 4]))
                            )
                        }
                        .buttonStyle(SmoothPressButtonStyle())
                        .padding(.horizontal, 16)

                        if let status = pdfLibrary.importStatusMessage {
                            Text(status)
                                .font(.harborCaption.weight(.bold))
                                .foregroundStyle(store.theme.accent)
                                .padding(.horizontal, 20)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("ملفات PDF المرفوعة (\(pdfLibrary.localPDFs.count))")
                                    .font(.harborTitle3.weight(.bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                if !pdfLibrary.localPDFs.isEmpty {
                                    Button("إضافة المزيد") {
                                        isShowingPDFFileImporter = true
                                    }
                                    .font(.harborCaption.weight(.bold))
                                    .foregroundStyle(store.theme.accent)
                                }
                            }
                            .padding(.horizontal, 18)

                            if pdfLibrary.localPDFs.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 10) {
                                        Image(systemName: "book.pages")
                                            .font(.harbor(size: 38))
                                            .foregroundStyle(.white.opacity(0.35))
                                        Text("لم تقم برفع أي ملف PDF بعد")
                                            .font(.harborSubheadline.weight(.bold))
                                            .foregroundStyle(.white.opacity(0.75))
                                        Text("اضغط على «رفع ملف PDF» بالأعلى لاختيار أي كتاب من تطبيق الملفات في الآيفون وتشغيله مباشرة.")
                                            .font(.harborCaption)
                                            .foregroundStyle(.white.opacity(0.50))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 24)
                                    }
                                    .padding(.vertical, 24)
                                    Spacer()
                                }
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .padding(.horizontal, 16)
                            } else {
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(pdfLibrary.localPDFs) { pdfItem in
                                        Button {
                                            let localURL = pdfLibrary.fileURL(for: pdfItem)
                                            if localURL.pathExtension.lowercased() == "pdf" {
                                                selectedPDFItem = pdfItem
                                            } else {
                                                selectedBook = HarborBookItem(
                                                    id: pdfItem.id,
                                                    title: pdfItem.title,
                                                    authors: [pdfItem.author],
                                                    coverURL: nil,
                                                    publishYear: pdfItem.fileSizeDisplay,
                                                    subjects: [localURL.pathExtension.uppercased()],
                                                    description: "ملف محلي مستورد من تطبيق الملفات",
                                                    textContentURL: localURL.absoluteString,
                                                    sampleChapters: [HarborBookChapter(number: 1, title: pdfItem.title, body: "جاري قراءة فصول الكتاب المحلي...")],
                                                    savedBookmarkChapter: max(pdfItem.lastReadPage - 1, 0),
                                                    savedScrollProgress: pdfItem.progressFraction
                                                )
                                            }
                                        } label: {
                                            VStack(alignment: .leading, spacing: 8) {
                                                ZStack(alignment: .topTrailing) {
                                                    HarborPDFCoverThumbnailView(
                                                        fileURL: pdfLibrary.fileURL(for: pdfItem),
                                                        accent: store.theme.accent
                                                    )
                                                    .frame(height: 215)
                                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                            .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                                                    )

                                                    Button {
                                                        pdfLibrary.deletePDF(pdfItem)
                                                    } label: {
                                                        Image(systemName: "trash.circle.fill")
                                                            .font(.harborTitle3)
                                                            .foregroundStyle(Color.white, Color.red.opacity(0.85))
                                                            .padding(8)
                                                    }
                                                }

                                                Text(pdfItem.title)
                                                    .font(.harborSubheadline.weight(.bold))
                                                    .foregroundStyle(.white)
                                                    .lineLimit(1)

                                                HStack {
                                                    Text("صفحة \(pdfItem.lastReadPage)/\(pdfItem.pageCount)")
                                                        .font(.harborCaption2.weight(.bold))
                                                        .foregroundStyle(store.theme.accent)
                                                    Spacer()
                                                    Text(pdfItem.fileSizeDisplay)
                                                        .font(.harborCaption2)
                                                        .foregroundStyle(.white.opacity(0.55))
                                                }

                                                ProgressView(value: pdfItem.progressFraction)
                                                    .tint(store.theme.accent)
                                            }
                                            .padding(10)
                                            .background(Color(white: 0.07))
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        }
                                        .buttonStyle(SmoothPressButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("كتالوج الكتب العالمية المفتوحة (Open Library)")
                                    .font(.harborHeadline.weight(.bold))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 18)

                            HStack(spacing: 10) {
                                TextField("ابحث في مكتبة الكتب المفتوحة...", text: $searchQuery)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit {
                                        Task { await store.loadBooksCatalog(query: searchQuery) }
                                    }
                                Button {
                                    Task { await store.loadBooksCatalog(query: searchQuery) }
                                } label: {
                                    Image(systemName: "magnifyingglass")
                                        .padding(10)
                                        .background(store.theme.accent)
                                        .foregroundStyle(.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .padding(.horizontal, 16)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(store.booksCatalog) { book in
                                    Button {
                                        selectedBook = book
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            AsyncImage(url: URL(string: book.coverURL ?? "")) { phase in
                                                switch phase {
                                                case .success(let img):
                                                    img.resizable().scaledToFill()
                                                default:
                                                    ZStack {
                                                        Color(white: 0.09)
                                                        Image(systemName: "book.closed.fill")
                                                            .font(.harborLargeTitle)
                                                            .foregroundStyle(store.theme.accent.opacity(0.7))
                                                    }
                                                }
                                            }
                                            .frame(height: 205)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                            Text(book.title)
                                                .font(.harborSubheadline.weight(.bold))
                                                .foregroundStyle(.white)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)

                                            Text(book.authorLine)
                                                .font(.harborCaption)
                                                .foregroundStyle(.white.opacity(0.60))
                                                .lineLimit(1)
                                        }
                                        .padding(10)
                                        .background(Color(white: 0.07))
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                    .buttonStyle(SmoothPressButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 130)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(
                isPresented: $isShowingPDFFileImporter,
                allowedContentTypes: [.pdf, .epub, .plainText, .html, .data],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    pdfLibrary.importPDFFiles(from: urls)
                case .failure(let err):
                    pdfLibrary.importStatusMessage = "تعذر اختيار الملف: \(err.localizedDescription)"
                }
            }
            .fullScreenCover(item: $selectedPDFItem) { pdfItem in
                HarborDesktopPDFReaderModal(pdfLibrary: pdfLibrary, item: pdfItem)
                    .environmentObject(store)
                    .preferredColorScheme(.dark)
            }
            .sheet(item: $selectedBook) { book in
                HarborNativeBookReaderModal(book: book)
                    .environmentObject(store)
                    .preferredColorScheme(.dark)
            }
        }
    }
}

struct HarborNativeBookReaderModal: View {
    @EnvironmentObject var store: HarborStore
    let book: HarborBookItem
    @Environment(\.dismiss) private var dismiss

    @State private var chapters: [HarborBookChapter] = []
    @State private var selectedChapterIndex: Int = 0
    @State private var fontSize: CGFloat = 19
    @State private var lineSpacing: CGFloat = 8
    @State private var horizontalMargin: CGFloat = 22
    @State private var selectedTheme: String = "Noir"
    @State private var useSerifFont: Bool = true
    @State private var isRightToLeft: Bool = true
    @State private var searchQuery: String = ""
    @State private var bookmarks: [HarborBookBookmark] = []
    @State private var notes: [HarborBookNote] = []
    @State private var newNoteText: String = ""
    @State private var showNotesDrawer: Bool = false
    @State private var isLoadingRemoteText: Bool = false

    private var themeBackground: Color {
        switch selectedTheme {
        case "Sepia": return Color(red: 0.95, green: 0.90, blue: 0.80)
        case "Light": return Color(white: 0.97)
        case "Midnight": return Color(red: 0.05, green: 0.08, blue: 0.14)
        default: return Color.black
        }
    }

    private var themeForeground: Color {
        switch selectedTheme {
        case "Sepia": return Color(red: 0.22, green: 0.16, blue: 0.10)
        case "Light": return Color.black.opacity(0.88)
        default: return Color.white.opacity(0.92)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Reader Customization Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if !chapters.isEmpty {
                            Picker("الفصل", selection: $selectedChapterIndex) {
                                ForEach(0..<chapters.count, id: \.self) { idx in
                                    Text(chapters[idx].title).tag(idx)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        Divider().frame(height: 18)

                        Button { fontSize = max(14, fontSize - 2) } label: { Image(systemName: "textformat.size.smaller") }
                        Text("\(Int(fontSize))pt").font(.harborCaption2)
                        Button { fontSize = min(32, fontSize + 2) } label: { Image(systemName: "textformat.size.larger") }

                        Divider().frame(height: 18)

                        Menu {
                            Button("داكن (Noir)") { selectedTheme = "Noir" }
                            Button("ورق دافئ (Sepia)") { selectedTheme = "Sepia" }
                            Button("نهاري (Light)") { selectedTheme = "Light" }
                            Button("كحلي ليلي (Midnight)") { selectedTheme = "Midnight" }
                        } label: {
                            Label(selectedTheme, systemImage: "paintpalette.fill")
                                .font(.harborCaption.weight(.bold))
                        }

                        Menu {
                            Button("تباعد الأسطر +") { lineSpacing = min(18, lineSpacing + 2) }
                            Button("تباعد الأسطر -") { lineSpacing = max(4, lineSpacing - 2) }
                            Button("توسيع الهوامش") { horizontalMargin = min(42, horizontalMargin + 4) }
                            Button("تقليل الهوامش") { horizontalMargin = max(14, horizontalMargin - 4) }
                            Button(useSerifFont ? "خط ThmanyahSans" : "خط Serif الكلاسيكي") { useSerifFont.toggle() }
                            Button(isRightToLeft ? "اتجاه LTR" : "اتجاه RTL (عربي)") { isRightToLeft.toggle() }
                        } label: {
                            Label("تنسيق النص", systemImage: "slider.horizontal.3")
                                .font(.harborCaption.weight(.bold))
                        }

                        Button {
                            addBookmarkForCurrentChapter()
                        } label: {
                            Label("علامة", systemImage: "bookmark.fill")
                                .font(.harborCaption.weight(.bold))
                        }

                        Button {
                            showNotesDrawer.toggle()
                        } label: {
                            Label("ملاحظاتي (\(notes.count))", systemImage: "note.text")
                                .font(.harborCaption.weight(.bold))
                        }
                    }
                    .foregroundStyle(store.theme.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color(white: 0.08))

                // In-Book Search Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("ابحث عن عبارة داخل فصول الكتاب...", text: $searchQuery)
                        .font(.harborCaption)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(white: 0.11))

                if isLoadingRemoteText {
                    ProgressView("جاري تحميل النص الكامل وتنسيقه...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(themeBackground)
                } else {
                    ScrollView {
                        if !chapters.isEmpty {
                            let safeIdx = min(max(selectedChapterIndex, 0), chapters.count - 1)
                            let ch = chapters[safeIdx]
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text(ch.title)
                                        .font(.harborTitle2.weight(.bold))
                                        .foregroundStyle(store.theme.accent)
                                    Spacer()
                                    Text("الفصل \(safeIdx + 1) من \(chapters.count)")
                                        .font(.harborCaption2)
                                        .foregroundStyle(.secondary)
                                }

                                Text(filteredChapterBody(ch.body))
                                    .font(.harbor(size: fontSize, design: useSerifFont ? .serif : .default))
                                    .foregroundStyle(themeForeground)
                                    .lineSpacing(lineSpacing)
                            }
                            .padding(.horizontal, horizontalMargin)
                            .padding(.vertical, 24)
                            .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
                        }
                    }
                    .background(themeBackground)
                }
            }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("إغلاق") {
                        let progress = chapters.isEmpty ? 0.0 : Double(selectedChapterIndex + 1) / Double(chapters.count)
                        store.updateBookReadingProgress(bookID: book.id, chapterIndex: selectedChapterIndex, scrollProgress: progress)
                        dismiss()
                    }
                }
            }
            .task {
                chapters = book.sampleChapters
                selectedChapterIndex = min(max(book.savedBookmarkChapter, 0), max(chapters.count - 1, 0))
                restoreBookmarksAndNotes()
                if let urlStr = book.textContentURL, let remoteURL = URL(string: urlStr) {
                    await fetchFullTextOrEPUBIfAvailable(from: remoteURL)
                }
            }
            .onChange(of: selectedChapterIndex) { _, newIdx in
                let progress = chapters.isEmpty ? 0.0 : Double(newIdx + 1) / Double(chapters.count)
                store.updateBookReadingProgress(bookID: book.id, chapterIndex: newIdx, scrollProgress: progress)
            }
            .sheet(isPresented: $showNotesDrawer) {
                NavigationStack {
                    List {
                        Section("إضافة ملاحظة على الفصل الحالي") {
                            HStack {
                                TextField("اكتب ملاحظتك أو اقتباسك...", text: $newNoteText)
                                Button("حفظ") {
                                    saveNewNote()
                                }
                                .disabled(newNoteText.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        Section("العلامات المرجعية المحفوظة (\(bookmarks.count))") {
                            ForEach(bookmarks) { bm in
                                Button {
                                    selectedChapterIndex = min(max(bm.pageOrChapter - 1, 0), max(chapters.count - 1, 0))
                                    showNotesDrawer = false
                                } label: {
                                    HStack {
                                        Image(systemName: "bookmark.fill").foregroundStyle(store.theme.accent)
                                        Text(bm.label)
                                    }
                                }
                            }
                        }
                        Section("الملاحظات الشخصية (\(notes.count))") {
                            ForEach(notes) { note in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.noteText).font(.harborSubheadline)
                                    Text("الفصل \(note.chapterOrPage)").font(.harborCaption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle("العلامات والملاحظات")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("تم") { showNotesDrawer = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func filteredChapterBody(_ bodyText: String) -> String {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return bodyText }
        let matchingParagraphs = bodyText
            .components(separatedBy: "\n\n")
            .filter { $0.localizedCaseInsensitiveContains(q) }
        return matchingParagraphs.isEmpty ? bodyText : matchingParagraphs.joined(separator: "\n\n— — —\n\n")
    }

    private func fetchFullTextOrEPUBIfAvailable(from url: URL) async {
        let cacheKey = "book.chapters.v3.\(book.id)"
        if let cached = HarborDiskCacheManager.shared.getCodable(forKey: cacheKey, as: [HarborBookChapter].self),
           !cached.isEmpty {
            chapters = cached
            return
        }
        if url.isFileURL {
            let ext = url.pathExtension.lowercased()
            if ext == "epub", let parsed = try? HarborEPUBParser.parseEPUB(at: url) {
                let mapped = parsed.map { HarborBookChapter(number: $0.index + 1, title: $0.title, body: $0.bodyText) }
                if !mapped.isEmpty { chapters = mapped }
            } else if let parsed = try? HarborEPUBParser.parsePlainTextFile(at: url) {
                let mapped = parsed.map { HarborBookChapter(number: $0.index + 1, title: $0.title, body: $0.bodyText) }
                if !mapped.isEmpty { chapters = mapped }
            }
            return
        }
    }

    private func addBookmarkForCurrentChapter() {
        let title = chapters.indices.contains(selectedChapterIndex) ? chapters[selectedChapterIndex].title : "الفصل \(selectedChapterIndex + 1)"
        let bm = HarborBookBookmark(bookID: book.id, label: title, pageOrChapter: selectedChapterIndex + 1)
        bookmarks.insert(bm, at: 0)
        persistBookmarksAndNotes()
    }

    private func saveNewNote() {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let note = HarborBookNote(bookID: book.id, chapterOrPage: selectedChapterIndex + 1, excerpt: "", noteText: trimmed)
        notes.insert(note, at: 0)
        newNoteText = ""
        persistBookmarksAndNotes()
    }

    private func restoreBookmarksAndNotes() {
        if let bmData = UserDefaults.standard.data(forKey: "harbor.bookmarks.\(book.id)"),
           let decoded = try? JSONDecoder().decode([HarborBookBookmark].self, from: bmData) {
            bookmarks = decoded
        }
        if let noteData = UserDefaults.standard.data(forKey: "harbor.notes.\(book.id)"),
           let decoded = try? JSONDecoder().decode([HarborBookNote].self, from: noteData) {
            notes = decoded
        }
    }

    private func persistBookmarksAndNotes() {
        if let bmData = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(bmData, forKey: "harbor.bookmarks.\(book.id)")
        }
        if let noteData = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(noteData, forKey: "harbor.notes.\(book.id)")
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
                            .font(.harborCaption)
                            .foregroundStyle(.red)
                    }
                }

                Section("الإضافات المثبتة حالياً (\(store.installedAddons.count))") {
                    ForEach(store.installedAddons) { addon in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(addon.name)
                                    .font(.harborHeadline)
                                Spacer()
                                Text("v\(addon.version)")
                                    .font(.harborCaption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(store.theme.accent.opacity(0.2))
                                    .foregroundStyle(store.theme.accent)
                                    .clipShape(Capsule())
                            }
                            if let desc = addon.description {
                                Text(desc)
                                    .font(.harborCaption)
                                    .foregroundStyle(.secondary)
                            }
                            if let types = addon.types, !types.isEmpty {
                                Text("الأنواع المدعومة: \(types.joined(separator: "، "))")
                                    .font(.harborCaption2)
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
                                Text(item.name).font(.harborSubheadline.weight(.bold))
                                Text(item.desc).font(.harborCaption).foregroundStyle(.secondary)
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
            .background(LinearGradient(colors: [Color(white: 0.14).opacity(0.45), Color.black, Color.black], startPoint: .top, endPoint: .bottom).ignoresSafeArea(.all))
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
                        .onChange(of: store.realDebridToken) { _, newVal in
                            if !newVal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                store.debridProviderRaw = DebridProviderType.realDebrid.rawValue
                            }
                        }

                    Button {
                        Task {
                            store.debridProviderRaw = DebridProviderType.realDebrid.rawValue
                            let status = await DebridService.shared.verifyRealDebridAccount(token: store.realDebridToken)
                            store.statusBannerMessage = status
                        }
                    } label: {
                        Label("فحص وتفعيل حساب Real-Debrid الآن", systemImage: "bolt.shield.fill")
                            .font(.harborSubheadline.weight(.bold))
                            .foregroundStyle(store.theme.accent)
                    }

                    if let msg = store.statusBannerMessage {
                        Text(msg)
                            .font(.harborCaption.weight(.bold))
                            .foregroundStyle(msg.contains("✅") ? Color.green : Color.orange)
                    }

                    SecureField("مفتاح TorBox API Key", text: $store.torBoxKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("يتم حفظ المفاتيح محلياً على جهازك فقط دون إرسالها لأي خادم خارجي، وتُستخدم لتحويل ملفات التورنت إلى روابط HTTP/HLS مباشرة تعمل داخل مشغل نظام iOS (AVPlayer).")
                        .font(.harborCaption2)
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

                Section("الأمان، التخزين المؤقت والفحص الذاتي (v3.0 Diagnostics)") {
                    LabeledContent("تخزين المفاتيح الحساسة", value: "iOS Keychain (Encrypted)")
                    LabeledContent("حجم التخزين المؤقت (LRU Disk Cache)", value: HarborDiskCacheManager.shared.formattedDiskUsage())

                    Button(role: .destructive) {
                        HarborDiskCacheManager.shared.clearAllCaches()
                        store.statusBannerMessage = "✅ تم تفريغ الذاكرة المؤقتة بنجاح"
                    } label: {
                        Label("تفريغ الذاكرة المؤقتة (Clear Disk & Memory Cache)", systemImage: "trash")
                    }

                    NavigationLink {
                        HarborSelfTestDiagnosticsView()
                            .environmentObject(store)
                    } label: {
                        Label("تشغيل الفحص الذاتي الشامل (6 Automated Tests)", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(store.theme.accent)
                    }
                }

                Section("حول Harbor لنظام iOS") {
                    LabeledContent("المعمارية", value: "SwiftUI + AVKit + HarborStreamEngine")
                    LabeledContent("البروتوكول", value: "Stremio Addon Protocol v3")
                    LabeledContent("المشغل", value: "Native iOS AVPlayer (HLS / HTTP / PiP)")
                    LabeledContent("الترخيص", value: "MIT Open Source")
                }
            }
            .scrollContentBackground(.hidden)
            .background(LinearGradient(colors: [Color(white: 0.14).opacity(0.45), Color.black, Color.black], startPoint: .top, endPoint: .bottom).ignoresSafeArea(.all))
            .navigationTitle("الإعدادات")
        }
    }
}

struct HarborSelfTestDiagnosticsView: View {
    @EnvironmentObject var store: HarborStore
    @State private var results: [HarborTestCaseResult] = HarborSelfTestSuite.runAllTests()

    var body: some View {
        List {
            Section("نتائج اختبارات الوحدات والمحركات (Harbor v3.0 QA)") {
                ForEach(results) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.passed ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(item.passed ? .green : .red)
                            .font(.harborTitle3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.harborSubheadline.weight(.bold))
                            Text(item.detail)
                                .font(.harborCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("الفحص الذاتي (Self-Tests)")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("إعادة الفحص") {
                    results = HarborSelfTestSuite.runAllTests()
                }
            }
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
