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
    var onGroupCreated: ObserverSetEntry<(Bool, String)>?
    
    // add name of group in return
    let groupEntered = ObserverSet<(Bool, String)>()
    let groupCreated = ObserverSet<(Bool, String)>()
    let groupLeft = ObserverSet<(Bool, String)>()
    let groupActivated = ObserverSet<(Bool, String)>()
    let pushActivated = ObserverSet<Bool>()
    let groupDeactivated = ObserverSet<(Bool, String)>()
    let groupList = ObserverSet<[Group]>()
    let trackDownoaded = ObserverSet<(Track)>()
    
    let connectionRun = ObserverSet<(Bool, String)>()
    let sessionRun = ObserverSet<(Bool, String)>()
    let groupsEnabled = ObserverSet<Bool>()
    let messageOfTheDayReceived = ObserverSet<(Bool, String)>()
    let connectionStart = ObserverSet<()>()
    let dataSendStart = ObserverSet<()>()
    let dataSendEnd = ObserverSet<()>()
    
    let monitoringGroupsUpdated = ObserverSet<[UserGroupCoordinate]>()
    
    fileprivate let log = LogQueue.sharedLogQueue
    
    //fileprivate var connection = TcpConnection()
    var connection = TcpConnection()

    fileprivate var reachability: Reachability
    fileprivate let aSelector : Selector = #selector(ConnectionManager.reachabilityChanged(_:))
    open var shouldReConnect = false
    
    class var sharedConnectionManager : ConnectionManager{
        
        struct Static {
            static let instance: ConnectionManager = ConnectionManager()
        }
        
        return Static.instance
    }

    override init(){
        
        self.reachability = Reachability.forInternetConnection()
        
        super.init()
        NotificationCenter.default.addObserver(self, selector: aSelector, name: NSNotification.Name.reachabilityChanged, object: self.reachability)
        
        self.reachability.startNotifier()
        
        //!! subscribtion for almost all types events
        connection.answerObservers.add(notifyAnswer)

    }
    
    open func reachabilityChanged(_ note: Notification) {
        log.enqueue("reachability changed")
        if let reachability = note.object as? Reachability {
            checkStatus(reachability)
        }
    }
    
    
    open var sessionUrl: String? { get { return self.connection.getSessionUrl() } }
    
    open var TrackerID: String? { get { return self.connection.getTrackerID() } }
    
    open var connected: Bool = false
    open var sessionOpened: Bool = false
 
    open func connect(_ reconnect: Bool = false){
        log.enqueue("ConnectionManager: connect")
        self.connectionStart.notify(())
        
        if !ConnectionManager.hasConnectivity() {
            shouldReConnect = true
            return
        }
        ConnectionHelper.getServerInfo(completed: {result, token -> Void in
            if (result) {
                /*Информация о сервере получена*/
                if self.connection.addCallBackOnError == nil {
                    self.connection.addCallBackOnError = {
                        (isError : Bool) -> Void in
                        self.shouldReConnect = isError
                        
                        if ((self.connected || reconnect) && isError) {
                            self.log.enqueue("CallBackOnError: should be reconnected")
                            self.shouldReConnect = true;
                        }
                        self.connected = false
                        
                        //self.checkStatus(self.reachability)
                        self.connectionRun.notify((false, ""))
                        
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
                if self.connection.addCallBackOnConnect == nil {
                    self.connection.addCallBackOnConnect = {
                        () -> Void in
                        self.connection.sendAuth(token!.device_key as String)
                    }
                }

                self.connection.connect(token!)
                self.shouldReConnect = false //interesting why here? may after connction is successful??
            } else {
                if (token?.error.isEmpty)! {
                    self.connectionRun.notify((false, ""))
                    self.shouldReConnect = false
                } else {
                    print("getServerInfo Error:\(token?.error)")
                    self.log.enqueue("getServerInfo Error:\(token?.error)")
                    if (token?.error == "Wrong device key") {
                        SettingsManager.setKey("", forKey: SettingKeys.device)
                        self.connectionRun.notify((false, ""))
                        self.shouldReConnect = true
                    } else {
                        self.connectionRun.notify((false, "\(token?.error)"))
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
    
    open func createGroup(_ name: String, email: String, phone: String, gtype: String, priv: Bool){
        if self.connected{
            if self.onGroupCreated == nil {
                
                self.onGroupCreated = connection.groupCreated.add {
                    self.groupCreated.notify($0)
                }
            }

            
            connection.sendCreateGroup(name, email: email, phone: phone, gtype: gtype, priv: priv)
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
    
    fileprivate func notifyAnswer(_ tag: AnswTags, name: String, answer: Bool){
        if tag == AnswTags.token {
            //means response to try connecting
            print("connected")
            log.enqueue("connected")
            
            self.connected = answer
            connectionRun.notify(answer, name)
            
            return
        }
        if tag == AnswTags.auth {
            //means response to try connecting
            print("connected")
            log.enqueue("connected")
            
            self.connected = answer
            connectionRun.notify(answer, name)
            
            return
        }
        if tag == AnswTags.enterGroup{
            groupEntered.notify(answer, name)
            
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
            self.sessionOpened = answer
            sessionRun.notify(answer, name)
            
            return
        }
        
        if tag == AnswTags.closeSession {
            self.sessionOpened = answer
            sessionRun.notify(answer, name)
            
            return
        }
        
        if tag == AnswTags.messageDay {
            messageOfTheDayReceived.notify(answer, name)
            
            return
        }
        
        if tag == AnswTags.remoteCommand {
            let sendingManger = SendingManager.sharedSendingManager
            if (name == RemoteCommand.TRACKER_SESSION_STOP.rawValue){
                closeSession()
                connection.sendRemoteCommandResponse(name)

                return
            }
            if (name == RemoteCommand.TRACKER_SESSION_START.rawValue){
                sendingManger.startSendingCoordinates(name)
                connection.sendRemoteCommandResponse(name)
                
                return
            }
            if (name == RemoteCommand.TRACKER_SESSION_PAUSE.rawValue){
                sendingManger.pauseSendingCoordinates()
                connection.sendRemoteCommandResponse(name)
                return
            }
            if (name == RemoteCommand.TRACKER_SESSION_CONTINUE.rawValue){
                sendingManger.startSendingCoordinates(name)
                connection.sendRemoteCommandResponse(name)
                return
            }
            if (name == RemoteCommand.TRACKER_GCM_ID.rawValue) {
                
                if let token = SettingsManager.getKey(SettingKeys.pushToken) as String! {
                    self.sendPush(token)
                }
                connection.sendRemoteCommandResponse(name)
                return
            }
        }
    }


    fileprivate func checkStatus(_ reachability: Reachability){
        
        let status: NetworkStatus = reachability.currentReachabilityStatus()
        
        if status.rawValue == NotReachable.rawValue && self.connected {
            
            log.enqueue("should be reconnected")
            shouldReConnect = true;
            
            connectionRun.notify((false, "")) //error but is not need to be popuped
            
         }
        
        if shouldReConnect /*&& (status.rawValue == ReachableViaWiFi.rawValue || status.rawValue == ReachableViaWWAN.rawValue)*/ {
            
            log.enqueue("Reconnect action")
            print("Reconnect action from Reachability")
            connect(true)
        }
        
    }
    
    class fileprivate func hasConnectivity() -> Bool {
        
        let reachability: Reachability = Reachability.forInternetConnection()
        let networkStatus: Int = reachability.currentReachabilityStatus().rawValue
        
        return networkStatus != 0
    }

    
}
