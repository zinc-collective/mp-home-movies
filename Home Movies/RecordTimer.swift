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
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.textAlignment = .Center
    }

    func startTimer() {
        startDate = NSDate()
        timer = NSTimer.scheduledTimerWithTimeInterval(1.00, target: self, selector: "updateTime:", userInfo: nil, repeats: true)
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        self.text = stringFromTimeInterval(0.0)
    }
    
    func updateTime(timer:NSTimer)
    {
        if let start = self.startDate {
            let elapsed: NSTimeInterval = NSDate().timeIntervalSinceDate(start)
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
