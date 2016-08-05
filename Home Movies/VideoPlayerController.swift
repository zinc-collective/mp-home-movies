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
    var playerView : AVPlayerViewController?
    
    
    @IBOutlet weak var playerContainer: UIView!
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet var actionItem: UIBarButtonItem!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var videoView:VideoView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        playerLayer.frame = playerContainer.bounds
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let title = movieTitle {
            self.title = title
            navigationItem.title = title
        }
        
        playButton.hidden = true
        self.navigationItem.rightBarButtonItems = []
        
        playerLayer = AVPlayerLayer(player: player)
        playerContainer.layer.insertSublayer(playerLayer, atIndex: 0)
        
        
        // generate movie when we load
        generateTitleAndMakeMovie()
    }
    
    @IBAction func sharePressed(){
        displayShareSheet()
    }
    
    @IBAction func playPressed(sender: AnyObject) {
        play()
    }
    
    func play() {
        
        guard let url = self.fullVideoURL else {
            return
        }
        
        let playerItem = AVPlayerItem(URL: url)
        let localPlayer = AVPlayer(playerItem: playerItem)
        
        let vc = AVPlayerViewController()
        vc.player = localPlayer
        vc.showsPlaybackControls = true
        self.playerView = vc
        
        self.presentViewController(vc, animated: true, completion: {
            localPlayer.play()
        })
        
    }
    
    func didFinishPlaying() {
        
    }
    

    func displayShareSheet(){
        if let videoURL = fullVideoURL {
            let shareText = "Made with #HomeMovies"
            let shareURL = NSURL(string: "https://itunes.apple.com/us/app/home-movies-video/id1075104413?mt=8")!
            let activityViewController = UIActivityViewController(activityItems: [videoURL, shareText, shareURL], applicationActivities: nil)
            self.presentViewController(activityViewController, animated: true, completion: {})
        }
    }
    
    @IBAction func viewTapped(sender: AnyObject) {
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
                        self.displayVideo(exportedURL)
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
    
    func displayVideo(videoURL : NSURL) {
        self.fullVideoURL = videoURL
        let playerItem = AVPlayerItem(URL: videoURL)
        player.replaceCurrentItemWithPlayerItem(playerItem)
        
        NSNotificationCenter.defaultCenter()
            .addObserver(self, selector: #selector(didFinishPlaying), name: AVPlayerItemDidPlayToEndTimeNotification, object: playerItem)
        
        navigationItem.rightBarButtonItems = [actionItem]
        playButton.hidden = false
    }
    
    func showAlert(tit: String, msg: String, comp: ((UIAlertAction!) -> Void)){
        
        let alertCtrller = UIAlertController(title: tit, message: msg, preferredStyle: UIAlertControllerStyle.Alert)
        alertCtrller.addAction( UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: comp ))
        self.presentViewController(alertCtrller, animated: true, completion: nil)
    
    }
    
}