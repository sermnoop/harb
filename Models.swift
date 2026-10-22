import SwiftUI
import Foundation

// MARK: - 1. Harbor Theme Engine & App Configuration

enum HarborThemePreset: String, CaseIterable, Identifiable, Codable {
    case harbor = "Harbor"
    case nord = "Nord"
    case dracula = "Dracula"
    case royal = "Royal"
    case noir = "Noir"
    case aurora = "Aurora"

    var id: String { rawValue }

    var backgroundPrimary: Color {
        switch self {
        case .harbor:  return Color.black
        case .nord:    return Color(red: 0.18, green: 0.20, blue: 0.25)
        case .dracula: return Color(red: 0.16, green: 0.16, blue: 0.21)
        case .royal:   return Color(red: 0.08, green: 0.05, blue: 0.16)
        case .noir:    return Color.black
        case .aurora:  return Color(red: 0.04, green: 0.11, blue: 0.12)
        }
    }

    var backgroundSecondary: Color {
        switch self {
        case .harbor:  return Color(white: 0.07)
        case .nord:    return Color(red: 0.23, green: 0.26, blue: 0.32)
        case .dracula: return Color(red: 0.21, green: 0.22, blue: 0.29)
        case .royal:   return Color(red: 0.14, green: 0.09, blue: 0.26)
        case .noir:    return Color(white: 0.07)
        case .aurora:  return Color(red: 0.07, green: 0.18, blue: 0.20)
        }
    }

    var accent: Color {
        switch self {
        case .harbor:  return Color(red: 0.22, green: 0.68, blue: 0.98)
        case .nord:    return Color(red: 0.53, green: 0.75, blue: 0.82)
        case .dracula: return Color(red: 0.74, green: 0.58, blue: 0.98)
        case .royal:   return Color(red: 0.95, green: 0.73, blue: 0.25)
        case .noir:    return Color.white
        case .aurora:  return Color(red: 0.20, green: 0.88, blue: 0.68)
        }
    }
}

enum StreamSafetyFilter: String, CaseIterable, Identifiable, Codable {
    case strict = "Strict"
    case balanced = "Balanced"
    case off = "Off"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .strict: return "صارم (Strict)"
        case .balanced: return "متوازن (Balanced)"
        case .off: return "متوقف (Off)"
        }
    }
}

enum DebridProviderType: String, CaseIterable, Identifiable, Codable {
    case none = "Direct HTTP / HLS"
    case realDebrid = "Real-Debrid"
    case torBox = "TorBox"

    var id: String { rawValue }
}

// MARK: - 2. Stremio Protocol & Media Domain Models

enum MediaType: String, Codable, CaseIterable, Identifiable {
    case movie = "movie"
    case series = "series"
    case anime = "anime"

    var id: String { rawValue }

    var arabicTitle: String {
        switch self {
        case .movie: return "أفلام"
        case .series: return "مسلسلات"
        case .anime: return "أنمي"
        }
    }
}

struct StremioManifest: Codable, Identifiable, Hashable {
    let id: String
    let version: String
    let name: String
    let description: String?
    let logo: String?
    let types: [String]?
    let catalogs: [StremioCatalogDescriptor]?
    var transportUrl: String?
}

struct StremioCatalogDescriptor: Codable, Hashable, Identifiable {
    var id: String { "\(type)_\(catalogId)" }
    let type: String
    let catalogId: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case type
        case catalogId = "id"
        case name
    }
}

struct StremioCatalogResponse: Codable {
    let metas: [StremioMetaPreview]
}

struct StremioMetaResponse: Codable {
    let meta: StremioMetaDetail
}

struct StremioMetaPreview: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let name: String
    let poster: String?
    let background: String?
    let logo: String?
    let description: String?
    let releaseInfo: String?
    let imdbRating: String?
    let genres: [String]?

    var displayYear: String {
        releaseInfo ?? ""
    }
}

struct StremioMetaDetail: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let name: String
    let poster: String?
    let background: String?
    let logo: String?
    let description: String?
    let releaseInfo: String?
    let imdbRating: String?
    let runtime: String?
    let genres: [String]?
    let cast: [String]?
    let director: [String]?
    let awards: String?
    let videos: [StremioEpisodeVideo]?
}

struct StremioEpisodeVideo: Codable, Identifiable, Hashable {
    let id: String
    let title: String?
    let season: Int?
    let episode: Int?
    let overview: String?
    let thumbnail: String?
    let released: String?

    var displayTitle: String {
        if let ep = episode {
            return "\(ep). \(title ?? "Episode \(ep)")"
        }
        return title ?? id
    }
}

struct StremioStreamResponse: Codable {
    let streams: [StremioRawStream]
}

struct StremioRawStream: Codable, Hashable {
    let name: String?
    let title: String?
    let description: String?
    let url: String?
    let infoHash: String?
    let fileIdx: Int?
    let externalUrl: String?
    let behaviorHints: StremioBehaviorHints?

    var combinedText: String {
        [name, title, description].compactMap { $0 }.joined(separator: " ")
    }
}

struct StremioBehaviorHints: Codable, Hashable {
    let bingeGroup: String?
    let filename: String?
    let videoSize: Int64?
    let notWebReady: Bool?
}

struct WatchProgressItem: Codable, Identifiable, Hashable {
    let id: String
    let mediaType: String
    let title: String
    let subtitle: String?
    let poster: String?
    let backdrop: String?
    let streamURL: String
    var positionSeconds: Double
    var durationSeconds: Double
    var updatedAt: Date

    var progressFraction: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(max(positionSeconds / durationSeconds, 0), 1)
    }

    var isCompleted: Bool {
        progressFraction >= 0.85
    }
}

// MARK: - 3. Music & Audio Domain Models

struct HarborMusicTrack: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let artworkURL: String?
    let streamURL: String
    let durationSeconds: Double
    let genre: String?
    let isLiveStream: Bool
}

struct ITunesSearchResponse: Codable {
    let results: [ITunesTrackItem]
}

struct ITunesTrackItem: Codable {
    let trackId: Int?
    let trackName: String?
    let artistName: String?
    let collectionName: String?
    let artworkUrl100: String?
    let previewUrl: String?
    let trackTimeMillis: Int?
    let primaryGenreName: String?
}

struct LRCLibResponse: Codable {
    let id: Int?
    let trackName: String?
    let artistName: String?
    let plainLyrics: String?
    let syncedLyrics: String?
}

struct SyncedLyricLine: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let timestampSeconds: Double
    let text: String
}

// MARK: - 3B. User Music Playlist Model (v3.0)

struct HarborMusicPlaylist: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var tracks: [HarborMusicTrack]
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, tracks: [HarborMusicTrack] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.createdAt = createdAt
    }
}

// MARK: - 4. Books & Ebooks Domain Models (Open Library & Project Gutenberg)

struct HarborBookItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let authors: [String]
    let coverURL: String?
    let publishYear: String?
    let subjects: [String]
    let description: String?
    let textContentURL: String?
    let sampleChapters: [HarborBookChapter]
    var savedBookmarkChapter: Int = 0
    var savedScrollProgress: Double = 0.0

    var authorLine: String {
        authors.isEmpty ? "مؤلف غير معروف" : authors.joined(separator: "، ")
    }
}

struct HarborBookChapter: Identifiable, Codable, Hashable {
    var id: String { "\(number)-\(title)" }
    let number: Int
    let title: String
    let body: String
}

struct GutendexResponse: Codable {
    let results: [GutendexBook]
}

struct GutendexBook: Codable {
    let id: Int
    let title: String
    let authors: [GutendexAuthor]
    let subjects: [String]?
    let formats: [String: String]
    let downloadCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, authors, subjects, formats
        case downloadCount = "download_count"
    }
}

struct GutendexAuthor: Codable {
    let name: String
}

struct OpenLibrarySearchResponse: Codable {
    let docs: [OpenLibraryDoc]
}

struct OpenLibraryDoc: Codable {
    let key: String?
    let title: String?
    let author_name: [String]?
    let first_publish_year: Int?
    let cover_i: Int?
    let subject: [String]?
}
