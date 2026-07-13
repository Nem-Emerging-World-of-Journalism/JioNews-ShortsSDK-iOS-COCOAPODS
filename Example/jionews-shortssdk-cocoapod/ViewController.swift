//
//  ViewController.swift
//  jionews-shortssdk-cocoapod
//
//  Created by Saif on 02/06/2024.
//  Copyright (c) 2024 Saif. All rights reserved.
//

import UIKit
import jionews_shortssdk_cocoapod

class ViewController: UIViewController {

    @IBOutlet weak var shortsView: ShortsView!

    // Staging Authorization (JWT) token for the JioNews GraphQL endpoint.
    
    private var hid = "4388842af19d80e20860dbc76fd6e76ce204422092e19015940c02cf5186e14c"


    override func viewDidLoad() {
        super.viewDidLoad()
        shortsView
            .initData(hid: hid, redirectSource: "org.cocoapods.demo.jionews-shortssdk-cocoapod-Example", theme: ShortsView.THEME_LIGHT, debug: false, env: .stg)
        shortsView.setOnEventListener(self)
        shortsView.shortload()
        shortsView.loadShorts()
        
        NotificationCenter.default.addObserver(self,
                                                       selector: #selector(handleApplicationDidBecomeActive),
                                                       name: UIApplication.didBecomeActiveNotification,
                                                       object: nil)
    }
    
    @objc
    func handleApplicationDidBecomeActive() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.shortsView.isSetupCompleted else { return }
            if self.shortsView.isPlaying {
                self.shortsView.playVideo()   // was set to play → resume
            } else {
                self.shortsView.pauseVideo()  // was paused → keep paused
            }
        }
    }
}

extension ViewController: ShortsEventListener {

    func onShareClick(_ brief: ShortsVideoBrief) {
        print("Share tapped: \(brief.id ?? "")")
    }

    func onSwipe(_ brief: ShortsVideoBrief) {
        print("Swiped to: \(brief.title ?? "")")
    }
}
