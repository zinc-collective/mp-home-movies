//
//  LaunchViewController.swift
//  Home Movies
//
//  Created by sudhir on 1/11/16.
//  Copyright © 2019 Zinc Collective LLC. All rights reserved.
//

import UIKit
import AVFoundation


class HomeViewController: UIViewController {

    @IBOutlet weak var launchButton: UIButton!
    @IBOutlet weak var videoButton: UIButton!
    @IBOutlet weak var launchImage: UIImageView!



    @IBAction func onLaunchButtonClick(_ sender: AnyObject) {

        let mainStoryboard = UIStoryboard(name: "Record", bundle: Bundle.main)

        let recordController:UIViewController = mainStoryboard.instantiateInitialViewController()!
        self.present(recordController, animated: true, completion: nil)
    }

    @IBAction func onVideoButton(_ sender: AnyObject) {
        UIApplication.shared.open (URL (string :  "http://www.momentpark.com/homemoviestutorial")!, options: [:], completionHandler: nil)
    }

    override func viewWillAppear(_ animated: Bool) {

        launchButton.layer.cornerRadius = 5
        launchButton.layer.borderWidth = 1
        videoButton.layer.borderWidth = 1
        videoButton.layer.cornerRadius=5
        self.view.layer.backgroundColor=UIColor.white.cgColor
    }
}
