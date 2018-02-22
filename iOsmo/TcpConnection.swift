//
//  TcpConnectionNew.swift
//  iOsmo
//
//  Created by Olga Grineva on 25/03/15.
//  Copyright (c) 2015 Olga Grineva, (c) 2017 Alexey Sirotkin. All rights reserved.
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
    
    let answerObservers = ObserverSet<(AnswTags, String, Int)>()
    let groupListDownloaded = ObserverSet<[Group]>()
    let groupCreated = ObserverSet<(Int, String)>()
    let monitoringGroupsUpdated = ObserverSet<[UserGroupCoordinate]>()
    let groupsUpdated = ObserverSet<(Int, Any)>()
    
    open var sessionUrlParsed: String = ""
    open var device_key: String = ""
    open var sessionTrackerID: String = ""
    open func getSessionUrl() -> String? {return "https://osmo.mobi/s/\(sessionUrlParsed)"}
    open func getTrackerID()-> String?{return sessionTrackerID}

    open override func connect(_ token: Token){
        super.tcpClient.callbackOnParse = parseOutput
        super.connect(token)
        
        //sendAuth(token.device_key as String)
    }
    
    open func openSession(){
        let request = "\(Tags.openSession.rawValue)"
        super.send(request)
    }
       
    open func sendGetGroups(){
        
        let request = "\(Tags.getGroups.rawValue)"
        super.send(request)
    }
    
    open func sendUpdateGroupResponse(group: Int, event:Int){
        
        let request = "\(Tags.updateGroupResponse.rawValue):\(group)|\(event)"
        super.send(request)
    }

    
    open func sendCreateGroup(_ name: String, email: String, nick: String, gtype: String, priv: Bool){
        
        let jsonInfo: NSDictionary =
            ["name": name as NSString, "email": email as NSString, "nick": nick as NSString, "type": gtype as NSString, "private":(priv == true ? "1" :"0") as NSString]
        
        do{
            let data = try JSONSerialization.data(withJSONObject: jsonInfo, options: JSONSerialization.WritingOptions(rawValue: 0))
            
            if let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                let request = "\(Tags.createGroup.rawValue):|\(jsonString)"
                super.send(request)
            }
        }catch {
            print("error generating system info")
        }
    }
    
    open func sendEnterGroup(_ name: String, nick: String){
        let request = "\(Tags.enterGroup.rawValue)\(name)|\(nick)"
        super.send(request)
    }
    
    open func sendLeaveGroup(_ u: String){
        let request = "\(Tags.leaveGroup.rawValue)\(u)"
        super.send(request)
    }
    
    open func sendActivateGroup(_ u: String){
        let request = "\(Tags.activateGroup.rawValue)\(u)"
        super.send(request)
    }
    
    open func sendDeactivateGroup(_ u: String){
        let request = "\(Tags.deactivateGroup.rawValue)\(u)"
        super.send(request)
    }
    
    
    open func sendActivatePoolGroups(_ s: Int){
        let request = "\(Tags.activatePoolGroups.rawValue)|\(s)"
        super.send(request)
    }
    
    open func sendGroupsSwitch(_ s: Int){
        let request = "\(Tags.groupSwitch.rawValue)"
        super.send(request)
    }
    
    open func sendMessageOfTheDay(){
        let request = "\(Tags.messageDay.rawValue)"
        super.send(request)
    }
    
    open func sendPush(_ token: String){
        let request = "\(Tags.push.rawValue)|\(token)"
        super.send(request)
    }
    //MARK private methods

    fileprivate func sendToken(_ token: Token){
        
        let request = "\(Tags.token.rawValue)\(token.token)"
        
        super.send(request)
        
        print("send token \(request)")
        log.enqueue("send token")
    }
    
    open func sendRemoteCommandResponse(_ rc: String) {
        let request = "\(Tags.remoteCommandResponse.rawValue)\(rc)"
        super.send(request)
    }
    
    open func sendAuth(_ device_key: String){
        let request = "\(Tags.auth.rawValue)\(device_key)"
        super.send(request)
    }
    
    open func sendCoordinate(_ coordinate: LocationModel){
        let request = "\(Tags.remoteCommandResponse.rawValue)\(RemoteCommand.WHERE.rawValue)|\(coordinate.getCoordinateRequest)"
        super.send(request)
    }

    //probably should be refactored and moved to ReconnectManager
    fileprivate func sendPing(){
        super.send("\(Tags.ping.rawValue)")
    }
    
    open func sendSystemInfo(){
        let model = UIDevice.current.model
        let version = UIDevice.current.systemVersion
        
        let jsonInfo: NSDictionary =
            ["devicename": model, "version": "iOS \(version)"]
        
        do{
            let data = try JSONSerialization.data(withJSONObject: jsonInfo, options: JSONSerialization.WritingOptions(rawValue: 0))
            
            if let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                let request = "\(Tags.remoteCommandResponse.rawValue)\(RemoteCommand.TRACKER_SYSTEM_INFO.rawValue)|\(jsonString)"
                send(request)
            }
        }catch {
            print("error generating system info")
        }
    }
    
    open func sendBatteryStatus(){
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel * 100
        var state = 0;
        if (UIDevice.current.batteryState == .charging) {
            state = 1;
        }
        
        let jsonInfo: NSDictionary =
            ["percent": level, "plugged": state]
        
        do{
            let data = try JSONSerialization.data(withJSONObject: jsonInfo, options: JSONSerialization.WritingOptions(rawValue: 0))
            
            if let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                let request = "\(Tags.remoteCommandResponse.rawValue)\(RemoteCommand.TRACKER_BATTERY_INFO.rawValue)|\(jsonString)"
                send(request)
            }
        }catch {
            print("error generating battery info")
        }
    }
    
    open func parseOutput(_ output: String){
        
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
        let addict = output.components(separatedBy: "|").last!
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
                if result.0 == 0 {
                    if let trackerID = parseTag(output, key: ParseKeys.id) {
                        sessionTrackerID = trackerID
                    } else {
                        sessionTrackerID = "error parsing TrackerID"
                    }
                    answerObservers.notify(AnswTags.auth, result.1 , result.0)
                    if let parsed = parseJson(output)  as? [String: Any] {
  
                    }
                } else {
                    answerObservers.notify(AnswTags.auth, result.1 , result.0)
                }
                
            }
            
        }
        
        if outputContains(AnswTags.openedSession){
            
            print("open session")
            log.enqueue("session opened answer") //ex: TO|{"session":145004,"url":"f1_o9_7s"}

            if let result = parseForErrorJson(output){
                if result.0 == 0 {
                    super.sessionOpened = true
                    if let sessionUrl = parseTag(output, key: ParseKeys.sessionUrl) {
                        sessionUrlParsed = sessionUrl
                    } else {
                        sessionUrlParsed = "error parsing url"
                    }
                }
                answerObservers.notify(AnswTags.openedSession, result.1 , result.0)
                return
            } else {
                log.enqueue("error: open session asnwer cannot be parsed")
            }
        }
        
        if outputContains(AnswTags.closeSession){
            log.enqueue("session closed answer")
            if let result = parseForErrorJson(output){
                answerObservers.notify((AnswTags.closeSession, NSLocalizedString("session was closed", comment:"session was closed") , result.0))
            }else {
                log.enqueue("error: session closed asnwer cannot be parsed")
            }
  
            return

        }
        
        if outputContains(AnswTags.push){
            log.enqueue("PUSH activated")
            
            //answerObservers.notify((AnswTags.push, "PUSH activated", !parseBoolAnswer()))
            if let result = parseForErrorJson(output){
                answerObservers.notify((AnswTags.push, "" , result.0))
            }else {
                log.enqueue("error: PUSH asnwer cannot be parsed")
            }
            return
        }
        if outputContains(AnswTags.createGroup){
            if let result = parseForErrorJson(output){

                groupCreated.notify(result)
                return
            } else {
                log.enqueue("error: create group asnwer cannot be parsed")
            }
            
            return
        }
        if outputContains(AnswTags.kick){
            log.enqueue("connection kicked")

            return
            //should update status of session and connection
        }
        
        if outputContains(AnswTags.pong){
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "HH:mm:ss"
            let eventDate = dateFormat.string(from: Date())
            
            log.enqueue("server wants answer ;)")
            sendPing()
            return
        }
        
        if command == AnswTags.coordinate.rawValue {
            let cnt = Int(addict)
            if cnt > 0 {
                super.onSentCoordinate(cnt:cnt!)
            }
            return
        }
        if command == AnswTags.buffer.rawValue {
            let cnt = Int(addict)
            if cnt > 0 {
                super.onSentCoordinate(cnt:cnt!)
            }
            return
        }
        
        if outputContains(AnswTags.enterGroup) {
            if let result = parseForErrorJson(output){
                answerObservers.notify(AnswTags.enterGroup, result.1 , result.0)
            } else {
                log.enqueue("error: enter group asnwer cannot be parsed")
            }
            return
        }
        if outputContains(AnswTags.leaveGroup) {
            if let result = parseForErrorJson(output){
                answerObservers.notify(AnswTags.leaveGroup, result.1 , result.0)
            }else {
                log.enqueue("error: leave group asnwer cannot be parsed")
            }
            

            return
        }
        if outputContains(AnswTags.activateGroup) {
            if let result = parseForErrorJson(output){
                let value = (result.0==1 ? result.1 : output.components(separatedBy: "|")[1])
                answerObservers.notify(AnswTags.activateGroup, value , result.0)
            }else {
                log.enqueue("error: activate group asnwer cannot be parsed")
            }
            return
        }
        if outputContains(AnswTags.deactivateGroup) {
            if let result = parseForErrorJson(output){
                answerObservers.notify(AnswTags.deactivateGroup, result.1 , result.0)
            }else {
                log.enqueue("error: deactivate group asnwer cannot be parsed")
            }
            return
        }
        
        if outputContains(AnswTags.getGroups){
            if let result = parseGroupsJson(output) {
                self.groupListDownloaded.notify(result)
            }
            else {
                log.enqueue("error: groups list answer cannot be parsed")
            }
            return
        }
        if outputContains(AnswTags.messageDay){
            if (command != "" && addict != "") {
                answerObservers.notify((AnswTags.messageDay, addict, 1))
            }
            else {
                log.enqueue("error: wrong parsing MD")
            }
            return
        }
        if outputContains(AnswTags.remoteCommand){
            self.answerObservers.notify((AnswTags.remoteCommand, param, 1))
            /*
            switch param {
            case RemoteCommand.TRACKER_SYSTEM_INFO.rawValue:
                self.sendSystemInfo()
            default:
                self.answerObservers.notify((AnswTags.remoteCommand, param, true))
            }
 */

            return
        }
        if outputContains(AnswTags.grCoord) {
            if let monitor = monitoringGroups {
                let parseRes = parseGroupCoordinates(output)
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
            }
            
        //D:47580|L37.33018:-122.032582S1.3A9H5C
        //G:1578|["17397|L59.852968:30.373739S0","47580|L37.330178:-122.032674S3"]
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
    
    func parseGroupUpdate(_ responce: String) -> (Int?, Any?){
        
        let index = responce.components(separatedBy: "|")[0].characters.count
        let range = Range<String.Index>(responce.startIndex..<responce.characters.index(responce.startIndex, offsetBy: index))
        let groupId = Int(responce.substring(with: range).components(separatedBy: ":")[1])
        
        return (groupId, parseJson(responce))
    }
    
    func parseForErrorJson(_ responce: String) -> (Int, String)? {
        if let dic = parseJson(responce) as? Dictionary<String, Any>{
            if dic.index(forKey: "error") == nil {
                return (0, "")
            }  else {
                if let err =  dic["error_description"] as? String{
                    return (1, err)
                }else if let err =  dic["error"] as? String{
                    return (1, err)
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
            
        if let data: Data = json.data(using: String.Encoding.utf8), let jsonObject: Any? =  try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) {
            var groups = [Group]()
            
            if let jsonGroups = jsonObject as? Array<Any> {
                for jsonG in jsonGroups{
                    let group = Group.init(json: jsonG as! Dictionary<String, AnyObject>)
                    
                    groups.append(group)
                }
            }
            /*
            var paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true);
            let filename = "GROUP.json"
            let path =  "\(paths[0])/"
            let fileManager = FileManager.default;
            
            var fileURL = URL(fileURLWithPath: "\(path)\(filename)")
            do {
                try data.write(to: fileURL)

                print("Saved file \(path)\(filename)")
            } catch{
                print("Error saving \(path)\(filename)")
            }
            */
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
