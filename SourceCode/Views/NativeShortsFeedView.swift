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
import UIKit

private extension Color {
    /// Creates a color from a 24-bit RGB hex value, e.g. `Color(hex: 0x141414)`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

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
            controller.log("API: getNativeShorts page 1 (size=\(pageSize))…")
            let result = try await GraphQLService.shared.fetchNativeShortsDecoded(token: token, page: 1, size: pageSize)
            currentPage = 1
            totalPages = result.cursor?.totalPages
            let raw = result.newsBriefs ?? []
            var loaded = raw.filter { $0.videoURL != nil }

            // Deep-link: if a specific brief was requested, fetch it and pin it to the top (index 0).
            if let briefId = controller.initialBriefId, !briefId.isEmpty,
               let pinned = try? await GraphQLService.shared.fetchNewsBriefById(token: token, newsBriefId: briefId, contentType: Constants.contentType),
               pinned.videoURL != nil {
                loaded.removeAll { $0.id == pinned.id }   // avoid a duplicate if it's also in page 1
                loaded.insert(pinned, at: 0)
                controller.log("Deep-link: pinned brief \(pinned.id) at top")
            }
            items = loaded
            controller.log("API: getNativeShorts ✓ \(items.count) playable / \(raw.count) returned (totalPages=\(totalPages ?? -1))")

            if items.isEmpty {
                errorMessage = raw.isEmpty
                    ? "No videos returned. (Check Authorization token.)"
                    : "Returned \(raw.count) item(s), but none had a usable video URL."
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            controller.log("API: ❌ getNativeShorts page 1 failed — \(error)")
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
            controller.log("Pagination: fetching page \(nextPage)…")
            let result = try await GraphQLService.shared.fetchNativeShortsDecoded(token: token, page: nextPage, size: pageSize)
            let raw = result.newsBriefs ?? []
            let newItems = raw.filter { $0.videoURL != nil }
            currentPage = nextPage
            totalPages = result.cursor?.totalPages ?? totalPages
            let existing = Set(items.map(\.id))
            let appended = newItems.filter { !existing.contains($0.id) }
            items.append(contentsOf: appended)
            controller.log("Pagination: page \(nextPage) +\(appended.count) (total=\(items.count))")
        } catch {
            controller.log("Pagination: ❌ page \(nextPage) failed — \(error)")
        }
    }
}

struct NativeShortsFeedView: View {
    @ObservedObject var controller: ShortsController
    @StateObject private var vm: NativeShortsViewModel

    init(controller: ShortsController) {
        self.controller = controller
        _vm = StateObject(wrappedValue: NativeShortsViewModel(controller: controller))
    }

    private var backgroundColor: Color {
        controller.theme == .dark ? .black : .white
    }

    private var errorBackgroundColor: Color {
        controller.theme == .dark ? Color(hex: 0x141414) : Color(hex: 0xF4F4F4)
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            if vm.isLoading && vm.items.isEmpty {
                ProgressView().tint(.white).scaleEffect(1.2)
            } else if vm.errorMessage != nil, vm.items.isEmpty {
                errorView()
            } else {
                feed
            }
        }
        .task {
            if vm.items.isEmpty { await vm.loadFirstPage() }
        }
    }

    private func errorView() -> some View {
        VStack(spacing: 28) {
            Text("Something went wrong!\nCheck back later for more shorts.")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: 0x8E8E8E))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button {
                Task { await vm.loadFirstPage() }
            } label: {
                Text("Retry")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .background(Color(hex: 0xC2002F), in: Capsule())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(errorBackgroundColor.ignoresSafeArea())
    }

    private var feed: some View {
        VerticalFeedPager(items: vm.items, controller: controller) { index, swipe in
            handlePageChange(to: index, swipe: swipe)
        }
        .ignoresSafeArea()
        .onDisappear { controller.recordFeedExit() }
    }

    /// Called when the pager settles on a page (and once for the initial page).
    private func handlePageChange(to index: Int, swipe: String) {
        guard vm.items.indices.contains(index) else { return }
        let item = vm.items[index]
        controller.recordCurrentBrief(item, swipe: swipe)   // updates currentBrief, fires shorts_view + onSwipe
        prefetchUpcomingThumbnails(after: item.id)
        Task { await vm.loadMoreIfNeeded(currentIndex: index) }
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

    @State private var hasStartedPlaying: Bool = false
    @State private var progress: Double = 0

    private var isCurrent: Bool { controller.currentBrief?.id == item.id }

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
                        controller.log("Playback: started \(item.id)")
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
        .onChange(of: isCurrent) { nowCurrent in
            if !nowCurrent {
                hasStartedPlaying = false
                progress = 0
            }
        }
    }
}

// MARK: - Vertical pager (UIPageViewController — works on iOS 15+)

/// Full-screen vertical pager backing the shorts feed. Uses `UIPageViewController`
/// so it runs on iOS 15.1 (the iOS 17 `ScrollView` paging APIs are avoided).
struct VerticalFeedPager: UIViewControllerRepresentable {
    let items: [STBNewsBrief]
    let controller: ShortsController
    /// Fires when the visible page settles (and once for the initial page). `swipe` is next/previous/NA.
    let onPageChanged: (_ index: Int, _ swipe: String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .vertical)
        pager.dataSource = context.coordinator
        pager.delegate = context.coordinator
        pager.view.backgroundColor = .black
        context.coordinator.installInitialPageIfNeeded(pager)
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        // Handles items arriving after the first render (no-op once installed).
        context.coordinator.installInitialPageIfNeeded(pager)
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: VerticalFeedPager
        private var currentIndex = 0
        private var didInstallInitial = false
        /// Hosting controllers by brief id, pruned to a small window around the current page.
        private var pages: [String: UIViewController] = [:]

        init(_ parent: VerticalFeedPager) { self.parent = parent }

        private func page(at index: Int) -> UIViewController? {
            guard parent.items.indices.contains(index) else { return nil }
            let item = parent.items[index]
            if let cached = pages[item.id] { return cached }
            let host = UIHostingController(rootView: NativeShortCardView(item: item, controller: parent.controller))
            host.view.backgroundColor = .clear
            pages[item.id] = host
            return host
        }

        private func index(of vc: UIViewController) -> Int? {
            guard let id = pages.first(where: { $0.value === vc })?.key else { return nil }
            return parent.items.firstIndex { $0.id == id }
        }

        /// Drops cached pages far from the current one to bound memory.
        private func prunePages() {
            let lower = max(0, currentIndex - 2)
            let upper = currentIndex + 2
            let keep = Set((lower...upper).compactMap { idx -> String? in
                parent.items.indices.contains(idx) ? parent.items[idx].id : nil
            })
            pages = pages.filter { keep.contains($0.key) }
        }

        func installInitialPageIfNeeded(_ pager: UIPageViewController) {
            guard !didInstallInitial, let first = page(at: 0) else { return }
            didInstallInitial = true
            currentIndex = 0
            pager.setViewControllers([first], direction: .forward, animated: false)
            // Deferred: this runs during a SwiftUI view-update pass, and onPageChanged
            // mutates @Published state — doing it synchronously triggers "Publishing
            // changes from within view updates".
            DispatchQueue.main.async { [weak self] in
                self?.parent.onPageChanged(0, "NA")
            }
        }

        // MARK: DataSource
        func pageViewController(_ pvc: UIPageViewController, viewControllerBefore vc: UIViewController) -> UIViewController? {
            guard let idx = index(of: vc) else { return nil }
            return page(at: idx - 1)
        }

        func pageViewController(_ pvc: UIPageViewController, viewControllerAfter vc: UIViewController) -> UIViewController? {
            guard let idx = index(of: vc) else { return nil }
            return page(at: idx + 1)
        }

        // MARK: Delegate
        func pageViewController(_ pvc: UIPageViewController,
                                didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController],
                                transitionCompleted completed: Bool) {
            guard completed,
                  let visible = pvc.viewControllers?.first,
                  let idx = index(of: visible) else { return }
            let swipe = idx > currentIndex ? "next" : (idx < currentIndex ? "previous" : "NA")
            currentIndex = idx
            prunePages()
            parent.onPageChanged(idx, swipe)
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
                Image(shorts: state.isLiked ? "ic_like_selected_border" : "ic_like_white")
                    .renderingMode(state.isLiked ? .original : .template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 23, height: 23)
                    .foregroundStyle(.white)   // applies only to the unliked (template) icon
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
