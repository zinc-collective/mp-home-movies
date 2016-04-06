//
//  ViewController.swift
//  Home Movies
//
//  Created by sudhir on 9/2/15.
//  Copyright (c) 2015 HomeMoviesDev. All rights reserved.
//

import UIKit
import AVFoundation

// what are my unique possible states
// Ready | Recording | Working

class RecordViewController: UIViewController, VideoViewDelegate, UITextFieldDelegate {

    var loadingFromBg: Bool = false
    
    var videoSession = VideoSessionManager.defaultManager
    var isRecording = false
    
    @IBOutlet weak var clipsButton: UIButton!
    @IBOutlet weak var recordButton: RecordButtonView!
    
    @IBOutlet weak var timerLabel: RecordTimer!
    @IBOutlet weak var recordLight: RecordLight!
    
    var videoView: VideoView!
    @IBOutlet weak var videoContainer: UIView!
    @IBOutlet weak var orientationIcon: UIImageView!
    
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var cameraSwitchButton: UIButton!
    
    @IBOutlet weak var deleteButton: UIButton!
    
    @IBOutlet weak var startOverButton: OutlineButton!
    var alertController : UIAlertController?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    @IBAction func recordPressed(sender: AnyObject) {
        toggleRecord()
    }
    
    @IBAction func donePressed(sender: AnyObject) {
        print("done pressed")
        showAlertWithCancel("Are You Sure You Want To Make Your Movie?", msg: "", comp: {
            (alert: UIAlertAction!) in self.showAlertForTitle("Do You Want To Add A Title?",msg: "",comp: { (alert: UIAlertAction!) in
                self.generateTitleAndMakeMovie(self.videoView.movieTitle!)
            })
        })
    }
    
    @IBAction func deletePressed() {
        print("Delete last clip")
        videoSession.deleteLastClip()
        renderControls()
    }
    
    @IBAction func startOverPressed() {
        print("START OVER")
        do {
            try videoSession.cleanupSessionDir()
        }
        catch let err as NSError {
            print("Error", err.localizedDescription)
        }
        renderControls()
    }
    
    func generateTitleAndMakeMovie(title: String)
    {
        showHideActivityIndicator(true)
        
        if title != "" {
            // TODO move this into VideoSessionManager?
            videoView.titleGenerated=false
            let dir = videoView.videoSession.sessionFileDir()
            videoView.titleFilePath = NSURL(fileURLWithPath: dir).URLByAppendingPathComponent(TitleTrackName + ".mp4")
            self.videoView.titDispGrp = dispatch_group_create()
            dispatch_group_enter(videoView.titDispGrp!)
            print(title.endIndex)
            self.videoView.createAnimatedTitleVideo(title, animGrp: videoView.getFadeTransformAnimGrp)
            dispatch_group_wait(videoView.titDispGrp!, DISPATCH_TIME_FOREVER)
        }
        //concatenate video.
        dispatch_async(GlobalUserInitiatedQueue){
            self.videoView.doneDispGroup = dispatch_group_create()
            dispatch_group_enter(self.videoView.doneDispGroup!)
            var exportedURL : NSURL?
            var exportMessage: String?
            do {
                exportedURL = try self.videoView.finalizeOutput()
            }
                
            catch VideoExportError.CompositionFailed(let error) {
                exportMessage = error.localizedDescription
            }
                
            catch VideoExportError.CouldNotCreateExporter() {
                exportMessage = "Could not create exporter"
            }
                
            catch VideoExportError.MissingAudio(let url, let time) {
                exportMessage = "Track missing audio: \(url.absoluteString) \(time)"
            }
                
            catch let err as NSError {
                exportMessage = err.localizedDescription
            }
            
            if let msg = exportMessage {
                dispatch_async(dispatch_get_main_queue()) {
                    self.showAlert("Video Error", msg: "Please contact support\n\n \(msg)", comp: {_ in })
                }
            }
            
            dispatch_group_wait(self.videoView.doneDispGroup!, DISPATCH_TIME_FOREVER)
            dispatch_async(GlobalMainQueue){
                self.showHideActivityIndicator(false)
                if let url = exportedURL {
                    self.playVideo(url)
                }
            }
        }
    }
    
    func playVideo(videoURL : NSURL) {
        let player = AVPlayer(URL: videoURL)
        let playerController = VideoPlayerController()
        playerController.fullVideoURL = videoURL
        playerController.player = player
        self.presentViewController(playerController, animated: true, completion:{})
        
    }
    
    func renderControls() {
        
        let isPortrait = isDevicePortrait()
        let isWorking = activityIndicator.hidden == false
        let numClips = videoSession.getClipsCount()
        let hasClips = (numClips > 0)
        
        let toAlpha = { (hidden: Bool) -> CGFloat in
            if hidden {
                return 0.0
            }
            else {
                return 1.0
            }
        }
        
        UIView.animateWithDuration(0.200, animations: {
            
            self.doneButton.alpha      = toAlpha(isPortrait || self.isRecording || !hasClips)
            self.startOverButton.alpha = toAlpha(isPortrait || self.isRecording || !hasClips)
            self.deleteButton.alpha    = toAlpha(isPortrait || self.isRecording || !hasClips)
            self.clipsButton.alpha     = toAlpha(isPortrait || !hasClips)
            self.recordButton.alpha    = toAlpha(isWorking || isPortrait)
        })
        
        self.clipsButton.setTitle("\(numClips)", forState: .Normal)
        
        recordButton.recording = isRecording
        
        recordLight.hidden = !isRecording
        cameraSwitchButton.hidden = isPortrait || isRecording
    }
    
    //used by video mgr
    func isSharing() -> Bool
    {
        return doneButton.titleLabel!.text == "Share"
    }
    
    func toggleRecord()
    {
        isRecording = !isRecording
        
        if isRecording
        {
            videoView.startRecording()
            timerLabel.startTimer()
        }
        else
        {
            videoView.stopRecording()
            timerLabel.stopTimer()
        }
        
        renderControls()
    }
    
    func showHideActivityIndicator(show: Bool){
        if show {
            activityIndicator.hidden = false
            activityIndicator.center = self.view.center
            activityIndicator.startAnimating()
        }
        else{
            self.activityIndicator.stopAnimating()
            activityIndicator.hidden=true
        }
        renderControls()
    }
    
    override func viewWillAppear(animated: Bool) {
        activityIndicator.hidden=true
        renderControls()

        print("view will appear")
        
        videoView?.orientation = UIApplication.sharedApplication().statusBarOrientation
        
        UIDevice.currentDevice().beginGeneratingDeviceOrientationNotifications()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(RecordViewController.orientationDidChange), name:UIDeviceOrientationDidChangeNotification, object: nil)
    }
    
    override func viewDidDisappear(animated: Bool) {
        print("view disappear")
        UIDevice.currentDevice().endGeneratingDeviceOrientationNotifications()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addVideoView()
        clipsButton.contentHorizontalAlignment = .Center
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(RecordViewController.applicationDidBecomeActive), name: UIApplicationDidBecomeActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(RecordViewController.applicationDidEnterBackground), name: UIApplicationDidEnterBackgroundNotification, object: nil)
         NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(RecordViewController.applicationWillEnterBackground), name: UIApplicationWillResignActiveNotification, object: nil)
        
        //doneButton.hidden = videoView.canFinalize()
        print("view did load")
    }
    
    func addVideoView(device:AVCaptureDevice?) {
        videoView = VideoView(frame: videoContainer.bounds, device: device)
        videoContainer.addSubview(videoView)
        videoView.delegate = self
    }
    
    func addVideoView() {
        addVideoView(nil)
    }
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    
    func applicationDidBecomeActive()
    {
        print("view - app became active")
        if loadingFromBg {
            loadingFromBg = false
            //if we were recording previously and got interrupted, update the view state...
            print("explicitly calling view will appear...")
            viewWillAppear(true)
            
            do
            {
                try self.videoView.startSession(true)
            }
            catch let error as NSError {
                print(error.description)
            }
        }
    }
    
    func applicationWillEnterBackground()
    {
        print("view - app will enter background")
        timerLabel.stopTimer()
        dispatch_async(GlobalUtilityQueue){
            self.videoView.stopRecording()
            self.videoView.stopSession()
        }
    }
    
    func applicationDidEnterBackground()
    {
        print("view - app entered background")
        loadingFromBg = true
        //
        
        //exit(0)
        
        
        
    }
    
    func showAlert(tit: String, msg: String, comp: ((UIAlertAction!) -> Void)){
        
        let alertCtrller = UIAlertController(title: tit, message: msg, preferredStyle: UIAlertControllerStyle.Alert)
        alertCtrller.addAction( UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: comp ))
        self.presentViewController(alertCtrller, animated: true, completion: nil)
    
    }
    
    func showAlertWithCancel(tit: String, msg: String, comp: ((UIAlertAction!) -> Void)){
        
        let alertCtrller = UIAlertController(title: tit, message: msg, preferredStyle: UIAlertControllerStyle.Alert)
        alertCtrller.addAction( UIAlertAction(title: "Yes", style: UIAlertActionStyle.Default, handler: comp ))
        alertCtrller.addAction( UIAlertAction(title: "No", style: UIAlertActionStyle.Default, handler: {(alert:UIAlertAction!) in } ))
        self.presentViewController(alertCtrller, animated: true, completion: nil)
        
    }
    
    
    
    
    
        
    override func viewDidAppear(animated: Bool) {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        if(appDelegate.freeSpaceMb <= 50)
        {
            showAlert("Warning!",msg: "You have less than 50 MB storage left! Please free up some space and try again!", comp: {(alert: UIAlertAction!) in exit(0)
            })
        }
        //check for devices TODO negate check below
        if !videoView.devicesPresent {
            showAlert("Error", msg: "Camera/Microphone not found!", comp: {(alert: UIAlertAction!) in exit(0)})
        }
            
        if !videoView.checkAllAuthorizations() {
            showAlert("Error", msg: "Camera/Microphone/Photos Usage Not Authorized!!! \n\nPlease Update App Settings And Try Again.", comp: {(alert: UIAlertAction!) in exit(0)})
        }
        else {
            do {
                try videoView.startSession(true)
            }
            catch let error as NSError {
                print(error.description)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        //
    }

    override func viewWillDisappear(animated: Bool) {
        print("view will disappesar")
    }
    
    
    
    /*func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!){
        videoView.recording=false
        if(error != nil)
        {
            let alert=UIAlertView()
            alert.title="Error!"
            alert.message=error.description
            alert.show()
        }
        else {
            print("done recording -> \(outputFileURL)")
        }
        
        dispatch_group_leave(videoView.recDispGrp!)
        
    }
    
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        videoView.recording=true
        print("started recording to -> \(fileURL)" )
    }*/
    
        
    
    
    
    func showAlertForTitle(tit: String, msg: String, comp: ((UIAlertAction!) -> Void)){
        
        self.videoView.movieTitle=""
        let alertCtrller = UIAlertController(title: tit, message: msg, preferredStyle: UIAlertControllerStyle.Alert)
        let okButton = UIAlertAction(title: "Add Title", style: UIAlertActionStyle.Default, handler: comp )
        alertCtrller.addAction(okButton)
        alertCtrller.addAction( UIAlertAction(title: "No Title", style: UIAlertActionStyle.Default, handler: {
            (alert: UIAlertAction!) in
            self.videoView.movieTitle=""
            comp(okButton)
        } ))
        alertCtrller.addTextFieldWithConfigurationHandler {(textField) in
            textField.delegate = self
            textField.placeholder = "Title"
        }
        
        // save for later
        self.alertController = alertCtrller
        self.presentViewController(alertCtrller, animated: true, completion: nil)
        
        
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        var str : NSString = ""
        if let old = textField.text {
            str = old as NSString
        }
        
        let newString = str.stringByReplacingCharactersInRange(range, withString: string)
        
        if (newString.characters.count > 40) {
            self.alertController?.message = "Title too long. Maximum 40 characters."
            return false
        }
        else {
            self.alertController?.message = ""
        }
        
        return true
    }
    
    
    func videoError(error: NSError) {
        if let msg = error.localizedRecoverySuggestion {
            self.showAlert("Error!", msg: msg, comp: {(alert: UIAlertAction!) in exit(0)})
        }
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        let orientation = UIApplication.sharedApplication().statusBarOrientation
        videoView?.orientation = orientation
    }
    
    func orientationDidChange() {
        let orientation = UIDevice.currentDevice().orientation
        
        orientationIcon.hidden = !isDevicePortrait()
        var a = M_PI / 2.0
        if (orientation == .Portrait) {
            a = -(M_PI / 2.0)
        }
        let m = CGAffineTransformMakeRotation(CGFloat(a))
        orientationIcon.transform = m
        
        renderControls()
    }
    
    func isDevicePortrait() -> Bool {
        let orientation = UIDevice.currentDevice().orientation
        return ((orientation == UIDeviceOrientation.Portrait) || (orientation == UIDeviceOrientation.PortraitUpsideDown))
    }
    
    func textFieldShouldReturn(field: UITextField) -> Bool {
        field.resignFirstResponder()
        return true
    }
    
    @IBAction func didTapCameraSwitch() {
        let oldVideoView = videoView
        if let device = videoView.switchedCameraDevice() {
            UIView.transitionWithView(videoContainer, duration: 0.250, options: .TransitionFlipFromTop, animations: {
                self.videoView.removeFromSuperview()
                self.addVideoView(device)
                
                // TODO: do this after you switch, have something nice to look at while it's animating
                do {
                    try self.videoView.startSession(true)
                }
                catch let error as NSError {
                    print(error.description)
                }
                
            }, completion: { (_) in
                oldVideoView.stopSession()
            })
        }
    }
    
    override func shouldAutorotate() -> Bool {
        return !recordButton.recording
    }
    
}

