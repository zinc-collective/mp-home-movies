//
//  VideoManager.swift
//  Home Movies
//
//  Created by sudhir on 9/3/15.
//  Copyright © 2019 Zinc Collective LLC. All rights reserved.
//

import Foundation
import AVFoundation
import Photos
import AVKit


enum AwfulError: Error {
    case noDevice
    case sessionError
}

protocol VideoViewDelegate : class {
    func videoError(_ error: NSError);
}

typealias Devices = (front: AVCaptureDevice?, back: AVCaptureDevice?, audio: AVCaptureDevice?)

@objc
class VideoView : UIView, AVCaptureFileOutputRecordingDelegate {

    weak var delegate: VideoViewDelegate?

    var videoSession = VideoSessionManager.defaultManager

    var captureSession: AVCaptureSession?
    var videoDataOutput: AVCaptureMovieFileOutput?
    var previewLayer : AVCaptureVideoPreviewLayer?

    var focusSquare : CameraFocusSquare?

    var recording: Bool = false
    var recDispGrp : DispatchGroup?
    var titDispGrp: DispatchGroup?
    var semp : DispatchSemaphore? = nil
    var doneDispGroup: DispatchGroup?
    //
    let screenWidth = UIScreen.main.bounds.size.width

    var titleGenerated:Bool?
    var titleFilePath:URL?

    var devices : Devices!
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

    init(frame: CGRect, device: AVCaptureDevice?, orientation:UIDeviceOrientation) {
        super.init(frame: frame)
        initialize(device)
    }

    func initialize(_ device:AVCaptureDevice?) {
        devices = availableDevices()

        if let d = device {
            currentVideoDevice = d
        }
        else {
            currentVideoDevice = devices.back
        }
    }

    func startRecording(_ orientation:UIDeviceOrientation)
    {
        let fileURL = URL(fileURLWithPath: videoSession.newVideoPath());

        if captureSession!.isRunning {
            print("session running")
            if(videoDataOutput?.connection(with: AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.video)))?.isVideoOrientationSupported == true) {
                let vidConn = videoDataOutput?.connection(with: AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.video)))
                // I'm a little lost and I'm not sure why opposite orientation is required
                // but it always is, no matter which way the device is currently facing
                vidConn?.videoOrientation = oppositeOrientation(orientation)
            }
            videoDataOutput?.startRecording(to: fileURL, recordingDelegate: self)
            print("Started recording")
        }
    }

    func stopRecording(_ complete:@escaping (() -> Void))
    {
        if videoDataOutput != nil  && videoDataOutput!.isRecording {

            print("saving video \(videoDataOutput!.outputFileURL!.absoluteString)")
            let fileURL = videoDataOutput!.outputFileURL;
            GlobalUserInitiatedQueue.sync{
                self.recDispGrp = DispatchGroup()
                self.recDispGrp!.enter()
                print("stopping recording")
                self.videoDataOutput?.stopRecording()
                GlobalUserInitiatedQueue.async{
                    print("waiting for video recording to finish")
                    _ = self.recDispGrp!.wait(timeout: DispatchTime.distantFuture)
                    print("done waiting for recording to complete...")

                    // don't wait for copy to camera roll to finish
                    complete()

                    //copy to camera roll
                    self.doneDispGroup = DispatchGroup()
                    self.doneDispGroup!.enter()
                    self.copyFileToCameraRoll(fileURL!)
                    GlobalUtilityQueue.async{
                        print("waiting for video copy  to camera roll finish")
                        _ = self.doneDispGroup!.wait(timeout: DispatchTime.distantFuture)
                        print("done waiting for video copy  to camera roll finish.")
                    }
                }
            }


        }

    }

    func startSession(_ preview: Bool) throws
    {
        if let videoDevice = currentVideoDevice {

            do {

                try configureDevice(videoDevice)
                captureSession = AVCaptureSession()
                videoDataOutput = AVCaptureMovieFileOutput()

                // disable fragment writing to fix loss of audio
                // http://stackoverflow.com/questions/26768987/avcapturesession-audio-doesnt-work-for-long-videos
                // https://developer.apple.com/library/prerelease/ios/documentation/AVFoundation/Reference/AVCaptureMovieFileOutput_Class/index.html#//apple_ref/occ/instp/AVCaptureMovieFileOutput/movieFragmentInterval
                videoDataOutput?.movieFragmentInterval = CMTime.invalid;

                try captureSession!.addInput(AVCaptureDeviceInput(device: videoDevice))
                try captureSession!.addInput(AVCaptureDeviceInput(device: devices.audio!))

                if preview {
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
                    self.layer.addSublayer(self.previewLayer!)
                    self.previewLayer?.frame = self.layer.frame
                    self.previewLayer?.connection!.videoOrientation = .landscapeRight
                    self.captureSession?.startRunning()

                    if captureSession!.canAddOutput(videoDataOutput!)
                    {
                        captureSession!.addOutput(videoDataOutput!)
                    }
                }
            }
            catch let error as NSError{
                print("session error: ", error.description)
                throw error
            }

        }
    }

    func stopSession()
    {
        stopRecording({})
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        captureSession = nil

        print("stopped session, cleanup done!")
    }

    func configureDevice(_ device:AVCaptureDevice) throws {
        do {
            try device.lockForConfiguration()
        } catch let err as NSError{
            throw err
        }

        if (device.isFocusModeSupported(.continuousAutoFocus)) {
            device.focusMode = .continuousAutoFocus
        }

        if (device.isSmoothAutoFocusSupported) {
            device.isSmoothAutoFocusEnabled = true
        }

        device.unlockForConfiguration()
    }

    func availableDevices() -> Devices {
//        find a better solution here:  I need a listing of all devices on this phone INCLUDEING AUDIO DEVICES
//        OR I need to add logic to find and set audio devices seperately below around: VideoView.swift - line #230
        let videoDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes:
            [.builtInTrueDepthCamera, .builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video, position: .unspecified)
        let audioDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes:
            [.builtInMicrophone], mediaType: .audio, position: .unspecified)
        let devices = videoDiscoverySession.devices + audioDiscoverySession.devices
        var front : AVCaptureDevice?
        var back : AVCaptureDevice?
        var audio : AVCaptureDevice?

        // Loop through all the capture devices on this phone
        for device in devices {
            // Make sure this particular device supports video
            if device.hasMediaType(AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.video))) {
                // Finally check the position and confirm we've got the back camera
                if(device.position == .back) {
                    back = device
                }
                else if (device.position == .front) {
                    front = device
                }
            }

            if device.hasMediaType(AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.audio))) {
                audio = device
            }
        }

        return (front, back, audio)
    }

    func finalizeOutput(_ complete:@escaping (URL) -> Void) throws -> Void
    {
        try videoSession.exportVideoSession { (url) in
            print("Exported: ", url)

            self.authorizeAndCopyFile(url as URL)
            print("Copied: ", url)

            complete(url as URL)
        }
    }


    func authorizeAndCopyFile(_ fileURL: URL)

    {

        PHPhotoLibrary.requestAuthorization { status in
            switch (status)
            {

            case .authorized:

                // Permission Granted

                self.copyFileToCameraRoll(fileURL)
                //get the player ready to play the video
                //self.playVideo(fileURL)

            case .denied:

                // Permission Denied

                print("User denied")

            default:

                print("Restricted")

            }

        }

    }

    func copyFileToCameraRoll(_ fileURL: URL){

        print("saving...")

        PHPhotoLibrary.shared().performChanges({
            // Create a change request from the asset to be modified.
            let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)

            // Set a property of the request to change the asset itself.
            print(request?.description as Any)
            }, completionHandler: { success, error in
                // print("Finished updating asset. %@", (success ? "Success." : error!))
                // print("finished")
                self.doneDispGroup!.leave()
        })

    }

    func checkAllAuthorizations() -> Bool{
        self.recDispGrp = DispatchGroup()
        self.recDispGrp!.enter()
        AVCaptureDevice.requestAccess(for: AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.audio)), completionHandler: {(granted: Bool)-> Void in
            print("perm \(granted)")
            self.recDispGrp!.leave()
        })
        _ = self.recDispGrp!.wait(timeout: DispatchTime.distantFuture)
        //
        self.recDispGrp!.enter()
        AVCaptureDevice.requestAccess(for: AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.video)), completionHandler: {(granted: Bool)-> Void in
            print("perm \(granted)")
            self.recDispGrp!.leave()
        })
        _ = self.recDispGrp!.wait(timeout: DispatchTime.distantFuture)
        //
        self.recDispGrp!.enter()
        PHPhotoLibrary.requestAuthorization { (status : PHAuthorizationStatus) -> Void in
            print("perm \(status)")
            self.recDispGrp!.leave()
        }
        _ = self.recDispGrp!.wait(timeout: DispatchTime.distantFuture)

        let videoAccess = AVCaptureDevice.authorizationStatus(for: AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.video)))
        let audioAccess = AVCaptureDevice.authorizationStatus(for: AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.audio)))
        let photoLibAcces = PHPhotoLibrary.authorizationStatus()

        var retVal = true
        if audioAccess != AVAuthorizationStatus.authorized {
            print("got no microphone accesss...")
            retVal = false
        }

        if videoAccess != AVAuthorizationStatus.authorized {
            print("got no camera accesss...")
            retVal = false
        }

        if  photoLibAcces != PHAuthorizationStatus.authorized{
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



    func fileOutput(_ captureOutput: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?){
        self.recording=false
        if(error != nil)
        {
            delegate?.videoError(error! as NSError)

        }
        else {
            print("done recording -> \(outputFileURL)")
        }
        if self.recDispGrp != nil {
            GlobalUserInitiatedQueue.async {
                self.recDispGrp!.leave()
            }
        }

    }




    func fileOutput(_ captureOutput: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        self.recording=true
        print("started recording to -> \(fileURL)" )
    }


    func getFadeTransformAnimGrp() -> CAAnimationGroup {

        //
        let animation : CABasicAnimation = CABasicAnimation(keyPath: "transform.scale");
        animation.fromValue = NSValue(caTransform3D: CATransform3DMakeScale(1, 1,1))
        animation.toValue = NSValue(caTransform3D: CATransform3DMakeScale(1.5, 1, 1))
        animation.duration = 4
        animation.fillMode=CAMediaTimingFillMode.both
        animation.beginTime=AVCoreAnimationBeginTimeAtZero
        //

        //grouping above animations before initiating
        let animGrp = CAAnimationGroup()
        animGrp.beginTime=AVCoreAnimationBeginTimeAtZero
        animGrp.animations=[animation]
        animGrp.isRemovedOnCompletion=false
        animGrp.fillMode=CAMediaTimingFillMode.both
        animGrp.duration = 4
        //




        return animGrp
    }

    func getAssetForDevice() -> AVURLAsset {
        var assetName: String = "iphone6p"

        // These were too small. Also, we don't want to support individual iPhone models
        let model = UIDevice.current.modelName
        switch model {
            case "iPhone 4": assetName = "iphone4sbelow"
            case "iPhone 4s": assetName = "iphone4sbelow"
            case "iPhone 5": assetName = "iphone5"
            case "iPhone 5s": assetName = "iphone5"
            case "iPhone 5c": assetName = "iphone5"
            case "iPhone 6" : assetName = "iphone6"
            case "iPhone 6s" : assetName = "iphone6"
            case "iPhone 6 Plus" : assetName = "iphone6p"
            case "iPhone 6s Plus" : assetName = "iphone6p"
            default: assetName = "iphone6p"
        }

        return AVURLAsset(url:Bundle.main.url(forResource: assetName, withExtension:"mov")!)

    }



    func prepareTitleTrack(_ movieTitle: String?) throws {
        if let title = movieTitle {
            self.titleGenerated=false
            self.titDispGrp = DispatchGroup()
            self.titleFilePath = videoSession.titleTrackURL() as URL
            self.titDispGrp!.enter()
            print(title.endIndex)
            self.createAnimatedTitleVideo(title, animGrp: self.getFadeTransformAnimGrp)
            _ = self.titDispGrp!.wait(timeout: DispatchTime.distantFuture)
        }
        else {
            try videoSession.deleteTitleTrack()
        }
    }


    func createAnimatedTitleVideo(_ label: String, animGrp: @escaping ()-> CAAnimationGroup)  {


        //let dispGrp = dispatch_group_create()
        GlobalUserInteractiveQueue.async {


            //dispatch_group_enter(self.dispGrp)
            //mutable composition
            let comp = AVMutableComposition()
            //video asset
            let asset = self.getAssetForDevice()
            let track = comp.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
            let asset_track = asset.tracks(withMediaType: AVMediaType.video)[0]
            print(asset.tracks(withMediaType: AVMediaType.video)[0])
            do {
                try track!.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: asset.duration), of: asset_track, at: CMTime.zero)
            }
            catch let err as NSError {
                print(err)
            }
            print(asset.duration)
            //
            let animComp = AVMutableVideoComposition(propertiesOf: asset)

            let parentLayer = CALayer()
            let videoLayer = CALayer()
            print(animComp.frameDuration)
            parentLayer.frame=CGRect(x: 0, y: 0, width: animComp.renderSize.width,height: animComp.renderSize.height)
            videoLayer.frame=CGRect(x: 0,y: 0,width: animComp.renderSize.width,height: animComp.renderSize.height)
            parentLayer.addSublayer(videoLayer)
            //
            //asset layer
            let al = CALayer()
            al.opacity=1.0
            //al.position=CGPointMake(animComp.renderSize.width/2, animComp.renderSize.height/2)
            al.frame=CGRect(x: 0, y: 0, width: animComp.renderSize.width, height: animComp.renderSize.height)
            print("ANIM COMP SIZE", animComp.renderSize)

//            al.backgroundColor = UIColor.blueColor().CGColor
            al.isGeometryFlipped=false
            al.contentsGravity = convertToCALayerContentsGravity("center")
            al.anchorPoint=CGPoint(x: 0.5, y: 0.5)
            //animation
            let textLayer = CATextLayer()
            let pw = animComp.renderSize.width
            let ph = animComp.renderSize.height
            let w = pw * 0.66
            let lineHeight : CGFloat = 50.0
            textLayer.frame = CGRect(x: ((pw - w)/2), y: 0, width: w, height: ph/2 + lineHeight)
            textLayer.string = label
            let fontName: CFString = "HelveticaNeue-Bold" as CFString
            textLayer.font = CTFontCreateWithName(fontName, 10.0, nil)
            textLayer.foregroundColor = UIColor.white.cgColor
//            textLayer.backgroundColor = UIColor.redColor().CGColor
            textLayer.fontSize = 55.0;
            textLayer.contentsScale=UIScreen.main.scale*2
            textLayer.isWrapped = true
            textLayer.alignmentMode = CATextLayerAlignmentMode.center
            textLayer.opacity=1
            textLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)//



            textLayer.add(animGrp(), forKey: "chosenAnimation")
            al.addSublayer(textLayer)
            parentLayer.addSublayer(al)


            let animTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
            animComp.animationTool=animTool

            let compInstr = AVMutableVideoCompositionInstruction()
            compInstr.timeRange=CMTimeRangeMake(start: CMTime.zero, duration: asset.duration)
            let layerInstr = AVMutableVideoCompositionLayerInstruction(assetTrack: asset_track)
            layerInstr.setOpacity(1, at: CMTime.zero)


            compInstr.layerInstructions=[layerInstr]
            animComp.instructions=[compInstr]

            //
            let fileURL = self.titleFilePath!
            let filePath = self.titleFilePath!.path
            if FileManager.default.fileExists(atPath: filePath) {
                do {
                    try FileManager.default.removeItem(atPath: filePath)
                }
                catch let err as NSError {
                    print("Remove Title Error", err)
                }

            }
            print(self.titleFilePath!)

            let exportSession = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)
            exportSession?.outputURL=fileURL
            exportSession?.videoComposition=animComp
            exportSession?.outputFileType=AVFileType.mp4
            print(exportSession?.estimatedOutputFileLength as Any)
            exportSession?.exportAsynchronously(){
                switch exportSession!.status{
                case  AVAssetExportSession.Status.completed:
                    self.titleGenerated = true
                default:
                    print("cancelled \(String(describing: exportSession!.error))")

                }
                self.titDispGrp!.leave()
            }
        }
    }

    func getImageFromVideo(_ url: URL) throws -> UIImage{
        let asset = AVURLAsset(url: url, options: nil)
        let imgGenerator = AVAssetImageGenerator(asset: asset)
        do {
            let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
            // !! check the error before proceeding
            let uiImage = UIImage(cgImage: cgImage)
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
//    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
//        if let touchPoint = touches.first?.locationInView(self), device = currentVideoDevice, preview = previewLayer {
//
//            let focusPoint = preview.captureDevicePointOfInterestForPoint(touchPoint)
//
//        }
//    }

    func focusPoint(_ touchPoint:CGPoint) {
        guard let device = currentVideoDevice, let preview = previewLayer else {
            return

        }

        let focusPoint = preview.captureDevicePointConverted(fromLayerPoint: touchPoint)

        do {
            try device.lockForConfiguration()
        } catch let err as NSError {
            print("Device Lock Error:", err.description)
        }

        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = focusPoint
            device.focusMode = .continuousAutoFocus
        }

        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = focusPoint
            device.exposureMode = AVCaptureDevice.ExposureMode.autoExpose
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

    func oppositeOrientation(_ orientation:UIDeviceOrientation) -> AVCaptureVideoOrientation {
        if orientation == .landscapeRight {
            return .landscapeLeft
        }
        else {
            return .landscapeRight
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVMediaType(_ input: AVMediaType) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToCALayerContentsGravity(_ input: String) -> CALayerContentsGravity {
	return CALayerContentsGravity(rawValue: input)
}
