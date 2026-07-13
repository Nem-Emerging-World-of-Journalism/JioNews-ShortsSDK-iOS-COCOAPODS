//
//  NativeVideoPlayerView.swift
//  JioNewsShortsSDK
//
//  AVPlayer-backed player for the native (getNativeShorts) shorts feed.
//  Ported from the DemoShorts native feed.
//

import SwiftUI
import AVFoundation
import UIKit

struct NativeVideoPlayerView: UIViewRepresentable {
    let videoURL: URL
    let isPlaying: Bool
    let isMuted: Bool
    var onPlaybackStarted: () -> Void = {}
    /// Reports playback progress as a fraction in 0...1.
    var onProgress: (Double) -> Void = { _ in }
    /// Reports the asset's total duration in seconds, once known.
    var onDuration: (Double) -> Void = { _ in }

    func makeUIView(context: Context) -> NativePlayerContainerView {
        let view = NativePlayerContainerView()
        view.onPlaybackStarted = onPlaybackStarted
        view.onProgress = onProgress
        view.onDuration = onDuration
        view.configure(url: videoURL, muted: isMuted)
        if isPlaying { view.play() } else { view.pause() }
        return view
    }

    func updateUIView(_ uiView: NativePlayerContainerView, context: Context) {
        uiView.onPlaybackStarted = onPlaybackStarted
        uiView.onProgress = onProgress
        uiView.onDuration = onDuration
        uiView.updateURL(videoURL, muted: isMuted)
        uiView.setMuted(isMuted)
        if isPlaying { uiView.play() } else { uiView.pause() }
    }

    static func dismantleUIView(_ uiView: NativePlayerContainerView, coordinator: ()) {
        uiView.dismantle()
    }
}

final class NativePlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var player: AVPlayer?
    private var currentURL: URL?
    private var endObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var hasFiredPlaybackStarted = false

    var onPlaybackStarted: () -> Void = {}
    var onProgress: (Double) -> Void = { _ in }
    var onDuration: (Double) -> Void = { _ in }
    private var hasFiredDuration = false
    private var hasResolvedGravity = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        // Fit the whole video without cropping the sides (letterbox/pillarbox).
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    func configure(url: URL, muted: Bool) {
        guard currentURL != url else { return }
        teardownPlayer()
        currentURL = url
        hasFiredPlaybackStarted = false
        hasFiredDuration = false
        hasResolvedGravity = false

        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.isMuted = muted
        p.actionAtItemEnd = .none
        p.automaticallyWaitsToMinimizeStalling = true
        player = p
        playerLayer.player = p

        // Default to fit; refined to fill (center-crop) for landscape clips once
        // the presentation size is known (portrait stays fit — no crop).
        playerLayer.videoGravity = .resizeAspect

        // Loop at end.
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }

        // First-frame detection, aspect, duration + progress — all read from
        // AVPlayerItem so there are no iOS 16-only AVAsset load APIs.
        timeObserver = p.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 10),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }

            if time.seconds > 0.05, !self.hasFiredPlaybackStarted {
                self.hasFiredPlaybackStarted = true
                self.onPlaybackStarted()
            }

            // Resolve aspect once the real video size is known.
            if !self.hasResolvedGravity,
               let size = self.player?.currentItem?.presentationSize,
               size.width > 0, size.height > 0 {
                self.hasResolvedGravity = true
                self.playerLayer.videoGravity = size.width > size.height ? .resizeAspectFill : .resizeAspect
            }

            if let duration = self.player?.currentItem?.duration.seconds,
               duration.isFinite, duration > 0 {
                if !self.hasFiredDuration {
                    self.hasFiredDuration = true
                    self.onDuration(duration)
                }
                let fraction = min(max(time.seconds / duration, 0), 1)
                self.onProgress(fraction)
            }
        }
    }

    func updateURL(_ url: URL, muted: Bool) {
        guard currentURL != url else { return }
        configure(url: url, muted: muted)
    }

    func play() { player?.play() }
    func pause() { player?.pause() }
    func setMuted(_ muted: Bool) { player?.isMuted = muted }

    func dismantle() { teardownPlayer() }

    private func teardownPlayer() {
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
        endObserver = nil
        if let obs = timeObserver { player?.removeTimeObserver(obs) }
        timeObserver = nil
        player?.pause()
        playerLayer.player = nil
        player = nil
        currentURL = nil
    }

    deinit { teardownPlayer() }
}
