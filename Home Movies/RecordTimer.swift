//
//  RecordTimer.swift
//  Home Movies
//
//  Created by Sean Hess on 3/31/16.
//  Copyright © 2016 HomeMoviesDev. All rights reserved.
//

import UIKit

class RecordTimer: UILabel {
    
    var timer:NSTimer?
    var startDate:NSDate?
    var elapsed:NSTimeInterval = 0
    
    var stoppedTime:NSTimeInterval = 0 {
        didSet {
            if timer == nil {
                self.text = stringFromTimeInterval(stoppedTime)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.textAlignment = .Center
    }

    func startTimer() {
        startDate = NSDate()
        elapsed = 0
        self.text = stringFromTimeInterval(0.0)
        timer = NSTimer.scheduledTimerWithTimeInterval(0.05, target: self, selector: #selector(RecordTimer.updateTime(_:)), userInfo: nil, repeats: true)
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        
        // guess the new stop time
        self.text = stringFromTimeInterval(stoppedTime + elapsed)
    }
    
    func updateTime(timer:NSTimer)
    {
        if let start = self.startDate {
            elapsed = NSDate().timeIntervalSinceDate(start)
            self.text = stringFromTimeInterval(elapsed)
        }
    }
    
    func stringFromTimeInterval(interval: NSTimeInterval) -> String {
        let interval = Int(interval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

}
