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

open class ConnectionManager: NSObject{

    var monitoringGroupsHandler: ObserverSetEntry<[UserGroupCoordinate]>?
    var monitoringGroups: [Int] {
        
        get {return self.connection.monitoringGroups!}
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
    let connectionRun = ObserverSet<(Bool, String)>()
    let sessionRun = ObserverSet<(Bool, String)>()
    let groupsEnabled = ObserverSet<Bool>()
    let messageOfTheDayReceived = ObserverSet<(Bool, String)>()
    
    
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
        
        if !ConnectionManager.hasConnectivity() {
            shouldReConnect = true
            return
        }

       if let tkn = ConnectionHelper.connectToServ() {
        
            if tkn.error.isEmpty {
                if connection.addCallBackOnError == nil {
                    connection.addCallBackOnError = {
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
                connection.connect(tkn)
                shouldReConnect = false //interesting why here? may after connction is successful??
            } else {
                connectionRun.notify((false, "\(tkn.error)"))
                shouldReConnect = false
            }
        } else {
            connectionRun.notify((false, "")) //token is missing
            shouldReConnect = true
        }
    }
    
    open func closeConnection() {
        if (self.connected && !self.sessionOpened) {
            connection.closeConnection()
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
            if (name == RemoteCommand.TRACKER_SESSION_STOP.rawValue){
                closeSession()
                
                return
            }
        
            if (name == RemoteCommand.TRACKER_SESSION_START.rawValue){
                //openSession()
                let sendingManger = SendingManager.sharedSendingManager
                sendingManger.startSendingCoordinates()
                return
            }
            if (name == RemoteCommand.TRACKER_SESSION_PAUSE.rawValue){
                let sendingManger = SendingManager.sharedSendingManager
                sendingManger.pauseSendingCoordinates()
                                
                return
            }
            if (name == RemoteCommand.TRACKER_SESSION_CONTINUE.rawValue){
                let sendingManger = SendingManager.sharedSendingManager
                sendingManger.startSendingCoordinates()
                
                
                return
            }
        }
        
        /// etc
    }


    fileprivate func checkStatus(_ reachability: Reachability){
        
        let status: NetworkStatus = reachability.currentReachabilityStatus()
        
        if status.rawValue == NotReachable.rawValue && self.connected {
            
            log.enqueue("should be reconnected")
            shouldReConnect = true;
            
            connectionRun.notify((false, "reconnect")) //error but is not need to be popuped
            
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
