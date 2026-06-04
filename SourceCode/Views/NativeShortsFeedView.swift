//
//  NativeShortsFeedView.swift
//  JioNewsShortsSDK
//
//  Native (AVPlayer) vertical shorts feed backed by the `getNativeShorts`
//  query. Ported from the DemoShorts native feed and wired to the shared
//  `ShortsController` so the UIKit `ShortsView` can drive playback/mute and
//  read back the current brief.
//

import SwiftUI
import Combine

@MainActor
final class NativeShortsViewModel: ObservableObject {
    @Published var items: [STBNewsBrief] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?

    private let controller: ShortsController
    private let pageSize: Int = 10
    private let prefetchThreshold: Int = 3
    private var currentPage: Int = 0
    private var totalPages: Int?
    private var didSignalFeedLoaded = false

    init(controller: ShortsController) {
        self.controller = controller
    }

    private var hasMore: Bool {
        guard let total = totalPages else { return true }
        return currentPage < total
    }

    func loadFirstPage() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        let start = Date()
        defer {
            isLoading = false
            if !didSignalFeedLoaded {
                didSignalFeedLoaded = true
                controller.onFeedLoaded?()
                controller.recordFeedLoad(loadTime: Int(Date().timeIntervalSince(start)), apiError: errorMessage)
            }
        }
        do {
            let token = try await controller.token()
            let result = try await GraphQLService.shared.fetchNativeShortsDecoded(token: token, page: 1, size: pageSize)
            currentPage = 1
            totalPages = result.cursor?.totalPages
            let raw = result.newsBriefs ?? []
            items = raw.filter { $0.videoURL != nil }
            if items.isEmpty {
                errorMessage = raw.isEmpty
                    ? "No videos returned. (Check Authorization token.)"
                    : "Returned \(raw.count) item(s), but none had a usable video URL."
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    func loadMoreIfNeeded(currentIndex: Int) async {
        guard !isLoadingMore, !isLoading, hasMore else { return }
        guard currentIndex >= items.count - prefetchThreshold else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }
        let nextPage = currentPage + 1
        do {
            let token = try await controller.token()
            let result = try await GraphQLService.shared.fetchNativeShortsDecoded(token: token, page: nextPage, size: pageSize)
            let raw = result.newsBriefs ?? []
            let newItems = raw.filter { $0.videoURL != nil }
            currentPage = nextPage
            totalPages = result.cursor?.totalPages ?? totalPages
            let existing = Set(items.map(\.id))
            let appended = newItems.filter { !existing.contains($0.id) }
            items.append(contentsOf: appended)
        } catch {
            // Pagination failed; keep the items already loaded.
        }
    }
}

struct NativeShortsFeedView: View {
    @ObservedObject var controller: ShortsController
    @StateObject private var vm: NativeShortsViewModel
    @State private var currentID: String?

    init(controller: ShortsController) {
        self.controller = controller
        _vm = StateObject(wrappedValue: NativeShortsViewModel(controller: controller))
    }

    private var backgroundColor: Color {
        controller.theme == .dark ? .black : .white
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            if vm.isLoading && vm.items.isEmpty {
                ProgressView().tint(.white).scaleEffect(1.2)
            } else if let msg = vm.errorMessage, vm.items.isEmpty {
                errorView(msg)
            } else {
                feed
            }
        }
        .task {
            if vm.items.isEmpty { await vm.loadFirstPage() }
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 44))
            Text(msg)
                .foregroundStyle(.white)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await vm.loadFirstPage() }
            } label: {
                Text("Retry")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.15), in: Capsule())
                    .foregroundStyle(.white)
            }
        }
    }

    private var feed: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(vm.items) { item in
                    NativeShortCardView(item: item, controller: controller, currentID: currentID)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(item.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
        .onAppear {
            if currentID == nil {
                currentID = vm.items.first?.id
                controller.recordCurrentBrief(brief(for: currentID), swipe: "NA")
                prefetchUpcomingThumbnails(after: currentID)
            }
        }
        .onChange(of: currentID) { oldID, newID in
            controller.recordCurrentBrief(brief(for: newID), swipe: swipeDirection(from: oldID, to: newID))
            prefetchUpcomingThumbnails(after: newID)
            guard let newID,
                  let idx = vm.items.firstIndex(where: { $0.id == newID }) else { return }
            Task { await vm.loadMoreIfNeeded(currentIndex: idx) }
        }
        .onDisappear {
            controller.recordFeedExit()
        }
    }

    private func brief(for id: String?) -> STBNewsBrief? {
        vm.items.first { $0.id == id }
    }

    /// Swipe direction between two items by their index in the feed.
    private func swipeDirection(from old: String?, to new: String?) -> String {
        guard let old, let new,
              let oi = vm.items.firstIndex(where: { $0.id == old }),
              let ni = vm.items.firstIndex(where: { $0.id == new }) else { return "NA" }
        if ni > oi { return "next" }
        if ni < oi { return "previous" }
        return "NA"
    }

    /// Warms the thumbnail cache for the next few **already-loaded** items so they
    /// don't flash black while downloading. Only looks at items already in
    /// `vm.items` and stops at the end of the list — never triggers pagination.
    private func prefetchUpcomingThumbnails(after id: String?) {
        guard let id, let idx = vm.items.firstIndex(where: { $0.id == id }) else { return }
        for offset in 1...3 {
            let next = idx + offset
            guard next < vm.items.count else { break }   // no more loaded items → stop
            if let thumb = vm.items[next].bestThumbnailURLString, let url = URL(string: thumb) {
                ThumbnailCache.prefetch(url)
            }
        }
    }
}

// MARK: - Card

struct NativeShortCardView: View {
    let item: STBNewsBrief
    @ObservedObject var controller: ShortsController
    let currentID: String?

    @State private var hasStartedPlaying: Bool = false
    @State private var progress: Double = 0

    private var isCurrent: Bool { item.id == currentID }

    var body: some View {
        ZStack {
            Color.black

            // Player — only mounted for the current card.
            if isCurrent, let videoURL = item.videoURL {
                NativeVideoPlayerView(
                    videoURL: videoURL,
                    isPlaying: isCurrent && controller.shouldPlay,
                    isMuted: controller.isMuted,
                    onPlaybackStarted: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            hasStartedPlaying = true
                        }
                    },
                    onProgress: { progress = $0 },
                    onDuration: { controller.recordDuration($0, for: item.id) }
                )
                .allowsHitTesting(false)
            }

            // Thumbnail — opacity-fades when playback starts.
            if let thumb = item.bestThumbnailURLString, let url = URL(string: thumb) {
                Color.clear
                    .overlay { ThumbnailImage(url: url) }
                    .clipped()
                    .allowsHitTesting(false)
                    .opacity(isCurrent && hasStartedPlaying ? 0 : 1)
                    .animation(.easeOut(duration: 0.25), value: hasStartedPlaying)
            }

            // Tap-to-play/pause.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !controller.isPlaybackDisabled else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        controller.isPaused.toggle()
                    }
                }

            // Bottom gradient + title + publisher + Shorts badge.
            VStack(spacing: 0) {
                Spacer()
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7), .black.opacity(0.97)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 260)
                    .allowsHitTesting(false)

                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            if let title = item.title, !title.isEmpty {
                                Text(title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineSpacing(2)
                                    .multilineTextAlignment(.leading)
                            }
                            HStack(spacing: 6) {
                                if let name = item.publisher?.name {
                                    Text(name).fontWeight(.medium)
                                }
                                if let ago = item.publishedAt?.agoFromNow {
                                    Text("•").opacity(0.6)
                                    Text(ago)
                                }
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 85)   // leave room for the right-side action icons
                    .padding(.bottom, 28)
                }
            }
            .allowsHitTesting(false)

            // Right-side action stack.
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 30) {
                        LikeButton(item: item, controller: controller)
                        ActionButton(assetName: "ic_share_white", label: item.shareText ?? "") {
                            controller.tapShare(item)        // backend impression (fire-and-forget)
                            controller.onShareTapped?(item)  // client callback
                        }
                        MuteButton(isMuted: controller.isMuted) { controller.toggleMute() }
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, 28)   // align stack bottom with the title/time-source line
                }
            }

            // Pause indicator.
            if controller.isPaused && isCurrent {
                Image(shorts: "ic_video_play")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .shadow(radius: 8)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale))
            }

            // Playback progress bar — bottom edge, 3px, red (YouTube-style).
            if isCurrent {
                VStack(spacing: 0) {
                    Spacer()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.25))
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 3)
                }
                .allowsHitTesting(false)
            }
        }
        .clipped()
        .onChange(of: isCurrent) { _, nowCurrent in
            if !nowCurrent {
                hasStartedPlaying = false
                progress = 0
            }
        }
    }
}

// MARK: - Components

struct ActionButton: View {
    let icon: AnyView
    let label: String
    var action: () -> Void = {}

    /// SF Symbol icon (tinted white).
    init(systemName: String, label: String, action: @escaping () -> Void = {}) {
        self.icon = AnyView(
            Image(systemName: systemName)
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .shadow(radius: 4)
        )
        self.label = label
        self.action = action
    }

    /// Custom icon from the SDK's resource bundle (rendered as-is).
    init(assetName: String, label: String, action: @escaping () -> Void = {}) {
        self.icon = AnyView(
            Image(shorts: assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
                .shadow(radius: 4)
        )
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                icon
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct LikeButton: View {
    let item: STBNewsBrief
    @ObservedObject var controller: ShortsController

    var body: some View {
        let state = controller.likeState(for: item)
        Button {
            controller.toggleLike(item)
        } label: {
            VStack(spacing: 4) {
                Image(shorts: "ic_like_white")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 23, height: 23)
                    .foregroundStyle(state.isLiked ? .green : .white)
                    .shadow(radius: 4)
                if state.count > 0 {
                    Text("\(state.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct MuteButton: View {
    let isMuted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(shorts: isMuted ? "ic_video_muteLarge" : "ic_video_unmuteLarge")
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
                .shadow(radius: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Thumbnail

private enum ThumbnailCache {
    static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 50
        return c
    }()

    private static let lock = NSLock()
    private static var inFlight = Set<String>()

    /// Downloads and caches a thumbnail ahead of time. No-op if it's already
    /// cached or a prefetch is already in flight for the same URL.
    static func prefetch(_ url: URL) {
        let keyString = url.absoluteString
        let key = keyString as NSString
        if cache.object(forKey: key) != nil { return }

        lock.lock()
        if inFlight.contains(keyString) { lock.unlock(); return }
        inFlight.insert(keyString)
        lock.unlock()

        Task.detached(priority: .utility) {
            defer { lock.lock(); inFlight.remove(keyString); lock.unlock() }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let img = UIImage(data: data) else { return }
            cache.setObject(img, forKey: key)
        }
    }
}

struct ThumbnailImage: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                // Landscape → center-crop to fill; portrait → fit (no crop).
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: image.size.width > image.size.height ? .fill : .fit)
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .task(id: url) {
            let key = url.absoluteString as NSString
            if let cached = ThumbnailCache.cache.object(forKey: key) {
                image = cached
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let img = UIImage(data: data) else { return }
                ThumbnailCache.cache.setObject(img, forKey: key)
                image = img
            } catch {
                // Ignore (including cancellation); the thumbnail just won't show.
            }
        }
    }
}
