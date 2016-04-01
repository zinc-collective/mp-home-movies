//
//  ViewController.swift
//  Home Movies
//
//  Created by sudhir on 9/2/15.
//  Copyright (c) 2015 HomeMoviesDev. All rights reserved.
//

import UIKit
import AVFoundation


class RecordViewController: UIViewController, VideoViewDelegate, UITextFieldDelegate {

    var loadingFromBg: Bool = false
    
    @IBOutlet weak var clipsLabel: UILabel!
    @IBOutlet weak var recordButton: RecordButtonView!
    
    @IBOutlet weak var timerLabel: RecordTimer!
    
    var videoView: VideoView!
    @IBOutlet weak var videoContainer: UIView!
    @IBOutlet weak var orientationIcon: UIImageView!
    
    var orientation : UIDeviceOrientation
    @IBOutlet weak var doneButton: UIButton!
    
    
    required init?(coder aDecoder: NSCoder) {
        orientation = UIDeviceOrientation.LandscapeRight
        super.init(coder: aDecoder)
    }
    
    
    @IBAction func recordPressed(sender: AnyObject) {
        print("record pressed")
        if videoView.isDoneFinalizingOutput() {
            videoView.cleanupSessionDir()
        }
        toggleRecord()
    }
    
    @IBAction func donePressed(sender: AnyObject) {
        print("done pressed")
        
        //if doneButton.titleLabel!.text == "Share"
        //{
        
            //displayShareSheet()
        //}
        //else
        //{
        
        showAlertWithCancel("Are You Sure You Want To Make Your Movie?", msg: "", comp: {
            (alert: UIAlertAction!) in self.showAlertForTitle("Do You Want To Add A Title?",msg: "",comp: { (alert: UIAlertAction!) in
                self.generateTitleAndMakeMovie(self.videoView.movieTitle!)
            })
        })
        
            
       // }
    }
    
    func generateTitleAndMakeMovie(title: String)
    {
        hideClipsLabel()
        showHideActivityIndicator(true)
        if title != "" {
            
            videoView.titleGenerated=false
            let dp = videoView.getSessionFileDir()
            if !dp.exists {
                return //defensive
            }
            videoView.titleFilePath = NSURL(fileURLWithPath: dp.path).URLByAppendingPathComponent(TitleTrackName + ".mp4")
            self.videoView.titDispGrp = dispatch_group_create()
            dispatch_group_enter(videoView.titDispGrp!)
            print(title.endIndex)
            self.videoView.createAnimatedTitleVideo(title, animGrp: videoView.getFadeTransformAnimGrp)
            dispatch_group_wait(videoView.titDispGrp!, DISPATCH_TIME_FOREVER)
            //
        }
        //concatenate video.
        dispatch_async(GlobalUserInitiatedQueue){
            self.videoView.doneDispGroup = dispatch_group_create()
            dispatch_group_enter(self.videoView.doneDispGroup!)
            if !self.videoView.finalizeOutput() {
                dispatch_async(dispatch_get_main_queue()) {
                    self.showAlert("Error",msg: "Could not create video. Please contact support.", comp: {_ in })
                }
            }
            dispatch_group_wait(self.videoView.doneDispGroup!, DISPATCH_TIME_FOREVER)
            dispatch_async(GlobalMainQueue){
                self.showHideActivityIndicator(false)
                self.updateDoneButton()
                let sessDir = self.videoView.getSessionFileDir()
                if  sessDir.exists{
                    let url = NSURL(fileURLWithPath: sessDir.path)
                    self.playVideo(url.URLByAppendingPathComponent("full.mp4"))
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
    
    // no this needs to be on the other one. can't present here.
    
    
    //used by video mgr
    func isSharing() -> Bool
    {
        return doneButton.titleLabel!.text == "Share"
    }
    
    func toggleRecord()
    {
        if recordButton.recording == false
        {
            //videoView.cleanupSessionDir()
            recordButton.recording = true
            doneButton.hidden = true
            hideClipsLabel()
            videoView.startRecording()
            timerLabel.startTimer()
        }
        else
        {
            recordButton.recording = false
            doneButton.hidden = videoView.canFinalize()
            showClipsLabel()
            timerLabel.stopTimer()
            videoView.stopRecording()
        }
        
    }
    
    func updateRecordButtonShown() {
        if (activityIndicator.hidden == false || isDevicePortrait()) {
            recordButton.hidden = true
        }
        else {
            recordButton.hidden = false
        }
    }
    
    
    func showHideActivityIndicator(show: Bool){
        if show {
            doneButton.hidden = true
            activityIndicator.hidden=false
            activityIndicator.center=self.view.center
            activityIndicator.startAnimating()
        }
        else{
            self.activityIndicator.stopAnimating()
            activityIndicator.hidden=true
            doneButton.hidden = false
        }
        self.updateRecordButtonShown()
    }
    
    
    func updateDoneButton()
    {
        if videoView.isDoneFinalizingOutput() {
            doneButton.hidden=true
        }
        else
        {
            showClipsLabel()
            let hasClips = (videoView.getClipsCount() > 0)
            doneButton.hidden = !hasClips
            
        }
        doneButton.setNeedsDisplay()

    }
    
    func showClipsLabel(){
        let count = videoView.getClipsCount()
        var txt: String?
        
        if count > 0 {
            txt = "\(count)"
        }
        else
        {
            txt = ""
        }
        
        clipsLabel.text = txt
        clipsLabel.hidden=false
    }
    
    func hideClipsLabel(){
        clipsLabel.hidden=true
    }
    
    override func viewWillAppear(animated: Bool) {
        recordButton.recording=false
        
        updateDoneButton()
        activityIndicator.hidden=true
        doneButton.layer.borderWidth=CGFloat(1.0)
        doneButton.layer.borderColor = UIColor.whiteColor().CGColor
        doneButton.layer.cornerRadius = CGFloat(5.0)

        print("view will appear")
        
        UIDevice.currentDevice().beginGeneratingDeviceOrientationNotifications()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "orientationDidChange", name:UIDeviceOrientationDidChangeNotification, object: nil)
    }
    
    override func viewDidDisappear(animated: Bool) {
        print("view disappear")
        UIDevice.currentDevice().endGeneratingDeviceOrientationNotifications()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addVideoView()
        
        //
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidEnterBackground", name: UIApplicationDidEnterBackgroundNotification, object: nil)
         NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationWillEnterBackground", name: UIApplicationWillResignActiveNotification, object: nil)
        
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
            NSNotificationCenter.defaultCenter().addObserverForName(UITextFieldTextDidChangeNotification, object: textField, queue: NSOperationQueue.mainQueue()) { (notification) in
                okButton.enabled = textField.text != ""
                if textField.text?.characters.count > 40 {
                    alertCtrller.message = "Title too long! Maximum 40 characters allowed."
                    okButton.enabled=false
                }
                else{
                    alertCtrller.message = ""
                    self.videoView.movieTitle = textField.text?.uppercaseString
                }
            }
        }
        self.presentViewController(alertCtrller, animated: true, completion: nil)
        
        
    }
    
    
    func videoError(error: NSError) {
        if let msg = error.localizedRecoverySuggestion {
            self.showAlert("Error!", msg: msg, comp: {(alert: UIAlertAction!) in exit(0)})
        }
    }
    
    func orientationDidChange() {
        updateRecordButtonShown()
        
        
        orientationIcon.hidden = !isDevicePortrait()
        var a = M_PI / 2.0
        if (UIDevice.currentDevice().orientation == .Portrait) {
            a = -(M_PI / 2.0)
        }
        let m = CGAffineTransformMakeRotation(CGFloat(a))
        orientationIcon.transform = m
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
 

}

