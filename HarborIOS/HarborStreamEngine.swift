import Foundation

// MARK: - 5. Harbor Stream Engine (Port of harbor-core Rust crate)
// Implements the 4-stage pipeline: Parse -> Trust -> Score -> Rank

enum StreamQualityTier: String, CaseIterable, Comparable, Codable {
    case uhd4KDV = "4K DV"
    case uhd4KHDR = "4K HDR"
    case uhd4K = "4K"
    case fhd1080pHDR = "1080p HDR"
    case fhd1080p = "1080p"
    case hd720p = "720p"
    case sd = "SD"

    private var sortOrder: Int {
        switch self {
        case .uhd4KDV: return 7
        case .uhd4KHDR: return 6
        case .uhd4K: return 5
        case .fhd1080pHDR: return 4
        case .fhd1080p: return 3
        case .hd720p: return 2
        case .sd: return 1
        }
    }

    static func < (lhs: StreamQualityTier, rhs: StreamQualityTier) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

struct HarborRankedStream: Identifiable, Hashable {
    let id = UUID()
    let addonName: String
    let raw: StremioRawStream
    let resolution: String
    let hdrFlavor: String?
    let videoCodec: String?
    let audioTag: String?
    let sourceType: String?
    let fileSizeDisplay: String?
    let seeders: Int
    let isCachedDebrid: Bool
    let debridBadge: String?
    let tier: StreamQualityTier
    let score: Int
    let scoreReasons: [String]
    let isTrusted: Bool
    let rejectionReason: String?

    var playableHTTPURL: URL? {
        guard let urlStr = raw.url, let url = URL(string: urlStr) else { return nil }
        return url
    }
}

enum HarborStreamEngine {

    /// Executes Harbor's 4-stage pipeline (`parse -> trust -> score -> rank`)
    static func processStreams(
        rawStreams: [(addonName: String, stream: StremioRawStream)],
        expectedTitle: String,
        safetyFilter: StreamSafetyFilter
    ) -> [HarborRankedStream] {
        var results: [HarborRankedStream] = []

        for entry in rawStreams {
            let parsed = parse(addonName: entry.addonName, raw: entry.stream)
            let trusted = trust(parsed: parsed, expectedTitle: expectedTitle, filter: safetyFilter)
            let scored = score(stream: trusted)
            results.append(scored)
        }

        // Stage 4: Rank (filter untrusted unless safetyFilter == .off, then sort by cached status, tier, and score)
        return results
            .filter { safetyFilter == .off ? true : $0.isTrusted }
            .sorted { lhs, rhs in
                if lhs.isCachedDebrid != rhs.isCachedDebrid {
                    return lhs.isCachedDebrid && !rhs.isCachedDebrid
                }
                if lhs.tier != rhs.tier {
                    return lhs.tier > rhs.tier
                }
                return lhs.score > rhs.score
            }
    }

    // Stage 1: Parse
    private static func parse(addonName: String, raw: StremioRawStream) -> HarborRankedStream {
        let text = raw.combinedText
        let upper = text.uppercased()

        // Resolution
        let resolution: String
        if upper.contains("2160P") || upper.contains("4K") || upper.contains("UHD") {
            resolution = "4K"
        } else if upper.contains("1080P") || upper.contains("FHD") {
            resolution = "1080p"
        } else if upper.contains("720P") || upper.contains("HD") {
            resolution = "720p"
        } else {
            resolution = "SD"
        }

        // HDR Flavor
        let hdrFlavor: String?
        if upper.contains("DOLBY VISION") || upper.contains("DV") || upper.contains("DOVI") {
            hdrFlavor = "Dolby Vision"
        } else if upper.contains("HDR10+") {
            hdrFlavor = "HDR10+"
        } else if upper.contains("HDR10") || upper.contains("HDR") {
            hdrFlavor = "HDR10"
        } else if upper.contains("HLG") {
            hdrFlavor = "HLG"
        } else {
            hdrFlavor = nil
        }

        // Video Codec
        let videoCodec: String?
        if upper.contains("HEVC") || upper.contains("X265") || upper.contains("H265") || upper.contains("H.265") {
            videoCodec = "HEVC"
        } else if upper.contains("AV1") {
            videoCodec = "AV1"
        } else if upper.contains("X264") || upper.contains("H264") || upper.contains("H.264") || upper.contains("AVC") {
            videoCodec = "AVC"
        } else {
            videoCodec = nil
        }

        // Audio Codec & Channels
        let audioTag: String?
        if upper.contains("ATMOS") {
            audioTag = "Dolby Atmos"
        } else if upper.contains("TRUEHD") {
            audioTag = "TrueHD"
        } else if upper.contains("DTS-HD") || upper.contains("DTS-MA") {
            audioTag = "DTS-HD MA"
        } else if upper.contains("DDP") || upper.contains("EAC3") || upper.contains("5.1") || upper.contains("7.1") {
            audioTag = "5.1 Surround"
        } else if upper.contains("AAC") || upper.contains("FLAC") {
            audioTag = "Stereo AAC"
        } else {
            audioTag = nil
        }

        // Source Type
        let sourceType: String?
        if upper.contains("REMUX") {
            sourceType = "BluRay Remux"
        } else if upper.contains("BLURAY") || upper.contains("BLU-RAY") {
            sourceType = "BluRay"
        } else if upper.contains("WEB-DL") || upper.contains("WEBDL") {
            sourceType = "WEB-DL"
        } else if upper.contains("WEBRIP") {
            sourceType = "WEBRip"
        } else if upper.contains("CAM") || upper.contains("HDCAM") || upper.contains("TS") || upper.contains("TELESYNC") {
            sourceType = "CAM"
        } else {
            sourceType = nil
        }

        // Cached Debrid Detection
        let isCached = upper.contains("[RD+]") || upper.contains("[TB+]") || upper.contains("[AD+]") ||
                       upper.contains("⚡") || upper.contains("INSTANT") || (raw.url?.hasPrefix("http") == true)

        let debridBadge: String?
        if upper.contains("RD+") || upper.contains("REAL-DEBRID") {
            debridBadge = "RD+"
        } else if upper.contains("TB+") || upper.contains("TORBOX") {
            debridBadge = "TB+"
        } else if raw.url?.hasPrefix("http") == true {
            debridBadge = "HTTP/HLS"
        } else {
            debridBadge = nil
        }

        // Extract Seeders (👤 145 or S: 145)
        var seeders = 0
        if let range = text.range(of: #"👤\s*(\d+)"#, options: .regularExpression) {
            let digits = text[range].filter { $0.isNumber }
            seeders = Int(digits) ?? 0
        }

        // Extract File Size (💾 4.2 GB)
        var fileSizeDisplay: String? = nil
        if let sizeBytes = raw.behaviorHints?.videoSize, sizeBytes > 0 {
            let gb = Double(sizeBytes) / 1_073_741_824.0
            fileSizeDisplay = gb >= 1.0 ? String(format: "%.2f GB", gb) : String(format: "%.0f MB", gb * 1024)
        } else if let range = text.range(of: #"(\d+(?:\.\d+)?\s*(?:GB|MB))"#, options: [.regularExpression, .caseInsensitive]) {
            fileSizeDisplay = String(text[range])
        }

        // Quality Tier
        let tier: StreamQualityTier
        switch (resolution, hdrFlavor) {
        case ("4K", .some("Dolby Vision")): tier = .uhd4KDV
        case ("4K", .some(_)):              tier = .uhd4KHDR
        case ("4K", .none):                 tier = .uhd4K
        case ("1080p", .some(_)):           tier = .fhd1080pHDR
        case ("1080p", .none):              tier = .fhd1080p
        case ("720p", _):                   tier = .hd720p
        default:                            tier = .sd
        }

        return HarborRankedStream(
            addonName: addonName,
            raw: raw,
            resolution: resolution,
            hdrFlavor: hdrFlavor,
            videoCodec: videoCodec,
            audioTag: audioTag,
            sourceType: sourceType,
            fileSizeDisplay: fileSizeDisplay,
            seeders: seeders,
            isCachedDebrid: isCached,
            debridBadge: debridBadge,
            tier: tier,
            score: 0,
            scoreReasons: [],
            isTrusted: true,
            rejectionReason: nil
        )
    }

    // Stage 2: Trust
    private static func trust(
        parsed: HarborRankedStream,
        expectedTitle: String,
        filter: StreamSafetyFilter
    ) -> HarborRankedStream {
        let upper = parsed.raw.combinedText.uppercased()

        // Must have either a valid URL or an infoHash for Debrid resolution
        let hasValidTarget = (parsed.raw.url != nil && !parsed.raw.url!.isEmpty) ||
                             (parsed.raw.infoHash != nil && !parsed.raw.infoHash!.isEmpty)
        if !hasValidTarget {
            return HarborRankedStream(
                addonName: parsed.addonName, raw: parsed.raw, resolution: parsed.resolution,
                hdrFlavor: parsed.hdrFlavor, videoCodec: parsed.videoCodec, audioTag: parsed.audioTag,
                sourceType: parsed.sourceType, fileSizeDisplay: parsed.fileSizeDisplay, seeders: parsed.seeders,
                isCachedDebrid: parsed.isCachedDebrid, debridBadge: parsed.debridBadge, tier: parsed.tier,
                score: -100, scoreReasons: ["رابط غير صالح"], isTrusted: false, rejectionReason: "Dead or empty link"
            )
        }

        if filter == .strict && parsed.sourceType == "CAM" {
            return HarborRankedStream(
                addonName: parsed.addonName, raw: parsed.raw, resolution: parsed.resolution,
                hdrFlavor: parsed.hdrFlavor, videoCodec: parsed.videoCodec, audioTag: parsed.audioTag,
                sourceType: parsed.sourceType, fileSizeDisplay: parsed.fileSizeDisplay, seeders: parsed.seeders,
                isCachedDebrid: parsed.isCachedDebrid, debridBadge: parsed.debridBadge, tier: parsed.tier,
                score: -50, scoreReasons: ["تم استبعاد نسخة CAM بواسطة الفلتر الصارم"], isTrusted: false, rejectionReason: "Low-quality CAM filtered"
            )
        }

        if filter != .off && (upper.contains("SAMPLE") || upper.contains("TRAILER ONLY") || upper.contains(".EXE")) {
            return HarborRankedStream(
                addonName: parsed.addonName, raw: parsed.raw, resolution: parsed.resolution,
                hdrFlavor: parsed.hdrFlavor, videoCodec: parsed.videoCodec, audioTag: parsed.audioTag,
                sourceType: parsed.sourceType, fileSizeDisplay: parsed.fileSizeDisplay, seeders: parsed.seeders,
                isCachedDebrid: parsed.isCachedDebrid, debridBadge: parsed.debridBadge, tier: parsed.tier,
                score: -200, scoreReasons: ["ملف مشبوه أو عينة فقط"], isTrusted: false, rejectionReason: "Sample / unsafe file"
            )
        }

        return parsed
    }

    // Stage 3: Score
    private static func score(stream: HarborRankedStream) -> HarborRankedStream {
        var total = 0
        var reasons: [String] = []

        if stream.isCachedDebrid {
            total += 100
            reasons.append("+100 جاهز للبث المباشر (Debrid/HTTP)")
        }

        switch stream.resolution {
        case "4K":
            total += 60
            reasons.append("+60 دقة 4K UHD")
        case "1080p":
            total += 45
            reasons.append("+45 دقة 1080p FHD")
        case "720p":
            total += 25
            reasons.append("+25 دقة 720p HD")
        default:
            total += 10
        }

        if let hdr = stream.hdrFlavor {
            total += 25
            reasons.append("+25 دعم \(hdr)")
        }

        if let codec = stream.videoCodec {
            total += (codec == "HEVC" || codec == "AV1") ? 15 : 10
            reasons.append("+15 ترميز \(codec)")
        }

        if let audio = stream.audioTag {
            total += audio.contains("Atmos") || audio.contains("TrueHD") ? 20 : 10
            reasons.append("+15 صوت \(audio)")
        }

        if let src = stream.sourceType {
            if src == "BluRay Remux" || src == "WEB-DL" {
                total += 20
                reasons.append("+20 مصدر \(src)")
            } else if src == "CAM" {
                total -= 40
                reasons.append("-40 جودة CAM")
            }
        }

        if stream.seeders > 50 {
            total += 15
            reasons.append("+15 توافر عالٍ (\(stream.seeders) متاح)")
        }

        return HarborRankedStream(
            addonName: stream.addonName,
            raw: stream.raw,
            resolution: stream.resolution,
            hdrFlavor: stream.hdrFlavor,
            videoCodec: stream.videoCodec,
            audioTag: stream.audioTag,
            sourceType: stream.sourceType,
            fileSizeDisplay: stream.fileSizeDisplay,
            seeders: stream.seeders,
            isCachedDebrid: stream.isCachedDebrid,
            debridBadge: stream.debridBadge,
            tier: stream.tier,
            score: total,
            scoreReasons: reasons,
            isTrusted: stream.isTrusted,
            rejectionReason: stream.rejectionReason
        )
    }
}
