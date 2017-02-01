//
//  TcpConnectionNew.swift
//  iOsmo
//
//  Created by Olga Grineva on 25/03/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


open class TcpConnection: BaseTcpConnection {

    open var monitoringGroups: [Int]?
    
    let answerObservers = ObserverSet<(AnswTags, String, Bool)>()
    let groupListDownloaded = ObserverSet<[Group]>()
    let monitoringGroupsUpdated = ObserverSet<[UserGroupCoordinate]>()
    
    open var sessionUrlParsed: String = ""
    open var sessionTrackerID: String = ""
    open func getSessionUrl() -> String? {return "https://osmo.mobi/s/\(sessionUrlParsed)"}
    open func getTrackerID()-> String?{return sessionTrackerID}

    open override func connect(_ token: Token){
        
        super.connect(token)
        super.tcpClient.callbackOnParse = parseOutput
        //sendToken(token)
        sendAuth(token)
    }
    
    open func openSession(){
        
        let request = "\(Tags.openSession.rawValue)"
        super.send(request)
    }
       
    open func sendGetGroups(){
        
        let request = "\(Tags.getGroups.rawValue)"
        super.send(request)
    }
    
    open func sendEnterGroup(_ name: String, nick: String){
        let request = "\(Tags.enterGroup.rawValue)\(name)|\(nick)"
        super.send(request)
    }
    
    open func sendLeaveGroup(_ u: String){
        let request = "\(Tags.leaveGroup.rawValue)\(u)"
        super.send(request)
    }
    
    
    
    open func sendActivatePoolGroups(_ s: Int){
        let request = "\(Tags.activatePoolGroups.rawValue)|\(s)"
        super.send(request)
    }
    
    open func sendActivateAllGroups(){
        let request = "\(Tags.activateAllGroup.rawValue)"
        super.send(request)
    }
    
    open func sendDeactivateAllGroups(){
        let request = "\(Tags.deactivateAllGroup.rawValue)"
        super.send(request)
    }
    
       
    //MARK private methods

    fileprivate func sendToken(_ token: Token){
        
        let request = "\(Tags.token.rawValue)\(token.token)"
        
        super.send(request)
        
        print("send token \(request)")
        log.enqueue("send token")
    }
    
    fileprivate func sendAuth(_ token: Token){

        let request = "\(Tags.auth.rawValue)\(token.device_key)"
        
        super.send(request)
        
        print("send auth \(request)")
        log.enqueue("send auth")
    }

    //probably should be refactored and moved to ReconnectManager
    fileprivate func sendPing(){
        super.send("\(Tags.ping.rawValue)")
    }
    
    
    fileprivate func parseOutput(_ output: String){
        
        let outputContains = {(tag: AnswTags) -> Bool in
            if let container = output.range(of: tag.rawValue) {
                 //return  distance(output.startIndex, container.startIndex) == 0 //should be found at begin of string
                return output.characters.distance(from: output.startIndex, to: container.lowerBound) == 0
            }
            return false
        }
        
        //let parseBoolAnswer = {()-> Bool in return output.components(separatedBy: "|")[1] == "1" }
        let parseBoolAnswer = {()-> Bool in return output.components(separatedBy: "|").last == "1" }
        
        var command = output.components(separatedBy: "|").first!
        var addict = output.components(separatedBy: "|").last!
        var param = ""
        if command.contains(":"){
            param = command.components(separatedBy: ":").last!
            command = command.components(separatedBy: ":").first!
        }
        
        
        let parseCommandName = {() -> String in return output.components(separatedBy: "|").first!.components(separatedBy: ":").first!}
        
        let parseParamName = {() -> String in return output.components(separatedBy: "|").first!.components(separatedBy: ":").last!}
        
        //if outputContains(AnswTags.token){
        if outputContains(AnswTags.auth){
            //ex: INIT|{"id":"CVH2SWG21GW","group":1,"motd":1429351583,"protocol":2,"v":0.88} || INIT|{"id":1,"error":"Token is invalid"}
            
            if let result = parseForErrorJson(output) {
                if !result.0 {
                    if let trackerID = parseTag(output, key: ParseKeys.id) {
                        sessionTrackerID = trackerID
                    } else {
                        sessionTrackerID = "error parsing TrackerID"
                    }
                    answerObservers.notify(AnswTags.auth, result.1 , !result.0)
                    if let parsed = parseJson(output)  as? [String: Any] {
                        
                        if let groupsEnabled = parsed["group"] as? Bool {

                             answerObservers.notify((AnswTags.allGroupsEnabled, "", groupsEnabled))
                        }
                       
                    }
                } else {
                    answerObservers.notify(AnswTags.auth, result.1 , !result.0)
                }
                
            }
            
        }
        
        if outputContains(AnswTags.openedSession){
            
            print("open session")
            log.enqueue("session opened answer") //ex: TO|{"session":145004,"url":"f1_o9_7s"}

            if let result = parseForErrorJson(output){
                
                if !result.0 {
                    super.sessionOpened = true
                    if let sessionUrl = parseTag(output, key: ParseKeys.sessionUrl) {
                        sessionUrlParsed = sessionUrl
                    }
                    else {sessionUrlParsed = "error parsing url"}
                
                }
                
                answerObservers.notify(AnswTags.openedSession, result.1 , !result.0)
                return
            } else {
                print("error: open session asnwer cannot be parsed")
                log.enqueue("error: open session asnwer cannot be parsed")
            }
        }
        
        if outputContains(AnswTags.closeSession){
            
            print("session closed")
            log.enqueue("session closed answer")
            
            answerObservers.notify((AnswTags.openedSession, "session was closed", !parseBoolAnswer()))
            return
//            old code - parsing status
//            if let result = parseTag(output, key: ParseKeys.status){
//                answerObservers.notify(AnswTags.openedSession, result, false)
//            }
//            else{
//                print("error: session close tag was not parsed")
//                log.enqueue("error: session close tag was not parsed")
//            }
            
//           return
            //should update status of session
        }
        
        if outputContains(AnswTags.kick){
            
            print("connection kicked")
            log.enqueue("connection kicked")
            
            return
            //should update status of session and connection
        }
        
        if outputContains(AnswTags.pong){
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "HH:mm:ss"
            let eventDate = dateFormat.string(from: Date())
            
            print("\(output) \(eventDate) server wants answer :)")
            log.enqueue("server wants answer ;)")
            sendPing()
            return
        }
        
        if outputContains(AnswTags.coordinate) {
            super.onSentCoordinate()
            return
        }
        
        if outputContains(AnswTags.enterGroup) {
            answerObservers.notify(AnswTags.enterGroup, parseCommandName(),parseBoolAnswer())
            return
        }
        if outputContains(AnswTags.leaveGroup) {
            answerObservers.notify(AnswTags.leaveGroup, parseCommandName(), parseBoolAnswer())
            return
        }
        
        if outputContains(AnswTags.getGroups){
            if let result = parseGroupsJson(output) {
                self.groupListDownloaded.notify(result)
            }
            else {
                log.enqueue("error: wrong parsing groups list")
                print("error: wrong parsing groups list")
            }
            return
        }
        if outputContains(AnswTags.gda){
            
           self.answerObservers.notify((AnswTags.allGroupsEnabled, "", !parseBoolAnswer()))
            return
        }
        if outputContains(AnswTags.gaa){
            
            self.answerObservers.notify((AnswTags.allGroupsEnabled, "", parseBoolAnswer()))
            return
        }
        if outputContains(AnswTags.remoteCommand){
            if param == RemoteCommand.TRACKER_SYSTEM_INFO.rawValue {
                super.sendSystemInfo()
            }else if param == RemoteCommand.TRACKER_BATTERY_INFO.rawValue {
                super.sendBatteryStatus()
            }else if param == RemoteCommand.TRACKER_SESSION_STOP.rawValue {
                self.answerObservers.notify((AnswTags.remoteCommand, param, true))
            }else if param == RemoteCommand.TRACKER_SESSION_START.rawValue {
                self.answerObservers.notify((AnswTags.remoteCommand,param, true))
            }else if param == RemoteCommand.TRACKER_SESSION_PAUSE.rawValue {
                self.answerObservers.notify((AnswTags.remoteCommand,param, true))
            }
            
            return
        }
        if outputContains(AnswTags.grCoord) {

            if let monitor = monitoringGroups {
                
                let parseRes = parseGroupCoordinates(output)
                    if let grId = parseRes.0, let res = parseRes.1 {
                        
                        if monitor.contains(grId){
                            if let groups = parseCoordinate(grId, coordinates: res) {
                                monitoringGroupsUpdated.notify(groups)
                            }
                            else {
                                log.enqueue("error: wrong parsing coordinate array")
                                print("error: wrong parsing coordinate array")
                            }
                        }
                    }
                                
            }
            
        //D:47580|L37.33018:-122.032582S1.3A9H5C
        //G:1578|["17397|L59.852968:30.373739S0","47580|L37.330178:-122.032674S3"]
            return
        }
    }
    
    func parseCoordinate(_ group: Int, coordinates: Any) -> [UserGroupCoordinate]? {
        
        if let users = coordinates as? Array<String> {
            var res = [UserGroupCoordinate]()
        
            for u in users {
                let uc = u.components(separatedBy: "|")
                let user = Int(uc[0])
                if user>0 { //id
                    
                    let location = LocationModel(coordString: uc[1])
                    let ugc: UserGroupCoordinate = UserGroupCoordinate(group: group, user: user!, location: location)
                    res.append(ugc)
                }
            }
            return res
        }
        return nil
    }
    
    func parseRemoteCommand(_ responce: String) -> (Int?, AnyObject?){
        
        let index = responce.components(separatedBy: "|")[0].characters.count
        let range = Range<String.Index>(responce.startIndex..<responce.characters.index(responce.startIndex, offsetBy: index))
        let commandId = Int(responce.substring(with: range).components(separatedBy: ":")[1])
        
        return (commandId, responce as AnyObject?)
    }

    
    func parseGroupCoordinates(_ responce: String) -> (Int?, Any?){
        
        let index = responce.components(separatedBy: "|")[0].characters.count
        let range = Range<String.Index>(responce.startIndex..<responce.characters.index(responce.startIndex, offsetBy: index))
        let groupId = Int(responce.substring(with: range).components(separatedBy: ":")[1])
        
        return (groupId, parseJson(responce))
    }
    
    func parseForErrorJson(_ responce: String) -> (Bool, String)? {
        if let dic = parseJson(responce) as? Dictionary<String, Any>{

            if dic.index(forKey: "error") == nil {
                return (false, "")
            }  else {
                if let err =  dic["error_description"] as? String{
                    return (true, err)
                }else if let err =  dic["error"] as? String{
                    return (true, err)
                }
                return (true, "error message is not parsed")
            }
        }
        return nil
    }
    
    func parseJson(_ responce: String) -> Any? {
        
        
        // server can accumulate some messages, so should define it
        //let responceFirst = responce.componentsSeparatedByString("\n")[0] <-- has no sense because splitting in other place
        
        // should parse only first | sign, because of responce structure
        // "TRACKER_SESSION_OPEN|{\"warn\":1,\"session\":\"40839\",\"url\":\"lGv|f2\"}\n"
        let index = responce.components(separatedBy: "|")[0].characters.count + 1
        let range = Range<String.Index>(responce.characters.index(responce.startIndex, offsetBy: index)..<responce.endIndex)
        
        
        let json = responce.substring(with: range)
        
        //tag.componentsSeparatedByString("|")[0]
        
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
    
    func parseGroupsJson(_ responce: String) -> [Group]? {
        
        //let responceFirst = responce.componentsSeparatedByString("\n")[0] <-- has no sense because splitting in other place
        
        // should parse only first | sign, because of responce structure
        // "TRACKER_SESSION_OPEN|{\"warn\":1,\"session\":\"40839\",\"url\":\"lGv|f2\"}\n"
        
        
        let index = responce.components(separatedBy: "|")[0].characters.count + 1
        let range = Range<String.Index>(responce.characters.index(responce.startIndex, offsetBy: index)..<responce.endIndex)
        
        
        let json = responce.substring(with: range)
        
        //tag.componentsSeparatedByString("|")[0]

        do {
        if let data: Data = json.data(using: String.Encoding.utf8), let jsonObject: Any? =  try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers), let jsonGroups = jsonObject as? Array<Any> {
            
            
                var groups = [Group]()
                
                for jsonG in jsonGroups{
                    
                    let g = jsonG as! Dictionary<String, AnyObject>
                    let gName = g["name"] as! String
                    let gDescr = g["description"] as! String
                    let gPolicy = g["policy"] as! String
                    let gActive = g["active"] as! String == "1"
                    let gId = g["u"] as! String
                    let jsonUsers = g["users"] as! Array<AnyObject>
                    
                    
                    let group = Group(id: gId, name: gName, active: gActive)
                    group.descr = gDescr
                    group.policy = gPolicy
                    
                    for jsonU in jsonUsers{
                        
                        let u = jsonU as! Dictionary<String, AnyObject>
                        let uId = u["u"] as! String
                        //let uDevice = u["device"] as? String
                        let uName = u["name"] as! String
                        let uConnected = u["connected"] as! Double
                        let uColor = u["color"] as! String
                        
                        let user = User(id: uId, name: uName, color: uColor, connected: uConnected)
                        group.users.append(user)
                    }
                    
                    groups.append(group)
                }
                
                return groups

        }
    }catch {}
        return nil
    }
    
    func parseTag(_ responce: String, key: ParseKeys) -> String? {
        
        if let responceValues: NSDictionary = parseJson(responce) as? Dictionary<String, AnyObject> as NSDictionary?, let tag = responceValues.object(forKey: key.rawValue) as? String {
            return tag
        }
        return nil
    }
    

}
