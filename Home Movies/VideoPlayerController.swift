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
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet var playItem: UIBarButtonItem!
    @IBOutlet var pauseItem: UIBarButtonItem!
    @IBOutlet var actionItem: UIBarButtonItem!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var videoView:VideoView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        isPlaying = false
        self.navigationItem.rightBarButtonItems = []
        playButton.hidden = true
        
        // generate movie when we load
        generateTitleAndMakeMovie()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        playerLayer.frame = playerView.bounds
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let title = movieTitle {
            self.title = title
            navigationItem.title = title
        }
        
        playerLayer = AVPlayerLayer(player: player)
        playerView.layer.insertSublayer(playerLayer, atIndex: 0)
        
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
        
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        
        if isFinished {
            isFinished = false
            player.seekToTime(kCMTimeZero)
        }
        
        isPlaying = true
        player.play()
        
        playButton.hidden = true
        navigationItem.rightBarButtonItems = [pauseItem, actionItem]
    }
    
    func pause() {
        isPlaying = false
        player.pause()
        playButton.hidden = false
        navigationItem.rightBarButtonItems = [playItem, actionItem]
    }
    
    func didFinishPlaying() {
        isFinished = true
        pause()
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    

    func displayShareSheet(){
        if let url = fullVideoURL {
            let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            self.presentViewController(activityViewController, animated: true, completion: {})
        }
    }
    
    @IBAction func viewTapped(sender: AnyObject) {
        let isHidden = self.navigationController?.navigationBarHidden
        self.navigationController?.setNavigationBarHidden(isHidden != true, animated: true)
    }
    
    /// Generate Movie //////////////////////////////
    
    
    func generateTitleAndMakeMovie()
    {
        activityIndicator.hidden = false
        activityIndicator.startAnimating()
        
        do {
            try videoView.prepareTitleTrack(movieTitle)
        }
        catch let err as NSError {
            print("Title Error", err.localizedDescription)
        }
        
        //concatenate video.
        dispatch_async(GlobalUserInitiatedQueue){
            self.videoView.doneDispGroup = dispatch_group_create()
            dispatch_group_enter(self.videoView.doneDispGroup!)
            var exportMessage: String?
            
            do {
                try self.videoView.finalizeOutput { exportedURL in
                    dispatch_async(dispatch_get_main_queue()){
                        self.activityIndicator.stopAnimating()
                        self.activityIndicator.hidden = true
                        self.playVideo(exportedURL)
                    }
                }
            }
                
            catch VideoExportError.CompositionFailed(let error) {
                exportMessage = "Composition Failed: " + error.description
            }
                
            catch VideoExportError.CouldNotCreateExporter() {
                exportMessage = "Could not create exporter"
            }
                
            catch VideoExportError.MissingAssets(let url, let time) {
                exportMessage = "Track missing audio or video: \(url.absoluteString) \(time)"
            }
                
            catch VideoExportError.NoClips() {
                exportMessage = "No video clips found"
            }
                
            catch let err as NSError {
                exportMessage = err.localizedDescription
            }
            
            if let msg = exportMessage {
                dispatch_async(dispatch_get_main_queue()) {
                    self.showAlert("Video Error", msg: "Please contact support\n\n \(msg)", comp: {_ in })
                    
                    
                    
                }
            }
            
        }
    }
    
    func playVideo(videoURL : NSURL) {
        self.fullVideoURL = videoURL
        let playerItem = AVPlayerItem(URL: videoURL)
        player.replaceCurrentItemWithPlayerItem(playerItem)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didFinishPlaying), name: AVPlayerItemDidPlayToEndTimeNotification, object: playerItem)
        
        navigationItem.rightBarButtonItems = [playItem, actionItem]
        playButton.hidden = false
    }
    
    func showAlert(tit: String, msg: String, comp: ((UIAlertAction!) -> Void)){
        
        let alertCtrller = UIAlertController(title: tit, message: msg, preferredStyle: UIAlertControllerStyle.Alert)
        alertCtrller.addAction( UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: comp ))
        self.presentViewController(alertCtrller, animated: true, completion: nil)
    
    }
    
}