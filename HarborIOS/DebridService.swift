import Foundation

enum DebridError: LocalizedError {
    case missingAPIKey(String)
    case unrestrictFailed(String)
    case noPlayableURL

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "يرجى إدخال مفتاح API الخاص بخدمة \(provider) في الإعدادات لتحويل ملفات التورنت (InfoHash) إلى بث مباشر."
        case .unrestrictFailed(let msg):
            return "تعذر فك تقييد الرابط عبر خدمة Real-Debrid: \(msg)"
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

    struct RDTorrentFile: Codable {
        let id: Int
        let path: String
        let bytes: Int64
        let selected: Int?
    }

    struct RDTorrentInfoResponse: Codable {
        let id: String
        let status: String
        let links: [String]?
        let files: [RDTorrentFile]?
    }

    private func cleanToken(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasPrefix("bearer ") {
            t = String(t.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }

    func verifyRealDebridAccount(token: String) async -> String {
        let clean = cleanToken(token)
        guard !clean.isEmpty, let url = URL(string: "https://api.real-debrid.com/rest/1.0/user") else {
            return "يرجى إدخال مفتاح API أولاً"
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(clean)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return "❌ مفتاح Real-Debrid غير صالح أو منتهي الصلاحية"
            }
            let username = (json["username"] as? String) ?? "User"
            let type = (json["type"] as? String)?.uppercased() ?? "PREMIUM"
            let exp = String(((json["expiration"] as? String) ?? "").prefix(10))
            return "✅ متصل بنجاح: \(username) (\(type)) • ينتهي: \(exp)"
        } catch {
            return "❌ تعذر الاتصال بخادم Real-Debrid"
        }
    }

    func resolvePlayableURL(
        for stream: HarborRankedStream,
        provider: DebridProviderType,
        realDebridToken: String,
        torBoxKey: String
    ) async throws -> URL {
        let rdClean = cleanToken(realDebridToken)
        let tbClean = cleanToken(torBoxKey)

        // 1. If the stream has an InfoHash and user entered a Real-Debrid token, ALWAYS resolve via Real-Debrid first!
        if let infoHash = stream.raw.infoHash, !infoHash.isEmpty {
            if !rdClean.isEmpty {
                return try await resolveInfoHashWithRealDebrid(infoHash: infoHash, fileIdx: stream.raw.fileIdx, token: rdClean)
            }
            if !tbClean.isEmpty {
                return try await resolveInfoHashWithTorBox(infoHash: infoHash, apiKey: tbClean)
            }
            // Fallback to cloud stream if user hasn't entered any Debrid key
            if let ext = stream.raw.externalUrl, let fallbackURL = URL(string: ext) {
                return fallbackURL
            }
            throw DebridError.missingAPIKey("Real-Debrid")
        }

        // 2. If the stream has a direct URL (from Torrentio RD, PlavioHD, or Cloud Server)
        if let rawURLStr = stream.raw.url, !rawURLStr.isEmpty, let directURL = URL(string: rawURLStr) {
            if !rdClean.isEmpty && (rawURLStr.contains("real-debrid.com/d/") == false) && (rawURLStr.contains("magnet:?") || rawURLStr.contains("1fichier") || rawURLStr.contains("rapidgator")) {
                if let unrestricted = try? await unrestrictRealDebridLink(link: rawURLStr, token: rdClean) {
                    return unrestricted
                }
            }
            return directURL
        }

        if let ext = stream.raw.externalUrl, let fallbackURL = URL(string: ext) {
            return fallbackURL
        }
        throw DebridError.noPlayableURL
    }

    private func unrestrictRealDebridLink(link: String, token: String) async throws -> URL {
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/unrestrict/link") else {
            throw DebridError.noPlayableURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encodedLink = link.addingPercentEncoding(withAllowedCharacters: allowed) ?? link
        request.httpBody = "link=\(encodedLink)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DebridError.unrestrictFailed("تعذر فك الرابط (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))")
        }
        let decoded = try JSONDecoder().decode(RDUnrestrictResponse.self, from: data)
        guard let dl = decoded.download, let resolvedURL = URL(string: dl) else {
            throw DebridError.noPlayableURL
        }
        return resolvedURL
    }

    private func resolveInfoHashWithRealDebrid(infoHash: String, fileIdx: Int?, token: String) async throws -> URL {
        let cleanHash = infoHash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let magnet = "magnet:?xt=urn:btih:\(cleanHash)"
        guard let addURL = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/addMagnet") else {
            throw DebridError.noPlayableURL
        }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encodedMagnet = magnet.addingPercentEncoding(withAllowedCharacters: allowed) ?? magnet

        var addReq = URLRequest(url: addURL)
        addReq.httpMethod = "POST"
        addReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        addReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        addReq.httpBody = "magnet=\(encodedMagnet)".data(using: .utf8)

        let (addData, addResp) = try await URLSession.shared.data(for: addReq)
        guard let addHttp = addResp as? HTTPURLResponse, (200..<300).contains(addHttp.statusCode) else {
            throw DebridError.unrestrictFailed("تأكد من صلاحية مفتاح Real-Debrid API (كود \((addResp as? HTTPURLResponse)?.statusCode ?? 0))")
        }
        let added = try JSONDecoder().decode(RDAddMagnetResponse.self, from: addData)

        // Step 2: Inspect files inside torrent and pick the largest video file (.mp4 preferred for native iOS AVPlayer, then .mkv)
        guard let infoURL = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/info/\(added.id)") else {
            throw DebridError.noPlayableURL
        }
        var infoReq = URLRequest(url: infoURL)
        infoReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var selectedFileParam = "all"
        if let (initialData, _) = try? await URLSession.shared.data(for: infoReq),
           let initialInfo = try? JSONDecoder().decode(RDTorrentInfoResponse.self, from: initialData),
           let files = initialInfo.files, !files.isEmpty {
            let videoExtensions = [".mp4", ".m4v", ".mkv", ".mov", ".avi", ".webm", ".ts"]
            let videoFiles = files.filter { f in
                let lower = f.path.lowercased()
                return videoExtensions.contains(where: { lower.hasSuffix($0) }) && !lower.contains("sample")
            }
            if let mp4File = videoFiles.filter({ $0.path.lowercased().hasSuffix(".mp4") }).max(by: { $0.bytes < $1.bytes }) {
                selectedFileParam = "\(mp4File.id)"
            } else if let largestVideo = videoFiles.max(by: { $0.bytes < $1.bytes }) {
                selectedFileParam = "\(largestVideo.id)"
            } else if let largestAny = files.max(by: { $0.bytes < $1.bytes }) {
                selectedFileParam = "\(largestAny.id)"
            }
        }

        // Step 3: Select the target video file WITH Content-Type: application/x-www-form-urlencoded!
        if let selectURL = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/selectFiles/\(added.id)") {
            var selectReq = URLRequest(url: selectURL)
            selectReq.httpMethod = "POST"
            selectReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            selectReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            selectReq.httpBody = "files=\(selectedFileParam)".data(using: .utf8)
            _ = try? await URLSession.shared.data(for: selectReq)
        }

        // Step 4: Poll torrent info (up to 3 quick checks) for the generated hoster link
        for _ in 0..<3 {
            let (finalData, _) = try await URLSession.shared.data(for: infoReq)
            let finalInfo = try JSONDecoder().decode(RDTorrentInfoResponse.self, from: finalData)
            if let firstLink = finalInfo.links?.first, !firstLink.isEmpty {
                return try await unrestrictRealDebridLink(link: firstLink, token: token)
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
        }

        throw DebridError.unrestrictFailed("هذا التورنت غير مخزن مؤقتاً (Not Cached) على خوادم Real-Debrid حالياً؛ جرب مصدراً آخر يحمل شارة ⚡ [RD+].")
    }

    private func resolveInfoHashWithTorBox(infoHash: String, apiKey: String) async throws -> URL {
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

