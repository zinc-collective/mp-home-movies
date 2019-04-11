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
    
    var fullVideoURL: URL?
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
        
        playButton.isHidden = true
        self.navigationItem.rightBarButtonItems = []
        
        playerLayer = AVPlayerLayer(player: player)
        playerContainer.layer.insertSublayer(playerLayer, at: 0)
        
        
        // generate movie when we load
        generateTitleAndMakeMovie()
    }
    
    @IBAction func sharePressed(){
        displayShareSheet()
    }
    
    @IBAction func playPressed(_ sender: AnyObject) {
        play()
    }
    
    func play() {
        
        guard let url = self.fullVideoURL else {
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        let localPlayer = AVPlayer(playerItem: playerItem)
        
        let vc = AVPlayerViewController()
        vc.player = localPlayer
        vc.showsPlaybackControls = true
        self.playerView = vc
        
        self.present(vc, animated: true, completion: {
            localPlayer.play()
        })
        
    }
    
    @objc func didFinishPlaying() {
        
    }
    

    func displayShareSheet(){
        if let videoURL = fullVideoURL {
            let shareText = "Made with #HomeMovies"
            let shareURL = URL(string: "https://itunes.apple.com/us/app/home-movies-video/id1075104413?mt=8")!
            let activityViewController = UIActivityViewController(activityItems: [videoURL, shareText, shareURL], applicationActivities: nil)
            self.present(activityViewController, animated: true, completion: {})
        }
    }
    
    @IBAction func viewTapped(_ sender: AnyObject) {
    }
    
    /// Generate Movie //////////////////////////////
    
    
    func generateTitleAndMakeMovie()
    {
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        
        do {
            try videoView.prepareTitleTrack(movieTitle)
        }
        catch let err as NSError {
            print("Title Error", err.localizedDescription)
        }
        
        //concatenate video.
        GlobalUserInitiatedQueue.async{
            self.videoView.doneDispGroup = DispatchGroup()
            self.videoView.doneDispGroup!.enter()
            var exportMessage: String?
            
            do {
                try self.videoView.finalizeOutput { exportedURL in
                    DispatchQueue.main.async{
                        self.activityIndicator.stopAnimating()
                        self.activityIndicator.isHidden = true
                        self.displayVideo(exportedURL)
                    }
                }
            }
                
            catch VideoExportError.compositionFailed(let error) {
                exportMessage = "Composition Failed: " + error.description
            }
                
            catch VideoExportError.couldNotCreateExporter() {
                exportMessage = "Could not create exporter"
            }
                
            catch VideoExportError.missingAssets(let url, let time) {
                exportMessage = "Track missing audio or video: \(url.absoluteString) \(time)"
            }
                
            catch VideoExportError.noClips() {
                exportMessage = "No video clips found"
            }
                
            catch let err as NSError {
                exportMessage = err.localizedDescription
            }
            
            if let msg = exportMessage {
                DispatchQueue.main.async {
                    self.showAlert("Video Error", msg: "Please contact support\n\n \(msg)", comp: {_ in })
                    
                    
                    
                }
            }
            
        }
    }
    
    func displayVideo(_ videoURL : URL) {
        self.fullVideoURL = videoURL
        let playerItem = AVPlayerItem(url: videoURL)
        player.replaceCurrentItem(with: playerItem)
        
        NotificationCenter.default
            .addObserver(self, selector: #selector(didFinishPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        navigationItem.rightBarButtonItems = [actionItem]
        playButton.isHidden = false
    }
    
    func showAlert(_ tit: String, msg: String, comp: @escaping ((UIAlertAction?) -> Void)){
        
        let alertCtrller = UIAlertController(title: tit, message: msg, preferredStyle: UIAlertController.Style.alert)
        alertCtrller.addAction( UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: comp ))
        self.present(alertCtrller, animated: true, completion: nil)
    
    }
    
}
