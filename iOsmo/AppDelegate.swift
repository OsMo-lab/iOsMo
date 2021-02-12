//
//  AppDelegate.swift
//  iOsmo
//
//  Created by Olga Grineva on 07/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2019 Alexey Sirotkin All rights reserved.
//

import UIKit
import UserNotifications

import FirebaseAnalytics
import FirebaseInstanceID
import FirebaseMessaging


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let connectionManager = ConnectionManager.sharedConnectionManager
    let groupManager = GroupManager.sharedGroupManager
    let log = LogQueue.sharedLogQueue
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    var localNotification: UILocalNotification? = nil;
    var appIsStarting: Bool = false;
    fileprivate var timer = Timer()
    
    let gcmMessageIDKey = "GCM" //"GCM"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        UIApplication.shared.registerForRemoteNotifications()

        
        // Use Firebase library to configure APIs
        FirebaseApp.configure()
        
        if let _ = launchOptions?[.remoteNotification] {
            self.appIsStarting = true;
        }
        
        // Override point for customization after application launch.
        
        _ = connectionManager.pushActivated.add{
            if $0  == 0{
                self.log.enqueue("CM.pushActivated")
            }
        }
        _ = connectionManager.sessionRun.add{
            let theChange = $0.0
            
            if theChange == 0 {
                self.displayNotification("OsMo — Tracker", NSLocalizedString("Tracking location", comment: "Tracking location"))
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
            Messaging.messaging().shouldEstablishDirectChannel = true;
        }
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        // [START set_messaging_delegate]
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
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        

        if SettingsManager.getKey(SettingKeys.locDistance)?.doubleValue == nil {
            SettingsManager.setKey("5", forKey: SettingKeys.locDistance)
        }
        
        if SettingsManager.getKey(SettingKeys.logView) == nil {
            if let tbc:UITabBarController = (window?.rootViewController as? UITabBarController){
                var vcs = tbc.viewControllers
                vcs?.removeLast()
                
                tbc.setViewControllers(vcs, animated: false)
            }
        }
        
        

        Analytics.logEvent("app_open", parameters: nil)
        if let url = launchOptions?[.url] as? URL {
            _ = presentViewController(url:url);
        }
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        self.appIsStarting = false;
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        self.appIsStarting = false;

        self.connectionManager.activatePoolGroups(-1)
        self.connectionManager.sendTrackUser("-1")
        self.groupManager.saveCache()
        
        if (connectionManager.connected && connectionManager.sessionOpened) {
            self.displayNotification("OsMo — Tracker", NSLocalizedString("Tracking location", comment: "Tracking location"))
        }
        
        if (connectionManager.connected && !connectionManager.sessionOpened) {
            if self.connectionManager.permanent == false {
                backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                    self?.endBackgroundTask()
                }
                connectionManager.timer.invalidate()
                DispatchQueue.main.async {
                    self.timer = Timer.scheduledTimer(timeInterval: 30.0, target: self, selector: #selector(self.disconnectByTimer), userInfo: nil, repeats: false)
                }
                
            }
            
        }
    }

    /*
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        log.enqueue("Firebase registration token: \(fcmToken)")
        
        let dataDict:[String: String] = ["token": fcmToken]
        //NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
 */
    
    public func displayNotification(_ title: String, _ body: String) {
        if self.localNotification == nil {
            self.localNotification = UILocalNotification()
            self.localNotification?.alertTitle = title
            self.localNotification?.alertBody = body
            
            //set the notification
            UIApplication.shared.presentLocalNotificationNow(self.localNotification!)
        }
    }
    
    @objc func connectOnActivate () {
        if !connectionManager.connected {
            connectionManager.connect()
        }
    }
    
    @objc func disconnectByTimer() {
        connectionManager.closeConnection()

        self.endBackgroundTask()
    }
    
    func endBackgroundTask() {
        print("Background task ended.")
        UIApplication.shared.endBackgroundTask(convertToUIBackgroundTaskIdentifier(backgroundTask.rawValue))
        backgroundTask = UIBackgroundTaskIdentifier.invalid
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        self.appIsStarting = true;
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        self.appIsStarting = false;
        if (backgroundTask != UIBackgroundTaskIdentifier.invalid) {
            UIApplication.shared.endBackgroundTask(convertToUIBackgroundTaskIdentifier(backgroundTask.rawValue))
            backgroundTask = UIBackgroundTaskIdentifier.invalid
        }

        if (self.localNotification != nil) {
            UIApplication.shared.cancelLocalNotification(self.localNotification!)
            self.localNotification = nil
        }
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().getDeliveredNotifications { (notifications) in
                if notifications.count > 0 {
                    self.log.enqueue ("unprocessed notification count: \(notifications.count)")
                    var identifiers: [String] = [];
                    
                    notifications.forEach({ (notification) in
                        DispatchQueue.main.async {
                            let userInfo = notification.request.content.userInfo
                            self.log.enqueue("userInfo : \(userInfo)")
                            if let messageID = userInfo[self.gcmMessageIDKey] {
                                self.log.enqueue("getDeliveredNotifications FCM : \(messageID)")
                                self.connectionManager.connection.parseOutput(messageID as! String)
                            }
                        }
                        identifiers.append( notification.request.identifier)
                        
                    })
                    if (identifiers.count > 0) {
                        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
                    }
                }
            }
        }
        
        
        
        UIApplication.shared.cancelAllLocalNotifications()
        
     }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) ->Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            let webURL = userActivity.webpageURL!;
            if !presentViewController(url:webURL) {
                UIApplication.shared.openURL(webURL);
            }
        }

        return true;
    
    }
    
    func presentViewController(url:URL)->Bool {
        if NSURLComponents(url: url, resolvingAgainstBaseURL: true) != nil{
            if (url.host == "osmo.mobi" && url.pathComponents[1] == "g" && url.pathComponents[2] != "") {
                let tbc:UITabBarController = (window?.rootViewController as! UITabBarController)
                let accountVC: AccountViewController = tbc.viewControllers![1] as! AccountViewController;
                tbc.selectedViewController = accountVC;
                accountVC.btnEnterGroupPress(_sender: self, url.pathComponents[2])
                
                return true;
              }
        }
        
        return false;
    }
    
    // [START receive_message]
    /* DEPRECATED
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // TODO: Handle data of notification
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            log.enqueue("FCM: \(messageID)")
            connectionManager.connection.parseOutput(messageID as! String)
        }
        // Print full message.
        //print(userInfo)
    }
 */
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        Messaging.messaging().appDidReceiveMessage(userInfo)
        log.enqueue("app didReceiveRemoteNotification \(userInfo)")
        
        // TODO: У нас есть 30 секунд !!!!!! на обработку события
        if let messageID = userInfo[gcmMessageIDKey] {
            log.enqueue("FCM: \(messageID)")
            connectionManager.connection.parseOutput(messageID as! String)
        }
        
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

    // MARK: - Background
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        ConnectionHelper.shared.backgroundCompletionHandler = completionHandler
    }
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
        
        if let messageID = userInfo[gcmMessageIDKey] {
            log.enqueue("FCM: \(messageID)")
            connectionManager.connection.parseOutput(messageID as! String)
        }
        
        // Change this to your preferred presentation option
        if UIApplication.shared.applicationState == .active {
            completionHandler([.badge, .alert])
        }else {
            completionHandler([.alert])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        log.enqueue("userNotificationCenter didReceive: \(userInfo)")

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
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
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
        
        if let messageID = data[gcmMessageIDKey] {
            log.enqueue("FCM: \(messageID)")
            connectionManager.connection.parseOutput(messageID as! String)
        }
    }
    // [END ios_10_data_message]
    
}
// [END ios_10_data_message_handling]

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIBackgroundTaskIdentifier(_ input: Int) -> UIBackgroundTaskIdentifier {
	return UIBackgroundTaskIdentifier(rawValue: input)
}
