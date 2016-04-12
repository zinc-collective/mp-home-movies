//
//  VideoProcess.swift
//  Home Movies
//
//  Created by Sean Hess on 4/4/16.
//  Copyright © 2016 HomeMoviesDev. All rights reserved.
//

import UIKit
import AVFoundation

enum VideoExportError: ErrorType {
    case MissingAssets(url: NSURL, time:CMTime)
    case CompositionFailed(err: NSError)
    case CouldNotCreateExporter()
    case NoClips()
}

let TitleTrackName = "1title"

class VideoSessionManager: NSObject {
    
    static let defaultManager = VideoSessionManager()
    
    let CompleteVideoName = "full"
    
    override init() {
        super.init()
        try! initializeSessionDir()
    }
    
    func exportVideoSession(complete:(NSURL) -> Void) throws -> Void {
        
        let completeMovieUrl = self.completeMovieURL()
        let fileUrls = sessionFileURLs()
        
        if (fileUrls.count < 0) {
            throw VideoExportError.NoClips()
        }
        
        try self.exportVideo(fileUrls, toURL: completeMovieUrl, complete: {
            print("Exported: ", completeMovieUrl)
            complete(completeMovieUrl)
        })
    }
    
    func exportVideo(sources: [NSURL], toURL: NSURL, complete:() -> Void) throws -> Void {
        
        // clean up old export target
        let mgr = NSFileManager.defaultManager()
        if mgr.fileExistsAtPath(toURL.path!){
            try mgr.removeItemAtURL(toURL)
        }
        
        let composition = AVMutableComposition()
        let trackVideo:AVMutableCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: CMPersistentTrackID())
        let trackAudio:AVMutableCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: CMPersistentTrackID())
        
        
        // Composition (for getting the transforms right)
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTimeMake(1,30)
        videoComposition.renderScale = 1.0
        
        let instruction = AVMutableVideoCompositionInstruction()
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: trackVideo)
        let videoLayerInstruction = AVMutableVideoCompositionInstruction()
        videoLayerInstruction.layerInstructions = []
        
        let clipAssets = sources.map(assetsForURL)
        
        let mLargestClipSize = clipAssets
            .flatMap({ (assets) in assets.video?.naturalSize })
            .maxElement({ (one, two) -> Bool in
                return one.height < two.height && one.width < two.width
            })
        
        if (mLargestClipSize == nil) {
            throw VideoExportError.NoClips()
        }
        
        let renderSize = mLargestClipSize!
        
        print("Largest Clip Size", renderSize)
        videoComposition.renderSize = renderSize
        
        var insertTime = kCMTimeZero
        do {
            for assets in clipAssets {
                if let assetVideo = assets.video {
                    
                    print("Inserting Video: ", assets.url.lastPathComponent, assetVideo.naturalSize)
                    
                    // insert video
                    try trackVideo.insertTimeRange(assetVideo.timeRange, ofTrack: assetVideo, atTime: insertTime)
                    
                    // insert audio
                    if let assetAudio = assets.audio {
                        try trackAudio.insertTimeRange(assetAudio.timeRange, ofTrack: assetAudio, atTime: insertTime)
                    }
                    else if !assets.url.absoluteString.containsString(TitleTrackName) {
                        throw VideoExportError.MissingAssets(url: assets.url, time: insertTime)
                    }
                    
                    // set the transform / orientation from the original. It scales from the bottom right
                    // start with the naturalSize to get the correct orientation of reverse camera, etc
                    let size = assetVideo.naturalSize
                    let scaleX = renderSize.width / size.width
                    let move = CGAffineTransformTranslate(assetVideo.preferredTransform, (size.width - renderSize.width), (size.height - renderSize.height))
                    let moveAndScale = CGAffineTransformScale(move, scaleX, scaleX)
                    layerInstruction.setTransform(moveAndScale, atTime: insertTime)
//                    print(" - scale", scaleX)
//                    print(" - translateX", (size.width - renderSize.width))
                    
                    // increment the time
                    insertTime = CMTimeAdd(insertTime, assets.source.duration)
                }
            }
        }
            
        catch let err as NSError {
            throw VideoExportError.CompositionFailed(err: err)
        }
        
        instruction.layerInstructions = [layerInstruction]
        instruction.timeRange = trackVideo.timeRange
        
        videoComposition.instructions = [instruction]
        
        if let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) {
            
            exporter.videoComposition = videoComposition
            
            exporter.outputURL = toURL
            
            exporter.outputFileType = AVFileTypeMPEG4 //AVFileTypeQuickTimeMovie
            
            // export asynchronously!! Yikes!
            // what a bad idea!
            exporter.exportAsynchronouslyWithCompletionHandler({
                
                switch exporter.status {
                    case AVAssetExportSessionStatus.Failed:
                        print("failed \(exporter.error)")
                        print(exporter.error?.localizedDescription)
                    case AVAssetExportSessionStatus.Cancelled:
                        print("cancelled \(exporter.error)")
                    default:
                        print("complete")
                        complete()
                }
            })
        }
        else {
            throw VideoExportError.CouldNotCreateExporter()
        }
    }
    
    func assetsForURL(url:NSURL) -> (url: NSURL, source: AVURLAsset, video: AVAssetTrack?, audio: AVAssetTrack?) {
        let sourceAsset = AVURLAsset(URL: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true, AVURLAssetReferenceRestrictionsKey:0])
        let videos = sourceAsset.tracksWithMediaType(AVMediaTypeVideo)
        let audios = sourceAsset.tracksWithMediaType(AVMediaTypeAudio)
        return (url: url, source: sourceAsset, video: videos.first, audio: audios.first)
    }
    
    func sessionFileDir() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let documentsDirectory = paths[0]
        let filePath:String = "\(documentsDirectory)/HomeMoviesSession"
        return filePath
    }
    
    private func completeMovieURL() -> NSURL {
        let base = NSURL.fileURLWithPath(sessionFileDir())
        return base.URLByAppendingPathComponent(CompleteVideoName + ".mp4")
    }
    
    func titleTrackURL() -> NSURL {
        let dir = self.sessionFileDir()
        return NSURL(fileURLWithPath: dir).URLByAppendingPathComponent(TitleTrackName + ".mp4")
    }
    
    func deleteTitleTrack() throws {
        let url = titleTrackURL()
        let mgr = NSFileManager.defaultManager()
        if mgr.fileExistsAtPath(url.path!) {
            try NSFileManager.defaultManager().removeItemAtURL(url)
        }
    }
    
    func initializeSessionDir() throws {
        let manager = NSFileManager.defaultManager()
        let dir = sessionFileDir()
        if (!manager.fileExistsAtPath(dir)) {
            try NSFileManager.defaultManager().createDirectoryAtPath(dir, withIntermediateDirectories: false, attributes: nil)
        }
    }
    
    func cleanupSessionDir() throws {
        let dir = self.sessionFileDir()
        try NSFileManager.defaultManager().removeItemAtPath(dir)
        try self.initializeSessionDir()
    }
    
    
    func newVideoPath() -> String {
        let formatter: NSDateFormatter = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss.SSS"
        let dateTimePrefix: String = formatter.stringFromDate(NSDate())
        
        let path = self.sessionFileDir()
        
        let filePath:String = "\(path)/\(dateTimePrefix).mp4"
        return filePath
    }
    
    func getClipsCount() -> Int {
        var count: Int = 0
        do {
            let path = sessionFileDir()
            let contents = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(path)
            for file in contents {
                count = count + 1
                if file.containsString(TitleTrackName)
                {
                    count = count - 1
                }
                if file.containsString(CompleteVideoName)
                {
                    count = count - 1
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
    
    func deleteLastClip () {
        let urls = sessionFileURLs()
        
        if let url = urls.last  {
            do {
                print("URL", url.lastPathComponent)
                try NSFileManager.defaultManager().removeItemAtURL(url)
            }
            catch _ {
                print("Could not delete url: ", url)
            }
        }
    }
    
    func sessionFileURLs() -> [NSURL] {
        let dir = sessionFileDir()
        let fileMgr = NSFileManager.defaultManager()
        var files = [String]()
        
        let pathURL = NSURL(fileURLWithPath: dir)
        
        do {
            try files = fileMgr.contentsOfDirectoryAtPath(dir)
        }
        catch _ {
            return []
        }
        
        let fileUrls = files.flatMap { filePath -> NSURL? in
            if (filePath.containsString(CompleteVideoName)) {
                return nil
            }
            else {
                return pathURL.URLByAppendingPathComponent(filePath)
            }
        }
        
        return fileUrls
    }
    
    
}
