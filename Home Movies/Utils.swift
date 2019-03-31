//
//  Utils.swift
//  Home Movies
//
//  Created by sudhir on 9/3/15.
//  Copyright (c) 2015 HomeMoviesDev. All rights reserved.
//

import Foundation


var GlobalMainQueue: DispatchQueue {
    return DispatchQueue.main
}

var GlobalUserInteractiveQueue: DispatchQueue {
    return DispatchQueue.global(priority: Int(DispatchQoS.QoSClass.userInteractive.rawValue))
}

var GlobalUserInitiatedQueue: DispatchQueue {
    return DispatchQueue.global(priority: Int(DispatchQoS.QoSClass.userInitiated.rawValue))
}

var GlobalUtilityQueue: DispatchQueue {
    return DispatchQueue.global(priority: Int(DispatchQoS.QoSClass.utility.rawValue))
}

var GlobalBackgroundQueue: DispatchQueue {
    return DispatchQueue.global(priority: Int(DispatchQoS.QoSClass.background.rawValue))
}

