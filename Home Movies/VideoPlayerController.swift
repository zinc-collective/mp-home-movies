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
import AVFoundation


class VideoPlayerController : UIViewController {
    
    var fullVideoURL: NSURL?
    var movieTitle: String?
    
    var player = AVPlayer()
    var playerLayer : AVPlayerLayer!
    var isPlaying = false
    var isFinished = false
    
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var navigationBar: UINavigationBar!
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet var playItem: UIBarButtonItem!
    @IBOutlet var pauseItem: UIBarButtonItem!
    @IBOutlet var actionItem: UIBarButtonItem!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        isPlaying = false
        navigationBar.topItem?.rightBarButtonItems = [playItem, actionItem]
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        playerLayer.frame = playerView.bounds
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let title = movieTitle {
            self.title = title
            navigationBar.topItem?.title = title
        }
        
        playerLayer = AVPlayerLayer(player: player)
        playerView.layer.insertSublayer(playerLayer, atIndex: 0)
        
        if let url = fullVideoURL {
            let playerItem = AVPlayerItem(URL: url)
            player.replaceCurrentItemWithPlayerItem(playerItem)
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didFinishPlaying), name: AVPlayerItemDidPlayToEndTimeNotification, object: playerItem)
        }
        
        
    }
    
    @IBAction func sharePressed(){
        pause()
        displayShareSheet()
    }
    
    @IBAction func donePressed() {
        pause()
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func playPressed(sender: AnyObject) {
        play()
    }
    
    @IBAction func pausePressed(sender: AnyObject) {
        pause()
    }
    
    func play() {
        
        hideNavbar()
        
        if isFinished {
            isFinished = false
            player.seekToTime(kCMTimeZero)
        }
        
        isPlaying = true
        player.play()
        
        playButton.hidden = true
        navigationBar.topItem?.rightBarButtonItems = [pauseItem, actionItem]
    }
    
    func pause() {
        isPlaying = false
        player.pause()
        playButton.hidden = false
        navigationBar.topItem?.rightBarButtonItems = [playItem, actionItem]
    }
    
    func didFinishPlaying() {
        isFinished = true
        pause()
    }
    

    func displayShareSheet(){
        if let url = fullVideoURL {
            let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            self.presentViewController(activityViewController, animated: true, completion: {})
        }
    }
    
    @IBAction func viewTapped(sender: AnyObject) {
        print("TAPPED")
        
        if navigationBar.alpha == 1.0 {
            hideNavbar()
        }
        else {
            showNavbar()
        }
    }
    
    func showNavbar() {
        UIView.animateWithDuration(0.300, animations: {
            self.navigationBar.alpha = 1.0
        })
    }
    
    func hideNavbar() {
        UIView.animateWithDuration(0.300, animations: {
            self.navigationBar.alpha = 0.0
        })
    }
    
}