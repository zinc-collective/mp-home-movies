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
    return DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive)
}

var GlobalUserInitiatedQueue: DispatchQueue {
    return DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated)
}

var GlobalUtilityQueue: DispatchQueue {
    return DispatchQueue.global(qos: DispatchQoS.QoSClass.utility)
}

var GlobalBackgroundQueue: DispatchQueue {
    return DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
}

