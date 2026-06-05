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
    
    private var hid = "dc42fc9ac83f04260a505fa20e8654af3711e1d268e1511a46f745113ee082bc"


    override func viewDidLoad() {
        super.viewDidLoad()
        shortsView
            .initData(hid: hid, redirectSource: 0, theme: ShortsView.THEME_LIGHT, debug: false, env: .stg)
        shortsView.setOnEventListener(self)
        shortsView.shortload()
        shortsView.loadShorts()
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
