import SwiftUI
import AVFoundation

// MARK: - 8. Harbor Native Audio Player & Synced Lyrics Manager

@MainActor
final class HarborAudioPlayerManager: ObservableObject {
    @Published var currentTrack: HarborMusicTrack? = nil
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 30
    @Published var queue: [HarborMusicTrack] = []
    @Published var syncedLyrics: [SyncedLyricLine] = []
    @Published var plainLyrics: String? = nil
    @Published var isShowingFullPlayer: Bool = false

    private var player: AVPlayer?
    private var timeObserver: Any?

    func play(track: HarborMusicTrack, queue: [HarborMusicTrack] = []) {
        guard let url = URL(string: track.streamURL) else { return }

        // Configure iOS background playback session
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }

        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        self.player = avPlayer
        self.currentTrack = track
        self.duration = max(track.durationSeconds, 30)
        self.currentTime = 0
        if !queue.isEmpty {
            self.queue = queue
        }

        avPlayer.play()
        self.isPlaying = true

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite {
                Task { @MainActor in
                    self.currentTime = seconds
                    if let d = self.player?.currentItem?.duration, CMTimeGetSeconds(d).isFinite && CMTimeGetSeconds(d) > 0 {
                        self.duration = CMTimeGetSeconds(d)
                    }
                }
            }
        }

        Task {
            await fetchLyrics(for: track)
        }
    }

    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func seek(to seconds: Double) {
        let cm = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: cm)
        currentTime = seconds
    }

    func playNext() {
        guard let current = currentTrack,
              let idx = queue.firstIndex(where: { $0.id == current.id }),
              idx + 1 < queue.count else { return }
        play(track: queue[idx + 1], queue: queue)
    }

    func playPrevious() {
        guard let current = currentTrack,
              let idx = queue.firstIndex(where: { $0.id == current.id }),
              idx - 1 >= 0 else { return }
        play(track: queue[idx - 1], queue: queue)
    }

    /// Queries LRCLIB API for synced LRC lyrics
    private func fetchLyrics(for track: HarborMusicTrack) async {
        self.syncedLyrics = []
        self.plainLyrics = nil
        guard !track.isLiveStream else {
            self.plainLyrics = "بث إذاعي مباشر على مدار الساعة عبر محرك الصوت في Harbor."
            return
        }

        let artist = track.artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let title = track.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://lrclib.net/api/get?artist_name=\(artist)&track_name=\(title)") else { return }

        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return }
            let decoded = try JSONDecoder().decode(LRCLibResponse.self, from: data)
            self.plainLyrics = decoded.plainLyrics
            if let lrc = decoded.syncedLyrics {
                self.syncedLyrics = Self.parseLRC(lrc)
            }
        } catch {
            // Silently ignore when track has no lyrics on LRCLIB
        }
    }

    private static func parseLRC(_ lrc: String) -> [SyncedLyricLine] {
        var lines: [SyncedLyricLine] = []
        let pattern = #"\[(\d{2}):(\d{2}(?:\.\d{1,3})?)\](.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for rawLine in lrc.components(separatedBy: .newlines) {
            let nsRange = NSRange(rawLine.startIndex..<rawLine.endIndex, in: rawLine)
            if let match = regex.firstMatch(in: rawLine, range: nsRange),
               let minRange = Range(match.range(at: 1), in: rawLine),
               let secRange = Range(match.range(at: 2), in: rawLine),
               let txtRange = Range(match.range(at: 3), in: rawLine) {
                let mins = Double(rawLine[minRange]) ?? 0
                let secs = Double(rawLine[secRange]) ?? 0
                let text = String(rawLine[txtRange]).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    lines.append(SyncedLyricLine(timestampSeconds: mins * 60 + secs, text: text))
                }
            }
        }
        return lines
    }
}
