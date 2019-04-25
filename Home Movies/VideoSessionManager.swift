//
//  VideoProcess.swift
//  Home Movies
//
//  Created by Sean Hess on 4/4/16.
//  Copyright © 2016 HomeMoviesDev. All rights reserved.
//

import UIKit
import AVFoundation

enum VideoExportError: Error {
    case missingAssets(url: URL, time:CMTime)
    case compositionFailed(err: NSError)
    case couldNotCreateExporter
    case noClips
}

let TitleTrackName = "1title"

class VideoSessionManager: NSObject {
    
    static let defaultManager = VideoSessionManager()
    
    let CompleteVideoName = "full"
    
    override init() {
        super.init()
        try! initializeSessionDir()
    }
    
    func exportVideoSession(_ complete:@escaping (URL) -> Void) throws -> Void {
        
        let completeMovieUrl = self.completeMovieURL()
        let fileUrls = sessionFileURLs()
        
        if (fileUrls.count < 0) {
            throw VideoExportError.noClips
        }
        
        try self.exportVideo(fileUrls, toURL: completeMovieUrl, complete: {
            print("Exported: ", completeMovieUrl)
            complete(completeMovieUrl)
        })
    }
    
    func exportVideo(_ sources: [URL], toURL: URL, complete:@escaping () -> Void) throws -> Void {
        
        // clean up old export target
        let mgr = FileManager.default
        if mgr.fileExists(atPath: toURL.path){
            try mgr.removeItem(at: toURL)
        }
        
        let composition = AVMutableComposition()
        let trackVideo:AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: CMPersistentTrackID())!
        let trackAudio:AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!
        
        
        // Composition (for getting the transforms right)
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTimeMake(value: 1,timescale: 30)
        videoComposition.renderScale = 1.0
        
        let instruction = AVMutableVideoCompositionInstruction()
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: trackVideo)
        let videoLayerInstruction = AVMutableVideoCompositionInstruction()
        videoLayerInstruction.layerInstructions = []
        
        let clipAssets = sources.map(assetsForURL)
        
        let mLargestClipSize = clipAssets
            .compactMap({ (assets) in assets.video?.naturalSize })
            .max(by: { (one, two) -> Bool in
                return one.height < two.height && one.width < two.width
            })
        
        if (mLargestClipSize == nil) {
            throw VideoExportError.noClips
        }
        
        let renderSize = mLargestClipSize!
        
        print("Largest Clip Size", renderSize)
        videoComposition.renderSize = renderSize
        
        var insertTime = CMTime.zero
        do {
            for assets in clipAssets {
                if let assetVideo = assets.video {
                    
                    print("Inserting Video: ", assets.url.lastPathComponent, assetVideo.naturalSize)
                    
                    // insert video
                    try trackVideo.insertTimeRange(assetVideo.timeRange, of: assetVideo, at: insertTime)
                    
                    // insert audio
                    if let assetAudio = assets.audio {
                        try trackAudio.insertTimeRange(assetAudio.timeRange, of: assetAudio, at: insertTime)
                    }
                    else if !assets.url.absoluteString.contains(TitleTrackName) {
                        throw VideoExportError.missingAssets(url: assets.url, time: insertTime)
                    }
                    
                    // set the transform / orientation from the original.
                    // start with the naturalSize to get the correct orientation of reverse camera, etc
                    let size = assetVideo.naturalSize
                    let scaleX = renderSize.width / size.width
                    let scale = CGAffineTransform(scaleX: scaleX, y: scaleX)
                    
                    layerInstruction.setTransform(
                            assetVideo.preferredTransform.concatenating(scale.concatenating(CGAffineTransform.identity
                            ))
                        , at: insertTime)
                    
//                    print(" - scale", scaleX)
//                    print(" - translateX", (size.width - renderSize.width))
                    
                    // increment the time
                    insertTime = CMTimeAdd(insertTime, assets.source.duration)
                }
            }
        }
            
        catch let err as NSError {
            throw VideoExportError.compositionFailed(err: err)
        }
        
        instruction.layerInstructions = [layerInstruction]
        instruction.timeRange = trackVideo.timeRange
        
        videoComposition.instructions = [instruction]
        
        if let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) {
            
            exporter.videoComposition = videoComposition
            
            exporter.outputURL = toURL
            
            exporter.outputFileType = AVFileType.mp4 //AVFileTypeQuickTimeMovie
            
            // export asynchronously!! Yikes!
            // what a bad idea!
            exporter.exportAsynchronously(completionHandler: {
                
                switch exporter.status {
                    case AVAssetExportSession.Status.failed:
                        print("failed \(String(describing: exporter.error))")
                        print(exporter.error?.localizedDescription ?? "Missing Error")
                    case AVAssetExportSession.Status.cancelled:
                        print("cancelled \(String(describing: exporter.error))")
                    default:
                        print("complete")
                        complete()
                }
            })
        }
        else {
            throw VideoExportError.couldNotCreateExporter
        }
    }
    
    func assetsForURL(_ url:URL) -> (url: URL, source: AVURLAsset, video: AVAssetTrack?, audio: AVAssetTrack?) {
        let sourceAsset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true, AVURLAssetReferenceRestrictionsKey:0])
        let videos = sourceAsset.tracks(withMediaType: AVMediaType.video)
        let audios = sourceAsset.tracks(withMediaType: AVMediaType.audio)
        return (url: url, source: sourceAsset, video: videos.first, audio: audios.first)
    }
    
    func sessionFileDir() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let filePath:String = "\(documentsDirectory)/HomeMoviesSession"
        return filePath
    }
    
    fileprivate func completeMovieURL() -> URL {
        let base = URL(fileURLWithPath: sessionFileDir())
        return base.appendingPathComponent(CompleteVideoName + ".mp4")
    }
    
    func titleTrackURL() -> URL {
        let dir = self.sessionFileDir()
        return URL(fileURLWithPath: dir).appendingPathComponent(TitleTrackName + ".mp4")
    }
    
    func deleteTitleTrack() throws {
        let url = titleTrackURL()
        let mgr = FileManager.default
        if mgr.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    func initializeSessionDir() throws {
        let manager = FileManager.default
        let dir = sessionFileDir()
        if (!manager.fileExists(atPath: dir)) {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: false, attributes: nil)
        }
    }
    
    func cleanupSessionDir() throws {
        let dir = self.sessionFileDir()
        try FileManager.default.removeItem(atPath: dir)
        try self.initializeSessionDir()
    }
    
    
    func newVideoPath() -> String {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss.SSS"
        let dateTimePrefix: String = formatter.string(from: Date())
        
        let path = self.sessionFileDir()
        
        let filePath:String = "\(path)/\(dateTimePrefix).mp4"
        return filePath
    }
    
    func getClipsCount() -> Int {
        var count: Int = 0
        do {
            let path = sessionFileDir()
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            for file in contents {
                count = count + 1
                if file.contains(TitleTrackName)
                {
                    count = count - 1
                }
                if file.contains(CompleteVideoName)
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
                try FileManager.default.removeItem(at: url)
            }
            catch _ {
                print("Could not delete url: ", url)
            }
        }
    }
    
    // doesn't always work, especially right after finishing recording
    func sessionDuration() -> TimeInterval {
        let urls = sessionFileURLs()
        let durations:[TimeInterval] = urls.map(assetsForURL).map({(_, source, video, _) in
            return CMTimeGetSeconds(source.duration)
        })
        
        return durations.reduce(0, +)
    }
    
    func sessionFileURLs() -> [URL] {
        let dir = sessionFileDir()
        let fileMgr = FileManager.default
        var files = [String]()
        
        let pathURL = URL(fileURLWithPath: dir)
        
        do {
            try files = fileMgr.contentsOfDirectory(atPath: dir)
        }
        catch _ {
            return []
        }
        
        let fileUrls = files.compactMap { filePath -> URL? in
            if (filePath.contains(CompleteVideoName)) {
                return nil
            }
            else {
                return pathURL.appendingPathComponent(filePath)
            }
        }
        
        return fileUrls
    }
    
    
}
