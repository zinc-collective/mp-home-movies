//
//  VideoManager.swift
//  Home Movies
//
//  Created by sudhir on 9/3/15.
//  Copyright (c) 2015 HomeMoviesDev. All rights reserved.
//

import Foundation
import AVFoundation
import Photos
import AVKit


enum AwfulError: ErrorType {
    case NoDevice
    case SessionError
}

protocol VideoViewDelegate : class {
    func videoError(error: NSError);
}

typealias Devices = (front: AVCaptureDevice?, back: AVCaptureDevice?, audio: AVCaptureDevice?)

@objc
class VideoView : UIView, AVCaptureFileOutputRecordingDelegate {
    
//    var parentVC: RecordViewController?
    
    weak var delegate: VideoViewDelegate?
    
    var videoSession = VideoSessionManager.defaultManager
    
    var captureSession: AVCaptureSession?
    var videoDataOutput: AVCaptureMovieFileOutput?
    var previewLayer : AVCaptureVideoPreviewLayer?
    
    var orientation : UIInterfaceOrientation {
        get {
            if self.videoOrientation == .LandscapeLeft {
                return .LandscapeLeft
            }
            else {
                return .LandscapeRight
            }
        }
        
        set(newValue) {
            if newValue == .LandscapeLeft {
                self.videoOrientation = .LandscapeLeft
            }
            else {
                self.videoOrientation = .LandscapeRight
            }
            
        }
    }
    
    var videoOrientation = AVCaptureVideoOrientation.LandscapeRight
    
    var focusSquare : CameraFocusSquare?
    
    // If we find a device we'll store it here for later use
    
    var recording: Bool = false
    var recDispGrp : dispatch_group_t?
    var titDispGrp: dispatch_group_t?
    var semp : dispatch_semaphore_t? = nil
    var doneDispGroup: dispatch_group_t?
    //
    let screenWidth = UIScreen.mainScreen().bounds.size.width
    
    var movieTitle: String?
    var titleGenerated:Bool?
    var titleFilePath:NSURL?
    
    var devices : Devices
    var currentVideoDevice : AVCaptureDevice?
    
    var devicesPresent : Bool {
        get {
            return (devices.front != nil || devices.back != nil) && devices.audio != nil
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize(nil)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize(nil)
    }
    
    init(frame: CGRect, device: AVCaptureDevice?) {
        super.init(frame: frame)
        initialize(device)
    }
    
    func initialize(device:AVCaptureDevice?) {
        devices = availableDevices()
        
        if let d = device {
            currentVideoDevice = d
        }
        else {
            currentVideoDevice = devices.back
        }
    }
    
    func startRecording()
    {
        let fileURL = NSURL(fileURLWithPath: videoSession.newVideoPath());
        //
        if captureSession!.running {
            print("session running")
            if(videoDataOutput?.connectionWithMediaType(AVMediaTypeVideo).supportsVideoOrientation == true) {
                let vidConn = videoDataOutput?.connectionWithMediaType(AVMediaTypeVideo)
                vidConn?.videoOrientation = self.videoOrientation
            }
            videoDataOutput?.startRecordingToOutputFileURL(fileURL, recordingDelegate: self)
            print("Started recording")
        }
    }
    
    func stopRecording()
    {
        if videoDataOutput != nil  && videoDataOutput!.recording {
            
            print("saving video \(videoDataOutput!.outputFileURL)")
            let fileURL = videoDataOutput!.outputFileURL;
            dispatch_sync(GlobalUserInitiatedQueue){
                self.recDispGrp = dispatch_group_create()
                dispatch_group_enter(self.recDispGrp!)
                print("stopping recording")
                self.videoDataOutput?.stopRecording()
                dispatch_async(GlobalUserInitiatedQueue){
                    print("waiting for video recording to finish")
                    dispatch_group_wait(self.recDispGrp!, DISPATCH_TIME_FOREVER)
                    print("done waiting for recording to complete...")
                    //copy to camera roll
                    self.doneDispGroup = dispatch_group_create()
                    dispatch_group_enter(self.doneDispGroup!)
                    self.copyFileToCameraRoll(fileURL)
                    dispatch_async(GlobalUtilityQueue){
                        print("waiting for video copy  to camera roll finish")
                        dispatch_group_wait(self.doneDispGroup!, DISPATCH_TIME_FOREVER)
                        print("done waiting for video copy  to camera roll finish.")
                    }
                }
            }
            
            
        }
        
    }
    
    
    func startSession(preview: Bool) throws
    {
        if let videoDevice = currentVideoDevice {
            
            do {
                
                try configureDevice(videoDevice)
                let err : NSError? = nil
                captureSession = AVCaptureSession()
                videoDataOutput = AVCaptureMovieFileOutput()
                
                // disable fragment writing to fix loss of audio
                // http://stackoverflow.com/questions/26768987/avcapturesession-audio-doesnt-work-for-long-videos
                // https://developer.apple.com/library/prerelease/ios/documentation/AVFoundation/Reference/AVCaptureMovieFileOutput_Class/index.html#//apple_ref/occ/instp/AVCaptureMovieFileOutput/movieFragmentInterval
                videoDataOutput?.movieFragmentInterval = kCMTimeInvalid;
                
                try captureSession!.addInput(AVCaptureDeviceInput(device: videoDevice))
                try captureSession!.addInput(AVCaptureDeviceInput(device: devices.audio))
                //
                if err != nil {
                    print("error: \(err?.localizedDescription)")
                }
                
                if preview {
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                    self.layer.addSublayer(self.previewLayer!)
                    self.previewLayer?.frame = self.layer.frame
                    self.captureSession?.startRunning()
                    
                    if let preview = previewLayer {
                        preview.connection.videoOrientation = self.videoOrientation
                    }
                
                    if captureSession!.canAddOutput(videoDataOutput)
                    {
                        captureSession!.addOutput(videoDataOutput)

                    }
                }
            }
            catch let error as NSError{
                print(error.description)
                throw error
            }
            
        }
    }
    
    func stopSession()
    {
        stopRecording()
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        captureSession = nil
        
        print("stopped session, cleanup done!")
    }
    
    func configureDevice(device:AVCaptureDevice) throws {
        do {
            try device.lockForConfiguration()
        } catch let err as NSError{
            throw err
        }
        
        if (device.isFocusModeSupported(.ContinuousAutoFocus)) {
            device.focusMode = .ContinuousAutoFocus
        }
        
        if (device.smoothAutoFocusSupported) {
            device.smoothAutoFocusEnabled = true
        }
        
        device.unlockForConfiguration()
    }
    
    func availableDevices() -> Devices {
        
        let devices = AVCaptureDevice.devices() as! [AVCaptureDevice]
        var front : AVCaptureDevice?
        var back : AVCaptureDevice?
        var audio : AVCaptureDevice?
        
        // Loop through all the capture devices on this phone
        for device in devices {
            // Make sure this particular device supports video
            if device.hasMediaType(AVMediaTypeVideo) {
                // Finally check the position and confirm we've got the back camera
                if(device.position == .Back) {
                    back = device
                }
                else if (device.position == .Front) {
                    front = device
                }
            }
            
            if device.hasMediaType(AVMediaTypeAudio) {
                audio = device
            }
        }
        
        return (front, back, audio)
    }
    
    func finalizeOutput(complete:(NSURL) -> Void) throws -> Void
    {
        try videoSession.exportVideoSession { (url) in
            print("Exported: ", url)
            
            self.authorizeAndCopyFile(url)
            print("Copied: ", url)
            
            complete(url)
        }
    }
    
    
    func authorizeAndCopyFile(fileURL: NSURL)
        
    {
        
        PHPhotoLibrary.requestAuthorization { status in
            switch (status)
            {
                
            case .Authorized:
                
                // Permission Granted
                
                self.copyFileToCameraRoll(fileURL)
                //get the player ready to play the video
                //self.playVideo(fileURL)
                
            case .Denied:
                
                // Permission Denied
                
                print("User denied")
                
            default:
                
                print("Restricted")
                
            }
            
        }
        
    }
    
    func copyFileToCameraRoll(fileURL: NSURL){
        
        print("saving...")
            
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({
            // Create a change request from the asset to be modified.
            let request = PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(fileURL)
            
            // Set a property of the request to change the asset itself.
            print(request?.description)
            }, completionHandler: { success, error in
                NSLog("Finished updating asset. %@", (success ? "Success." : error!))
                print("finished")
                dispatch_group_leave(self.doneDispGroup!)
        })
        
    }
    
    func checkAllAuthorizations() -> Bool{
        self.recDispGrp = dispatch_group_create()
        dispatch_group_enter(self.recDispGrp!)
        AVCaptureDevice.requestAccessForMediaType(AVMediaTypeAudio, completionHandler: {(granted: Bool)-> Void in
            print("perm \(granted)")
            dispatch_group_leave(self.recDispGrp!)
        })
        dispatch_group_wait(self.recDispGrp!, DISPATCH_TIME_FOREVER)
        //
        dispatch_group_enter(self.recDispGrp!)
        AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: {(granted: Bool)-> Void in
            print("perm \(granted)")
            dispatch_group_leave(self.recDispGrp!)
        })
        dispatch_group_wait(self.recDispGrp!, DISPATCH_TIME_FOREVER)
        //
        dispatch_group_enter(self.recDispGrp!)
        PHPhotoLibrary.requestAuthorization { (status : PHAuthorizationStatus) -> Void in
            print("perm \(status)")
            dispatch_group_leave(self.recDispGrp!)
        }
        dispatch_group_wait(self.recDispGrp!, DISPATCH_TIME_FOREVER)
        
        let videoAccess = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        let audioAccess = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeAudio)
        let photoLibAcces = PHPhotoLibrary.authorizationStatus()
        
        var retVal = true
        if audioAccess != AVAuthorizationStatus.Authorized {
            print("got no microphone accesss...")
            retVal = false
        }
        
        if videoAccess != AVAuthorizationStatus.Authorized {
            print("got no camera accesss...")
            retVal = false
        }
        
        if  photoLibAcces != PHAuthorizationStatus.Authorized{
            print("got no photo roll accesss...")
            retVal = false
        }
        print("got all authorizations...")
        
        return retVal
    }
    

    
//    func focusTo(value : Float) {
//        if let device = currentVideoDevice {
//            do{
//                try device.lockForConfiguration()
//                device.setFocusModeLockedWithLensPosition(value, completionHandler: { (time) -> Void in})
//                device.unlockForConfiguration()
//                
//            }
//            catch let err as NSError {
//                print(err.description)
//            }
//            
//        }
//    }
    
    
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!){
        self.recording=false
        if(error != nil)
        {
            delegate?.videoError(error)
            
        }
        else {
            print("done recording -> \(outputFileURL)")
        }
        if self.recDispGrp != nil {
            dispatch_async(GlobalUserInitiatedQueue) {
                dispatch_group_leave(self.recDispGrp!)
            }
        }
        
    }
    
    
    
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        self.recording=true
        print("started recording to -> \(fileURL)" )
    }
    
    
    func getFadeTransformAnimGrp() -> CAAnimationGroup {
        
        //
        let animation : CABasicAnimation = CABasicAnimation(keyPath: "transform.scale");
        animation.fromValue = NSValue(CATransform3D: CATransform3DMakeScale(1, 1,1))
        animation.toValue = NSValue(CATransform3D: CATransform3DMakeScale(1.5, 1, 1))
        animation.duration = 4
        animation.fillMode=kCAFillModeBoth
        animation.beginTime=AVCoreAnimationBeginTimeAtZero
        //
       
        //grouping above animations before initiating
        let animGrp = CAAnimationGroup()
        animGrp.beginTime=AVCoreAnimationBeginTimeAtZero
        animGrp.animations=[animation]
        animGrp.removedOnCompletion=false
        animGrp.fillMode=kCAFillModeBoth
        animGrp.duration = 4
        //
        
     
       
        
        return animGrp
    }
    
    func getAssetForDevice() -> AVURLAsset {
        let model = UIDevice.currentDevice().modelName
        var assetName: String?
        switch model {
        case "iPhone 5": assetName = "iphone5"
        case "iPhone 5s": assetName = "iphone5"
        case "iPhone 5c": assetName = "iphone5"
        case "iPhone 6" : assetName = "iphone6"
        case "iPhone 6s" : assetName = "iphone6"
        case "iPhone 6 Plus" : assetName = "iphone6p"
        case "iPhone 6s Plus" : assetName = "iphone6p"
        default: assetName = "iphone4sbelow"
        }
        
        let asset = AVURLAsset(URL:NSBundle.mainBundle().URLForResource(assetName, withExtension:"mov")!)
        return asset
        
    }
    
    
    
    func createAnimatedTitleVideo(label: String, animGrp: ()-> CAAnimationGroup)  {
        
        
        //let dispGrp = dispatch_group_create()
        dispatch_async(GlobalUserInteractiveQueue) {
            
            
            //dispatch_group_enter(self.dispGrp)
            //mutable composition
            let comp = AVMutableComposition()
            //video asset
            let asset = self.getAssetForDevice()
            let track = comp.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
            let asset_track = asset.tracksWithMediaType(AVMediaTypeVideo)[0]
            print(asset.tracksWithMediaType(AVMediaTypeVideo)[0])
            do {
                try track.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), ofTrack: asset_track, atTime: kCMTimeZero)
            }
            catch let err as NSError {
                print(err)
            }
            print(asset.duration)
            //
            let animComp = AVMutableVideoComposition(propertiesOfAsset: asset)
            //
            let parentLayer = CALayer()
            let videoLayer = CALayer()
            print(animComp.frameDuration)
            parentLayer.frame=CGRectMake(0, 0, animComp.renderSize.width,animComp.renderSize.height)
            videoLayer.frame=CGRectMake(0,0,animComp.renderSize.width,animComp.renderSize.height)
            parentLayer.addSublayer(videoLayer)
            //
            //asset layer
            let al = CALayer()
            al.opacity=1.0
            //al.position=CGPointMake(animComp.renderSize.width/2, animComp.renderSize.height/2)
            al.frame=CGRectMake(0, 0, animComp.renderSize.width,animComp.renderSize.height)
            al.geometryFlipped=false
            al.contentsGravity = "center"
            al.anchorPoint=CGPointMake(0.5, 0.5)
            //animation
            let textLayer = CATextLayer()
            let pw = animComp.renderSize.width
            let ph = animComp.renderSize.height
            let w = pw * 0.66
            let lineHeight : CGFloat = 50.0
            textLayer.frame = CGRectMake(((pw - w)/2), 0, w, ph/2 + lineHeight)
            textLayer.string = label
            let fontName: CFStringRef = "HelveticaNeue-Bold"
            textLayer.font = CTFontCreateWithName(fontName, 10.0, nil)
            textLayer.foregroundColor = UIColor.whiteColor().CGColor
//            textLayer.backgroundColor = UIColor.redColor().CGColor
            textLayer.fontSize = 55.0;
            textLayer.contentsScale=UIScreen.mainScreen().scale*2
            textLayer.wrapped = true
            textLayer.alignmentMode = kCAAlignmentCenter
            textLayer.opacity=1
            textLayer.anchorPoint = CGPointMake(0.5, 0.5)//
            
            
            
            textLayer.addAnimation(animGrp(), forKey: "chosenAnimation")
            al.addSublayer(textLayer)
            parentLayer.addSublayer(al)
            
            
            let animTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, inLayer: parentLayer)
            animComp.animationTool=animTool
            
            let compInstr = AVMutableVideoCompositionInstruction()
            compInstr.timeRange=CMTimeRangeMake(kCMTimeZero, asset.duration)
            let layerInstr = AVMutableVideoCompositionLayerInstruction(assetTrack: asset_track)
            layerInstr.setOpacity(1, atTime: kCMTimeZero)
            
            
            compInstr.layerInstructions=[layerInstr]
            animComp.instructions=[compInstr]
            
            //
            let fileURL = self.titleFilePath!
            let filePath = self.titleFilePath!.path!
            if NSFileManager.defaultManager().fileExistsAtPath(filePath) {
                do {
                    try NSFileManager.defaultManager().removeItemAtPath(filePath)
                }
                catch let err as NSError {
                    print(err)
                }
                
            }
            print(self.titleFilePath!)
            
            let exportSession = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)
            print(comp)
            exportSession?.outputURL=fileURL
            exportSession?.videoComposition=animComp
            exportSession?.outputFileType=AVFileTypeMPEG4
            print(exportSession?.estimatedOutputFileLength)
            exportSession?.exportAsynchronouslyWithCompletionHandler(){
                switch exportSession!.status{
                case  AVAssetExportSessionStatus.Completed:
                    self.titleGenerated = true
                default:
                    print("cancelled \(exportSession!.error)")
                    
                }
                dispatch_group_leave(self.titDispGrp!)
            }
        }
    }

    func getImageFromVideo(url: NSURL) throws -> UIImage{
        let asset = AVURLAsset(URL: url, options: nil)
        let imgGenerator = AVAssetImageGenerator(asset: asset)
        do {
            let cgImage = try imgGenerator.copyCGImageAtTime(CMTimeMake(0, 1), actualTime: nil)
            // !! check the error before proceeding
            let uiImage = UIImage(CGImage: cgImage)
            return uiImage
        }
        catch let err as NSError {
            print(err)
            throw err
        }
    }
    
    func switchedCameraDevice() -> AVCaptureDevice? {
        
        if (currentVideoDevice == devices.front) {
            return devices.back
        }
        else {
            return devices.front
        }
        
    }
    
    // Tap to focus and exposure
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let touchPoint = touches.first?.locationInView(self), device = currentVideoDevice, preview = previewLayer {
            
            let focusPoint = preview.captureDevicePointOfInterestForPoint(touchPoint)
            
            do {
                try device.lockForConfiguration()
            } catch let err as NSError {
                print("Device Lock Error:", err.description)
            }
            
            if device.focusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .ContinuousAutoFocus
            }
            
            if device.exposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = AVCaptureExposureMode.AutoExpose
            }
            
            
            device.unlockForConfiguration()
            
            if let oldSquare = focusSquare {
                oldSquare.removeFromSuperview()
            }
            
            let square = CameraFocusSquare(frame: CameraFocusSquare.centerFrame(size: 80, center: touchPoint))
            addSubview(square)
            
            square.animate {
                square.removeFromSuperview()
            }
            
            self.focusSquare = square
        }
    }
 

}
