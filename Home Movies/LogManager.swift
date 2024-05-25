//
//  LogManager.swift
//  Home Movies
//
//  Created by Cricket on 5/25/24.
//  Copyright © 2024 HomeMoviesDev. All rights reserved.
//

import os
import Sentry


protocol AppLogger {
    //https://theswiftdev.com/logging-for-beginners-in-swift
    // Consider: https://docs.sentry.io/platforms/apple/guides/macos/usage/#swift-errors
    func logError(_ error: Error)
    func logToConsole(_ message: String, _ level: OSLogType, _ category: LogManagerCategory)
}

enum LogManagerCategory: String {
    case recordVC       = "RecordViewController"
}


class LogManager: AppLogger {
    func logError(_ error: Error) {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "error")
        logger.log(level: .error, "###--> \(error.localizedDescription)")
        SentrySDK.capture(error: error)
    }
    
    func logToConsole(_ message: String, _ level: OSLogType = .debug, _ category: LogManagerCategory = .recordVC) {
        #if DEBUG
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: category.rawValue)
        logger.log(level: level, "###--> \(message)")
        #endif
    }
}
