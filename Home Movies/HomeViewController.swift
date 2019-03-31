//
//  LaunchViewController.swift
//  Home Movies
//
//  Created by sudhir on 1/11/16.
//  Copyright © 2016 HomeMoviesDev. All rights reserved.
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
        UIApplication.shared.openURL(URL( string: "http://www.momentpark.com/homemoviestutorial")!)
    }
    
    override func viewWillAppear(_ animated: Bool) {
  
        launchButton.layer.cornerRadius = 5
        launchButton.layer.borderWidth = 1
        videoButton.layer.borderWidth = 1
        videoButton.layer.cornerRadius=5
        self.view.layer.backgroundColor=UIColor.white.cgColor
    }
}
