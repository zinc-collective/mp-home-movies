//
//  RecordButtonView.swift
//  Home Movies
//
//  Created by sudhir on 9/2/15.
//  Copyright © 2019 Zinc Collective LLC. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable

class RecordButtonView : UIButton {

    fileprivate var _recording:Bool = false

    var recording: Bool {
        get {
            return _recording
        }
        set(newValue) {
            _recording = newValue
            self.setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect)
    {
        if !_recording {

            //let inner = CGRectMake(rect.minX-10, rect.minY-10, rect.width-10,rect.height-10)


//            CGRectGetMidX(rect), CGRectGetMidY(rect)

            //let inner = CGRectMake( rect.minX-10, rect.minY-10, rect.width-10,rect.height-10)
            let inner = rect.insetBy(dx: 10 ,dy: 10)
            var path = UIBezierPath(ovalIn: inner)
            //UIColor.greenColor().setFill()
            //let r = CGFloat(50)
            //let g = CGFloat(205)
            //let b = CGFloat(50)
            //let a = CGFloat(1)
            //let uicolor = UIColor(red: r/255.0, green: g/255.0, blue: b/255.0, alpha: a)
            let uicolor = UIColor.red
            uicolor.setFill();
            path.fill()
            path = UIBezierPath(ovalIn: rect.insetBy(dx: 3 ,dy: 3))
            path.lineWidth = CGFloat(3)
            UIColor.white.setStroke()
            path.stroke()
        }
        else
        {
            //self.layer.backgroundColor = UIColor.redColor().CGColor
            let inner = rect.insetBy(dx: 15 ,dy: 15)
            let uicolor = UIColor.red
            uicolor.setFill()
            UIRectFill(inner)
            let path = UIBezierPath(ovalIn: rect.insetBy(dx: 3 ,dy: 3))
            path.lineWidth = CGFloat(3)
            UIColor.white.setStroke()
            path.stroke()
        }
    }
}
