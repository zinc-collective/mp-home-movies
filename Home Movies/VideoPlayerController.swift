//
//  VideoPlayerController.swift
//  Home Movies
//
//  Created by Sean Hess on 3/2/16.
//  Copyright © 2016 HomeMoviesDev. All rights reserved.
//

import Foundation
import UIKit
import AVKit


class VideoPlayerController : AVPlayerViewController {
    
    var button: UIButton?
    var fullVideoURL: NSURL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        button   = UIButton(type:UIButtonType.Custom)
        let img = UIImage(named: "Upload-50r")
        button!.setImage(img, forState: UIControlState.Normal)
        
        button!.frame = CGRectMake(100, 100, 100, 50)
        
        // button.frame = CGRectMake(self.view.frame.size.width/2 - button.frame.size.width/2, self.view.frame.size.height/2 - button.frame.size.height/2, button.frame.size.width, button.frame.size.height)
        
        //button.backgroundColor = UIColor.greenColor()
        //button.setTitle("Button", forState: UIControlState.Normal)
        button!.addTarget(self, action: #selector(VideoPlayerController.buttonPressed(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        self.view.addSubview(button!)
        
        
    }
    
    override func viewDidLayoutSubviews() {
        let bounds = button!.superview!.bounds
        button!.center = CGPointMake(CGRectGetMaxX(bounds)-50, CGRectGetMidY(bounds))
    }
    
    func buttonPressed(sender: UIButton!){
        print("share pressed \(self.parentViewController)")
        //self.dismissViewControllerAnimated(true, completion: nil)
        displayShareSheet()
    }
    
    func displayShareSheet(){
        if let url = fullVideoURL {
            let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            self.presentViewController(activityViewController, animated: true, completion: {})
        }
    }
    
}