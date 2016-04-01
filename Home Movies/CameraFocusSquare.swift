//
//  CameraFocusSquare.swift
//  Home Movies
//
//  Created by Sean Hess on 4/1/16.
//  Copyright © 2016 HomeMoviesDev. All rights reserved.
//


func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

import UIKit

class CameraFocusSquare: UIView {

    
    private var _selectionBlink : CABasicAnimation!
    private var _completion : () -> Void
    
    required init?(coder aDecoder: NSCoder) {
        _completion = {}
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        _completion = {}
        super.init(frame: frame)
        
        backgroundColor = UIColor.clearColor()
        layer.borderWidth = 1.0
        layer.cornerRadius = 0.0
        layer.borderColor = UIColor.yellowColor().CGColor
    }
    
    class func centerFrame(size size:CGFloat, center: CGPoint) -> CGRect {
        return CGRect(x: center.x - size/2, y: center.y - size/2, width: size, height: size)
    }
    
    func animate(completion: () -> Void) {
        self.transform = CGAffineTransformMakeScale(1.5, 1.5)
            
        UIView.animateWithDuration(0.300, animations: {
            self.transform = CGAffineTransformMakeScale(1.0, 1.0)
        }, completion: {(completed) in
            delay(0.500) {
                completion()
            }
        })
    }
}
