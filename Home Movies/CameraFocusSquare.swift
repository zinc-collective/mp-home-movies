//
//  CameraFocusSquare.swift
//  Home Movies
//
//  Created by Sean Hess on 4/1/16.
//  Copyright © 2019 Zinc Collective LLC. All rights reserved.
//


func delay(_ delay:Double, closure:@escaping ()->()) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}

import UIKit

class CameraFocusSquare: UIView {


    fileprivate var _selectionBlink : CABasicAnimation!
    fileprivate var _completion : () -> Void

    required init?(coder aDecoder: NSCoder) {
        _completion = {}
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        _completion = {}
        super.init(frame: frame)

        backgroundColor = UIColor.clear
        layer.borderWidth = 1.0
        layer.cornerRadius = 0.0
        layer.borderColor = UIColor.yellow.cgColor
    }

    class func centerFrame(size:CGFloat, center: CGPoint) -> CGRect {
        return CGRect(x: center.x - size/2, y: center.y - size/2, width: size, height: size)
    }

    func animate(_ completion: @escaping () -> Void) {
        self.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)

        UIView.animate(withDuration: 0.300, animations: {
            self.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        }, completion: {(completed) in
            delay(0.500) {
                completion()
            }
        })
    }
}
