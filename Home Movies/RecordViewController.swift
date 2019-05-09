//
//  ViewController.swift
//  Home Movies
//
//  Created by sudhir on 9/2/15.
//  Copyright (c) 2015 HomeMoviesDev. All rights reserved.
//

import UIKit
import AVFoundation
import JPSVolumeButtonHandler

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
    @IBOutlet weak var contentControlsView: UIView!
    
    @IBOutlet weak var thumbControlsLeading: NSLayoutConstraint!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var alertController : UIAlertController?
    
    var volumeHandler:JPSVolumeButtonHandler!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    @IBAction func recordPressed(_ sender: AnyObject) {
        toggleRecord()
    }
    
    @IBAction func donePressed(_ sender: AnyObject) {
        doneButton.isEnabled = false
        print("done pressed")
        self.performSegue(withIdentifier: "TitleViewController", sender: self)
        
        // TODO move this
        self.isChooseContinueModal = true
    }
    
    @IBAction func deletePressed() {
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Delete last clip", style: .destructive, handler: { action in
            self.videoSession.deleteLastClip()
            self.renderControls()
            self.sessionChanged()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Start new movie", style: .default, handler: { action in
            self.startOverPressed()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(actionSheet, animated: true, completion: {})
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
    
    func renderControls() {
        
        let isPortrait = isDevicePortrait()
        let isWorking = activityIndicator.isHidden == false
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
        
        UIView.animate(withDuration: 0.200, animations: {
            
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
        
        self.clipsButton.setTitle("\(numClips)", for: UIControl.State())
        
        recordButton.recording = isRecording
        recordLight.isHidden = !isRecording
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
            // this might need to be more complex
            videoView.startRecording(UIDevice.current.orientation)
            timerLabel.startTimer()
        }
        else
        {
            videoView.stopRecording({
                print("STOP RECORDING", self.videoSession.sessionDuration())
                DispatchQueue.main.async {
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
    
    func showHideActivityIndicator(_ show: Bool){
        if show {
            activityIndicator.isHidden = false
            activityIndicator.center = self.view.center
            activityIndicator.startAnimating()
        }
        else{
            self.activityIndicator.stopAnimating()
            activityIndicator.isHidden=true
        }
        renderControls()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        doneButton.isEnabled = true
        activityIndicator.isHidden=true
        renderControls()
        
        self.navigationController?.setNavigationBarHidden(true, animated: animated)

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(RecordViewController.orientationDidChange), name:UIDevice.orientationDidChangeNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(RecordViewController.applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(RecordViewController.applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
         NotificationCenter.default.addObserver(self, selector: #selector(RecordViewController.applicationWillEnterBackground), name: UIApplication.willResignActiveNotification, object: nil)
        
        // correct the layout for landscape right
        if (UIDevice.current.orientation == .landscapeRight) {
            landscapeRightLayout(0)
        }
        else {
            defaultLayout(0)
        }
        
        volumeHandler = JPSVolumeButtonHandler(up: {
            self.recordPressed(self)
        }, downBlock: {
            self.recordPressed(self)
        })
        
        
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        print("view disappear")
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addVideoView()
        clipsButton.contentHorizontalAlignment = .center
        let duration = videoSession.sessionDuration()
        print("INITIAL DURATION", duration)
        timerLabel.stoppedTime = duration
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .done, target: nil, action: nil)
        
        //doneButton.hidden = videoView.canFinalize()
        print("view did load")
        
    }
    
    func addVideoView(_ device:AVCaptureDevice?) {
        videoView = VideoView(frame: videoContainer.bounds, device: device, orientation: UIDevice.current.orientation)
        videoContainer.addSubview(videoView)
        videoView.delegate = self
    }
    
    func addVideoView() {
        addVideoView(nil)
    }
    
    @objc func applicationDidBecomeActive()
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
    
    @objc func applicationWillEnterBackground()
    {
        print("view - app will enter background")
        timerLabel.stopTimer()
        GlobalUtilityQueue.async{
            self.videoView.stopRecording({})
            self.videoView.stopSession()
        }
    }
    
    @objc func applicationDidEnterBackground()
    {
        print("view - app entered background")
        loadingFromBg = true
    }
    
    func showAlert(_ tit: String, msg: String, comp: @escaping ((UIAlertAction?) -> Void)){
        
        let alertCtrller = UIAlertController(title: tit, message: msg, preferredStyle: UIAlertController.Style.alert)
        alertCtrller.addAction( UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: comp ))
        self.present(alertCtrller, animated: true, completion: nil)
    
    }
    
    func showAlertWithCancel(_ tit: String, msg: String, comp: @escaping ((UIAlertAction?) -> Void)){
        let alertCtrller = UIAlertController(title: tit, message: msg, preferredStyle: UIAlertController.Style.alert)
        alertCtrller.addAction( UIAlertAction(title: "Yes", style: UIAlertAction.Style.default, handler: comp ))
        alertCtrller.addAction( UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: {(alert:UIAlertAction!) in } ))
        self.present(alertCtrller, animated: true, completion: nil)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    func videoError(_ error: NSError) {
        if let msg = error.localizedRecoverySuggestion {
            self.showAlert("Error!", msg: msg, comp: {(alert: UIAlertAction!) in exit(0)})
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // the orientation has already updated to the new one
        let orientation = UIDevice.current.orientation
//        videoView?.orientation = orientation
        
        let duration = coordinator.transitionDuration
        print("TRANSITION TO SIZE")
        
        // BUTTON ROTATION
        // it won't animate
        if orientation == .landscapeRight {
            landscapeRightLayout(duration)
        }
        else {
            defaultLayout(duration)
        }
        
//        if orientation == .LandscapeRight {
//            landscapeRightLayout(duration)
//        }
//        else {
//            landscapeLeftLayout(duration)
//        }
        
//        // prevent all animations until the transition is complete
//        UIView.setAnimationsEnabled(false)
//        coordinator.animateAlongsideTransition({ context in
//            
//        }, completion: { context in
//            // turn them back on
//            UIView.setAnimationsEnabled(true)
//        })
    }
    
    func landscapeRightLayout(_ duration:TimeInterval) {
        let transform = CGAffineTransform(rotationAngle: CGFloat(Float.pi))
        self.contentControlsView.transform = transform
        UIView.animate(withDuration: duration, animations: {
            self.clipsButton.transform = transform
        }) 
    }
    
    func defaultLayout(_ duration:TimeInterval) {
        self.contentControlsView.transform = CGAffineTransform.identity
        UIView.animate(withDuration: duration, animations: {
            self.clipsButton.transform = CGAffineTransform.identity
        }) 
    }
    
    @objc func orientationDidChange() {
        let orientation = UIDevice.current.orientation
        
        let isPortrait = isDevicePortrait()
        
        if (isRecording && isPortrait) {
            toggleRecord()
        }
        
        // ORIENATION ICON
        orientationIcon.isHidden = !isDevicePortrait() || isChooseContinueModal
        
        // either updside down or portrait
        var a = 0.0
        let quarterPi = (Double.pi / 2.0)
        if (orientation == .portrait) {
            a = -(quarterPi)
        }
        else if (orientation == .portraitUpsideDown) {
            a = quarterPi
        }
        else {
            a = 0
        }
        
        let m = CGAffineTransform(rotationAngle: CGFloat(a))
        orientationIcon.transform = m
        
        renderControls()
    }
    
    func isDevicePortrait() -> Bool {
        let orientation = UIDevice.current.orientation
        return ((orientation == .portrait) || (orientation == .portraitUpsideDown))
    }
    
    @IBAction func didTapCameraSwitch() {
        let oldVideoView = videoView
        if let device = videoView.switchedCameraDevice() {
            UIView.transition(with: videoContainer, duration: 0.250, options: .transitionFlipFromTop, animations: {
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
                oldVideoView?.stopSession()
            })
        }
    }
    
    override var shouldAutorotate : Bool {
        return !isRecording
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let title = segue.destination as? TitleViewController {
            title.videoView = videoView
        }
    }
    
    
    @IBAction func didTapControls(_ gesture: UIGestureRecognizer) {
        let point = gesture.location(in: self.videoView)
        videoView.focusPoint(point)
    }
    
}

