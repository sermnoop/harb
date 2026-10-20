import Foundation

// MARK: - 6. Debrid HTTP/HLS Resolver (Real-Debrid & TorBox)

enum DebridError: LocalizedError {
    case missingAPIKey(String)
    case unrestrictFailed(String)
    case noPlayableURL

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "يرجى إدخال مفتاح API الخاص بخدمة \(provider) في الإعدادات لتحويل ملفات المغناطيس (InfoHash) إلى بث HTTP مباشر."
        case .unrestrictFailed(let msg):
            return "تعذر فك تقييد الرابط عبر خدمة Debrid: \(msg)"
        case .noPlayableURL:
            return "لا يتوفر رابط HTTP/HLS مباشر قابل للتشغيل لهذا المصدر."
        }
    }
}

actor DebridService {
    static let shared = DebridService()

    struct RDUnrestrictResponse: Codable {
        let id: String?
        let filename: String?
        let download: String?
        let streamable: Int?
    }

    struct RDAddMagnetResponse: Codable {
        let id: String
        let uri: String?
    }

    struct RDTorrentInfoResponse: Codable {
        let id: String
        let status: String
        let links: [String]?
    }

    /// Resolves a `HarborRankedStream` into a direct HTTP/HLS `URL` playable by `AVPlayer`.
    func resolvePlayableURL(
        for stream: HarborRankedStream,
        provider: DebridProviderType,
        realDebridToken: String,
        torBoxKey: String
    ) async throws -> URL {
        // 1. If the stream already provides an unrestricted HTTP/HLS URL
        if let directURL = stream.playableHTTPURL {
            if provider == .realDebrid && !realDebridToken.isEmpty && directURL.host?.contains("real-debrid.com") == false && stream.raw.infoHash != nil {
                // Can optionally unrestrict hoster links via RD
                if let unrestricted = try? await unrestrictRealDebridLink(link: directURL.absoluteString, token: realDebridToken) {
                    return unrestricted
                }
            }
            return directURL
        }

        // 2. If the stream is an infoHash, resolve it via configured Debrid service into a direct HTTP stream
        guard let infoHash = stream.raw.infoHash, !infoHash.isEmpty else {
            throw DebridError.noPlayableURL
        }

        switch provider {
        case .realDebrid:
            guard !realDebridToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DebridError.missingAPIKey("Real-Debrid")
            }
            return try await resolveInfoHashWithRealDebrid(infoHash: infoHash, token: realDebridToken)

        case .torBox:
            guard !torBoxKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DebridError.missingAPIKey("TorBox")
            }
            return try await resolveInfoHashWithTorBox(infoHash: infoHash, apiKey: torBoxKey)

        case .none:
            throw DebridError.missingAPIKey("Real-Debrid أو TorBox")
        }
    }

    private func unrestrictRealDebridLink(link: String, token: String) async throws -> URL {
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/unrestrict/link") else {
            throw DebridError.noPlayableURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "link=\(link.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? link)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DebridError.unrestrictFailed("HTTP Status Error")
        }
        let decoded = try JSONDecoder().decode(RDUnrestrictResponse.self, from: data)
        guard let dl = decoded.download, let resolvedURL = URL(string: dl) else {
            throw DebridError.noPlayableURL
        }
        return resolvedURL
    }

    private func resolveInfoHashWithRealDebrid(infoHash: String, token: String) async throws -> URL {
        let magnet = "magnet:?xt=urn:btih:\(infoHash)"
        guard let addURL = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/addMagnet") else {
            throw DebridError.noPlayableURL
        }
        var addReq = URLRequest(url: addURL)
        addReq.httpMethod = "POST"
        addReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        addReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        addReq.httpBody = "magnet=\(magnet.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? magnet)".data(using: .utf8)

        let (addData, _) = try await URLSession.shared.data(for: addReq)
        let added = try JSONDecoder().decode(RDAddMagnetResponse.self, from: addData)

        // Select all files in torrent
        if let selectURL = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/selectFiles/\(added.id)") {
            var selectReq = URLRequest(url: selectURL)
            selectReq.httpMethod = "POST"
            selectReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            selectReq.httpBody = "files=all".data(using: .utf8)
            _ = try? await URLSession.shared.data(for: selectReq)
        }

        // Fetch torrent info for generated link
        guard let infoURL = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/info/\(added.id)") else {
            throw DebridError.noPlayableURL
        }
        var infoReq = URLRequest(url: infoURL)
        infoReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (infoData, _) = try await URLSession.shared.data(for: infoReq)
        let info = try JSONDecoder().decode(RDTorrentInfoResponse.self, from: infoData)

        guard let firstLink = info.links?.first else {
            throw DebridError.unrestrictFailed("الملف غير مخزن مؤقتاً (Not Cached) على Real-Debrid حالياً")
        }
        return try await unrestrictRealDebridLink(link: firstLink, token: token)
    }

    private func resolveInfoHashWithTorBox(infoHash: String, apiKey: String) async throws -> URL {
        // TorBox instant stream resolution flow
        guard let url = URL(string: "https://api.torbox.app/v1/api/torrents/createtorrent") else {
            throw DebridError.noPlayableURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "magnet=magnet:?xt=urn:btih:\(infoHash)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DebridError.unrestrictFailed("TorBox API HTTP Error")
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataObj = json["data"] as? [String: Any],
           let torrentId = dataObj["torrent_id"] as? Int,
           let dlURL = URL(string: "https://api.torbox.app/v1/api/torrents/requestdl?token=\(apiKey)&torrent_id=\(torrentId)&file_id=0") {
            let (dlData, _) = try await URLSession.shared.data(from: dlURL)
            if let dlJson = try? JSONSerialization.jsonObject(with: dlData) as? [String: Any],
               let directLink = dlJson["data"] as? String,
               let finalURL = URL(string: directLink) {
                return finalURL
            }
        }
        throw DebridError.unrestrictFailed("تعذر استخراج رابط HTTP مباشر من TorBox")
    }
}
