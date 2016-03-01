//
//  RecordButtonView.swift
//  Home Movies
//
//  Created by sudhir on 9/2/15.
//  Copyright (c) 2015 HomeMoviesDev. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable

class RecordButtonView : UIButton {
    
    var record:Bool = false
    
    override func drawRect(rect: CGRect)
    {
        if record {
            
            //let inner = CGRectMake(rect.minX-10, rect.minY-10, rect.width-10,rect.height-10)
            
           
//            CGRectGetMidX(rect), CGRectGetMidY(rect)
            
            //let inner = CGRectMake( rect.minX-10, rect.minY-10, rect.width-10,rect.height-10)
            let inner = CGRectInset(rect, 10 ,10)
            var path = UIBezierPath(ovalInRect: inner)
            //UIColor.greenColor().setFill()
            //let r = CGFloat(50)
            //let g = CGFloat(205)
            //let b = CGFloat(50)
            //let a = CGFloat(1)
            //let uicolor = UIColor(red: r/255.0, green: g/255.0, blue: b/255.0, alpha: a)
            let uicolor = UIColor.redColor()
            uicolor.setFill();
            path.fill()
            path = UIBezierPath(ovalInRect: CGRectInset(rect, 3 ,3))
            path.lineWidth = CGFloat(3)
            UIColor.whiteColor().setStroke()
            path.stroke()
        }
        else
        {
            //self.layer.backgroundColor = UIColor.redColor().CGColor
            let inner = CGRectInset(rect, 15 ,15)
            let uicolor = UIColor.redColor()
            uicolor.setFill()
            UIRectFill(inner)
            let path = UIBezierPath(ovalInRect: CGRectInset(rect, 3 ,3))
            path.lineWidth = CGFloat(3)
            UIColor.whiteColor().setStroke()
            path.stroke()
        }
    }
}