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
    case MissingAudio(url: NSURL, time:CMTime)
    case CompositionFailed(err: NSError)
    case CouldNotCreateExporter()
}

let TitleTrackName = "1title"

class VideoSessionManager: NSObject {
    
    static let defaultManager = VideoSessionManager()
    
    override init() {
        super.init()
        try! initializeSessionDir()
    }
    
    func exportVideo(sources: [NSURL], toURL: NSURL) throws -> Void {
        
        let composition = AVMutableComposition()
        let trackVideo:AVMutableCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: CMPersistentTrackID())
        let trackAudio:AVMutableCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: CMPersistentTrackID())
        
        // Stuff
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTimeMake(1,30)
        videoComposition.renderScale = 1.0
        
        let instruction = AVMutableVideoCompositionInstruction()
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: trackVideo)
        
        // Stuff
        
        let videoLayerInstruction = AVMutableVideoCompositionInstruction()
        videoLayerInstruction.layerInstructions = []
        
        
        var insertTime = kCMTimeZero
        
        do {
            for moviePathUrl in sources {
//                let moviePathUrl =  pathURL.URLByAppendingPathComponent(assetFile)
                let sourceAsset = AVURLAsset(URL: moviePathUrl, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true,AVURLAssetReferenceRestrictionsKey:0])
                let tracks = sourceAsset.tracksWithMediaType(AVMediaTypeVideo)
                var audios: [AVAssetTrack] = sourceAsset.tracksWithMediaType(AVMediaTypeAudio)
                if tracks.count > 0 {
                    
                    let assetTrack:AVAssetTrack = tracks[0]
                    
                    videoComposition.renderSize = assetTrack.naturalSize
                    layerInstruction.setTransform(assetTrack.preferredTransform, atTime: insertTime)
                    
                    try trackVideo.insertTimeRange(assetTrack.timeRange, ofTrack: assetTrack, atTime: insertTime)
                    
                    if audios.count > 0 {
                        let assetTrackAudio:AVAssetTrack = audios[0]
                   
                        try trackAudio.insertTimeRange(CMTimeRangeMake(kCMTimeZero,sourceAsset.duration), ofTrack: assetTrackAudio, atTime: insertTime)
                    }
                        
                    else if !moviePathUrl.absoluteString.containsString(TitleTrackName) {
                        throw VideoExportError.MissingAudio(url: moviePathUrl, time: insertTime)
                    }
                    
                    // set the transform / orientation from the original
                    // for transforms, etc
                    let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: trackVideo)
                    instruction.setTransform(assetTrack.preferredTransform, atTime: insertTime)
                    
                    videoLayerInstruction.layerInstructions.append(instruction)
                    
                    insertTime = CMTimeAdd(insertTime, sourceAsset.duration)
                    
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
            
            exporter.exportAsynchronouslyWithCompletionHandler({
                
                switch exporter.status{
                    
                case  AVAssetExportSessionStatus.Failed:
                    print("failed \(exporter.error)")
                    print(exporter.error?.localizedDescription)
                case AVAssetExportSessionStatus.Cancelled:
                    print("cancelled \(exporter.error)")
                default:
                    print("complete")
                }
            })
        }
        else {
            throw VideoExportError.CouldNotCreateExporter()
        }
    }
    
    func sessionFileDir() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let documentsDirectory = paths[0]
        let filePath:String = "\(documentsDirectory)/HomeMoviesSession"
        return filePath
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
                if file.containsString("full")
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
        
        if let url = urls.last {
            do {
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
        
        let fileUrls = files.map { (filePath) in
            return pathURL.URLByAppendingPathComponent(filePath)
        }
        
        return fileUrls
    }
    
    
}
