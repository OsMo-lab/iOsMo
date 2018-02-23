//
//  ConnectionManager.swift
//  iOsmo
//
//  Created by Olga Grineva on 13/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2016 Alexey Sirotkin All rights reserved.
//
// implementations of Singleton: https://github.com/hpique/SwiftSingleton
// implement http://stackoverflow.com/questions/9810585/how-to-get-reachability-notifications-in-ios-in-background-when-dropping-wi-fi-n


import Foundation
import FirebaseInstanceID
import FirebaseMessaging


open class ConnectionManager: NSObject{

    var monitoringGroupsHandler: ObserverSetEntry<[UserGroupCoordinate]>?
    var monitoringGroups: [Int] {
        
        get {
            return self.connection.monitoringGroups!
        }
        set (newValue){
            
            self.connection.monitoringGroups = newValue
            if newValue.count > 0 && self.monitoringGroupsHandler == nil {
                
                self.monitoringGroupsHandler = connection.monitoringGroupsUpdated.add({
                    self.monitoringGroupsUpdated.notify($0)
                    })
            }
            if newValue.count == 0 && self.monitoringGroupsHandler != nil {
                
                connection.monitoringGroupsUpdated.remove(self.monitoringGroupsHandler!)
                self.monitoringGroupsHandler = nil
            }
            
        }
    }
    
    var onGroupListUpdated: ObserverSetEntry<[Group]>?
    var onGroupCreated: ObserverSetEntry<(Int, String)>?
    
    // add name of group in return
    let groupEntered = ObserverSet<(Int, String)>()
    let groupCreated = ObserverSet<(Int, String)>()
    let groupLeft = ObserverSet<(Int, String)>()
    let groupActivated = ObserverSet<(Int, String)>()
    let pushActivated = ObserverSet<Int>()
    let groupDeactivated = ObserverSet<(Int, String)>()
    let groupList = ObserverSet<[Group]>()
    let trackDownoaded = ObserverSet<(Track)>()
    
    let connectionRun = ObserverSet<(Int, String)>()
    let sessionRun = ObserverSet<(Int, String)>()
    let groupsEnabled = ObserverSet<Int>()
    let messageOfTheDayReceived = ObserverSet<(Int, String)>()
    let connectionClose = ObserverSet<()>()
    let connectionStart = ObserverSet<()>()
    let dataSendStart = ObserverSet<()>()
    let dataSendEnd = ObserverSet<()>()
    
    let monitoringGroupsUpdated = ObserverSet<[UserGroupCoordinate]>()
    
    fileprivate let log = LogQueue.sharedLogQueue
    
    //fileprivate var connection = TcpConnection()
    var connection = TcpConnection()

    let reachability = Reachability()!
    
    fileprivate let aSelector : Selector = #selector(ConnectionManager.reachabilityChanged(_:))
    open var shouldReConnect = false
    open var isGettingLocation = false
    
    class var sharedConnectionManager : ConnectionManager{
        
        struct Static {
            static let instance: ConnectionManager = ConnectionManager()
        }
        
        return Static.instance
    }

    override init(){
        super.init()
        NotificationCenter.default.addObserver(self, selector: aSelector, name: NSNotification.Name.reachabilityChanged, object: self.reachability)
        do  {
            try self.reachability.startNotifier()
        }catch{
            print("could not start reachability notifier")
        }

        
        //!! subscribtion for almost all types events
        connection.answerObservers.add(notifyAnswer)

    }
    
    open func reachabilityChanged(_ note: Notification) {
        log.enqueue("reachability changed")
        let reachability = note.object as! Reachability
        
        switch reachability.connection {
            case .wifi:
                reachabilityStatus = .reachableViaWiFi
                print("Reachable via WiFi")
                if (!self.connected) {
                    log.enqueue("should be reconnected via WiFi")
                    shouldReConnect = true;
                }
            
            case .cellular:
                reachabilityStatus = .reachableViaWWAN
                print("Reachable via Cellular")
                if (!self.connected) {
                    log.enqueue("should be reconnected via Cellular")
                    shouldReConnect = true;
                }
            case .none:
                reachabilityStatus = .notReachable
                if (self.connected) {
                    log.enqueue("should be reconnected")
                    shouldReConnect = true;
                    
                    connectionRun.notify((1, "")) //error but is not need to be popuped
                }
            

        }
        if shouldReConnect /*&& (status.rawValue == ReachableViaWiFi.rawValue || status.rawValue == ReachableViaWWAN.rawValue)*/ {
            
            log.enqueue("Reconnect action")
            connect(true)
        }
    }
    
    
    open var sessionUrl: String? { get { return self.connection.getSessionUrl() } }
    
    open var TrackerID: String? { get { return self.connection.getTrackerID() } }
    
    open var connected: Bool = false
    open var sessionOpened: Bool = false
    private var connecting: Bool = false
 
    open func connect(_ reconnect: Bool = false){
        log.enqueue("ConnectionManager: connect")
        if self.connecting {
            log.enqueue("Conection already in process")
            return;
        }
        self.connecting = true;
        if !isNetworkAvailable {
            log.enqueue("Network is NOT available")
            shouldReConnect = true
            self.connecting = false;
            return
        }
        self.connectionStart.notify(())
        
        
        ConnectionHelper.getServerInfo(completed: {result, token -> Void in
            if (result) {
                /*Информация о сервере получена*/
                if self.connection.addCallBackOnError == nil {
                    self.connection.addCallBackOnError = {
                        (isError : Bool) -> Void in
                        self.connecting = false
                        self.shouldReConnect = isError
                        
                        if ((self.connected || reconnect) && isError) {
                            self.shouldReConnect = true;
                        }
                        self.connected = false
                        
                        self.connectionRun.notify((1, ""))
                        
                        if (self.shouldReConnect) {
                            self.connect(self.shouldReConnect)
                        }
                    }
                }
                if self.connection.addCallBackOnSendStart == nil {
                    self.connection.addCallBackOnSendStart = {
                        () -> Void in
                        self.dataSendStart.notify(())
                    }
                }
                if self.connection.addCallBackOnSendEnd == nil {
                    self.connection.addCallBackOnSendEnd = {
                        () -> Void in
                        self.dataSendEnd.notify(())
                    }
                }
                if self.connection.addCallBackOnCloseConnection == nil {
                    self.connection.addCallBackOnCloseConnection = {
                        () -> Void in
                        self.connecting = false
                        self.connectionClose.notify(())
                    }
                }
                if self.connection.addCallBackOnConnect == nil {
                    self.connection.addCallBackOnConnect = {
                        () -> Void in
                        self.connecting = false
                        self.connection.sendAuth(token!.device_key as String)
                    }
                }

                self.connection.connect(token!)
                self.shouldReConnect = false //interesting why here? may after connction is successful??
            } else {
                self.connecting = false
                if (token?.error.isEmpty)! {
                    self.connectionRun.notify((1, ""))
                    self.shouldReConnect = false
                } else {
                    print("getServerInfo Error:\(token?.error)")
                    self.log.enqueue("getServerInfo Error:\(token?.error)")
                    if (token?.error == "Wrong device key") {
                        SettingsManager.setKey("", forKey: SettingKeys.device)
                        self.connectionRun.notify((1, ""))
                        self.shouldReConnect = true
                    } else {
                        self.connectionRun.notify((1, "\(token?.error)"))
                        self.shouldReConnect = false
                    }
                    
                }
            }
        })
    }
    
    open func closeConnection() {
        if (self.connected && !self.sessionOpened) {
            connection.closeConnection()
            self.connection.addCallBackOnConnect = nil
            self.connected = false
        }
    }
    
    open func openSession(){
        log.enqueue("ConnectionManager: open session")
        if (self.connected && !self.sessionOpened) {
            connection.openSession()
       }
    }

    open func closeSession(){
        log.enqueue("ConnectionManager: close session")
        
        if self.connected {
            connection.closeSession()
        }
    }
    
    open func sendCoordinate(_ coordinate: LocationModel) {
        connection.sendCoordinate(coordinate)
    }
    
    open func sendCoordinates(_ coordinates: [LocationModel])
    {
        if self.sessionOpened {
            connection.sendCoordinates(coordinates)
        }
    }
    
    
    // Groups funcs
    open func getGroups(){
        if self.connected {
            if self.onGroupListUpdated == nil {
                
                self.onGroupListUpdated = connection.groupListDownloaded.add {
                    self.groupList.notify($0)
                    
                }
            }
            connection.sendGetGroups()
        }
    }
    
    open func createGroup(_ name: String, email: String, nick: String, gtype: String, priv: Bool){
        if self.connected{
            if self.onGroupCreated == nil {
                
                self.onGroupCreated = connection.groupCreated.add {
                    self.groupCreated.notify($0)
                }
            }

            
            connection.sendCreateGroup(name, email: email, nick: nick, gtype: gtype, priv: priv)
        }
    }
    
    open func enterGroup(_ name: String, nick: String){
        if self.connected{
            connection.sendEnterGroup(name, nick: nick)
        }
    }
    
    open func leaveGroup(_ u: String){
        if self.connected {
            connection.sendLeaveGroup(u)
        }
    }

    
    open func activatePoolGroups(_ s: Int){
        if self.connected {
            connection.sendActivatePoolGroups(s)
        }
    }
    
    open func groupsSwitch(_ s: Int){
        if self.connected {
            connection.sendGroupsSwitch(s)
        }
    }
    
    
    open func activateGroup(_ u: String){
        if self.connected {
            connection.sendActivateGroup(u)
        }
        
    }
    
    open func deactivateGroup(_ u: String){
        if self.connected {
            connection.sendDeactivateGroup(u)
        }
        
    }
    
    open func getMessageOfTheDay(){
        if self.connected{
            connection.sendMessageOfTheDay()
        }
    }
    
    open func sendPush(_ token: String){
        if self.connected{
            connection.sendPush(token)
        }
    }

    
    //MARK private methods
    
    fileprivate func notifyAnswer(_ tag: AnswTags, name: String, answer: Int){
        if tag == AnswTags.token {
            //means response to try connecting

            log.enqueue("connected with token")
            
            self.connected = answer != 0;
            connectionRun.notify(answer , name)
            
            return
        }
        if tag == AnswTags.auth {
            //means response to try connecting
            log.enqueue("connected with Auth")
            
            self.connected = answer == 0;
            if (answer == 100) {
                SettingsManager.setKey("", forKey: SettingKeys.user)
                SettingsManager.setKey("", forKey: SettingKeys.device)
                closeConnection()
                connect()
                
            } else {
                connectionRun.notify(answer, name)
            }
            
            return
        }
        if tag == AnswTags.enterGroup{
            groupEntered.notify(answer,  name)
            
            return
        }

        if tag == AnswTags.leaveGroup {
            groupLeft.notify(answer, name)
            
            return
        }
        
        if tag == AnswTags.activateGroup {
            groupActivated.notify(answer, name)
            
            return
        }
        if tag == AnswTags.push {
            pushActivated.notify(answer)
            return
        }
        
        if tag == AnswTags.deactivateGroup {
            groupDeactivated.notify(answer, name)
            
            return
        }
        

        if tag == AnswTags.openedSession {
            self.sessionOpened = answer == 0;
            sessionRun.notify(answer, name)
            
            return
        }
        
        if tag == AnswTags.closeSession {
            self.sessionOpened = answer != 1;
            sessionRun.notify((answer != 1 ? 1 : 0, name))
            
            return
        }
        
        if tag == AnswTags.messageDay {
            messageOfTheDayReceived.notify(answer, name)
            return
        }
        
        if tag == AnswTags.remoteCommand {
            let sendingManger = SendingManager.sharedSendingManager
            if (name == RemoteCommand.TRACKER_BATTERY_INFO.rawValue){
                sendingManger.sendBatteryStatus(name)
                return
            }
            
            if (name == RemoteCommand.TRACKER_SYSTEM_INFO.rawValue){
                sendingManger.sendSystemInfo()
                return
            }

            if (name == RemoteCommand.TRACKER_SESSION_STOP.rawValue){
                sendingManger.stopSendingCoordinates(name)

                return
            }
            if (name == RemoteCommand.TRACKER_EXIT.rawValue){
                sendingManger.stopSendingCoordinates(name)
                connection.closeConnection()
                return
            }
            if (name == RemoteCommand.TRACKER_SESSION_START.rawValue){
                sendingManger.startSendingCoordinates(name)
                return
            }
            if (name == RemoteCommand.TRACKER_SESSION_PAUSE.rawValue){
                sendingManger.pauseSendingCoordinates(name)
                return
            }
            if (name == RemoteCommand.TRACKER_SESSION_CONTINUE.rawValue){
                sendingManger.startSendingCoordinates(name)
                return
            }
            if (name == RemoteCommand.TRACKER_GCM_ID.rawValue) {
                //Отправляем токен ранее полученный от FCM
                if let token = Messaging.messaging().fcmToken {
                    self.sendPush(token)
                }
                connection.sendRemoteCommandResponse(name)
                return
            }
            
            if (name == RemoteCommand.REFRESH_GROUPS.rawValue){
                connection.sendGetGroups()
                connection.sendRemoteCommandResponse(name)
                return
            }

            if (name == RemoteCommand.WHERE.rawValue) {
                connection.sendRemoteCommandResponse(name)
                if self.sessionOpened == false {
                    self.isGettingLocation = true
                    sendingManger.startSendingCoordinates(name)
                }
                return
            }
        }
    }


    var isNetworkAvailable : Bool {
        return reachabilityStatus != .notReachable
    }
    var reachabilityStatus: Reachability.NetworkStatus = .notReachable
    /*
    
    class fileprivate func hasConnectivity() -> Bool {
        
        
        
        let reachability: Reachability = Reachability.NetworkReachable
        reachability.
        let networkStatus: Int = Reachability.NetworkReachable
        
        return networkStatus != 0
    }*/

    
}
