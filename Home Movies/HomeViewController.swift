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
    
    
    
    @IBAction func onLaunchButtonClick(sender: AnyObject) {
        
        let mainStoryboard = UIStoryboard(name: "Record", bundle: NSBundle.mainBundle())
        
        let camCtrllr:UIViewController = mainStoryboard.instantiateViewControllerWithIdentifier("MainViewController") as UIViewController
        
        self.presentViewController(camCtrllr, animated: true, completion: nil)
  
    }

    @IBAction func onVideoButton(sender: AnyObject) {
        //bNSWorkspace.sharedWorkspace().openURL(NSURL(string: "http://www.google.com")!)
        UIApplication.sharedApplication().openURL(NSURL( string: "http://www.homemoviesapp.com/tour")!)
    }
    
    override func viewWillAppear(animated: Bool) {
  
        launchButton.layer.cornerRadius = 5
        launchButton.layer.borderWidth = 1
        videoButton.layer.borderWidth = 1
        videoButton.layer.cornerRadius=5
        self.view.layer.backgroundColor=UIColor.whiteColor().CGColor
    }
}