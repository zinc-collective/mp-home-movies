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

let TitleTrackName = "1title"

enum AwfulError: ErrorType {
    case NoDevice
    case SessionError
}

protocol VideoViewDelegate : class {
    func videoError(error: NSError);
}

@objc
class VideoView : UIView, AVCaptureFileOutputRecordingDelegate{
    
//    var parentVC: RecordViewController?
    
    weak var delegate: VideoViewDelegate?
    
    var captureSession: AVCaptureSession?
    var videoDataOutput: AVCaptureMovieFileOutput?
    var previewLayer : AVCaptureVideoPreviewLayer?
    // If we find a device we'll store it here for later use
    var captureDevice : AVCaptureDevice?
    var audCaptureDevice : AVCaptureDevice?
    //
    var recording: Bool = false
    var devicesPresent : Bool = false
    var recDispGrp : dispatch_group_t?
    var titDispGrp: dispatch_group_t?
    var semp : dispatch_semaphore_t? = nil
    var doneDispGroup: dispatch_group_t?
    //
    let screenWidth = UIScreen.mainScreen().bounds.size.width
    
    var movieTitle: String?
    var titleGenerated:Bool?
    var titleFilePath:NSURL?
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        devicesPresent = areDevicesPresent()
    }
    
//    init()
//    {
//
//    }
    
    func startRecording()
    {
        let fileURL = NSURL(fileURLWithPath: getFilePath());
        //
        if captureSession!.running {
            print("session running")
            if(videoDataOutput?.connectionWithMediaType(AVMediaTypeVideo).supportsVideoOrientation == true) {
            //
                let vidConn = videoDataOutput?.connectionWithMediaType(AVMediaTypeVideo)
                print(vidConn?.videoOrientation)
                vidConn?.videoOrientation = AVCaptureVideoOrientation.LandscapeRight
                print(vidConn?.videoOrientation)
            }
            videoDataOutput?.startRecordingToOutputFileURL(fileURL, recordingDelegate: self)
            print("Started recording")
        }
    }
    
    func canFinalize() -> Bool {
        
        if !self.recording {
            let dp = getSessionFileDir()
            if(dp.exists){
                return true
            }
            
        }
        return false
    }
    
    
    
    func cleanupSessionDir()
    {
        let dp = getSessionFileDir()
        if dp.exists {
            try! NSFileManager.defaultManager().removeItemAtPath(dp.path)
        }
    }
    
    func getClipsCount() -> Int {
        var count: Int = 0
        do {
            let dp = getSessionFileDir()
            if dp.exists {
                let contents = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(dp.path)
                for file in contents {
                    count = count + 1
                    if file.containsString(TitleTrackName)
                    {
                        count = count - 1
                    }
                    if file.containsString("full")
                    {
                        count = count - 1
                    }
                }
            }
            
        }
        catch let err as NSError {
            print(err)
        }
        if count >= 0 {
            return count
        }
        else {
            return 0
        }
    }
    
    
    //fix this later
    
    
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
                    self.copyFileToCameraRoll(fileURL, folderPath: fileURL)
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
        do {
            
            try configureDevice()
            let err : NSError? = nil
            captureSession = AVCaptureSession()
            videoDataOutput = AVCaptureMovieFileOutput()
            
            // disable fragment writing to fix loss of audio
            // http://stackoverflow.com/questions/26768987/avcapturesession-audio-doesnt-work-for-long-videos
            // https://developer.apple.com/library/prerelease/ios/documentation/AVFoundation/Reference/AVCaptureMovieFileOutput_Class/index.html#//apple_ref/occ/instp/AVCaptureMovieFileOutput/movieFragmentInterval
            videoDataOutput?.movieFragmentInterval = kCMTimeInvalid;
            
            try captureSession!.addInput(AVCaptureDeviceInput(device: captureDevice))
            try captureSession!.addInput(AVCaptureDeviceInput(device: audCaptureDevice))
            //
            if err != nil {
                print("error: \(err?.localizedDescription)")
            }
            
            if preview {
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                self.layer.addSublayer(previewLayer!)
                previewLayer?.frame = self.layer.frame
                captureSession?.startRunning()
                let previewConn = self.previewLayer!.connection
                let orientation = UIInterfaceOrientation.LandscapeRight
                //let orientation = UIDevice.currentDevice().orientation//parentVC!.interfaceOrientation.rawValue
                let avorientation = AVCaptureVideoOrientation(rawValue: orientation.rawValue)
                previewConn.videoOrientation = avorientation!
                //
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
    
    func stopSession()
    {
        stopRecording()
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        captureSession = nil
        
        print("stopped session, cleanup done!")
    }
    
    func configureDevice() throws {
        if let device = captureDevice {
            do {
                try device.lockForConfiguration()
            } catch let err as NSError{
                throw err
            }
            device.focusMode = .ContinuousAutoFocus
            device.unlockForConfiguration()
        }
        
    }
    
    func areDevicesPresent() -> Bool {
        //check for devices
        let devices = AVCaptureDevice.devices()
        
        // Loop through all the capture devices on this phone
        for device in devices {
            // Make sure this particular device supports video
            if device.hasMediaType(AVMediaTypeVideo) {
                // Finally check the position and confirm we've got the back camera
                if(device.position == AVCaptureDevicePosition.Back) {
                    captureDevice = device as? AVCaptureDevice
                    if captureDevice != nil {
                        print("Video Capture device found")
                        
                    }
                }
            }
            if device.hasMediaType(AVMediaTypeAudio) {
                audCaptureDevice = device as? AVCaptureDevice
                if audCaptureDevice != nil {
                    print("Audio Capture device found")
                }
                
            }
        }
        //
        if captureDevice == nil || audCaptureDevice == nil {
            return false
        }
        
        //checkAllAuthorizations()
        
        return true
    }
    
    func isDoneFinalizingOutput() -> Bool {
         let dp = getSessionFileDir()
        if dp.exists {
            let fileMgr = NSFileManager.defaultManager()
            let pathURL = NSURL(fileURLWithPath: dp.path)
            let completeMovieUrl = pathURL.URLByAppendingPathComponent("full.mp4")
            if fileMgr.fileExistsAtPath(completeMovieUrl.path!){
                return true
            }
        }
        
        return false
        
    }
    
    func finalizeOutput() -> Bool
    {
        let dp = getSessionFileDir()
        if !dp.exists{
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(dp.path, withIntermediateDirectories: false, attributes: nil)
                
            }
            catch let err as NSError {
                print(err.description)
            }
        }
        
        if dp.exists
        {
            //parentVC!.showHideActivityIndicator(true)
            let result = processDirContents(dp.path);
            //parentVC!.showHideActivityIndicator(false)
            if (result) {
                print("done concatenating files")
            }
            return result
        }
        else
        {
            return false
        }
    }
    
    func processDirContents(path: String) -> Bool {
        
        let fileMgr = NSFileManager.defaultManager()
        var files = [String]()
        
        let pathURL = NSURL(fileURLWithPath: path)
        
        let completeMovieUrl = pathURL.URLByAppendingPathComponent("full.mp4")
        
        if fileMgr.fileExistsAtPath(completeMovieUrl.path!){
            try! fileMgr.removeItemAtURL(completeMovieUrl)
        }
        
        do {
            try  files = fileMgr.contentsOfDirectoryAtPath(path)
        }
        catch let err as NSError {
            print(err.description)
            return false
        }
        
        if files.count <= 0 {
            return false
        }
        
        print(files)
        
        
        
        let composition = AVMutableComposition()
        let trackVideo:AVMutableCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: CMPersistentTrackID())
        
        let trackAudio:AVMutableCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: CMPersistentTrackID())
        
        var insertTime = kCMTimeZero
        
        
        do{
            for assetFile in files {
                let moviePathUrl =  pathURL.URLByAppendingPathComponent(assetFile)
                let sourceAsset = AVURLAsset(URL: moviePathUrl, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true,AVURLAssetReferenceRestrictionsKey:0])
                let tracks = sourceAsset.tracksWithMediaType(AVMediaTypeVideo)
                var audios: [AVAssetTrack] = sourceAsset.tracksWithMediaType(AVMediaTypeAudio)
                if tracks.count > 0{
                    
                    let assetTrack:AVAssetTrack = tracks[0]
                    try trackVideo.insertTimeRange(CMTimeRangeMake(kCMTimeZero,sourceAsset.duration), ofTrack: assetTrack, atTime: insertTime)
                    
                     if audios.count > 0 {
                        let assetTrackAudio:AVAssetTrack = audios[0]
                   
                        try trackAudio.insertTimeRange(CMTimeRangeMake(kCMTimeZero,sourceAsset.duration), ofTrack: assetTrackAudio, atTime: insertTime)
                    }
                        
                    else if !assetFile.containsString(TitleTrackName) {
                        print("Track", assetFile, "at time", insertTime.value, "has no audio")
                        return false
                    }
                    
                    insertTime = CMTimeAdd(insertTime, sourceAsset.duration)
                    
                }
            }
        }
        catch let err as NSError {
            print(err.description)
            return false
        }
        
        
        
        let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        
        exporter!.outputURL = completeMovieUrl
        
        exporter!.outputFileType = AVFileTypeMPEG4 //AVFileTypeQuickTimeMovie
        
        exporter!.exportAsynchronouslyWithCompletionHandler({
            
            switch exporter!.status{
                
            case  AVAssetExportSessionStatus.Failed:
                print("failed \(exporter!.error)")
            case AVAssetExportSessionStatus.Cancelled:
                print("cancelled \(exporter!.error)")
            default:
                print(exporter!.outputURL)
                self.authorizeAndCopyFile(completeMovieUrl, path:pathURL)
                print("complete")
                
            }
        })
        return true
    }
    
    
    
    
    
    
    func authorizeAndCopyFile(fileURL: NSURL, path: NSURL)
        
    {
        
        PHPhotoLibrary.requestAuthorization { (PHAuthorizationStatus status) -> Void in
            switch (status)
            {
                
            case .Authorized:
                
                // Permission Granted
                
                self.copyFileToCameraRoll(fileURL, folderPath: path)
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
    
    func copyFileToCameraRoll(fileURL: NSURL, folderPath: NSURL){
        
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
        PHPhotoLibrary.requestAuthorization { (PHAuthorizationStatus status) -> Void in
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
    

    
    func getSessionFileDir() -> (path: String, exists: Bool){
        
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let documentsDirectory = paths[0]
        var filePath:String? = nil
        filePath = "\(documentsDirectory)/ezvideoSession"
        return (filePath!,NSFileManager.defaultManager().fileExistsAtPath(filePath!))
    }
    
    func getFilePath() -> String{
        
        let formatter: NSDateFormatter = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateTimePrefix: String = formatter.stringFromDate(NSDate())
        
        let dp = getSessionFileDir()
        
        if !dp.exists{
            
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(dp.path, withIntermediateDirectories: false, attributes: nil)
            } catch let error1 as NSError {
                print(error1.description)
            }
        }
        
        var filePath:String? = nil
        var fileNamePostfix = 0
        repeat {
            filePath =
            "\(dp.path)/\(dateTimePrefix)-\(fileNamePostfix++).mp4"
        } while (NSFileManager.defaultManager().fileExistsAtPath(filePath!))
        
        return filePath!;
    }
    
    func focusTo(value : Float) {
        if let device = captureDevice {
            do{
                try device.lockForConfiguration()
                device.setFocusModeLockedWithLensPosition(value, completionHandler: { (time) -> Void in})
                device.unlockForConfiguration()
                
            }
            catch let err as NSError {
                print(err.description)
            }
            
        }
    }
    
    
    
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
    

    
}
