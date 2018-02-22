//
//  AppDelegate.swift
//  iOsmo
//
//  Created by Olga Grineva on 07/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2017 Alexey Sirotkin All rights reserved.
//

import UIKit
import UserNotifications

import FirebaseAnalytics
import FirebaseInstanceID
import FirebaseMessaging


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var connectionManager = ConnectionManager.sharedConnectionManager
    let log = LogQueue.sharedLogQueue
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    var localNotification: UILocalNotification? = nil;
    
    fileprivate var timer = Timer()
    
    let gcmMessageIDKey = "GCM"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Use Firebase library to configure APIs
        FirebaseApp.configure()
        
        // Override point for customization after application launch.
        connectionManager.pushActivated.add{
            if $0  == 0{
                self.log.enqueue("connectionManager.pushActivated")
            }
            //self.activateSwitcher.isOn = $0
        }
        connectionManager.sessionRun.add{
            let theChange = $0.0
            
            if theChange == 0 {
                self.displayNotification()
                
            } else {
                
            }
        }

        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self
            
            
            // For iOS 10 data message (sent via FCM)
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        
        
        // [START set_messaging_delegate]
        Messaging.messaging().shouldEstablishDirectChannel = true;
        Messaging.messaging().delegate = self
        // [END set_messaging_delegate]
        
        // Add observer for InstanceID token refresh callback.
        
        /*
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.tokenRefreshNotification),
                                               name: .firInstanceIDTokenRefresh,
                                               object: nil)
 */
        // [END add_token_refresh_observer]
        
        //Добавляем обработчик возврата из background-а для восстановления связи с сервером
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.connectOnActivate),
                                               name: NSNotification.Name.UIApplicationWillEnterForeground,
                                               object: nil)
        
        if SettingsManager.getKey(SettingKeys.sendTime)?.doubleValue == nil {
            SettingsManager.setKey("5", forKey: SettingKeys.sendTime)
        }

        if SettingsManager.getKey(SettingKeys.locDistance)?.doubleValue == nil {
            SettingsManager.setKey("5", forKey: SettingKeys.locDistance)
        }
        UIApplication.shared.setStatusBarStyle(UIStatusBarStyle.lightContent, animated: true)
        if SettingsManager.getKey(SettingKeys.logView) == nil {
            if let tbc:UITabBarController = (window?.rootViewController as? UITabBarController){
                var vcs = tbc.viewControllers
                vcs?.removeLast()
                
                tbc.setViewControllers(vcs, animated: false)
            }
        }
        
        UIApplication.shared.registerForRemoteNotifications()

        Analytics.logEvent("app_open", parameters: nil)
        if let url = launchOptions?[.url] as? URL {
            presentViewController(url:url);
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


        self.connectionManager.activatePoolGroups(-1)
        if (connectionManager.connected && connectionManager.sessionOpened) {
            self.displayNotification()
        }
        
        if (connectionManager.connected && !connectionManager.sessionOpened) {
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.endBackgroundTask()
            }
            DispatchQueue.main.async {
                self.timer = Timer.scheduledTimer(timeInterval: 30.0, target: self, selector: #selector(self.disconnectByTimer), userInfo: nil, repeats: false)
            }
        }
    }

    func displayNotification() {
        if self.localNotification == nil {
            self.localNotification = UILocalNotification()
            self.localNotification?.alertBody = NSLocalizedString("Tracking location", comment: "Tracking location")
            
            //set the notification
            UIApplication.shared.presentLocalNotificationNow(self.localNotification!)
        }
    }
    
    func connectOnActivate () {
        if !connectionManager.connected {
            connectionManager.connect()
        }
        
    }
    
    func disconnectByTimer() {
        connectionManager.closeConnection()
        self.endBackgroundTask()
    }
    
    func endBackgroundTask() {
        print("Background task ended.")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = UIBackgroundTaskInvalid
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if (backgroundTask != UIBackgroundTaskInvalid) {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = UIBackgroundTaskInvalid
        }
        //self.connectToFcm()
        if (self.localNotification != nil) {
            UIApplication.shared.cancelLocalNotification(self.localNotification!)
            self.localNotification = nil
        }
        UIApplication.shared.cancelAllLocalNotifications()
        
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
            if (url.host == "osmo.mobi" && url.pathComponents[1] == "g" && url.pathComponents[2] != "") {
                /*let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let accountVC = storyboard.instantiateViewController(withIdentifier: "AccountViewController")
                    as! AccountViewController
                */
                
                if let tbc:UITabBarController = (window?.rootViewController as! UITabBarController){

                    let accountVC: AccountViewController = tbc.viewControllers![1] as! AccountViewController;
                    
                    tbc.selectedViewController = accountVC;
                    
                    accountVC.btnEnterGroupPress(_sender: self, url.pathComponents[2])
                }
                return true;
              }
            
        }
        
        return false;
    }
    
    // [START receive_message]
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // TODO: Handle data of notification
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            log.enqueue("FCM: \(messageID)")
            log.enqueue(messageID as! String)
            connectionManager.connection.parseOutput(messageID as! String)
        }
        // Print full message.
        //print(userInfo)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // TODO: Handle data of notification
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            log.enqueue("FCM: \(messageID)")
            log.enqueue(messageID as! String)
            
            connectionManager.connection.parseOutput(messageID as! String)
        }
        
        // Print full message.
        //print(userInfo)
        
        completionHandler(UIBackgroundFetchResult.newData)
    }
    // [END receive_message]
    
    
    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        if notificationSettings.types != [.alert, .badge, .sound] {
            application.registerForRemoteNotifications()
        }
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        log.enqueue("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    // This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
    // If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
    // the InstanceID token.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        var token: String = ""
        for i in 0..<deviceToken.count {
            token += String(format: "%02.2hhx", deviceToken[i] as CVarArg)
        }
    
        log.enqueue("APNs token retrieved: \(token)")

        // With swizzling disabled you must set the APNs token here.
        Messaging.messaging().apnsToken = deviceToken
        //Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
    }
    

    // [END connect_on_active]
	}


// [START ios_10_message_handling]
@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        
        let userInfo = notification.request.content.userInfo
        log.enqueue("userNotificationCenter willPresent: \(userInfo)")
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            log.enqueue("FCM: \(messageID)")
            log.enqueue(messageID as! String)
            connectionManager.connection.parseOutput(messageID as! String)
        }
        
        // Print full message.
        //print(userInfo)
        
        // Change this to your preferred presentation option
        completionHandler([])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        log.enqueue("userNotificationCenter didReceive: \(userInfo)")
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            log.enqueue("FCM: \(messageID)")
            connectionManager.connection.parseOutput(messageID as! String)
        }
        Messaging.messaging().appDidReceiveMessage(userInfo)

        
        completionHandler()
    }
}
// [END ios_10_message_handling]
// [START ios_10_data_message_handling]
extension AppDelegate : MessagingDelegate {

    // [START refresh_token]
    func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
        log.enqueue("Firebase registration token: \(fcmToken)")
        connectionManager.sendPush(fcmToken)
        
    }
    // [END refresh_token]
    
    
    // [START ios_10_data_message]
    // Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
    // To enable direct data messages, you can set Messaging.messaging().shouldEstablishDirectChannel to true.
    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        let data = remoteMessage.appData
        log.enqueue("Received remote message: \(remoteMessage.appData)")
        
        // Print message ID.
        if let messageID = data[gcmMessageIDKey] {
            log.enqueue("FCM: \(messageID)")
            connectionManager.connection.parseOutput(messageID as! String)
        }
    }
    // [END ios_10_data_message]
    
}
// [END ios_10_data_message_handling]
