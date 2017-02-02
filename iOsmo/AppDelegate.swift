//
//  AppDelegate.swift
//  iOsmo
//
//  Created by Olga Grineva on 07/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        if SettingsManager.getKey(SettingKeys.logView) == nil {
            UIApplication.shared.setStatusBarStyle(UIStatusBarStyle.lightContent, animated: true)
            if let tbc:UITabBarController = (window?.rootViewController as! UITabBarController){
                
                
                var vcs = tbc.viewControllers
                vcs?.removeLast()
                
                tbc.setViewControllers(vcs, animated: false)
                
            }
            
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) ->Void) -> Bool {
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            let webURL = userActivity.webpageURL!;
            if !presentViewController(url:webURL) {
                UIApplication.shared.openURL(webURL);
            }
            
        }
        
        return true;
    
    }
    
    func presentViewController(url:URL)->Bool {
        
        if let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true){
            if (url.host == "osmo.mobi" && url.pathComponents[2] == "g") {
                return true;
              }
            
        }
        
        return false;
    }
    

}

