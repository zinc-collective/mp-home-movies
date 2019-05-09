//
//  RecordLight.swift
//  Home Movies
//
//  Created by Sean Hess on 4/6/16.
//  Copyright © 2016 HomeMoviesDev. All rights reserved.
//

import UIKit

class RecordLight: UIView {
    
    var timer : Timer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    func initialize() {
        backgroundColor = UIColor.red
        layer.cornerRadius = frame.width / 2.0
        startBlinking()
    }
    
    override var isHidden: Bool {
        set(val) {
            super.isHidden = val
            
            if val {
                stopBlinking()
            }
            else {
                startBlinking()
            }
        }
        
        get {
            return super.isHidden
        }
    }
    
    func startBlinking() {
        stopBlinking()
        timer = Timer.scheduledTimer(timeInterval: 0.600, target: self, selector: #selector(blink), userInfo: nil, repeats: true)
    }
    
    @objc func blink() {
        super.isHidden = !super.isHidden
    }
    
    func stopBlinking() {
        if let t = timer {
            t.invalidate()
            timer = nil
        }
    }

}
