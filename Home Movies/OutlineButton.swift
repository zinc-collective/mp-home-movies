//
//  OutlineButton.swift
//  Home Movies
//
//  Created by Sean Hess on 4/6/16.
//  Copyright © 2019 Zinc Collective LLC. All rights reserved.
//

import UIKit

class OutlineButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }

    func initialize() {
        layer.borderWidth=CGFloat(1.0)
        layer.borderColor = UIColor.white.cgColor
        layer.cornerRadius = CGFloat(5.0)
    }

}
