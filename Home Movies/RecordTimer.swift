//
//  RecordTimer.swift
//  Home Movies
//
//  Created by Sean Hess on 3/31/16.
//  Copyright © 2019 Zinc Collective LLC. All rights reserved.
//

import UIKit

class RecordTimer: UILabel {

    var timer:Timer?
    var startDate:Date?
    var elapsed:TimeInterval = 0

    var stoppedTime:TimeInterval = 0 {
        didSet {
            if timer == nil {
                self.text = stringFromTimeInterval(stoppedTime)
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.textAlignment = .center
    }

    func startTimer() {
        startDate = Date()
        elapsed = 0
        self.text = stringFromTimeInterval(0.0)
        timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(RecordTimer.updateTime(_:)), userInfo: nil, repeats: true)
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil

        // guess the new stop time
        self.text = stringFromTimeInterval(stoppedTime + elapsed)
    }

    @objc func updateTime(_ timer:Timer)
    {
        if let start = self.startDate {
            elapsed = Date().timeIntervalSince(start)
            self.text = stringFromTimeInterval(elapsed)
        }
    }

    func stringFromTimeInterval(_ interval: TimeInterval) -> String {
        let interval = Int(interval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

}
