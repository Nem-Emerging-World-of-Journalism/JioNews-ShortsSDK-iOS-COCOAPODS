//
//  ShortsView.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 11/01/24.
//

import UIKit
import WebKit

public protocol ShortsViewDelegate: AnyObject {
    func didTapOnShareButton(_ brief: ShortsVideoBrief)
}

public class ShortsView: UIView {
    
    private lazy var shimmerView: ShortsShimmerView = {
        let view = ShortsShimmerView(frame: .zero, theme: self.theme)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var webView: WKWebView
    private var hid: String?
    private var briefId: String?
    private var client: JioShortsClient = .myJio
    private var theme: JioShortsTheme = .dark
    private var shortsModel: JioShortsModel!
    private var webURL = "https://stgjionews.pie.news/short_video"
    private var currentBrief: ShortsVideoBrief?
    private var isMuted: Bool = false
    public weak var delegate: ShortsViewDelegate?
    
    override public init(frame: CGRect) {
        self.webView = WKWebView()
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        self.webView = WKWebView()
        super.init(coder: coder)
    }
    
    /***
     This function call is mandatory to initiate data for shorts feature
     Call this mehod on VIewDidLoad as it sets up WKWebView instance with cookies
     - Parameters
     - hid: Required, for the use of shorts view
     - briefId: Optional, Shorts item id
     - redirectSource: Required JioShortsClient enum value. Default value .myJio
     - theme: Required JioShortsTheme enum value dark or light based on app theme. Default value .dark
     */
    public func configure(
        with hid: String,
        briefId: String? = nil,
        redirectSource: JioShortsClient = .myJio,
        theme: JioShortsTheme = .dark
    ) {
        self.hid = hid
        self.briefId = briefId
        self.client = redirectSource
        self.theme = theme
        checkInitialisation()
        setupBaseView()
    }
    
    /***
     This function call is for initiate data with briefId for shorts feature
     Call this mehod only if  you already called "configure()" method once
     - Parameters
     - hid: Optional, for the use of shorts view
     - briefId: Required, Shorts item id
     - redirectSource: Required JioShortsClient enum value. Default value .myJio
     - theme: Required JioShortsTheme enum value dark or light based on app theme. Default value .dark
     */
    public func openShortsByBriefId(
        hid: String? = nil,
        redirectSource: JioShortsClient = .myJio,
        briefId: String,
        theme: JioShortsTheme = .dark
    ) {
        self.briefId = briefId
        self.client = redirectSource
        self.theme = theme
        if let hid = hid {
            self.hid = hid
        } else if let hid = UserDefaults.hid {
            self.hid = hid
        }
        setupBaseView()
    }
    
}

// MARK: - Helper Methods

extension ShortsView {
    
    private func setupBaseView() {
        checkInitialisation()
        
        guard let hid = hid else {
            fatalError(SDKInitializationError.hidEmpty.message)
        }
        
        shortsModel = JioShortsModel(
            theme: theme,
            localisation: JioShortsLocalisation(endFeedMessage: "", exploreVideoTitle: ""),
            analyticsValue: JioShortsAnalyticsValue(theme: theme)
        )
        
        UserDefaults.hid = hid
        
        if let isShortsMuted = UserDefaults.isShortsMuted {
            isMuted = isShortsMuted
        } else {
            UserDefaults.isShortsMuted = false
            isMuted = false
        }
        self.backgroundColor = (theme == .dark) ? .black : .white
        webURL = "\(webURL)?hid=\(hid)&id=\(briefId ?? "")"
        setupWebView()
        setupShimmerView()
        addObservers()
    }
    
    private func checkInitialisation() {
        if hid == nil || (hid?.isEmpty ?? false) {
            fatalError(SDKInitializationError.hidEmpty.message)
        }
        
        let clientPackageName = Bundle.main.bundleIdentifier
        if !(clientPackageName == "com.jio.myjio" || clientPackageName == "com.jio.shorts" || clientPackageName == "com.jio.media.jioxpressnews" || clientPackageName == "org.cocoapods.demo.jionews-shortssdk-cocoapod-Example") {
            fatalError(SDKInitializationError.invalidClient.message)
        }
    }
    
    private func setupView() {
        webView.backgroundColor = (self.theme == .dark) ? .black : .white
        insertSubview(webView, at: 0)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let source = """
            window.addEventListener('message', function(e) {
                if(e.origin==="https://devjionews.pie.news" ||e.origin==="https://stgjionews.pie.news" || e.origin==="https://jionews.pie.news") {
                    window.webkit.messageHandlers.shortsEventListner.postMessage(e.data);
                }
            });
        """
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        config.userContentController.add(self, name: "shortsEventListner")
        
        config.set(cookies: createCookies()) { [weak self] in
            guard let self = self else { return }
            // add webview
            let wv = WKWebView(frame: self.frame, configuration: config)
            wv.scrollView.contentInsetAdjustmentBehavior = .never
            wv.backgroundColor = (self.theme == .dark) ? .black : .white
            self.webView = wv
            self.webView.navigationDelegate = self
            self.setupView()
            
            // load webview
            self.loadWebView()
        }
    }
    
    private func setupShimmerView() {
        addSubview(shimmerView)
        
        NSLayoutConstraint.activate([
            shimmerView.topAnchor.constraint(equalTo: self.topAnchor),
            shimmerView.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor),
            shimmerView.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor),
            shimmerView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor),
        ])
        
        startShimmerView()
    }
    
    private func startShimmerView() {
        shimmerView.startShimmer()
        shimmerView.isHidden = false
    }
    
    private func stopShimmerView() {
        shimmerView.stopShimmer()
        shimmerView.isHidden = true
    }
    
    // Create cookies for webview
    private func createCookies() -> [HTTPCookie] {
        guard let finalURL = URL(string: webURL) else {
            return []
        }
        
        return shortsModel.asParameters().compactMap { name, value in
            HTTPCookie(properties: [
                .domain: finalURL.host ?? "",
                .path: "/",
                .name: name,
                .value: value,
                .secure: "TRUE"
            ])
        }
    }
    
    // load web view
    private func loadWebView() {
        if let finalURL = URL(string: webURL) {
            var request = URLRequest(url: finalURL)
            request.timeoutInterval = 30
            webView.loadWithCookies(request: request)
        }
    }
    
    private func manageEvent(_ data: [String: Any]) {
        guard let eventName = data["eventName"] as? String,
              let eventData = data["eventData"] as? [String: Any] else {
            return
        }
        //print("Event: \(eventName)")
        
        if eventName == "SWIPE",
           let currentBrief = eventData["currentlyPlaying"] as? [String: Any] {
            setBrief(from: currentBrief)
        }
        
        if let currentBrief = eventData["video"] as? [String: Any] {
            setBrief(from: currentBrief)
        }
        
        switch eventName {
        case "FEED_LOAD":
            stopShimmerView()
            break
        case "PLAY_CLICK": break
        case "PAUSE_CLICK": break
        case "MUTE_CLICK":
            isMuted = true
            UserDefaults.isShortsMuted = true
            break
        case "UNMUTE_CLICK":
            isMuted = false
            UserDefaults.isShortsMuted = false
            break
        case "SHARE_CLICK":
            if let brief = currentVideoBrief {
                delegate?.didTapOnShareButton(brief)
            }
            break
        case "SWIPE": break
        case "SWIPE_UP": break
        case "SWIPE_DOWN": break
        case "LIKE_CLICK": break
        case "RESET_LIKE_CLICK": break
        case "PLAYER_READY":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.manageMuteState()
            }
            break
        case "VIDEO_STARTED": break
        case "VIDEO_STOPPED": break
        case "VIDEO_PAUSED": break
        case "EXPLORE_VIDEOS_CLICK": break
        case "FEED_ERROR": break
        case "EMPTY_FEED": break
        case "INITIALIZATION_ERROR": break
        case "SEARCH_PAGE_LOADED": break
        default: break
        }
    }
    
    private func setBrief(from data: [String: Any]) {
        do {
            let brief = try JSONSerialization.data(withJSONObject: data)
            guard let video = try? JSONDecoder().decode(ShortsVideoBrief.self, from: brief) else {
                return
            }
            self.currentBrief = video
        } catch let e {
            print("Error: \(String(describing: e))")
        }
    }
    
    private func manageMuteState() {
        if isMuted {
            muteVideo()
        } else {
            unmuteVideo()
        }
    }
    
    internal func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appResignActive), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
    }
    
    internal func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
    }
    
    @objc internal func appBecomeActive() {
        startVideo()
    }
    
    @objc internal func appResignActive() {
        
    }
    
    /**
     Call this method to clean up WKWebView configurations and release memory
     */
    public func cleanup() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "shortsEventListner")
        webView.configuration.userContentController.removeAllUserScripts()
        removeObservers()
    }
    
    /**
     Get current video URL if any
     */
    public var currentVideoURL: String? {
        return currentBrief?.video?.url
    }
    
    /**
     Get current video model if any
     */
    public var currentVideoBrief: ShortsVideoBrief? {
        return currentBrief
    }
    
    // MARK: - Player Events
    
    /**
     Call this method if you want to start video
     */
    public func startVideo() {
        checkInitialisation()
        webView.evaluateJavaScript("activeVideoPlayer.start()")
    }
    
    /**
     Call this method if you want to play video
     - Parameter isMute: Required, Boolean value to make shorts either mute or unmute. Default value false
     */
    public func playVideo(isMute: Bool = false) {
        checkInitialisation()
        if isMute {
            webView.evaluateJavaScript("activeVideoPlayer.play();activeVideoPlayer.mute()")
        } else {
            webView.evaluateJavaScript("activeVideoPlayer.play();activeVideoPlayer.unmute()")
        }
    }
    
    /**
     Call this method if you want to stop video
     */
    public func stopVideo() {
        checkInitialisation()
        webView.evaluateJavaScript("activeVideoPlayer.stop()")
    }
    
    /**
     Call this method if you want to pause video
     */
    public func pauseVideo() {
        checkInitialisation()
        webView.evaluateJavaScript("activeVideoPlayer.pause()")
    }
    
    /**
     Call this method if you want to mute video
     */
    public func muteVideo() {
        checkInitialisation()
        webView.evaluateJavaScript("activeVideoPlayer.mute()")
    }
    
    /**
     Call this method if you want to unmute video
     */
    public func unmuteVideo() {
        checkInitialisation()
        webView.evaluateJavaScript("activeVideoPlayer.unmute()")
    }
    
    /**
     Call this method if you want to enable/disable playback
     - Parameter isDisable: Required, Boolean value to make playback enable or disable. Default value false
     */
    public func setPlaybackDisable(_ isDisable: Bool = false) {
        checkInitialisation()
        webView.evaluateJavaScript("activeVideoPlayer.disablePlayback(\(isDisable))")
    }
    
}

extension ShortsView: WKNavigationDelegate, WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !message.name.isEmpty else { return }
        if message.name == "shortsEventListner" {
            if let body = message.body as? String,
               let data = body.data(using: .utf8) {
                do {
                    guard let jsonData = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        return
                    }
                    manageEvent(jsonData)
                } catch let e {
                    print("Error: \(String(describing: e))")
                }
            }
        }
    }
    
}
