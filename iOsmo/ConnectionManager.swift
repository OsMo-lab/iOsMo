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
    
    // add name of group in return
    let groupEntered = ObserverSet<(Bool, String)>()
    let groupCreated = ObserverSet<(Bool, String)>()
    let groupLeft = ObserverSet<(Bool, String)>()
    let groupList = ObserverSet<[Group]>()
    let connectionRun = ObserverSet<(Bool, String)>()
    let sessionRun = ObserverSet<(Bool, String)>()
    let groupsEnabled = ObserverSet<Bool>()
    
    let monitoringGroupsUpdated = ObserverSet<[UserGroupCoordinate]>()
    
    fileprivate let log = LogQueue.sharedLogQueue
    
    fileprivate var connection = TcpConnection()
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
    
    open var connected: Bool = false
    open var sessionOpened: Bool = false
 
    open func connect(_ reconnect: Bool = false){
        log.enqueue("ConnectionManager: connect")
        
        if !ConnectionManager.hasConnectivity() {
            
            shouldReConnect = true
            return
        }
        //if (!reconnect || token == nil) { token = ConnectionHelper.getToken()} //-- "Он одноразовый"
       if let tkn = ConnectionHelper.connectToServ() {
        
            if tkn.error.isEmpty {
                
                if connection.addCallBackOnError == nil {
                    connection.addCallBackOnError = {
                        (isError : Bool) -> Void in
                        self.connected = false
                        self.shouldReConnect = isError
                        self.checkStatus(self.reachability)
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
    
    open func openSession(){
        log.enqueue("ConnectionManager: open session")
        
        if connected {
            
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
                
                self.onGroupListUpdated = connection.groupListDownloaded.add {self.groupList.notify($0)}
            }
            connection.sendGetGroups()
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

    open func activateAllGroups(){
        if self.connected {
            connection.sendActivateAllGroups()
        }
    }
    
    
    
    open func deactivateAllGroups(){
        if self.connected {
            connection.sendDeactivateAllGroups()
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
        }
        if tag == AnswTags.auth {
            //means response to try connecting
            print("connected")
            log.enqueue("connected")
            
            self.connected = answer
            connectionRun.notify(answer, name)
        }
        if tag == AnswTags.enterGroup{
            
            groupEntered.notify(answer, name)
            
        }

        if tag == AnswTags.leaveGroup {
            
            groupLeft.notify(answer, name)
        }
        if tag == AnswTags.openedSession {
        
            self.sessionOpened = answer
            sessionRun.notify(answer, name)
        }
        if tag == AnswTags.allGroupsEnabled {
            
            groupsEnabled.notify(answer)
        }
        if tag == AnswTags.remoteCommand {
            if (name == RemoteCommand.TRACKER_SESSION_STOP.rawValue){
                closeSession()
                
            }
            if (name == RemoteCommand.TRACKER_SESSION_START.rawValue){
                openSession()
                
            }
            if (name == RemoteCommand.TRACKER_SESSION_PAUSE.rawValue){
                
                
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
