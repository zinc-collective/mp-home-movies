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
    var isChooseContinueModal = false
    
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
    
    @IBOutlet weak var topBar: UIView!
    @IBOutlet weak var sideBar: UIView!
    @IBOutlet weak var continueButton: OutlineButton!
    @IBOutlet weak var newMovieButton: OutlineButton!
    
    var alertController : UIAlertController?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    @IBAction func recordPressed(sender: AnyObject) {
        toggleRecord()
    }
    
    @IBAction func donePressed(sender: AnyObject) {
        print("done pressed")
        self.showAlertForTitle({ title in
            self.generateTitleAndMakeMovie(title)
        })
    }
    
    @IBAction func deletePressed() {
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Delete last clip", style: .Destructive, handler: { action in
            self.videoSession.deleteLastClip()
            self.renderControls()
            self.sessionChanged()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Start new movie", style: .Default, handler: { action in
            self.startOverPressed()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        
        self.presentViewController(actionSheet, animated: true, completion: {})
    }
    
    @IBAction func startOverPressed() {
        do {
            try self.videoSession.cleanupSessionDir()
        }
        catch let err as NSError {
            print("Error", err.localizedDescription)
        }
        isChooseContinueModal = false
        self.renderControls()
        self.sessionChanged()
    }
    
    @IBAction func continuePressed() {
        isChooseContinueModal = false
        self.renderControls()
    }
    
    func generateTitleAndMakeMovie(movieTitle: String?)
    {
        showHideActivityIndicator(true)
        
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
                        self.showHideActivityIndicator(false)
                        self.playVideo(exportedURL, movieTitle: movieTitle)
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
    
    func playVideo(videoURL : NSURL, movieTitle: String?) {
        let playerController = UIStoryboard(name: "Player", bundle: nil).instantiateInitialViewController() as! VideoPlayerController
        playerController.fullVideoURL = videoURL
        playerController.movieTitle = movieTitle
        self.presentViewController(playerController, animated: true, completion: {
            self.isChooseContinueModal = true
        })
    }
    
    func renderControls() {
        
        let isPortrait = isDevicePortrait()
        let isWorking = activityIndicator.hidden == false
        let numClips = videoSession.getClipsCount()
        let hasClips = (numClips > 0)
        
        let allControlsHidden = isPortrait || isWorking || isChooseContinueModal
        
        let fromHidden = { (hidden: Bool) -> CGFloat in
            if hidden {
                return 0.0
            }
            //
            else {
                return 1.0
            }
        }
        
        UIView.animateWithDuration(0.200, animations: {
            
            self.doneButton.alpha      = fromHidden(self.isRecording || !hasClips || allControlsHidden)
            
            self.topBar.alpha = fromHidden(allControlsHidden)
            self.sideBar.alpha = fromHidden(allControlsHidden)
            
            // the following are on the top or side bar
            self.deleteButton.alpha    = fromHidden(self.isRecording || !hasClips)
            self.clipsButton.alpha     = fromHidden(!hasClips)
            self.cameraSwitchButton.alpha = fromHidden(self.isRecording)
            
            self.newMovieButton.alpha = fromHidden(!self.isChooseContinueModal)
            self.continueButton.alpha = fromHidden(!self.isChooseContinueModal)
        })
        
        self.clipsButton.setTitle("\(numClips)", forState: .Normal)
        
        recordButton.recording = isRecording
        recordLight.hidden = !isRecording
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
            videoView.stopRecording({
                print("STOP RECORDING", self.videoSession.sessionDuration())
                dispatch_async(dispatch_get_main_queue()) {
                    self.sessionChanged()
                }
            })
            timerLabel.stopTimer()
        }
        
        renderControls()
    }
    
    func sessionChanged() {
        let duration = videoSession.sessionDuration()
        print("DURATION", duration)
        self.timerLabel.stoppedTime = duration
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
        super.viewWillAppear(animated)
        activityIndicator.hidden=true
        renderControls()

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
        let duration = videoSession.sessionDuration()
        print("INITIAL DURATION", duration)
        timerLabel.stoppedTime = duration
        
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
        videoView.orientation = UIDevice.currentDevice().orientation
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
            self.videoView.stopRecording({})
            self.videoView.stopSession()
        }
    }
    
    func applicationDidEnterBackground()
    {
        print("view - app entered background")
        loadingFromBg = true
    }
    
    func showAlert(tit: String, msg: String, comp: ((UIAlertAction!) -> Void)){
        
        let alertCtrller = UIAlertController(title: tit, message: msg, preferredStyle: UIAlertControllerStyle.Alert)
        alertCtrller.addAction( UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: comp ))
        self.presentViewController(alertCtrller, animated: true, completion: nil)
    
    }
    
    func showAlertWithCancel(tit: String, msg: String, comp: ((UIAlertAction!) -> Void)){
        let alertCtrller = UIAlertController(title: tit, message: msg, preferredStyle: UIAlertControllerStyle.Alert)
        alertCtrller.addAction( UIAlertAction(title: "Yes", style: UIAlertActionStyle.Default, handler: comp ))
        alertCtrller.addAction( UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: {(alert:UIAlertAction!) in } ))
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
        super.viewWillDisappear(animated)
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
    
        
    
    
    
    func showAlertForTitle(comp: ((title: String?) -> Void)){
        
        var movieTitle : String? = nil
        
        let alertCtrller = UIAlertController(title: "Do you want to add a title?", message: nil, preferredStyle: .Alert)
        
        alertCtrller.addAction( UIAlertAction(title: "Continue", style: UIAlertActionStyle.Default) { alert in
            comp(title: movieTitle)
        })
        
        alertCtrller.addAction(UIAlertAction(title: "Cancel", style: .Cancel) { _ in
            print("CANCEL")
        })
        
        alertCtrller.addTextFieldWithConfigurationHandler {(textField) in
            textField.delegate = self
            textField.placeholder = "No Title"
            textField.autocapitalizationType = .AllCharacters
            
            NSNotificationCenter.defaultCenter().addObserverForName(UITextFieldTextDidChangeNotification, object: textField, queue: NSOperationQueue.mainQueue()) { (notification) in
                movieTitle = textField.text?.uppercaseString
            }
        }
        
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
        
        let orientation = UIDevice.currentDevice().orientation
        videoView?.orientation = orientation
    }
    
    func orientationDidChange() {
        let orientation = UIDevice.currentDevice().orientation
        let isPortrait = isDevicePortrait()
        
        if (isRecording && isPortrait) {
            toggleRecord()
        }
        
        orientationIcon.hidden = !isDevicePortrait() || isChooseContinueModal
        
        // either updside down or portrait
        var a = M_PI / 2.0
        if (orientation == .Portrait) {
            a = -(M_PI / 2.0)
        }
        
        // rotate depending on current interface orientation
        if (videoView?.orientation == .LandscapeRight){
            a += M_PI
        }
            
        let m = CGAffineTransformMakeRotation(CGFloat(a))
        orientationIcon.transform = m
        
        renderControls()
    }
    
    func isDevicePortrait() -> Bool {
        let orientation = UIDevice.currentDevice().orientation
        return ((orientation == .Portrait) || (orientation == .PortraitUpsideDown))
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
        return !isRecording
    }
    
}

