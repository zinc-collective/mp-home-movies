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

class VideoProcess: NSObject {
    
    class func exportVideo(sources: [NSURL], toURL: NSURL) throws -> Void {
        
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
    
}
