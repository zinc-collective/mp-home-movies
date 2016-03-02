//
//  ViewController.swift
//  Home Movies
//
//  Created by sudhir on 9/2/15.
//  Copyright (c) 2015 HomeMoviesDev. All rights reserved.
//

import UIKit
import AVFoundation


class ViewController: UIViewController {

    var videoMgr: VideoManager?
    var loadingFromBg: Bool = false
    
    @IBOutlet weak var clipsLabel: UILabel!
    @IBOutlet weak var recordButton: RecordButtonView!
    
    @IBOutlet weak var timerLabel: UILabel!
    
    
    var startTime : NSTimeInterval?
    var timer: NSTimer?
    @IBOutlet weak var doneButton: UIButton!
    
    
    
   
    
    
    @IBAction func recordPressed(sender: AnyObject) {
        print("record pressed")
        if videoMgr!.isDoneFinalizingOutput() {
            self.videoMgr!.cleanupSessionDir()
        }
        updateRecordButtonState()
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
            (alert: UIAlertAction!) in self.showAlertForTitle("Do You Want To Add A Title?",msg: "",comp: {(alert: UIAlertAction!) in self.generateTitleAndMakeMovie(self.videoMgr!.movieTitle!)})
        })
        
            
       // }
    }
    
    func displayShareSheet(){
        let sessDir = self.videoMgr!.getSessionFileDir()
        if  sessDir.exists{
            let url = NSURL(fileURLWithPath: sessDir.path)
            let shareContent = url.URLByAppendingPathComponent("full.mp4")
            let activityViewController = UIActivityViewController(activityItems: [shareContent as NSURL], applicationActivities: nil)
            presentViewController(activityViewController, animated: true, completion: {})
        }
    }
    
    func generateTitleAndMakeMovie(title: String)
    {
        hideClipsLabel()
        showHideActivityIndicator(true)
        if title != "" {
            
            videoMgr!.titleGenerated=false
            let dp = videoMgr!.getSessionFileDir()
            if !dp.exists {
                return //defensive
            }
            videoMgr!.titleFilePath = NSURL(fileURLWithPath: dp.path).URLByAppendingPathComponent("1title.mp4")
            self.videoMgr!.titDispGrp = dispatch_group_create()
            dispatch_group_enter(videoMgr!.titDispGrp!)
            print(title.endIndex)
            self.videoMgr!.createAnimatedTitleVideo(title, animGrp: videoMgr!.getFadeTransformAnimGrp)
            dispatch_group_wait(videoMgr!.titDispGrp!, DISPATCH_TIME_FOREVER)
            //
        }
        //concatenate video.
        dispatch_async(GlobalUserInitiatedQueue){
            self.videoMgr!.doneDispGroup = dispatch_group_create()
            dispatch_group_enter(self.videoMgr!.doneDispGroup!)
            self.videoMgr!.finalizeOutput()
            dispatch_group_wait(self.videoMgr!.doneDispGroup!, DISPATCH_TIME_FOREVER)
            dispatch_async(GlobalMainQueue){
                self.showHideActivityIndicator(false)
                self.updateDoneButton()
                let sessDir = self.videoMgr!.getSessionFileDir()
                if  sessDir.exists{
                    let url = NSURL(fileURLWithPath: sessDir.path)
                    self.videoMgr!.playVideo(url.URLByAppendingPathComponent("full.mp4"))
                }
                
            }
        }
    }
    
    //used by video mgr
    func isSharing() -> Bool
    {
        return doneButton.titleLabel!.text == "Share"
    }
    
    func updateRecordButtonState()
    {
        
        if recordButton.record
        {
            //videoMgr!.cleanupSessionDir()
            recordButton.record = false
            timerLabel.hidden=false
            doneButton.hidden = true
            hideClipsLabel()
            recordButton.setNeedsDisplay()
            videoMgr?.startRecording()
            startTimer()
        }
        else
        {
            recordButton.record = true
            timerLabel.hidden=true
            doneButton.hidden = videoMgr!.canFinalize()
            showClipsLabel()
            recordButton.setNeedsDisplay()
            stopTimer()
            videoMgr?.stopRecording()
        }
        
    }
    
    
    
    func showHideActivityIndicator(show: Bool){
        if show {
            recordButton.hidden = true
            timerLabel.hidden=true
            doneButton.hidden = true
            activityIndicator.hidden=false
            activityIndicator.center=self.view.center
            self.view.bringSubviewToFront(activityIndicator)
            activityIndicator.startAnimating()
        }
        else{
            self.activityIndicator.stopAnimating()
            activityIndicator.hidden=true
            recordButton.hidden = false
            timerLabel.hidden=true
            doneButton.hidden = false
        }
    }
    
    func startTimer()
    {
        let sel : Selector = "updateTime"
        timer = NSTimer.scheduledTimerWithTimeInterval(0.01, target:self,selector: sel, userInfo: nil, repeats:true)
        startTime=NSDate.timeIntervalSinceReferenceDate()
    }
    
    func stopTimer()
    {
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }
    
    func updateTime()
    {
        let currentTime = NSDate.timeIntervalSinceReferenceDate()
        var elapsedTime: NSTimeInterval = currentTime - startTime!
        let minutes = UInt8(elapsedTime / 60.0)
        elapsedTime -= (NSTimeInterval(minutes) * 60)
        let seconds = UInt8(elapsedTime)
        elapsedTime -= NSTimeInterval(seconds)
        let fraction = UInt8(elapsedTime * 100)
        let strMinutes = String(format: "%02d", minutes)
        let strSeconds = String(format: "%02d", seconds)
        let strFraction = String(format: "%02d", fraction)
        timerLabel.text = "\(strMinutes):\(strSeconds):\(strFraction)"
    }
    
    func updateDoneButton()
    {
        if videoMgr!.isDoneFinalizingOutput() {
            //doneButton.setTitle("Make Movie", forState: .Normal)
            doneButton.hidden=true
            self.view.sendSubviewToBack(doneButton)
        }
        else
        {
            //doneButton.setTitle("Make Movie", forState: .Normal)
            showClipsLabel()
            if videoMgr!.getClipsCount() > 0 {
                doneButton.hidden=false
                self.view.bringSubviewToFront(doneButton)
            }
            else{
                doneButton.hidden=true
                self.view.sendSubviewToBack(doneButton)
            }
            
        }
        doneButton.setNeedsDisplay()

    }
    
    func showClipsLabel(){
        let count = videoMgr!.getClipsCount()
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
        self.view.bringSubviewToFront(clipsLabel)
    }
    
    func hideClipsLabel(){
        clipsLabel.hidden=true
    }
    
    override func viewWillAppear(animated: Bool) {
        recordButton.record=true
        recordButton.setNeedsDisplay()
        timerLabel.hidden=true
        
        updateDoneButton()
        activityIndicator.hidden=true
        doneButton.layer.borderWidth=CGFloat(1.0)
        doneButton.layer.borderColor = UIColor.whiteColor().CGColor
        doneButton.layer.cornerRadius = CGFloat(5.0)
        //doneButton.setNeedsDisplay()
        //
       

        print("view will appear")
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //
        videoMgr = VideoManager(viewController: self)
        //
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidEnterBackground", name: UIApplicationDidEnterBackgroundNotification, object: nil)
         NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationWillEnterBackground", name: UIApplicationWillResignActiveNotification, object: nil)
        
        //doneButton.hidden = videoMgr!.canFinalize()
        print("view did load")
        
        
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
                try self.videoMgr?.startSession(true)
            }
            catch let error as NSError {
                print(error.description)
            }
        }
    }
    
    func applicationWillEnterBackground()
    {
        print("view - app will enter background")
        stopTimer()
        timerLabel.hidden=true
        dispatch_async(GlobalUtilityQueue){
            self.videoMgr?.stopRecording()
            self.videoMgr?.stopSession()
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
        //
        
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        if(appDelegate.freeSpaceMb <= 50)
        {
            showAlert("Warning!",msg: "You have less than 50 MB storage left! Please free up some space and try again!", comp: {(alert: UIAlertAction!) in exit(0)
            })
        }
        //check for devices TODO negate check below
        if !videoMgr!.devicesPresent {
            showAlert("Error", msg: "Camera/Microphone not found!", comp: {(alert: UIAlertAction!) in exit(0)})
        }
            
        if !videoMgr!.checkAllAuthorizations() {
            showAlert("Error", msg: "Camera/Microphone/Photos Usage Not Authorized!!! \n\nPlease Update App Settings And Try Again.", comp: {(alert: UIAlertAction!) in exit(0)})
        }
        else {
            do {
                try videoMgr!.startSession(true)
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
    
    
    override func viewDidDisappear(animated: Bool) {
        print("view disappear")
    }
    
    
    /*func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!){
        videoMgr!.recording=false
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
        
        dispatch_group_leave(videoMgr!.recDispGrp!)
        
    }
    
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        videoMgr!.recording=true
        print("started recording to -> \(fileURL)" )
    }*/
    
        
    
    
    
    func showAlertForTitle(tit: String, msg: String, comp: ((UIAlertAction!) -> Void)){
        
        self.videoMgr!.movieTitle=""
        let alertCtrller = UIAlertController(title: tit, message: msg, preferredStyle: UIAlertControllerStyle.Alert)
        let okButton = UIAlertAction(title: "Add Title", style: UIAlertActionStyle.Default, handler: comp )
        alertCtrller.addAction(okButton)
        alertCtrller.addAction( UIAlertAction(title: "No Title", style: UIAlertActionStyle.Default, handler: {
            (alert: UIAlertAction!) in
            self.videoMgr!.movieTitle=""
            comp(okButton)
        } ))
        alertCtrller.addTextFieldWithConfigurationHandler { (textField) in
            textField.placeholder = "Title"
            NSNotificationCenter.defaultCenter().addObserverForName(UITextFieldTextDidChangeNotification, object: textField, queue: NSOperationQueue.mainQueue()) { (notification) in
                okButton.enabled = textField.text != ""
                if textField.text?.characters.count > 40 {
                    alertCtrller.message = "Title too long! Maximum 40 characters allowed."
                    okButton.enabled=false
                }
                else{
                    alertCtrller.message = ""
                    self.videoMgr!.movieTitle = textField.text?.uppercaseString
                }
            }
        }
        self.presentViewController(alertCtrller, animated: true, completion: nil)
        
        
    }
 

}

