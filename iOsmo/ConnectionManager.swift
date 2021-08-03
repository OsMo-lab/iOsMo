//
//  ConnectionManager.swift
//  iOsmo
//
//  Created by Olga Grineva on 13/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2019 Alexey Sirotkin All rights reserved.
//
// implementations of Singleton: https://github.com/hpique/SwiftSingleton
// implement http://stackoverflow.com/questions/9810585/how-to-get-reachability-notifications-in-ios-in-background-when-dropping-wi-fi-n


import Foundation
import CoreLocation
import AudioToolbox
import AVFoundation


let iOsmoAppKey = "EfMNuZdpaGGYoQmWXZ4b"

open class ConnectionManager: NSObject{

    private let bgController = ConnectionHelper()
    var monitoringGroupsHandler: ObserverSetEntry<[UserGroupCoordinate]>?

    var onGroupListUpdated: ObserverSetEntry<[Group]>?
    var onMessageListUpdated: ObserverSetEntry<(Int)>?
    //var onGroupCreated: ObserverSetEntry<(Int, String)>?
    
    // add name of group in return
    let groupEntered = ObserverSet<(Int, String)>()
    let groupCreated = ObserverSet<(Int, String)>()
    let groupLeft = ObserverSet<(Int, String)>()
    let groupActivated = ObserverSet<(Int, String)>()
    let groupsUpdated = ObserverSet<(Int, Any)>()
    let messagesUpdated = ObserverSet<(Int, Any)>()
    let messageSent = ObserverSet<(Int, String)>()
    
    let pushActivated = ObserverSet<Int>()
    let groupDeactivated = ObserverSet<(Int, String)>()
    let groupListDownloaded = ObserverSet<[Group]>()
    
    let groupList = ObserverSet<[Group]>()

    let connectionRun = ObserverSet<(Int, String)>()
    let sessionRun = ObserverSet<(Int, String)>()
    let groupsEnabled = ObserverSet<Int>()
    let messageOfTheDayReceived = ObserverSet<(Int, String)>()
    let historyReceived = ObserverSet<(Int, Any)>()
    let connectionClose = ObserverSet<()>()
    let connectionStart = ObserverSet<()>()
    let dataSendStart = ObserverSet<()>()
    let dataReceiveEnd = ObserverSet<()>()
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

    var delayedRequests : [String]  = [];
    var transports: [Transport] = [Transport]()
    var privacyList: [Private] = [Private]()
    
    var connection = BaseTcpConnection()
    var coordinates: [LocationModel]
    var sendingCoordinates = false;
    
    fileprivate let aSelector : Selector = #selector(ConnectionManager.reachabilityChanged(_:))
    open var shouldReConnect = false
    open var isGettingLocation = false
    var serverToken: Token
    var reachability: Reachability?
    
    open var transportType: Int = 0;
    open var trip_privacy : Int = -1;
    
    var audioPlayer = AVAudioPlayer()
    public var timer = Timer()
    
    class var sharedConnectionManager : ConnectionManager{
        struct Static {
            static let instance: ConnectionManager = ConnectionManager()
        }
        
        return Static.instance
    }

    override init(){
        let reachability: Reachability?
        
        reachability = try? Reachability() 
        
        self.reachability = reachability
        coordinates = [LocationModel]()
        self.serverToken = Token(tokenString: "", address: "", port:0, key: "")
        super.init()
        
        
        NotificationCenter.default.addObserver(self, selector: aSelector, name: NSNotification.Name.reachabilityChanged, object: reachability)
        do  {
            try reachability?.startNotifier()
        }catch{
            print("could not start reachability notifier")
        }

        
        //!! subscribtion for almost all types events
        _ = connection.answerObservers.add(notifyAnswer)
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)), mode: AVAudioSession.Mode.default)
        
        } catch {
            log.enqueue("CM.Inint: Unable to set AVAudioSessionCategory \(error)")
        }
            
        
    }
    
    func getServerInfo(key:String?) {
        conHelper.onCompleted = {(dataURL, data) in
            var res : NSDictionary = [:]
            var tkn : Token;
            LogQueue.sharedLogQueue.enqueue("CM.getServerInfo.onCompleted")
            guard let data = data else {
                tkn = Token(tokenString:"", address: "", port: 0, key: "")
                tkn.error = "Server address not received"
                self.completed(result: false, token: tkn)
                return
            }
            if let output = String(data:data, encoding:.utf8) {
                LogQueue.sharedLogQueue.enqueue("server: \(output)")
            }
            do {
                let jsonDict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers);
                res = (jsonDict as? NSDictionary)!
                if let server = res[Keys.address.rawValue] as? String {
                    let server_arr = server.components(separatedBy: ":")
                    if server_arr.count > 1 {
                        if let tknPort = Int(server_arr[1]) {
                            self.serverToken =  Token(tokenString:"", address: server_arr[0], port: tknPort, key: key! as String)
                            self.completed(result: true,token: self.serverToken)
                            return
                        }
                    }
                    tkn = Token(tokenString:"", address: "", port: -1, key: "")
                    tkn.error = "Server address not parsed"
                    self.completed(result: false, token: tkn)
                } else {
                    tkn = Token(tokenString:"", address: "", port: -1, key: "")
                    tkn.error = "Server address not received"
                    self.completed(result: false, token: tkn)
                }
            } catch {
                LogQueue.sharedLogQueue.enqueue("error serializing JSON from POST")
                
                tkn = Token(tokenString:"", address: "", port: -1, key: "")
                tkn.error = "error serializing JSON"
                self.completed(result: false, token: tkn)
            }
        }
        LogQueue.sharedLogQueue.enqueue("CM.getServerInfo")
        let requestString = "app=\(iOsmoAppKey)"
        conHelper.backgroundRequest(URL(string: URLs.servUrl)!, requestBody: requestString as NSString)
    }
    
    func Authenticate () {
        let device = SettingsManager.getKey(SettingKeys.device)
        if device == nil || device?.length == 0{
            LogQueue.sharedLogQueue.enqueue("CM.Authenticate:getting key from server")
            conHelper.onCompleted = {(dataURL, data) in
                guard let data = data else { return }
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
            let vendorKey = UIDevice.current.identifierForVendor!.uuidString
            let model = UIDevice.current.modelName
            let version = UIDevice.current.systemVersion
            let requestString = "app=\(iOsmoAppKey)&id=\(vendorKey)&platform=\(model) iOS \(version)"
            conHelper.backgroundRequest(URL(string: URLs.authUrl)!, requestBody: requestString as NSString)
        } else {
            LogQueue.sharedLogQueue.enqueue("CM.Authenticate:using local key \(device!)")
            self.Authenticated = true
            self.getServerInfo(key: device! as String)
        }
    }
    
    @objc open func reachabilityChanged(_ note: Notification) {
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
            case .unavailable:
                if (self.connected) {
                    self.connected = false
                    self.sendingCoordinates = false
                    log.enqueue("should be reconnected")
                    shouldReConnect = true;
                    
                    connectionRun.notify((1, "")) //error but is not need to be popuped
                }
        }
        if (shouldReConnect) {
            self.connecting = false
            log.enqueue("Reconnect action")
            connect()
        }
    }
    
    open var sessionUrl: String? { get { return self.getSessionUrl() } }
    
    open var TrackerID: String? { get { return self.getTrackerID() } }
    
    open var connected: Bool = false
    open var sessionOpened: Bool = false
    private var connecting: Bool = false
 
    /*Информация о сервере получена*/
    private func completed (result: Bool, token: Token?) {
        self.connecting = false
        if (result) {
            if self.connection.addCallBackOnError == nil {
                self.connection.addCallBackOnError = {
                    (isError : Bool) -> Void in
                    
                    self.connecting = false
                    self.shouldReConnect = isError
                    self.connected = false
                    
                    self.connectionRun.notify((1, ""))
                    if (self.shouldReConnect) {
                        //self.connect()
                        if (!self.timer.isValid) {
                            self.log.enqueue("CM.completed scheduling connect by timer")
                            self.timer = Timer.scheduledTimer(timeInterval: 30.0, target: self, selector: #selector(self.connectByTimer), userInfo: nil, repeats: true)
                        }
                        
                    }
                }
            }
            if self.connection.addCallBackOnSendStart == nil {
                self.connection.addCallBackOnSendStart = {
                    () -> Void in
                    self.dataSendStart.notify(())
                }
            }
            if self.connection.addCallBackOnReceiveEnd == nil {
                self.connection.addCallBackOnReceiveEnd = {
                    () -> Void in
                    self.dataReceiveEnd.notify(())
                    if (!self.connected) { //Восстановления коннекта после обрыва
                        self.connected = true
                    }
                }
            }
            if self.connection.addCallBackOnSendEnd == nil {
                self.connection.addCallBackOnSendEnd = {
                    (message) -> Void in
                    
                    let command = message.components(separatedBy: "|").first!
                    
                    if (command == Tags.coordinate.rawValue || command == Tags.buffer.rawValue) {
                        self.sendingCoordinates = true
                    }
                     
                    self.dataSendEnd.notify(()) //Передаем событие подписчикам
                }
            }
            if self.connection.addCallBackOnCloseConnection == nil {
                self.connection.addCallBackOnCloseConnection = {
                    () -> Void in
                    self.connecting = false
                    self.connected = false
                    self.sendingCoordinates = false
                    self.connectionClose.notify(())
                }
            }
            if self.connection.addCallBackOnConnect == nil {
                self.connection.addCallBackOnConnect = {
                    () -> Void in
                    self.connecting = false
                    if (self.timer.isValid) {
                        self.timer.invalidate()
                    }
                    let device = SettingsManager.getKey(SettingKeys.device)! as String
                    let request = "\(Tags.auth.rawValue)\(device)"
                    
                    self.connection.send(request)
                }
            }
            self.connection.connect(token!)
            self.shouldReConnect = false //interesting why here? may after connction is successful??
        } else {
            if (token != nil) {
                if (token?.error.isEmpty)! {
                    self.connectionRun.notify((1, ""))
                    self.shouldReConnect = false
                } else {
                    self.log.enqueue("CM.completed Error:\(token?.error ?? "")")
                    if (token?.error == "Wrong device key") {
                        SettingsManager.setKey("", forKey: SettingKeys.device)
                        self.connectionRun.notify((1, ""))
                        self.shouldReConnect = true
                    } else {
                        if (token?.port ?? 0 >= 0 ) {
                            self.connectionRun.notify((1, "\(token?.error ?? "")"))
                        } else {
                            self.connectionRun.notify((1, ""))
                        }
                        self.shouldReConnect = false
                    }
                }
            } else {
                self.log.enqueue("CM.completed Error: Invalid data")
                self.connectionRun.notify((1, "Invalid data"))
                self.shouldReConnect = false
            }
        }
    }
    
    open func connect(){
        log.enqueue("CM: connect")
        self.sendingCoordinates = false
        if self.connecting {
            log.enqueue("Conection already in process")
            return;
        }
        if self.connected {
            log.enqueue("Already connected !")
            return;
        }
        self.connecting = true;
        /*
        if !isNetworkAvailable {
            log.enqueue("Network is NOT available")
            shouldReConnect = true
            self.connecting = false;
            return
        }*/
        self.connectionStart.notify(())
        
        
        self.Authenticate()
        
    }
    
    open func closeConnection() {
        if (self.connected && !self.sessionOpened) {
            connection.closeConnection()
            self.connected = false
            self.Authenticated = false
            self.sendingCoordinates = false
        }
    }
    
    open func openSession(){
        log.enqueue("CM.openSession")
        if (self.connected && !self.sessionOpened) {
            let json: NSDictionary = ["transportid": self.transportType, "private": self.trip_privacy]
            
            do{
                let data = try JSONSerialization.data(withJSONObject: json, options: JSONSerialization.WritingOptions(rawValue: 0))
                
                if let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                    let request = "\(Tags.openSession.rawValue)|\(jsonString)"
                    send(request: request)
                }
            }catch {
                print("error generating trip open info")
            }
        }
    }


    open func closeSession(){
        log.enqueue("CM.closeSession")
        self.trip_privacy = -1
        if self.sessionOpened {
            let request = "\(Tags.closeSession.rawValue)"
            connection.send(request)
        }
    }
    
    open func send(request: String) {
        let command = request.components(separatedBy: "|").first!
        if (self.connected || command == Tags.coordinate.rawValue || command == Tags.buffer.rawValue || self.connecting) {
            connection.send(request)
        } else {
            if (UIApplication.shared.applicationState == .active ) {
                log.enqueue("CM.send appActive or coorinate")
                delayedRequests.append(request)
                if (!self.timer.isValid) {
                    log.enqueue("CM.send scheduling connect by timer")
                    self.timer = Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(self.connectByTimer), userInfo: nil, repeats: true)
                }
            } else {
                log.enqueue("CM.send appInActive")
                self.connecting = false;
                let device = SettingsManager.getKey(SettingKeys.device)! as String
                let escapedRequest = request.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)

                if let url = URL(string: (URLs.apiUrl + "k=" + device + "&m=" + escapedRequest! ) ) {
                    conHelper.onCompleted = {(dataURL, data) in
                        guard let data = data else { return }
                        LogQueue.sharedLogQueue.enqueue("CM.Send.onCompleted")
                        if let output = String(data:data, encoding:.utf8) {
                            LogQueue.sharedLogQueue.enqueue(output)
                            self.notifyAnswer(output: output)
                        }
                    }
                    conHelper.backgroundRequest(url, requestBody: "")
                }
            }
        }
    }
    
    //Попытка посстановить соединение после обрыва, по срабатыванию таймера
    @objc func connectByTimer() {
        self.connecting = false
        self.connect()
    }
    
    //probably should be refactored and moved to ReconnectManager
    fileprivate func sendPing(){
        self.send(request:"\(Tags.ping.rawValue)")
    }
    
    open func sendCoordinate(_ coordinate: LocationModel) {
        let request = "\(Tags.remoteCommandResponse.rawValue)\(RemoteCommand.WHERE.rawValue)|\(coordinate.getCoordinateRequest)"
        send(request: request)
    }
    
    open func sendCoordinates(_ coordinates: [LocationModel])
    {
        if self.sessionOpened {
            self.coordinates += coordinates
            if (!self.sendingCoordinates) {
                self.sendNextCoordinates()
            }
        }
    }
    
    open func sendRemoteCommandResponse(_ rc: String) {
        let request = "\(Tags.remoteCommandResponse.rawValue)\(rc)|1"
        send(request: request)
    }
    
    // Groups funcs
    open func getGroups(){
        if self.onGroupListUpdated == nil {
            self.onGroupListUpdated = self.groupListDownloaded.add{
                self.groupList.notify($0)
            }
        }
        self.sendGetGroups()
    }
    
    open func getChatMessages(u: Int){
        self.send(request: "\(Tags.groupChat.rawValue):\(u)")
    }
    
    open func createGroup(_ name: String, email: String, nick: String){
        /*
        if self.onGroupCreated == nil {
            print("CM.creatGroup add onGroupCreated")
            self.onGroupCreated = self.groupCreated.add{
                print("CM.onGroupCreated notify")
                self.groupCreated.notify($0)
            }
        }
        */
        let jsonInfo: NSDictionary =
            ["name": name as NSString, "email": email as NSString, "nick": nick as NSString]
        
        do{
            let data = try JSONSerialization.data(withJSONObject: jsonInfo, options: JSONSerialization.WritingOptions(rawValue: 0))
            
            if let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                let request = "\(Tags.createGroup.rawValue):|\(jsonString)"
                send(request: request)
            }
        }catch {
            print("error generating new group info")
        }
    }
    
    open func enterGroup(_ name: String, nick: String){
        let request = "\(Tags.enterGroup.rawValue)\(name)|\(nick)"
        send(request: request)
    }
    
    open func leaveGroup(_ u: String){
        let request = "\(Tags.leaveGroup.rawValue)\(u)"
        send(request: request)
    }

    //Активация-деактиация получени обновления координат из группы
    open func activatePoolGroups(_ s: Int){
        let request = "\(Tags.activatePoolGroups.rawValue):\(s)"
        send(request: request)
    }
    
    open func groupsSwitch(_ s: Int){
        let request = "\(Tags.groupSwitch.rawValue)"
        send(request: request)
    }
    
    open func activateGroup(_ u: String){
        let request = "\(Tags.activateGroup.rawValue)\(u)"
        send(request: request)
    }
    
    open func deactivateGroup(_ u: String){
        let request = "\(Tags.deactivateGroup.rawValue)\(u)"
        send(request: request)
    }

    open func sendGetGroups(){
        let request = "\(Tags.getGroups.rawValue)"
        send(request: request)
    }
    
    open func sendTrackUser(_ user_id:String){
        let request = "\(Tags.setTrackedkUser.rawValue):\(user_id)|1"
        send(request: request)
    }
    
    open func sendUpdateGroupResponse(group: Int, event:Int){
        let request = "\(Tags.updateGroupResponse.rawValue):\(group)|\(event)"
        send(request: request)
    }
    
    open func sendChatMessage(group: Int, text: String){
        let jsonInfo: NSDictionary = ["text": text]
        
        do{
            let data = try JSONSerialization.data(withJSONObject: jsonInfo, options: JSONSerialization.WritingOptions(rawValue: 0))
        
            if let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                let request = "\(Tags.groupChatSend.rawValue):\(group)|\(jsonString)"
                send(request: request)
            }
        
        }catch {
            print("error generating system info")
        }
    }
    
    open func getMessageOfTheDay(){
        let request = "\(Tags.messageDay.rawValue)"
        send(request: request)
    }
    
    open func getHistory(){
        let request = "\(Tags.history.rawValue)"
        send(request: request)
    }
    
    open func sendPush(_ token: String){
        let request = "\(Tags.push.rawValue)|\(token)"
        if connected {
            send(request: request)
        }
    }

    open func sendSystemInfo(){
        let model = UIDevice.current.modelName
        let version = UIDevice.current.systemVersion
        let appVersion : String! = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String ?? "unknown"
        let jsonInfo: NSDictionary = ["devicename": model, "version": "iOS \(version)", "app":"\(appVersion!)"]
        
        do{
            
            let data = try JSONSerialization.data(withJSONObject: jsonInfo, options: JSONSerialization.WritingOptions(rawValue: 0))
            
            if let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                let request = "\(Tags.remoteCommandResponse.rawValue)\(RemoteCommand.TRACKER_SYSTEM_INFO.rawValue)|\(jsonString)"
                send(request: request)
            }
        }catch {
            print("error generating system info")
        }
    }
    

    
    open func sendBatteryStatus(_ rc: String){
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
                send(request: request)
            }
        }catch {
            print("error generating battery info")
        }
    }
    
    //MARK private methods
    
    var isNetworkAvailable : Bool {
        return reachabilityStatus != .unavailable
    }
    var reachabilityStatus: Reachability.Connection = .unavailable
    
    
    //fileprivate func notifyAnswer(_ tag: AnswTags, name: String, answer: Int){
    fileprivate func notifyAnswer(output: String){
        
        var command = output.components(separatedBy: "|").first!
        
        let index = command.count + 1
        let addict = index < output.count ? String(output[output.index(output.startIndex, offsetBy: index)..<output.endIndex]) : ""

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
                    //means response to try connecting
                    log.enqueue("connected with Auth")
                    self.connecting = false
                    
                    self.connected = answer == 0;
                    let js = parseJson(output) as! Dictionary<String, AnyObject>;
                    
                    if let json_array = js["transport"] as? Array<AnyObject> {
                        self.transports = [Transport]();
                        for t in json_array {
                            let tt = Transport.init(json: (t as!  Dictionary<String, AnyObject>));
                            self.transports.append(tt);
                        }
                    }
                    if let json_array = js["private"] as? Array<AnyObject> {
                        self.privacyList = [Private]();
                        for t in json_array {
                            let p = Private.init(json: (t as!  Dictionary<String, AnyObject>));
                            self.privacyList.append(p);
                        }
                    }
  
                    if let trackerID = parseTag(output, key: Keys.id) {
                        sessionTrackerID = trackerID
                    } else {
                        sessionTrackerID = "error parsing TrackerID"
                    }
                    if let user = parseTag(output, key: Keys.name) {
                        SettingsManager.setKey(user as NSString, forKey: SettingKeys.user)
                    }
                    if let uid = parseTag(output, key: Keys.uid) {
                        SettingsManager.setKey(uid as NSString, forKey: SettingKeys.uid)
                    }
                    if let spermanent = parseTag(output, key: Keys.permanent) {
                        if spermanent == "1" {
                            self.permanent = true;
                        }
                        
                    }
                    if let motd = parseTag(output, key: Keys.motd) {
                        let cur_motd = SettingsManager.getKey(SettingKeys.motdtime) as String? ?? "0"
                        if (Int(motd)! > Int(cur_motd)!) {
                            SettingsManager.setKey(motd as NSString, forKey: SettingKeys.motdtime)
                            self.getMessageOfTheDay()
                        }
                    }
                    
                    if (answer == 10 || answer == 100) {
                        DispatchQueue.main.async {
                            SettingsManager.clearKeys()
                            self.connection.closeConnection()
                            self.connect()
                        }
                    } else {
                        if (!self.connected) {
                            self.shouldReConnect = false
                        } else {
                            for request in self.delayedRequests {
                                self.send(request: request)
                            }
                            self.delayedRequests = []
                        }
                        if let trackerId = self.TrackerID {
                            SettingsManager.setKey(trackerId as NSString, forKey: SettingKeys.trackerId)
                        }
                        connectionRun.notify((answer, name))
                        
                    }
                } else {
                    connectionRun.notify((answer, name))
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
                groupActivated.notify((result.0, value))
            }else {
                log.enqueue("error: activate group asnwer cannot be parsed")
            }

            return
        }
        if command == AnswTags.deactivateGroup.rawValue {
            if let result = parseForErrorJson(output){
                groupDeactivated.notify((result.0,  result.1))
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
        if command == Tags.groupChat.rawValue {
            let parseRes = parseGroupUpdate(output)
            if let grId = parseRes.0, let res = parseRes.1 {
                self.messagesUpdated.notify((grId, res))
            }else {
                log.enqueue("error: groups chat answer cannot be parsed")
            }
     
            return
        }
        if command == Tags.groupChatMessage.rawValue {
            let parseRes = parseGroupUpdate(output)
            if let grId = parseRes.0, let res = parseRes.1 {
                self.messagesUpdated.notify((grId, res))
            }else {
                log.enqueue("error: groups chat message cannot be parsed")
            }
            
            return
        }
        if command == Tags.groupChatSend.rawValue {
            if let result = parseForErrorJson(output){
                messageSent.notify((result.0,  result.1))
            } else {
                log.enqueue("error: message sent cannot be parsed")
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
                let value = (result.0==1 ? result.1 : (result.1=="" ? output.components(separatedBy: "|")[1] : result.1 ))
                groupCreated.notify((result.0,  value))
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
                    
                    if let sessionUrl = parseTag(output, key: Keys.sessionUrl) {
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
            if parseForErrorJson(output) != nil{
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
                self.onSentCoordinate(cnt:cnt!)
            }
            
            return
        }
        if command == AnswTags.buffer.rawValue {
            
            let cnt = Int(addict)
            if cnt ?? 0 > 0 {
                self.onSentCoordinate(cnt:cnt!)
            }
            
            return
        }
        if command == AnswTags.grCoord.rawValue {
            let parseRes = parseGroupUpdate(output)
            if let grId = parseRes.0, let res = parseRes.1 {
                if let userCoordinates = parseCoordinate(grId, coordinates: res) {
                    monitoringGroupsUpdated.notify(userCoordinates)
                }
                else {
                    log.enqueue("error: parsing coordinate array")
                }
            }
            
            //D:47580|L37.33018:-122.032582S1.3A9H5C
            //G:1578|["17397|L59.852968:30.373739S0","47580|L37.330178:-122.032674S3"]
            return
        }
        if command == AnswTags.messageDay.rawValue {
            if (command != "" && addict != "") {
                SettingsManager.setKey(addict as NSString, forKey: SettingKeys.motd)
                messageOfTheDayReceived.notify((1, addict))
            }
            else {
                log.enqueue("error: wrong parsing MD")
            }
            
            return
        }
        
        if command == Tags.history.rawValue {
            if (command != "" && addict != "") {
                if let json = parseJson(output) {
                    historyReceived.notify((1, json))
                }
            }
            else {
                log.enqueue("error: wrong parsing HISTORY")
            }
            
            return
        }
        
        if command == AnswTags.remoteCommand.rawValue {
            let sendingManger = SendingManager.sharedSendingManager
            if (param == RemoteCommand.TRACKER_BATTERY_INFO.rawValue){
                sendBatteryStatus(param)
                return
            }
            
            if (param == RemoteCommand.TRACKER_SYSTEM_INFO.rawValue){
                sendSystemInfo()
                return
            }
            if (param == RemoteCommand.TRACKER_VIBRATE.rawValue){
                //for _ in 1...3 {
                    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
                    //sleep(1)
                //}
                sendRemoteCommandResponse(param)
                return
            }
            if (param == RemoteCommand.ALARM_ON.rawValue){
                if let fileURL = Bundle.main.path(forResource: "signal", ofType: "mp3") {
                    do {
                        audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: fileURL))
                        audioPlayer.numberOfLoops = 3
                        audioPlayer.prepareToPlay()
                        audioPlayer.play()
                        sendRemoteCommandResponse(param)
                    } catch {
                        
                        
                    }
                }
                
                return
            }
            if (param == RemoteCommand.ALARM_OFF.rawValue){
                if audioPlayer.isPlaying {
                    audioPlayer.stop()
                    sendRemoteCommandResponse(param)
                }
                return
            }
            

            if (param == RemoteCommand.TRACKER_SESSION_STOP.rawValue){
                sendingManger.stopSendingCoordinates()
                sendRemoteCommandResponse(param)
                return
            }
            if (param == RemoteCommand.TRACKER_EXIT.rawValue){
                sendingManger.stopSendingCoordinates()
                sendRemoteCommandResponse(param)
                connection.closeConnection()
                return
            }
            if (param == RemoteCommand.TRACKER_SESSION_START.rawValue){
                self.isGettingLocation = false
                sendingManger.startSendingCoordinates(false)
                sendRemoteCommandResponse(param)
                return
            }
            if (param == RemoteCommand.TRACKER_SESSION_PAUSE.rawValue){
                sendingManger.pauseSendingCoordinates(true)
                sendRemoteCommandResponse(param)
                return
            }
            if (param == RemoteCommand.TRACKER_SESSION_CONTINUE.rawValue){
                sendingManger.startSendingCoordinates(false)
                sendRemoteCommandResponse(param)
                return
            }
            if (param == RemoteCommand.TRACKER_GCM_ID.rawValue) {
                //Отправляем токен ранее полученный от FCM
                if let token = Messaging.messaging().fcmToken {
                    sendPush(token)
                }
                sendRemoteCommandResponse(param)
                return
            }
            
            if (param == RemoteCommand.REFRESH_GROUPS.rawValue){
                sendGetGroups()
                sendRemoteCommandResponse(param)
                return
            }
            if (param == RemoteCommand.CHANGE_MOTD_TEXT.rawValue){
                messageOfTheDayReceived.notify((1, addict))
                sendRemoteCommandResponse(param)
                return
            }

            if (param == RemoteCommand.WHERE.rawValue || param == RemoteCommand.WHERE_GPS_ONLY.rawValue || param == RemoteCommand.WHERE_NETWORK_ONLY.rawValue) {
                sendRemoteCommandResponse(param)
                if self.sessionOpened == false {
                    if (param == RemoteCommand.WHERE.rawValue) {
                        LocationTracker.sharedLocationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                    } else if (param == RemoteCommand.WHERE_GPS_ONLY.rawValue){
                        LocationTracker.sharedLocationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
                    } else if (param == RemoteCommand.WHERE_NETWORK_ONLY.rawValue){
                        LocationTracker.sharedLocationManager.desiredAccuracy = kCLLocationAccuracyKilometer
                    }
                    self.isGettingLocation = true
                    sendingManger.startSendingCoordinates(true)
                }
                return
            }
        }
    }


    
    //MARK - parsing server response functions
    func onSentCoordinate(cnt: Int){
        log.enqueue("Removing \(cnt) coordinates from buffer")
        for _ in 1...cnt {
            if self.coordinates.count > 0 {
                self.coordinates.remove(at: 0)
            }
        }
        self.sendingCoordinates = false
        self.sendNextCoordinates()
    }
    
    fileprivate func sendNextCoordinates(){
        /*
         if self.shouldCloseSession {
         
         self.coordinates.removeAll(keepingCapacity: false)
         closeSession()
         }*/
        
        //TODO: refactoring send best coordinates
        let cnt = self.coordinates.count;
        if self.sessionOpened && cnt > 0 {
            var req = ""
            var sep = ""
            var idx = 0;
            if cnt > 1 {
                sep = "\""
            }
            for theCoordinate in self.coordinates {
                if req != "" {
                    req = "\(req),"
                }
                req = "\(req)\(sep)\(theCoordinate.getCoordinateRequest)\(sep)"
                idx = idx + 1
                //Ограничиваем количество отправляемых точек в одном пакете
                if idx > 500 {
                    break;
                }
            }
            if cnt > 1 {
                req = "\(Tags.buffer.rawValue)|[\(req)]"
            } else {
                req = "\(Tags.coordinate.rawValue)|\(req)"
            }
            send(request:req)
            if (idx % 10 == 0 && !self.connected) { //Накопилось 10 координат а соединение разорвано?
                self.connect() //Пытаемся восстановить соединение
                
            }
        }
    }
    
    fileprivate func parseCoordinate(_ group: Int, coordinates: Any) -> [UserGroupCoordinate]? {
        if let users = coordinates as? Array<String> {
            var res : [UserGroupCoordinate] = [UserGroupCoordinate]()
            
            for u in users {
                let uc = u.components(separatedBy: "|")
                let user_id = Int(uc[0])
                if ((user_id ?? 0) != 0) { //id
                    
                    let location = LocationModel(coordString: uc[1])
                    let ugc: UserGroupCoordinate = UserGroupCoordinate(group: group, user: user_id!, location: location)
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
        let json = responce[responce.index(responce.startIndex, offsetBy: index)..<responce.endIndex]
        
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
        let json = responce[responce.index(responce.startIndex, offsetBy: index)..<responce.endIndex]
        
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
    
    fileprivate func parseTag(_ responce: String, key: Keys) -> String? {
        
        if let responceValues: NSDictionary = parseJson(responce) as? Dictionary<String, AnyObject> as NSDictionary? {
            if let tag = responceValues.object(forKey: key.rawValue) as? String {
                return tag
            } else if let itag = responceValues.object(forKey: key.rawValue) as? Int {
                return "\(itag)"
            }
        }
        return nil
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
