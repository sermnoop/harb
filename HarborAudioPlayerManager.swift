import SwiftUI
import UIKit
import AVFoundation
import MediaPlayer

// MARK: - 8. Harbor × BitChord Audio Player, Multi-Candidate Full-Length Failover & Real-Time DSP Studio

@MainActor
final class HarborAudioPlayerManager: ObservableObject {
    @Published var currentTrack: HarborMusicTrack? = nil
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 215
    @Published var queue: [HarborMusicTrack] = []
    @Published var syncedLyrics: [SyncedLyricLine] = []
    @Published var plainLyrics: String? = nil
    @Published var isLoadingLyrics: Bool = false
    @Published var isTrueSyncedLyrics: Bool = false
    @Published var lyricsSourceBadge: String = "LRCLIB + LyricsPlus"
    @Published var favoriteTracks: [HarborMusicTrack] = []
    @Published var recentlyPlayedTracks: [HarborMusicTrack] = []
    @Published var userPlaylists: [HarborMusicPlaylist] = []
    @Published var audioRouteDescription: String = "سماعة الجهاز"
    @Published var playbackErrorBanner: String? = nil
    @Published var isShowingFullPlayer: Bool = false
    @Published var isShowingLyricsSheet: Bool = false
    @Published var isResolvingFullStream: Bool = false
    @Published var isShuffleEnabled: Bool = false
    @Published var isRepeatEnabled: Bool = false
    @Published var activeYouTubeVideoID: String? = nil
    @Published var isUsingWebAudioFallback: Bool = false
    @Published var activeEngineLabel: String = "STUDIO MASTER • HI-FI"

    // Real-Time Audio DSP State (Slowed / Slowed + Reverb / Nightcore / Custom)
    @Published var dspPreset: HarborAudioDSPPreset = .normal
    @Published var playbackSpeed: Float = 1.0
    @Published var reverbMix: Float = 0.0
    @Published var useAnalogVarispeedPitch: Bool = true

    // Real-Time Beat & Rhythm Reactive Aura State (0.0 ... 1.0)
    @Published var beatPulseLevel: CGFloat = 0.0
    @Published var beatSecondaryWave: CGFloat = 0.0

    private var player: AVPlayer?
    private var reverbEchoPlayer: AVPlayer?
    private var activeStreamURL: URL? = nil
    private var candidateStreamURLs: [String] = []
    private var currentCandidateIndex: Int = 0
    private var isReverbSynced: Bool = false
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var failObserver: NSObjectProtocol?
    private var webFallbackTimer: Timer?
    private var beatReactiveTimer: Timer?
    private var trackBaseBPM: Double = 104.0
    private var watchdogTask: Task<Void, Never>?
    private var nowPlayingArtwork: MPMediaItemArtwork? = nil
    private var nowPlayingArtworkTrackID: String? = nil
    private var isRemoteCommandCenterConfigured: Bool = false
    private var lastRestartTrackID: String? = nil
    private var lastRestartTime: Date = .distantPast
    private var lastNowPlayingSyncSecond: Int = -1

    private var audioInterruptionObserver: NSObjectProtocol?
    private var audioRouteChangeObserver: NSObjectProtocol?
    private let favoritesStorageKey = "harbor.music.favorites.v3"
    private let recentTracksStorageKey = "harbor.music.recent.v3"
    private let playlistsStorageKey = "harbor.music.playlists.v3"
    private let persistedQueueStorageKey = "harbor.music.queue.v3"

    init() {
        setupRemoteTransportControls()
        configureAudioSessionNotifications()
        restoreMusicLibraryAndQueueState()
        startBeatReactiveEngine()
    }

    private func configureAudioSessionNotifications() {
        #if os(iOS)
        let nc = NotificationCenter.default
        audioInterruptionObserver = nc.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let self = self,
                  let info = note.userInfo,
                  let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }
            Task { @MainActor in
                switch type {
                case .began:
                    if self.isPlaying {
                        self.player?.pause()
                        self.reverbEchoPlayer?.pause()
                        self.isPlaying = false
                        self.updateNowPlayingInfo()
                    }
                case .ended:
                    let optVal = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    let options = AVAudioSession.InterruptionOptions(rawValue: optVal)
                    if options.contains(.shouldResume) && !self.isPlaying {
                        self.togglePlayPause()
                    }
                @unknown default:
                    break
                }
            }
        }

        audioRouteChangeObserver = nc.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let self = self else { return }
            let reasonVal = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonVal)
            Task { @MainActor in
                self.refreshAudioRouteLabel()
                if reason == .oldDeviceUnavailable, self.isPlaying {
                    self.player?.pause()
                    self.reverbEchoPlayer?.pause()
                    self.isPlaying = false
                    self.updateNowPlayingInfo()
                }
            }
        }
        refreshAudioRouteLabel()
        #endif
    }

    private func refreshAudioRouteLabel() {
        #if os(iOS)
        if let port = AVAudioSession.sharedInstance().currentRoute.outputs.first {
            audioRouteDescription = port.portName
        } else {
            audioRouteDescription = "سماعة الجهاز"
        }
        #endif
    }

    // MARK: - Favorites, Recently Played, Playlists & Queue Persistence (v3.0)

    private func restoreMusicLibraryAndQueueState() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: favoritesStorageKey),
           let decoded = try? JSONDecoder().decode([HarborMusicTrack].self, from: data) {
            favoriteTracks = decoded
        }
        if let data = defaults.data(forKey: recentTracksStorageKey),
           let decoded = try? JSONDecoder().decode([HarborMusicTrack].self, from: data) {
            recentlyPlayedTracks = decoded
        }
        if let data = defaults.data(forKey: playlistsStorageKey),
           let decoded = try? JSONDecoder().decode([HarborMusicPlaylist].self, from: data) {
            userPlaylists = decoded
        }
        if let data = defaults.data(forKey: persistedQueueStorageKey),
           let decoded = try? JSONDecoder().decode([HarborMusicTrack].self, from: data) {
            queue = decoded
        }
    }

    private func saveMusicLibraryAndQueueState() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(favoriteTracks) {
            defaults.set(data, forKey: favoritesStorageKey)
        }
        if let data = try? JSONEncoder().encode(recentlyPlayedTracks) {
            defaults.set(data, forKey: recentTracksStorageKey)
        }
        if let data = try? JSONEncoder().encode(userPlaylists) {
            defaults.set(data, forKey: playlistsStorageKey)
        }
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: persistedQueueStorageKey)
        }
    }

    func isFavorite(_ track: HarborMusicTrack) -> Bool {
        favoriteTracks.contains(where: { $0.id == track.id })
    }

    func toggleFavorite(_ track: HarborMusicTrack) {
        if let idx = favoriteTracks.firstIndex(where: { $0.id == track.id }) {
            favoriteTracks.remove(at: idx)
        } else {
            favoriteTracks.insert(track, at: 0)
        }
        saveMusicLibraryAndQueueState()
    }

    func recordRecentlyPlayed(_ track: HarborMusicTrack) {
        recentlyPlayedTracks.removeAll(where: { $0.id == track.id })
        recentlyPlayedTracks.insert(track, at: 0)
        if recentlyPlayedTracks.count > 40 {
            recentlyPlayedTracks = Array(recentlyPlayedTracks.prefix(40))
        }
        saveMusicLibraryAndQueueState()
    }

    func createPlaylist(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        userPlaylists.insert(HarborMusicPlaylist(name: trimmed), at: 0)
        saveMusicLibraryAndQueueState()
    }

    func deletePlaylist(id: String) {
        userPlaylists.removeAll(where: { $0.id == id })
        saveMusicLibraryAndQueueState()
    }

    func addTrack(_ track: HarborMusicTrack, toPlaylistID playlistID: String) {
        guard let idx = userPlaylists.firstIndex(where: { $0.id == playlistID }) else { return }
        if !userPlaylists[idx].tracks.contains(where: { $0.id == track.id }) {
            userPlaylists[idx].tracks.append(track)
            saveMusicLibraryAndQueueState()
        }
    }

    func removeTrack(id trackID: String, fromPlaylistID playlistID: String) {
        guard let idx = userPlaylists.firstIndex(where: { $0.id == playlistID }) else { return }
        userPlaylists[idx].tracks.removeAll(where: { $0.id == trackID })
        saveMusicLibraryAndQueueState()
    }

    func playNextInQueue(_ track: HarborMusicTrack) {
        guard let current = currentTrack,
              let curIdx = queue.firstIndex(where: { $0.id == current.id }) else {
            play(track: track, queue: [track])
            return
        }
        queue.removeAll(where: { $0.id == track.id && $0.id != current.id })
        let insertIdx = min(curIdx + 1, queue.count)
        queue.insert(track, at: insertIdx)
        saveMusicLibraryAndQueueState()
    }

    func appendToQueue(_ track: HarborMusicTrack) {
        if currentTrack == nil {
            play(track: track, queue: [track])
            return
        }
        if !queue.contains(where: { $0.id == track.id }) {
            queue.append(track)
            saveMusicLibraryAndQueueState()
        }
    }

    func removeFromQueue(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
        saveMusicLibraryAndQueueState()
    }

    func moveInQueue(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        saveMusicLibraryAndQueueState()
    }

    func retryLyrics() {
        guard let track = currentTrack else { return }
        Task {
            await fetchMultiSourceLyrics(for: track, forceRefresh: true)
        }
    }

    private func computeTrackBaseBPM(for track: HarborMusicTrack) -> Double {
        let combined = "\(track.artist) \(track.title)".lowercased()
        if combined.contains("cigarettes after sex") || combined.contains("lana del rey") || combined.contains("joji") || combined.contains("apocalypse") || combined.contains("sweet") {
            return 78.0
        }
        var hash: UInt64 = 5381
        for byte in combined.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return 92.0 + Double(hash % 34) // 92 ... 125 BPM
    }

    private func startBeatReactiveEngine() {
        beatReactiveTimer?.invalidate()
        beatReactiveTimer = Timer.scheduledTimer(withTimeInterval: 0.065, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.tickBeatReactiveEnvelope()
            }
        }
    }

    private func tickBeatReactiveEnvelope() {
        guard isPlaying, currentTrack != nil else {
            if beatPulseLevel > 0.01 || abs(beatSecondaryWave) > 0.01 {
                withAnimation(.easeOut(duration: 0.25)) {
                    beatPulseLevel = 0.0
                    beatSecondaryWave = 0.0
                }
            }
            return
        }

        let liveSecs: Double
        if !isUsingWebAudioFallback, let p = player {
            let cm = CMTimeGetSeconds(p.currentTime())
            liveSecs = (cm.isFinite && cm > 0) ? cm : currentTime
        } else {
            liveSecs = currentTime
        }

        // Effective BPM scales dynamically with playbackSpeed (e.g., 0.84x Slowed or 1.18x Nightcore)
        let effectiveBPM = trackBaseBPM * Double(playbackSpeed)
        let beatsPerSec = effectiveBPM / 60.0
        let beatPos = liveSecs * beatsPerSec

        // 1. Primary Kick Drum transient (sharp attack + smooth exponential release on every beat)
        let frac = beatPos - floor(beatPos)
        let kickEnvelope = exp(-frac * 5.2) * (0.78 + 0.22 * sin(beatPos * .pi * 0.5))

        // 2. Backbeat Snare / Hi-hat accent on off-beats
        let snareFrac = (beatPos + 0.5) - floor(beatPos + 0.5)
        let snareEnvelope = exp(-snareFrac * 6.5) * 0.44

        // 3. Sub-bass melodic swell across 4-bar phrases
        let bassSwell = 0.5 + 0.5 * sin(beatPos * .pi * 0.25)

        let rawPulse = min(max(kickEnvelope * 0.68 + snareEnvelope * 0.32 + bassSwell * 0.18, 0.08), 1.0)
        let smoothed = CGFloat(rawPulse) * 0.65 + beatPulseLevel * 0.35

        beatPulseLevel = smoothed
        beatSecondaryWave = CGFloat(sin(beatPos * .pi * 0.5))
    }

    func setupRemoteTransportControls() {
        guard !isRemoteCommandCenterConfigured else { return }
        isRemoteCommandCenterConfigured = true
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {}
        UIApplication.shared.beginReceivingRemoteControlEvents()

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false

        commandCenter.playCommand.removeTarget(nil)
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                if !self.isPlaying { self.togglePlayPause() }
            }
            return .success
        }

        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                if self.isPlaying { self.togglePlayPause() }
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.togglePlayPause()
            }
            return .success
        }

        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.playNext()
            }
            return .success
        }

        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.playPrevious()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let targetTime = posEvent.positionTime
            Task { @MainActor in
                self.seek(to: targetTime)
            }
            return .success
        }
        #endif
    }

    func updateNowPlayingInfo() {
        #if os(iOS)
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: "Harbor Sonic Studio • \(dspPreset.shortBadge)",
            MPMediaItemPropertyPlaybackDuration: max(duration, 1),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(currentTime, 0),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackSpeed) : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(playbackSpeed),
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let art = nowPlayingArtwork, nowPlayingArtworkTrackID == track.id {
            info[MPMediaItemPropertyArtwork] = art
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        #endif
    }

    private func loadNowPlayingArtwork(for track: HarborMusicTrack) async {
        #if os(iOS)
        if let img = await HarborArtworkService.shared.loadImage(from: track.artworkURL) {
            guard self.currentTrack?.id == track.id else { return }
            let artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            self.nowPlayingArtwork = artwork
            self.nowPlayingArtworkTrackID = track.id
            self.updateNowPlayingInfo()
        }
        #endif
    }

    func selectDSPPreset(_ preset: HarborAudioDSPPreset) {
        self.dspPreset = preset
        self.playbackSpeed = preset.defaultRate
        self.reverbMix = preset.defaultReverbMix
        self.useAnalogVarispeedPitch = preset.usesAnalogVarispeedPitch
        applyLiveDSPToActivePlayers(forceResyncReverb: true)
    }

    func updateCustomDSP(speed: Float, reverb: Float, varispeed: Bool) {
        self.playbackSpeed = min(max(speed, 0.65), 1.35)
        self.reverbMix = min(max(reverb, 0.0), 1.0)
        self.useAnalogVarispeedPitch = varispeed
        applyLiveDSPToActivePlayers(forceResyncReverb: true)
    }

    func applyLiveDSPToActivePlayers(forceResyncReverb: Bool = false) {
        guard let mainPlayer = player else { return }
        let pitchAlgo: AVAudioTimePitchAlgorithm = useAnalogVarispeedPitch ? .varispeed : .spectral
        mainPlayer.currentItem?.audioTimePitchAlgorithm = pitchAlgo

        if isPlaying {
            mainPlayer.rate = playbackSpeed
        }

        if reverbMix > 0.04, let url = activeStreamURL, isPlaying, currentTime > 0.2 {
            if reverbEchoPlayer == nil {
                let headers = [
                    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
                ]
                let echoItem = AVPlayerItem(asset: AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers]))
                echoItem.audioTimePitchAlgorithm = pitchAlgo
                let echo = AVPlayer(playerItem: echoItem)
                echo.volume = min(reverbMix * 0.42, 0.45)
                self.reverbEchoPlayer = echo
                self.isReverbSynced = false
            }
            reverbEchoPlayer?.currentItem?.audioTimePitchAlgorithm = pitchAlgo
            reverbEchoPlayer?.volume = min(reverbMix * 0.42, 0.45)

            if forceResyncReverb || !isReverbSynced {
                isReverbSynced = true
                let targetEchoSecs = max(currentTime - 0.068, 0)
                let cm = CMTime(seconds: targetEchoSecs, preferredTimescale: 600)
                reverbEchoPlayer?.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
                reverbEchoPlayer?.play()
                reverbEchoPlayer?.rate = playbackSpeed
            } else if reverbEchoPlayer?.rate != playbackSpeed {
                reverbEchoPlayer?.rate = playbackSpeed
            }
        } else {
            reverbEchoPlayer?.volume = 0
            reverbEchoPlayer?.pause()
            isReverbSynced = false
        }
    }

    func play(track: HarborMusicTrack, queue: [HarborMusicTrack] = []) {
        if !queue.isEmpty {
            self.queue = queue
        } else if !self.queue.contains(where: { $0.id == track.id }) {
            self.queue.insert(track, at: 0)
        }
        setupRemoteTransportControls()
        self.currentTrack = track
        self.playbackErrorBanner = nil
        self.recordRecentlyPlayed(track)
        self.trackBaseBPM = computeTrackBaseBPM(for: track)
        self.duration = max(track.durationSeconds, 120)
        self.currentTime = 0
        self.lastNowPlayingSyncSecond = -1
        self.updateNowPlayingInfo()
        Task {
            await self.loadNowPlayingArtwork(for: track)
        }
        self.isUsingWebAudioFallback = false
        self.isReverbSynced = false
        self.candidateStreamURLs = []
        self.currentCandidateIndex = 0
        stopWebFallbackTimer()
        watchdogTask?.cancel()
        statusObservation?.invalidate()
        statusObservation = nil

        let rawStream = track.streamURL
        if rawStream.hasPrefix("http") && !rawStream.contains("mzstatic.com") && !rawStream.contains("dzcdn.net") {
            let alt96 = rawStream.replacingOccurrences(of: "_160.mp4", with: "_96.mp4")
            self.candidateStreamURLs = alt96 != rawStream ? [rawStream, alt96] : [rawStream]
            self.currentCandidateIndex = 0
            self.isResolvingFullStream = false
            self.activeEngineLabel = "160K AAC • STUDIO MASTER"
            playCurrentCandidate(for: track)

            // Also resolve YouTube HLS backup candidates in background in case the direct CDN link expires
            Task {
                if let resolved = await JioSaavnStreamCrypto.resolveBestFullStreamCandidates(
                    title: track.title,
                    artist: track.artist,
                    expectedDuration: track.durationSeconds
                ) {
                    guard self.currentTrack?.id == track.id else { return }
                    if let vid = resolved.youtubeVideoID {
                        self.activeYouTubeVideoID = vid
                    }
                    for c in resolved.candidates where !self.candidateStreamURLs.contains(c) {
                        self.candidateStreamURLs.append(c)
                    }
                }
            }
        } else {
            resolveAndPlayFullTrack(track: track)
        }

        Task {
            await fetchMultiSourceLyrics(for: track)
        }
    }

    func upgradeCurrentTrackToFullStreamIfVerified() async {
        guard let track = currentTrack else { return }
        resolveAndPlayFullTrack(track: track)
    }

    private func resolveAndPlayFullTrack(track: HarborMusicTrack) {
        isResolvingFullStream = true
        player?.pause()
        reverbEchoPlayer?.pause()
        reverbEchoPlayer = nil
        watchdogTask?.cancel()
        statusObservation?.invalidate()
        statusObservation = nil

        Task {
            if let resolved = await JioSaavnStreamCrypto.resolveBestFullStreamCandidates(
                title: track.title,
                artist: track.artist,
                expectedDuration: track.durationSeconds
            ) {
                guard self.currentTrack?.id == track.id else { return }
                self.isResolvingFullStream = false
                if let vid = resolved.youtubeVideoID {
                    self.activeYouTubeVideoID = vid
                }
                self.duration = max(resolved.duration, track.durationSeconds, 120)
                self.candidateStreamURLs = resolved.candidates
                self.currentCandidateIndex = 0
                self.playCurrentCandidate(for: track)
            } else {
                guard self.currentTrack?.id == track.id else { return }
                self.isResolvingFullStream = false
                if let vid = await JioSaavnStreamCrypto.resolveYouTubeVideoID(title: track.title, artist: track.artist) {
                    self.activeYouTubeVideoID = vid
                    self.candidateStreamURLs = ["ytweb://\(vid)"]
                    self.currentCandidateIndex = 0
                    self.playCurrentCandidate(for: track)
                }
            }
        }
    }

    private func playCurrentCandidate(for track: HarborMusicTrack) {
        guard currentCandidateIndex < candidateStreamURLs.count else {
            if let vid = activeYouTubeVideoID {
                activeEngineLabel = "YOUTUBE OFFICIAL AUDIO"
                startWebAudioFallback(duration: max(track.durationSeconds, 150), track: track)
            }
            return
        }

        let candidate = candidateStreamURLs[currentCandidateIndex]
        if candidate.hasPrefix("ytweb://") {
            let vid = candidate.replacingOccurrences(of: "ytweb://", with: "")
            self.activeYouTubeVideoID = vid
            self.activeEngineLabel = "YOUTUBE OFFICIAL AUDIO"
            self.startWebAudioFallback(duration: max(self.duration, track.durationSeconds, 150), track: track)
            return
        }

        guard let fullURL = URL(string: candidate) else {
            advanceToNextCandidateStream(for: track)
            return
        }

        if candidate.contains(".m3u8") {
            self.activeEngineLabel = "APPLE HLS • FULL MASTER"
        } else if candidate.contains("googlevideo") {
            self.activeEngineLabel = "YOUTUBE HI-FI • FULL MASTER"
        } else {
            self.activeEngineLabel = "160K AAC • STUDIO MASTER"
        }

        startAVPlayer(with: fullURL, track: track)
    }

    private func advanceToNextCandidateStream(for track: HarborMusicTrack) {
        guard self.currentTrack?.id == track.id else { return }
        watchdogTask?.cancel()
        statusObservation?.invalidate()
        statusObservation = nil
        currentCandidateIndex += 1
        playCurrentCandidate(for: track)
    }

    private func startWebAudioFallback(duration: Double, track: HarborMusicTrack) {
        player?.pause()
        reverbEchoPlayer?.pause()
        reverbEchoPlayer = nil
        self.duration = max(duration, 150)
        self.currentTime = 0
        self.isUsingWebAudioFallback = true
        self.isPlaying = true
        stopWebFallbackTimer()
        webFallbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                guard self.isPlaying && self.isUsingWebAudioFallback else { return }
                let step = 0.5 * Double(self.playbackSpeed)
                if self.currentTime + step < self.duration {
                    self.currentTime += step
                } else if self.isRepeatEnabled {
                    self.currentTime = 0
                } else {
                    self.playNext()
                }
            }
        }
    }

    private func stopWebFallbackTimer() {
        webFallbackTimer?.invalidate()
        webFallbackTimer = nil
    }

    private func startAVPlayer(with url: URL, track: HarborMusicTrack) {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        UIApplication.shared.beginReceivingRemoteControlEvents()
        #endif

        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
        if let endObs = endObserver {
            NotificationCenter.default.removeObserver(endObs)
            endObserver = nil
        }
        if let failObs = failObserver {
            NotificationCenter.default.removeObserver(failObs)
            failObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil

        reverbEchoPlayer?.pause()
        reverbEchoPlayer = nil
        isReverbSynced = false
        activeStreamURL = url

        let isGoogleVideo = url.host?.contains("googlevideo") == true
        let ua = isGoogleVideo
            ? "com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)"
            : "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"

        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": ua]
        ])
        let item = AVPlayerItem(asset: asset)
        item.audioTimePitchAlgorithm = useAnalogVarispeedPitch ? .varispeed : .spectral

        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.volume = 1.0
        self.player = avPlayer
        self.duration = max(track.durationSeconds, 120)
        self.currentTime = 0
        self.isUsingWebAudioFallback = false

        // Observe AVPlayerItem.status so if a candidate URL 403s or fails, we switch to the next full-length candidate in <50ms!
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            guard let self = self else { return }
            if observedItem.status == .failed {
                Task { @MainActor in
                    self.advanceToNextCandidateStream(for: track)
                }
            }
        }

        avPlayer.play()
        if abs(playbackSpeed - 1.0) > 0.01 {
            avPlayer.rate = playbackSpeed
        }
        self.isPlaying = true

        // 2.8-Second Watchdog: If candidate stream stalls at 0:00, immediately advance to the next full-length candidate!
        watchdogTask?.cancel()
        watchdogTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard !Task.isCancelled, self.currentTrack?.id == track.id, self.isPlaying, !self.isUsingWebAudioFallback else { return }
            if self.currentTime < 0.12 {
                self.advanceToNextCandidateStream(for: track)
            }
        }

        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite {
                Task { @MainActor in
                    self.currentTime = seconds
                    if self.isPlaying && abs(avPlayer.rate - self.playbackSpeed) > 0.02 && seconds > 0.1 {
                        avPlayer.rate = self.playbackSpeed
                    }
                    if self.reverbMix > 0.04 && !self.isReverbSynced && seconds > 0.25 {
                        self.applyLiveDSPToActivePlayers(forceResyncReverb: true)
                    }
                    if let d = self.player?.currentItem?.duration {
                        let dSecs = CMTimeGetSeconds(d)
                        // Strict 55-second floor: NEVER accept a 29-second duration!
                        if dSecs.isFinite && dSecs > 55 {
                            self.duration = dSecs
                        }
                    }
                    let secInt = Int(seconds)
                    if secInt != self.lastNowPlayingSyncSecond {
                        self.lastNowPlayingSyncSecond = secInt
                        self.updateNowPlayingInfo()
                    }
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.isRepeatEnabled {
                    self.seek(to: 0)
                    self.player?.play()
                    self.player?.rate = self.playbackSpeed
                    self.isPlaying = true
                    self.applyLiveDSPToActivePlayers(forceResyncReverb: true)
                } else {
                    self.playNext()
                }
            }
        }

        failObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.advanceToNextCandidateStream(for: track)
            }
        }
    }

    func togglePlayPause() {
        if isUsingWebAudioFallback {
            isPlaying.toggle()
            updateNowPlayingInfo()
            return
        }
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            reverbEchoPlayer?.pause()
            isPlaying = false
        } else {
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
            player.play()
            player.rate = playbackSpeed
            isPlaying = true
            applyLiveDSPToActivePlayers(forceResyncReverb: true)
        }
        updateNowPlayingInfo()
    }

    func seek(to seconds: Double) {
        let clamped = max(0, min(seconds, max(duration, 1)))
        currentTime = clamped
        if !isUsingWebAudioFallback {
            let cm = CMTime(seconds: clamped, preferredTimescale: 600)
            player?.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
            if reverbMix > 0.04 {
                let cmEcho = CMTime(seconds: max(clamped - 0.068, 0), preferredTimescale: 600)
                reverbEchoPlayer?.seek(to: cmEcho, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
        updateNowPlayingInfo()
    }

    func replayCurrentTrack() {
        seek(to: 0)
        if isUsingWebAudioFallback {
            isPlaying = true
            updateNowPlayingInfo()
            return
        }
        if let player = player {
            player.play()
            player.rate = playbackSpeed
            isPlaying = true
            applyLiveDSPToActivePlayers(forceResyncReverb: true)
            updateNowPlayingInfo()
        } else if let track = currentTrack {
            play(track: track, queue: queue)
        }
    }

    func stopAndCloseTrack() {
        watchdogTask?.cancel()
        statusObservation?.invalidate()
        statusObservation = nil
        stopWebFallbackTimer()
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        reverbEchoPlayer?.pause()
        reverbEchoPlayer = nil
        isPlaying = false
        isUsingWebAudioFallback = false
        currentTime = 0
        isShowingFullPlayer = false
        isShowingLyricsSheet = false
        currentTrack = nil
        beatPulseLevel = 0.0
        beatSecondaryWave = 0.0
        nowPlayingArtwork = nil
        nowPlayingArtworkTrackID = nil
        updateNowPlayingInfo()
    }

    func playNext() {
        guard !queue.isEmpty else { return }
        if isShuffleEnabled, let randomTrack = queue.randomElement() {
            play(track: randomTrack, queue: queue)
            return
        }
        guard let current = currentTrack,
              let idx = queue.firstIndex(where: { $0.id == current.id }) else {
            if let first = queue.first { play(track: first, queue: queue) }
            return
        }
        let nextIdx = (idx + 1) % queue.count
        play(track: queue[nextIdx], queue: queue)
    }

    func playPrevious() {
        let now = Date()
        let recentlyRestartedSameTrack = (lastRestartTrackID == currentTrack?.id) && (now.timeIntervalSince(lastRestartTime) < 4.8)
        if currentTime > 3.2 || !recentlyRestartedSameTrack {
            lastRestartTrackID = currentTrack?.id
            lastRestartTime = now
            replayCurrentTrack()
            return
        }
        lastRestartTrackID = nil
        guard !queue.isEmpty,
              let current = currentTrack,
              let idx = queue.firstIndex(where: { $0.id == current.id }) else {
            replayCurrentTrack()
            return
        }
        let prevIdx = (idx - 1 + queue.count) % queue.count
        play(track: queue[prevIdx], queue: queue)
    }

    private struct CachedLyricsRecord: Codable {
        let synced: [SyncedLyricLine]
        let plain: String?
        let isTrueSynced: Bool
        let badge: String
    }

    private func fetchMultiSourceLyrics(for track: HarborMusicTrack, forceRefresh: Bool = false) async {
        self.syncedLyrics = []
        self.plainLyrics = nil
        self.isTrueSyncedLyrics = false
        self.isLoadingLyrics = true
        defer { self.isLoadingLyrics = false }

        let cacheKey = "lyrics.v3.\(track.artist.lowercased()).\(track.title.lowercased())"
        if !forceRefresh,
           let cached = HarborDiskCacheManager.shared.getCodable(forKey: cacheKey, as: CachedLyricsRecord.self) {
            self.syncedLyrics = cached.synced
            self.plainLyrics = cached.plain
            self.isTrueSyncedLyrics = cached.isTrueSynced
            self.lyricsSourceBadge = cached.badge
            return
        }

        guard !track.isLiveStream else {
            self.plainLyrics = "بث إذاعي مباشر على مدار الساعة عبر محرك الصوت في Harbor."
            return
        }

        let cleanTitle = track.title
            .components(separatedBy: "(").first?
            .components(separatedBy: "[").first?
            .components(separatedBy: "-").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? track.title
        let cleanArtist = track.artist
            .components(separatedBy: ",").first?
            .components(separatedBy: "&").first?
            .components(separatedBy: "feat").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? track.artist

        let artistEnc = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let titleEnc = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let durInt = Int(max(track.durationSeconds, 180))

        // Layer 1: LRCLIB Exact Match
        if let url = URL(string: "https://lrclib.net/api/get?artist_name=\(artistEnc)&track_name=\(titleEnc)") {
            var req = URLRequest(url: url)
            req.timeoutInterval = 3.0
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let decoded = try? JSONDecoder().decode(LRCLibResponse.self, from: data) {
                self.plainLyrics = decoded.plainLyrics
                if let lrc = decoded.syncedLyrics {
                    let parsed = Self.parseLRC(lrc)
                    if !parsed.isEmpty {
                        self.lyricsSourceBadge = "LRCLIB Synced"
                        self.isTrueSyncedLyrics = true
                        self.syncedLyrics = parsed
                        HarborDiskCacheManager.shared.setCodable(
                            CachedLyricsRecord(synced: parsed, plain: self.plainLyrics, isTrueSynced: true, badge: self.lyricsSourceBadge),
                            forKey: cacheKey
                        )
                        return
                    }
                }
            }
        }

        // Layer 2: BitChord's LyricsPlus Multi-Host Aggregator (Apple Music + Musixmatch + Spotify)
        let lyricsPlusHosts = [
            "https://lyricsplus.prjktla.workers.dev",
            "https://lyricsplus.binimum.org",
            "https://lyricsplus.atomix.one",
            "https://lyrics-plus-backend.vercel.app"
        ]
        for host in lyricsPlusHosts {
            guard let lpURL = URL(string: "\(host)/v2/lyrics/get?title=\(titleEnc)&artist=\(artistEnc)&duration=\(durInt)&source=apple,lyricsplus,musixmatch,spotify") else { continue }
            var req = URLRequest(url: lpURL)
            req.timeoutInterval = 3.0
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let lyricItems = root["lyrics"] as? [[String: Any]], !lyricItems.isEmpty {
                var lines: [SyncedLyricLine] = []
                for item in lyricItems {
                    guard let text = (item["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !text.isEmpty else { continue }
                    let timeMs = (item["time"] as? Double) ?? Double((item["time"] as? Int) ?? 0)
                    let secs = timeMs > 500 ? (timeMs / 1000.0) : timeMs
                    lines.append(SyncedLyricLine(timestampSeconds: max(secs, 0), text: text))
                }
                if !lines.isEmpty {
                    self.lyricsSourceBadge = "Apple Music / LyricsPlus"
                    self.isTrueSyncedLyrics = true
                    self.syncedLyrics = lines
                    self.plainLyrics = lines.map { $0.text }.joined(separator: "\n")
                    HarborDiskCacheManager.shared.setCodable(
                        CachedLyricsRecord(synced: lines, plain: self.plainLyrics, isTrueSynced: true, badge: self.lyricsSourceBadge),
                        forKey: cacheKey
                    )
                    return
                }
            }
        }

        // Layer 3: LRCLIB Broad Search (/api/search?q=...)
        for queryCandidate in ["\(cleanTitle) \(cleanArtist)", cleanTitle] {
            let searchEnc = queryCandidate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? titleEnc
            guard let sURL = URL(string: "https://lrclib.net/api/search?q=\(searchEnc)") else { continue }
            var req = URLRequest(url: sURL)
            req.timeoutInterval = 3.0
            if let (sData, sResp) = try? await URLSession.shared.data(for: req),
               let sHttp = sResp as? HTTPURLResponse, sHttp.statusCode == 200,
               let list = try? JSONDecoder().decode([LRCLibResponse].self, from: sData),
               let best = list.first(where: { $0.syncedLyrics != nil && !($0.syncedLyrics ?? "").isEmpty }) ?? list.first {
                self.plainLyrics = best.plainLyrics
                if let lrc = best.syncedLyrics {
                    let parsed = Self.parseLRC(lrc)
                    if !parsed.isEmpty {
                        self.lyricsSourceBadge = "LRCLIB Synced"
                        self.isTrueSyncedLyrics = true
                        self.syncedLyrics = parsed
                        HarborDiskCacheManager.shared.setCodable(
                            CachedLyricsRecord(synced: parsed, plain: self.plainLyrics, isTrueSynced: true, badge: self.lyricsSourceBadge),
                            forKey: cacheKey
                        )
                        return
                    }
                } else if let plain = best.plainLyrics, !plain.isEmpty {
                    self.lyricsSourceBadge = "Plain Lyrics (نص غير متزامن)"
                    self.isTrueSyncedLyrics = false
                    self.syncedLyrics = []
                    self.plainLyrics = plain
                    HarborDiskCacheManager.shared.setCodable(
                        CachedLyricsRecord(synced: [], plain: plain, isTrueSynced: false, badge: self.lyricsSourceBadge),
                        forKey: cacheKey
                    )
                    return
                }
            }
        }

        // Layer 4: Lyrics.ovh Plain Text Fallback (Explicitly labeled as Plain Lyrics, never fake-synced)
        if let ovhURL = URL(string: "https://api.lyrics.ovh/v1/\(artistEnc)/\(titleEnc)") {
            var req = URLRequest(url: ovhURL)
            req.timeoutInterval = 3.5
            if let (oData, oResp) = try? await URLSession.shared.data(for: req),
               let oHttp = oResp as? HTTPURLResponse, oHttp.statusCode == 200,
               let oJson = try? JSONSerialization.jsonObject(with: oData) as? [String: Any],
               let rawLyrics = oJson["lyrics"] as? String, !rawLyrics.isEmpty {
                self.plainLyrics = rawLyrics
                self.isTrueSyncedLyrics = false
                self.syncedLyrics = []
                self.lyricsSourceBadge = "Lyrics.ovh (نص غير متزامن)"
                HarborDiskCacheManager.shared.setCodable(
                    CachedLyricsRecord(synced: [], plain: rawLyrics, isTrueSynced: false, badge: self.lyricsSourceBadge),
                    forKey: cacheKey
                )
                return
            }
        }
    }

    private static func distributePlainLines(_ plain: String, duration: Double) -> [SyncedLyricLine] {
        let rawLines = plain
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("Paroles de") }
        let step = max(duration / Double(max(rawLines.count, 1)), 3.2)
        var generated: [SyncedLyricLine] = []
        for (idx, txt) in rawLines.enumerated() {
            generated.append(SyncedLyricLine(timestampSeconds: Double(idx) * step, text: txt))
        }
        return generated
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

