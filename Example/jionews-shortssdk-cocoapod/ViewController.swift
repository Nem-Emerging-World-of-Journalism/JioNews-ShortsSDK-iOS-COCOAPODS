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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        shortsView.configure(with: "U2FsdGVkX18BPThCMH6XBQXr1IEiKKufHmYFoflb9UnylpcCW4CNfoy7IGmhL7hD")
        //shortsView.openShortsByBriefId(briefId: "65c1d56dbe473f0b88adebef")
        shortsView.delegate = self
    }

}

extension ViewController: ShortsViewDelegate {
    
    func didTapOnShareButton(_ brief: ShortsVideoBrief) {
        print("Tapped on share button for \(brief.title ?? "")")
    }
    
}
