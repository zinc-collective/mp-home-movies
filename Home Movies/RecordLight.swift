//
//  RecordLight.swift
//  Home Movies
//
//  Created by Sean Hess on 4/6/16.
//  Copyright © 2016 HomeMoviesDev. All rights reserved.
//

import UIKit

class RecordLight: UIView {
    
    var timer : NSTimer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    func initialize() {
        backgroundColor = UIColor.redColor()
        layer.cornerRadius = frame.width / 2.0
        startBlinking()
    }
    
    override var hidden: Bool {
        set(val) {
            super.hidden = val
            
            if val {
                stopBlinking()
            }
            else {
                startBlinking()
            }
        }
        
        get {
            return super.hidden
        }
    }
    
    func startBlinking() {
        stopBlinking()
        timer = NSTimer.scheduledTimerWithTimeInterval(0.600, target: self, selector: #selector(blink), userInfo: nil, repeats: true)
    }
    
    func blink() {
        super.hidden = !super.hidden
    }
    
    func stopBlinking() {
        if let t = timer {
            t.invalidate()
            timer = nil
        }
    }

}
