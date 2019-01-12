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

let authUrl = URL(string: "https://api.osmo.mobi/new?")
let servUrl = URL(string: "https://api.osmo.mobi/serv?") // to get server info
let iOsmoAppKey = "hD74_vDa3Lc_3rDs"
let apiUrl = URL(string: "https://api.osmo.mobi/inProx?")

open class ConnectionManager: NSObject{

    private let bgController = ConnectionHelper()
    var monitoringGroupsHandler: ObserverSetEntry<[UserGroupCoordinate]>?

    var onGroupListUpdated: ObserverSetEntry<[Group]>?
    var onGroupCreated: ObserverSetEntry<(Int, String)>?
    
    // add name of group in return
    let groupEntered = ObserverSet<(Int, String)>()
    let groupCreated = ObserverSet<(Int, String)>()
    let groupLeft = ObserverSet<(Int, String)>()
    let groupActivated = ObserverSet<(Int, String)>()
    let groupsUpdated = ObserverSet<(Int, Any)>()
    
    let pushActivated = ObserverSet<Int>()
    let groupDeactivated = ObserverSet<(Int, String)>()
    let groupListDownloaded = ObserverSet<[Group]>()
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
    
    let conHelper = ConnectionHelper()
    
    let monitoringGroupsUpdated = ObserverSet<[UserGroupCoordinate]>()
    
    fileprivate let log = LogQueue.sharedLogQueue
    private var Authenticated = false

    open var device_key: String = ""
    open var permanent: Bool = false
    open var sessionTrackerID: String = ""
    open func getTrackerID()-> String?{return sessionTrackerID}
    private var sessionUrlParsed: String = ""
    
    open func getSessionUrl() -> String? {return "https://osmo.mobi/s/\(sessionUrlParsed)"}

    
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
    
    
    func getServerInfo(key:String?) {
        
        conHelper.onCompleted = {(dataURL, data) in
            LogQueue.sharedLogQueue.enqueue("CM.getServerInfo.onCompleted")
            var res : NSDictionary = [:]
            var tkn : Token?;
            do {
                let jsonDict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers);
                res = (jsonDict as? NSDictionary)!
                if let server = res[Keys.address.rawValue] as? String {
                    let server_arr = server.components(separatedBy: ":")
                    if server_arr.count > 1 {
                        if let tknPort = Int(server_arr[1]) {
                            tkn =  Token(tokenString:"", address: server_arr[0], port: tknPort, key: key! as String)
                            self.completed(result: true,token: tkn)
                            return
                        }
                    }
                    self.completed(result: true, token: tkn)
                } else {
                    self.completed(result: false, token: tkn)
                }
            } catch {
                LogQueue.sharedLogQueue.enqueue("error serializing JSON from POST")
                self.completed(result: false, token: tkn)
            }
            
        }
        LogQueue.sharedLogQueue.enqueue("CM.getServerInfo")
        let requestString = "app=\(iOsmoAppKey)"
        conHelper.backgroundRequest(servUrl!, requestBody: requestString as NSString)
        
    }
    
    func Authenticate () {
        let device = SettingsManager.getKey(SettingKeys.device)
        if device == nil || device?.length == 0{
            let vendorKey = UIDevice.current.identifierForVendor!.uuidString
            let model = UIDevice.current.model
            let version = UIDevice.current.systemVersion
            LogQueue.sharedLogQueue.enqueue("CM.Authenticate:getting key from server")
            let requestString = "app=\(iOsmoAppKey)&id=\(vendorKey)&imei=0&platform=\(model) iOS \(version)"
            
            conHelper.onCompleted = {(dataURL, data) in
                LogQueue.sharedLogQueue.enqueue("CM.Authenticate.onCompleted")
                var res : NSDictionary = [:]

                do {
                     let jsonDict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers);
                    res = (jsonDict as? NSDictionary)!

                    if let newKey = res[Keys.device.rawValue] as? String {
                        LogQueue.sharedLogQueue.enqueue("CM.Authenticate: got key from server \(newKey)")
                        SettingsManager.setKey(newKey as NSString, forKey: SettingKeys.device)
                        self.Authenticated = true
                        self.getServerInfo(key: newKey)
                        
                    } else {

                    }

                } catch {
                    LogQueue.sharedLogQueue.enqueue("CM.Authenticate: error serializing key")
                }
                
            }
            
            
            conHelper.backgroundRequest(authUrl!, requestBody: requestString as NSString)
        } else {
            LogQueue.sharedLogQueue.enqueue("CM.Authenticate:using local key \(device)")
            self.Authenticated = true
            self.getServerInfo(key: device as! String)
        }
    }
    
    open func reachabilityChanged(_ note: Notification) {
        log.enqueue("CM.reachability changed")
        let reachability = note.object as! Reachability
        reachabilityStatus = reachability.connection
        switch reachability.connection {
            case .wifi:
                //reachabilityStatus = .reachableViaWiFi
                print("Reachable via WiFi")
                if (!self.connected) {
                    log.enqueue("should be reconnected via WiFi")
                    shouldReConnect = true;
                }
            
            case .cellular:
                //reachabilityStatus = .reachableViaWWAN
                print("Reachable via Cellular")
                if (!self.connected) {
                    log.enqueue("should be reconnected via Cellular")
                    shouldReConnect = true;
                }
            case .none:
                //reachabilityStatus = .notReachable
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
    
    
    open var sessionUrl: String? { get { return self.getSessionUrl() } }
    
    open var TrackerID: String? { get { return self.getTrackerID() } }
    
    open var connected: Bool = false
    open var sessionOpened: Bool = false
    private var connecting: Bool = false
 
    private func completed (result: Bool, token: Token?) {
        if (result) {
            /*Информация о сервере получена*/
            if self.connection.addCallBackOnError == nil {
                self.connection.addCallBackOnError = {
                    (isError : Bool) -> Void in
                    
                    self.connecting = false
                    self.shouldReConnect = isError
                    
                    if ((self.connected /*|| reconnect*/) && isError) {
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
                    self.connected = false
                    self.connectionClose.notify(())
                }
            }
            if self.connection.addCallBackOnConnect == nil {
                self.connection.addCallBackOnConnect = {
                    () -> Void in
                    //self.connecting = false
                    let device = SettingsManager.getKey(SettingKeys.device) as! String

                    let request = "\(Tags.auth.rawValue)\(device)"
                    self.connection.send(request)
                }
            }
            if self.monitoringGroupsHandler == nil {
                self.monitoringGroupsHandler = self.monitoringGroupsUpdated.add({
                    self.monitoringGroupsUpdated.notify($0)
                })
            }
            
            self.connection.connect(token!)
            self.shouldReConnect = false //interesting why here? may after connction is successful??
        } else {
            self.connecting = false
            if (token?.error.isEmpty)! {
                self.connectionRun.notify((1, ""))
                self.shouldReConnect = false
            } else {
                self.log.enqueue("connectionManager completed Error:\(token?.error)")
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
        
    }
    open func connect(_ reconnect: Bool = false){
        log.enqueue("ConnectionManager: connect")
        if self.connecting {
            log.enqueue("Conection already in process")
            return;
        }
        if self.connected {
            log.enqueue("Already connected !")
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
        
        self.Authenticate()
        
    }
    
    open func closeConnection() {
        if (self.connected && !self.sessionOpened) {
            connection.closeConnection()
            self.connection.addCallBackOnConnect = nil
            self.connected = false
            self.Authenticated = false
        }
    }
    
    open func openSession(){
        log.enqueue("ConnectionManager: open session")
        if (self.connected && !self.sessionOpened) {
            let request = "\(Tags.openSession.rawValue)"
            connection.send(request)
       }
    }


    open func closeSession(){
        log.enqueue("ConnectionManager: close session")
        
        if self.sessionOpened {
            connection.closeSession()
        }
    }
    //probably should be refactored and moved to ReconnectManager
    fileprivate func sendPing(){
        connection.send("\(Tags.ping.rawValue)")
    }
    
    open func sendCoordinate(_ coordinate: LocationModel) {
        let request = "\(Tags.remoteCommandResponse.rawValue)\(RemoteCommand.WHERE.rawValue)|\(coordinate.getCoordinateRequest)"
        connection.send(request)
    }
    
    open func sendCoordinates(_ coordinates: [LocationModel])
    {
        if self.sessionOpened {
            self.sendCoordinates(coordinates)
        }
    }
    open func sendRemoteCommandResponse(_ rc: String) {
        let request = "\(Tags.remoteCommandResponse.rawValue)\(rc)"
        connection.send(request)
    }
    
    // Groups funcs
    open func getGroups(){
        if self.connected {
            if self.onGroupListUpdated == nil {
                
                self.onGroupListUpdated = self.groupListDownloaded.add {
                    self.groupList.notify($0)
                    
                }
            }
            self.sendGetGroups()
        }
    }
    
    open func createGroup(_ name: String, email: String, nick: String, gtype: String, priv: Bool){
        if self.connected{
            if self.onGroupCreated == nil {
                
                self.onGroupCreated = self.groupCreated.add {
                    self.groupCreated.notify($0)
                }
            }


            let jsonInfo: NSDictionary =
                ["name": name as NSString, "email": email as NSString, "nick": nick as NSString, "type": gtype as NSString, "private":(priv == true ? "1" :"0") as NSString]
            
            do{
                let data = try JSONSerialization.data(withJSONObject: jsonInfo, options: JSONSerialization.WritingOptions(rawValue: 0))
                
                if let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                    let request = "\(Tags.createGroup.rawValue):|\(jsonString)"
                    connection.send(request)
                }
            }catch {
                print("error generating system info")
            }
        }
    }
    
    open func enterGroup(_ name: String, nick: String){
        if self.connected{
            let request = "\(Tags.enterGroup.rawValue)\(name)|\(nick)"
            connection.send(request)
        }
    }
    
    open func leaveGroup(_ u: String){
        if self.connected {
            let request = "\(Tags.leaveGroup.rawValue)\(u)"
            connection.send(request)
        }
    }

    //Активация-деактиация получени обновления координат из группы
    open func activatePoolGroups(_ s: Int){
        if self.connected {
            let request = "\(Tags.activatePoolGroups.rawValue):\(s)"
            connection.send(request)
        }
    }
    
    open func groupsSwitch(_ s: Int){
        if self.connected {
            let request = "\(Tags.groupSwitch.rawValue)"
            connection.send(request)
        }
    }
    
    
    open func activateGroup(_ u: String){
        if self.connected {
            let request = "\(Tags.activateGroup.rawValue)\(u)"
            connection.send(request)
        }
        
    }
    
    open func deactivateGroup(_ u: String){
        if self.connected {
            let request = "\(Tags.deactivateGroup.rawValue)\(u)"
            connection.send(request)
        }
        
    }
    
    open func sendGetGroups(){
        let request = "\(Tags.getGroups.rawValue)"
        connection.send(request)
    }
    
    open func sendUpdateGroupResponse(group: Int, event:Int){
        let request = "\(Tags.updateGroupResponse.rawValue):\(group)|\(event)"
        connection.send(request)
    }
    open func getMessageOfTheDay(){
        if self.connected{
            let request = "\(Tags.messageDay.rawValue)"
            connection.send(request)
        }
    }
    
    open func sendPush(_ token: String){
        let request = "\(Tags.push.rawValue)|\(token)"
        connection.send(request)
    }

    open func sendSystemInfo(){
        let model = UIDevice.current.model
        let version = UIDevice.current.systemVersion
        
        let jsonInfo: NSDictionary = ["devicename": model, "version": "iOS \(version)"]
        
        do{
            let data = try JSONSerialization.data(withJSONObject: jsonInfo, options: JSONSerialization.WritingOptions(rawValue: 0))
            
            if let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                let request = "\(Tags.remoteCommandResponse.rawValue)\(RemoteCommand.TRACKER_SYSTEM_INFO.rawValue)|\(jsonString)"
                connection.send(request)
            }
        }catch {
            print("error generating system info")
        }
    }
    
    open func sendBatteryStatus(){
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = Int(UIDevice.current.batteryLevel * 100)
        var state = 0;
        if (UIDevice.current.batteryState == .charging) {
            state = 1;
        }
        
        let jsonInfo: NSDictionary = ["percent": level, "plugged": state]
        
        do{
            let data = try JSONSerialization.data(withJSONObject: jsonInfo, options: JSONSerialization.WritingOptions(rawValue: 0))
            
            if let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                let request = "\(Tags.remoteCommandResponse.rawValue)\(RemoteCommand.TRACKER_BATTERY_INFO.rawValue)|\(jsonString)"
                connection.send(request)
            }
        }catch {
            print("error generating battery info")
        }
    }
    
    //MARK private methods
    
    var isNetworkAvailable : Bool {
        return reachabilityStatus != .none
    }
    var reachabilityStatus: Reachability.Connection = .none
    
    
    //fileprivate func notifyAnswer(_ tag: AnswTags, name: String, answer: Int){
    fileprivate func notifyAnswer(output: String){
        
        var command = output.components(separatedBy: "|").first!
        let addict = output.components(separatedBy: "|").last!
        var param = ""
        if command.contains(":"){
            param = command.components(separatedBy: ":").last!
            command = command.components(separatedBy: ":").first!
        }
        var answer : Int = 0;
        var name: String;
        
        if command == AnswTags.auth.rawValue {
            //ex: INIT|{"id":"CVH2SWG21GW","group":1,"motd":1429351583,"protocol":2,"v":0.88} || INIT|{"id":1,"error":"Token is invalid"}
            if let result = parseForErrorJson(output) {
                answer =  result.0
                name = result.1
                
                if result.0 == 0 {
                    if let trackerID = parseTag(output, key: ParseKeys.id) {
                        sessionTrackerID = trackerID
                    } else {
                        sessionTrackerID = "error parsing TrackerID"
                    }
                    if let spermanent = parseTag(output, key: ParseKeys.permanent) {
                        if spermanent == "1" {
                            self.permanent = true;
                        }
                        
                    }
                    //means response to try connecting
                    log.enqueue("connected with Auth")
                    self.connecting = false
                    
                    self.connected = answer == 0;
                    if (answer == 100) {
                        DispatchQueue.main.async {
                            SettingsManager.clearKeys()
                            self.connection.closeConnection()
                            self.connect()
                        }
                    } else {
                        if (!self.connected) {
                            self.shouldReConnect = false
                        }
                        if let trackerId = self.TrackerID {
                            SettingsManager.setKey(trackerId as NSString, forKey: SettingKeys.trackerId)
                        }
                        connectionRun.notify((answer, name))
                    }
                } else {
                    connectionRun.notify((result.0,  result.1))
                }
                
            }

            return
        }
        if command == AnswTags.enterGroup.rawValue {
            if let result = parseForErrorJson(output){
                groupEntered.notify((result.0,  result.1))
            } else {
                log.enqueue("error: enter group asnwer cannot be parsed")
            }

            return
        }

        if command == AnswTags.leaveGroup.rawValue {
            if let result = parseForErrorJson(output){
                groupLeft.notify((result.0,  result.1))
            }else {
                log.enqueue("error: leave group asnwer cannot be parsed")
            }
    
            return
        }
        
        if command == AnswTags.activateGroup.rawValue {
            if let result = parseForErrorJson(output){
                let value = (result.0==1 ? result.1 : (result.1=="" ? output.components(separatedBy: "|")[1] : result.1 ))
                groupActivated.notify(result.0, value)
            }else {
                log.enqueue("error: activate group asnwer cannot be parsed")
            }

            return
        }
        if command == AnswTags.deactivateGroup.rawValue {
            if let result = parseForErrorJson(output){
                groupDeactivated.notify(result.0,  result.1)
            }else {
                log.enqueue("error: deactivate group asnwer cannot be parsed")
            }
            return
        }
        if command == AnswTags.updateGroup.rawValue {
            let parseRes = parseGroupUpdate(output)
            if let grId = parseRes.0, let res = parseRes.1 {
                groupsUpdated.notify((grId, res))
            }else {
                log.enqueue("error parsing GP")
            }
            return
        }
        if command == AnswTags.getGroups.rawValue {
            if let result = parseGroupsJson(output) {
                self.groupList.notify(result)
            } else {
                log.enqueue("error: groups list answer cannot be parsed")
            }
            return
        }
        
        if command == AnswTags.push.rawValue {
            log.enqueue("PUSH activated")
            
            if let result = parseForErrorJson(output){
                pushActivated.notify(result.0)
            }else {
                log.enqueue("error: PUSH asnwer cannot be parsed")
            }

            return
        }
        if command == AnswTags.createGroup.rawValue {
            if let result = parseForErrorJson(output){
                
                groupCreated.notify((result))
                return
            } else {
                log.enqueue("error: create group asnwer cannot be parsed")
            }
            
            return
        }

        if command == AnswTags.openedSession.rawValue {
            log.enqueue("session opened answer") //ex: TO|{"session":145004,"url":"f1_o9_7s"}
            
            if let result = parseForErrorJson(output){
                answer =  result.0
                name = result.1
                
                if result.0 == 0 {
                    sessionOpened = true
                    
                    if let sessionUrl = parseTag(output, key: ParseKeys.sessionUrl) {
                        sessionUrlParsed = sessionUrl
                    } else {
                        sessionUrlParsed = "error parsing url"
                    }
                }
                sessionRun.notify((answer, name))
                
                return
            } else {
                log.enqueue("error: open session asnwer cannot be parsed")
            }

            return
        }
        
        if command == AnswTags.closeSession.rawValue {
            log.enqueue("session closed answer")
            if let result = parseForErrorJson(output){
                answer =  result.0
                name = result.1
                
                self.sessionOpened = answer != 0;
                sessionRun.notify((answer == 0 ? 1 : 0, NSLocalizedString("session was closed", comment:"session was closed")))

            }else {
                log.enqueue("error: session closed asnwer cannot be parsed")
            }

            return
        }
        if command == AnswTags.kick.rawValue {
            log.enqueue("connection kicked")
            if let result = parseForErrorJson(output){
                self.connected = false
                self.connection.closeConnection()
                self.connect()
            } else {
                log.enqueue("kick asnwer cannot be parsed")
            }
            
            
            return
        }
        if command == AnswTags.pong.rawValue {
            log.enqueue("server wants answer ;)")
            sendPing()
            return
        }
        if command == AnswTags.coordinate.rawValue {
            let cnt = Int(addict)
            if cnt ?? 0  > 0 {
                connection.onSentCoordinate(cnt:cnt!)
            }
            return
        }
        if command == AnswTags.buffer.rawValue {
            let cnt = Int(addict)
            if cnt ?? 0 > 0 {
                connection.onSentCoordinate(cnt:cnt!)
            }
            return
        }
        if command == AnswTags.grCoord.rawValue {
            let parseRes = parseGroupUpdate(output)
            if let grId = parseRes.0, let res = parseRes.1 {
                
                //if monitor.contains(grId){
                if let groups = parseCoordinate(grId, coordinates: res) {
                    monitoringGroupsUpdated.notify(groups)
                }
                else {
                    log.enqueue("error: parsing coordinate array")
                }
                //}
            }
            
            //D:47580|L37.33018:-122.032582S1.3A9H5C
            //G:1578|["17397|L59.852968:30.373739S0","47580|L37.330178:-122.032674S3"]
            return
        }
        if command == AnswTags.messageDay.rawValue {
            if (command != "" && addict != "") {
                messageOfTheDayReceived.notify((1, addict))
            }
            else {
                log.enqueue("error: wrong parsing MD")
            }
            
            return
        }
        
        if command == AnswTags.remoteCommand.rawValue {
            let sendingManger = SendingManager.sharedSendingManager
            if (param == RemoteCommand.TRACKER_BATTERY_INFO.rawValue){
                sendingManger.sendBatteryStatus(param)
                return
            }
            
            if (param == RemoteCommand.TRACKER_SYSTEM_INFO.rawValue){
                sendingManger.sendSystemInfo()
                return
            }

            if (param == RemoteCommand.TRACKER_SESSION_STOP.rawValue){
                sendingManger.stopSendingCoordinates(param)

                return
            }
            if (param == RemoteCommand.TRACKER_EXIT.rawValue){
                sendingManger.stopSendingCoordinates(param)
                connection.closeConnection()
                return
            }
            if (param == RemoteCommand.TRACKER_SESSION_START.rawValue){
                sendingManger.startSendingCoordinates(param)
                return
            }
            if (param == RemoteCommand.TRACKER_SESSION_PAUSE.rawValue){
                sendingManger.pauseSendingCoordinates(param)
                return
            }
            if (param == RemoteCommand.TRACKER_SESSION_CONTINUE.rawValue){
                sendingManger.startSendingCoordinates(param)
                return
            }
            if (param == RemoteCommand.TRACKER_GCM_ID.rawValue) {
                //Отправляем токен ранее полученный от FCM
                if let token = Messaging.messaging().fcmToken {
                    self.sendPush(token)
                }
                self.sendRemoteCommandResponse(param)
                return
            }
            
            if (param == RemoteCommand.REFRESH_GROUPS.rawValue){
                self.sendGetGroups()
                self.sendRemoteCommandResponse(param)
                return
            }

            if (param == RemoteCommand.WHERE.rawValue) {
                if self.connected{
                    self.sendRemoteCommandResponse(param)
                }
                if self.sessionOpened == false {
                    self.isGettingLocation = true
                    sendingManger.startSendingCoordinates(param)
                }
                return
            }
        }
    }


    
    //MARK - parsing server response functions
    
    fileprivate func parseCoordinate(_ group: Int, coordinates: Any) -> [UserGroupCoordinate]? {
        if let users = coordinates as? Array<String> {
            var res = [UserGroupCoordinate]()
            
            for u in users {
                let uc = u.components(separatedBy: "|")
                let user = Int(uc[0])
                if user ?? 0 > 0 { //id
                    
                    let location = LocationModel(coordString: uc[1])
                    let ugc: UserGroupCoordinate = UserGroupCoordinate(group: group, user: user!, location: location)
                    res.append(ugc)
                }
            }
            return res
        }
        return nil
    }
    
    
    fileprivate func parseGroupUpdate(_ responce: String) -> (Int?, Any?){
        let cmd = responce.components(separatedBy: "|")[0]
        let groupId = Int(cmd.components(separatedBy: ":")[1])
        
        return (groupId, parseJson(responce))
    }
    
    fileprivate func parseForErrorJson(_ responce: String) -> (Int, String)? {
        if let dic = parseJson(responce) as? Dictionary<String, Any>{
            if dic.index(forKey: "error") == nil {
                return (0, "")
            }  else {
                if let err =  dic["error"] as? Int {
                    if let err_msg =  dic["error_description"] as? String{
                        return (err, err_msg)
                    }else {
                        return (err, "\(err)")
                    }
                    
                }
                return (1, "error message is not parsed")
            }
        } else {
            if Int(responce.components(separatedBy: "|").last!)! > 0 {
                return (0, "")
            }
        }
        return nil
    }
    
    fileprivate func parseJson(_ responce: String) -> Any? {
        // server can accumulate some messages, so should define it
        //let responceFirst = responce.componentsSeparatedByString("\n")[0] <-- has no sense because splitting in other place
        
        // should parse only first | sign, because of responce structure
        // "TRACKER_SESSION_OPEN|{\"warn\":1,\"session\":\"40839\",\"url\":\"lGv|f2\"}\n"
        
        let index = responce.components(separatedBy: "|")[0].count + 1
        let json = responce.substring(with: responce.index(responce.startIndex, offsetBy: index)..<responce.endIndex)
        
        if let data: Data = json.data(using: String.Encoding.utf8) {
            
            do  {
                let jsonObject: Any! = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)
                
                return jsonObject;
            } catch {
                return nil;
                
            }
        }
        
        return nil
    }
    
    fileprivate func parseGroupsJson(_ responce: String) -> [Group]? {
        //let responceFirst = responce.componentsSeparatedByString("\n")[0] <-- has no sense because splitting in other place
        
        // should parse only first | sign, because of responce structure
        // "TRACKER_SESSION_OPEN|{\"warn\":1,\"session\":\"40839\",\"url\":\"lGv|f2\"}\n"
        
        let index = responce.components(separatedBy: "|")[0].count + 1
        let json = responce.substring(with: responce.index(responce.startIndex, offsetBy: index)..<responce.endIndex)
        
        do {
            
            if let data: Data = json.data(using: String.Encoding.utf8), let jsonObject: Any? =  try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) {
                var groups = [Group]()
                
                if let jsonGroups = jsonObject as? Array<Any> {
                    for jsonG in jsonGroups{
                        let group = Group.init(json: jsonG as! Dictionary<String, AnyObject>)
                        
                        groups.append(group)
                    }
                }
                return groups
                
            }
        }catch {}
        return nil
    }
    
    fileprivate func parseTag(_ responce: String, key: ParseKeys) -> String? {
        
        if let responceValues: NSDictionary = parseJson(responce) as? Dictionary<String, AnyObject> as NSDictionary?, let tag = responceValues.object(forKey: key.rawValue) as? String {
            return tag
        }
        return nil
    }
}
