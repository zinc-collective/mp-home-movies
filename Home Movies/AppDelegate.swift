//
//  AppDelegate.swift
//  Home Movies
//
//  Created by sudhir on 9/2/15.
//  Copyright (c) 2015 HomeMoviesDev. All rights reserved.
//
import HockeySDK
import UIKit


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    var freeSpaceMb:Int32 = 0
    
    var fromBg = false

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        //
        //Override point for customization after application launch.
        BITHockeyManager.sharedHockeyManager().configureWithIdentifier("aeedf4d16dafdc8a2d7acf84c561df79")
        // Do some additional configuration if needed here
        //BITHockeyManager.sharedHockeyManager().disableCrashManager = true
        BITHockeyManager.sharedHockeyManager().startManager()
        BITHockeyManager.sharedHockeyManager().authenticator.authenticateInstallation()
        BITHockeyManager.sharedHockeyManager().testIdentifier()
        //
        if let bytes = deviceRemainingFreeSpaceInBytes() {
            freeSpaceMb = Int32(bytes/(1024*1024))
            print("free space: \(freeSpaceMb) Mb")
        }
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        self.fromBg = true
 
        
        
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        print("app entered foreground")
        
        
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func deviceRemainingFreeSpaceInBytes() -> Int64? {
        let documentDirectoryPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        if let systemAttributes = try? NSFileManager.defaultManager().attributesOfFileSystemForPath(documentDirectoryPath.last!) {
            if let freeSize = systemAttributes[NSFileSystemFreeSize] as? NSNumber {
                return freeSize.longLongValue
            }
        }
        // something failed
        return nil
    }
    
    



}

