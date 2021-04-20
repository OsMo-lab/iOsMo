//
//  GroupsManager.swift
//  iOsmo
//
//  Created by Olga Grineva on 08/04/15.
//  Copyright (c) 2015 Olga Grineva, (c) 2017 Alexey Sirotkin All rights reserved.
//

import Foundation
import CoreLocation

open class GroupManager{
    var allGroups: [Group] = [Group]()
    var monitoringGroupsHandler: ObserverSetEntry<[UserGroupCoordinate]>?
    var monitoringGroupsUpdated = ObserverSet<[UserGroupCoordinate]>()
 
    var groupListUpdated = ObserverSet<[Group]>()
  
    
    var groupEntered = ObserverSet<(Int, String)>()
    var groupLeft = ObserverSet<(Int, String)>()
    var groupActivated = ObserverSet<(Int, String)>()
    var groupDeactivated = ObserverSet<(Int, String)>()
    var groupCreated = ObserverSet<(Int, String)>()
    var groupsUpdated = ObserverSet<(Int, Any)>()
    var messagesUpdated = ObserverSet<(Int, Any)>()
    var messageSent = ObserverSet<(Int, String)>()
    let trackDownloaded =  ObserverSet<(Track)>()
    
    var onGroupListUpdated: ObserverSetEntry<[Group]>?

    
    var onActivateGroup : ObserverSetEntry<(Int, String)>?
    var onDeactivateGroup : ObserverSetEntry<(Int, String)>?
    var onUpdateGroup : ObserverSetEntry<(Int, Any)>?
    var onMessagesUpdated : ObserverSetEntry<(Int, Any)>?
    
    var onEnterGroup : ObserverSetEntry<(Int, String)>?
    var onLeaveGroup : ObserverSetEntry<(Int, String)>?
    var onMessageSent : ObserverSetEntry<(Int, String)>?
    var onCreateGroup : ObserverSetEntry<(Int, String)>?
    
    fileprivate let log = LogQueue.sharedLogQueue
    
    class var sharedGroupManager : GroupManager {
    
        struct Static {
            static let instance: GroupManager = GroupManager()
        }
        
        return Static.instance
    }
    
    fileprivate let connection = ConnectionManager.sharedConnectionManager

    public init(){
        self.monitoringGroupsHandler = connection.monitoringGroupsUpdated.add({
            let locations = $0
            for location in locations {
                let clLocation = CLLocationCoordinate2D(latitude: location.location.lat, longitude: location.location.lon)
                
                if let user = self.getUser(location.groupId, user: location.userId){
                    user.coordinate = CLLocationCoordinate2D(latitude: location.location.lat, longitude: location.location.lon);
                    user.time = location.location.time
                    if location.location.speed>=0 {
                        user.speed = location.location.speed
                        user.subtitle = "\(user.speed)"
                    }
                    user.track.append(clLocation)
                } else {
                    //Получены координаты пользователя, которого нет в кэше. Запрашиваем группы с сервера
                    self.groupList(false)
                }
            }
            self.monitoringGroupsUpdated.notify($0)
            })
        self.onUpdateGroup = connection.groupsUpdated.add({
            let g = $1 as! Dictionary<String, AnyObject>
            let group = $0
            var max_id = 0
            if let foundGroup = self.allGroups.filter({$0.u == "\(group)"}).first {
                if let jsonUsers = g["users"] as? Array<AnyObject> {
                    for jsonU in jsonUsers{
                        let u = jsonU as! Dictionary<String, AnyObject>
                        let uId = (u["u"] as? Int) ?? Int(u["u"] as? String ?? "0")!
                        let uE = (u["e"] as? Int) ?? Int(u["e"] as? String ?? "0")!
                        
                        let uTime = (u["time"] as? Double) ?? atof(u["time"] as? String ?? "0")
                        let deleteUser = u["deleted"] as? String
                        
                        if let user = self.getUser($0,user: uId) {
                            if (deleteUser != nil ) {
                                let uIdx = foundGroup.users.index(of: user)
                                if uIdx! > -1 {
                                    foundGroup.users.remove(at: uIdx!)
                                }
                            } else {
                                if let uName = u["name"] as? String {
                                    let uConnected = (u["connected"] as? Double) ?? 0
                                    let uColor = u["color"] as? String ?? ""
                                    let uState = (u["state"] as? Int) ?? 0
                                    user.state = uState
                                    user.color = uColor
                                    user.connected = uConnected
                                    user.name = uName
                                    user.time = Date(timeIntervalSince1970: uTime)
                                    user.speed = -1.0
                                }
                            }
                        } else {
                            if (deleteUser == nil) {
                                let nUser = User(json:jsonU as! Dictionary<String, AnyObject>)
                                nUser.groupId = Int(foundGroup.u) ?? 0
                                foundGroup.users.append(nUser)
                            }
                        }
                        if uE != 0 {
                            max_id = uE
                        }
                    }
                    /*
                     //Вступление нового пользователя в группу, без кооординат. Ничего не делаем. Ждем users
                     } else if let jsonJoin = g["join"] as? Array<AnyObject> {
                     for json in jsonJoin{
                     
                     }
                     */
                } else if let jsonLeave = g["leave"] as? Array<AnyObject> {
                    for jsonL in jsonLeave{
                        let u = jsonL as! Dictionary<String, AnyObject>
                        let uId = (u["u"] as? Int) ?? Int(u["u"] as? String ?? "0")!
                        let uE = (u["e"] as? Int) ?? Int(u["e"] as? String ?? "0")!
                        
                        if let user = self.getUser($0,user: uId) {
                            let uIdx = foundGroup.users.index(of: user)
                            if uIdx! > -1 {
                                foundGroup.users.remove(at: uIdx!)
                            }
                        }
                        if uE != 0 {
                            max_id = uE
                        }
                        
                    }
                } else if let jsonPoints = g["point"] as? Array<AnyObject> {
                    for jsonP in jsonPoints {
                        let u = jsonP as! Dictionary<String, AnyObject>
                        let uId = (u["u"] as? Int) ?? Int(u["u"] as? String ?? "0")!
                        let uE = (u["e"] as? Int) ?? Int(u["e"] as? String ?? "0")!
                        
                        if let point = self.getPoint($0,point: uId) {
                            if (u["deleted"] as? String) != nil {
                                let uIdx = foundGroup.points.index(of: point)
                                if uIdx! > -1 {
                                    foundGroup.points.remove(at: uIdx!)
                                }
                            } else {
                                let lat = u["lat"] as? Double ?? atof((u["lat"] as? String) ?? "")
                                let lon = u["lon"] as? Double ?? atof((u["lon"] as? String) ?? "")
                                let uName = u["name"] as? String ?? ""
                                let descr = u["description"] as? String ?? ""
                                let uColor = u["color"] as? String ?? ""
                                let uURL = u["url"] as? String ?? ""
                                
                                point.color = uColor
                                point.name = uName
                                point.lat = lat
                                point.lon = lon
                                point.descr = descr
                                point.url = uURL
                            }
                        } else {
                            let pointNew = Point (json: jsonP as! Dictionary<String, AnyObject>)
                            pointNew.groupId = Int(foundGroup.u) ?? 0
                            foundGroup.points.append(pointNew)
                        }
                        if uE != 0 {
                            max_id = uE
                        }
                    }
                } else if let jsonTracks = g["track"] as? Array<AnyObject> {
                    for jsonT in jsonTracks {
                        let u = jsonT as! Dictionary<String, AnyObject>
                        let uId = (u["u"] as? Int) ?? Int(u["u"] as? String ?? "0")!
                        let uE = (u["e"] as? Int) ?? Int(u["e"] as? String ?? "0")!
                        
                        if let track = self.getTrack($0,track: uId) {
                            if (u["deleted"] as? String) != nil {
                                let uIdx = foundGroup.tracks.index(of: track)
                                if uIdx! > -1 {
                                    foundGroup.tracks.remove(at: uIdx!)
                                }
                            } else {
                                let uName = u["name"] as? String ?? ""
                                let uColor = u["color"] as? String ?? ""
                                track.name = uName
                                track.color = uColor
                            }
                        } else {
                            let track = Track(json:jsonT as! Dictionary<String, AnyObject>)
                            track.groupId = Int(foundGroup.u ) ?? 0
                            foundGroup.tracks.append(track)
                        }
                        if uE != 0 {
                            max_id = uE
                        }
                    }
                }
                
            }
            
            
            if max_id != 0 {
                self.connection.sendUpdateGroupResponse(group: group, event: max_id)
            }
            self.saveCache()
            self.groupsUpdated.notify(($0,$1))
        })
        
        self.onGroupListUpdated = connection.groupList.add{
            self.allGroups = $0
            self.groupListUpdated.notify($0)
            self.saveCache()
            for group in $0 {
                for track in group.tracks{
                    self.getTrackData(track)
                }
            }
        }
        self.onMessagesUpdated = connection.messagesUpdated.add({
            let json = $1
            let group = $0

            if let jsonarr = json as? Array<Any>, let foundGroup = self.allGroups.filter({$0.u == "\(group)"}).first {
                for m in jsonarr {
                    let message = ChatMessage.init(json: m as! Dictionary<String, AnyObject>)
                    foundGroup.messages.append(message)
                }
            } else if let foundGroup = self.allGroups.filter({$0.u == "\(group)"}).first {
                let message = ChatMessage.init(json: json as! Dictionary<String, AnyObject>)
                foundGroup.messages.append(message)
            }
            self.messagesUpdated.notify((group, json))
        })
    }
    
    open func activateGroup(_ name: String){
        self.onActivateGroup = connection.groupActivated.add{
            self.groupActivated.notify(($0, $1))
            print("ACTIVATED! \($0) \(name)")
            if($0 == 0) {
                do {
                    if let data: Data = $1.data(using: String.Encoding.utf8), let jsonObject: Any? =  try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) {
                        
                        let group = Group.init(json: jsonObject as! Dictionary<String, AnyObject>)

                        let idx = self.allGroups.index(of: group)
                        if idx! > -1 {
                            self.allGroups[idx!] = group
                        }
                        
                    }
                    self.saveCache()
                } catch {}
            }
            
            self.connection.groupActivated.remove(self.onActivateGroup!)
        }
        connection.activateGroup(name)
    }
    
    open func deactivateGroup(_ name: String) {
        self.onDeactivateGroup = connection.groupDeactivated.add{
            self.groupDeactivated.notify(($0, $1))
            
            print("DEACTIVATED \(name)! \($0) ")
            if($0 == 0) {
                for group in self.allGroups {
                    if group.u == name {
                        group.active = false;
                        break;
                    }
                }
                self.saveCache()
            }
            self.connection.groupDeactivated.remove(self.onDeactivateGroup!)
        }
        connection.deactivateGroup(name)
    }
    
    open func groupsSwitch(_ s: Int) {
        connection.groupsSwitch(s)
    }

    open func createGroup(_ name: String, email: String, nick: String){
        self.onCreateGroup = connection.groupCreated.add{
            print("GM.createGroup add")
            /*if ($0 != 0) {
                self.groupList(false)
            }*/
            
            if ($0 == 0) {
                do {
                    if let data: Data = $1.data(using: String.Encoding.utf8), let jsonObject: Any? =  try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) {
                        
                        let group = Group.init(json: jsonObject as! Dictionary<String, AnyObject>)
                        self.allGroups.append(group)
                    }
                    self.saveCache()
                } catch {}
                
            }
            
            self.groupCreated.notify(($0, $1))
            self.connection.groupCreated.remove(self.onCreateGroup!)
        }
        connection.createGroup(name, email: email, nick: nick)
    }
    
    open func enterGroup(_ name: String, nick: String){
        self.onEnterGroup = connection.groupEntered.add{
            self.groupEntered.notify(($0, $1))
            self.connection.groupEntered.remove(self.onEnterGroup!)
        }
        connection.enterGroup(name, nick: nick)
    }
    
    open func leaveGroup(_ u: String) {
        self.onLeaveGroup = connection.groupLeft.add{
            self.groupLeft.notify(($0, $1))
            if $0 == 0 {
                let foundGroup = self.allGroups.filter{$0.u == "\(u)"}.first
                let idx = self.allGroups.index(of: foundGroup!)
                if idx! > -1 {
                    self.allGroups.remove(at: idx!);
                    self.saveCache()
                }
            }
            self.connection.groupLeft.remove(self.onLeaveGroup!)
        }
        connection.leaveGroup(u)
    }
    
    open func saveCache() {
        if self.allGroups.count > 0 {
            let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true);
            let path =  "\(paths[0])/GROUP.json"
            do {
                var jsonInfo : [NSDictionary] = [NSDictionary]()
                for g in self.allGroups {
                    var users : [NSDictionary] = [NSDictionary]()
                    for u in g.users {
                        let t:TimeInterval = u.time.timeIntervalSince1970
                        
                        let user : NSDictionary =
                            ["u": u.u, "name": u.name, "connected": u.connected, "color": u.color, "state": u.state, "time": t, "online": u.online, "lat": "\(u.coordinate.latitude)", "lon": "\(u.coordinate.longitude)"];
                        users.append(user)
                    }
                    
                    var points : [NSDictionary] = [NSDictionary]()
                    for p in g.points {
                        let t:TimeInterval = (p.time != nil) ? p.time!.timeIntervalSince1970 : 0
                        let s:TimeInterval = (p.start != nil) ? p.start!.timeIntervalSince1970 : 0
                        let f:TimeInterval = (p.finish != nil) ? p.finish!.timeIntervalSince1970 : 0
                        let point : NSDictionary =
                            ["u": p.u, "name": p.name,"url": p.url, "description": p.descr, "color": p.color, "lat": "\(p.lat)", "lon": "\(p.lon)","time":"\(t)","start":"\(s)","finish":"\(f)"];
                        points.append(point)
                    }
                    
                    var tracks : [NSDictionary] = [NSDictionary]()
                    for t in g.tracks {
                        let track : NSDictionary =
                            ["u": t.u, "name": t.name, "description": t.descr, "color": t.color, "size": "\(t.size)", "url": t.url, "type": t.type];
                        tracks.append(track)
                    }

                    
                    let jsonGroup : NSDictionary =
                        ["u": g.u, "url": g.url, "name": g.name, "description": g.descr, "active": (g.active ? "1" : "0"), "type": g.type, "color": g.color, "policy": g.policy
                        ,"nick": g.nick
                        ,"permament": g.permanent
                        ,"users": users, "point": points, "track": tracks
                    ];
                    jsonInfo.append(jsonGroup)
                    
                }
                
                let data = try JSONSerialization.data(withJSONObject: jsonInfo, options: JSONSerialization.WritingOptions(rawValue: 0))
                try data.write(to: URL(fileURLWithPath: path))
                log.enqueue("GROUP cached")
                
            }catch {
                log.enqueue("error saving GROUP info")
            }
        }
    }
    
    open func sendChatMessage(group: Int, text: String) {
        self.onMessageSent = connection.messageSent.add{
            /*
            if let foundGroup = self.allGroups.filter({$0.u == "\(group)"}).first {
                let message = ChatMessage.init(text:text);
                foundGroup.messages.append(message)
                
            }*/
            self.messageSent.notify(($0, $1))
            self.connection.messageSent.remove(self.onMessageSent!)
        }
        connection.sendChatMessage(group: group, text: text)
    }
    
    open func clearCache() {
        log.enqueue("Clearing GROUP cache")
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true);
        var path =  "\(paths[0])/GROUP.json"
        let fileManager = FileManager.default;

        do {
            //Удаляем кэш группы
            try fileManager.removeItem(atPath: path)
            //Удаляем кешированые треки
            path = "\(paths[0])/channelsgpx/"
            let files = try fileManager.contentsOfDirectory(atPath: path)
           
            for file in files {
                try fileManager.removeItem(atPath: "\(path)\(file)")
            }
            
        } catch {
            
        }
    }
    
    open func groupList(_ cached: Bool){
        var shouldDownload = true;
        if (cached) {
            let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true);
            let filename = "GROUP.json"
            let path =  "\(paths[0])/"
            let fileManager = FileManager.default;
 
            if fileManager.fileExists(atPath: "\(path)\(filename)") {
                do {
                    print("Found cached \(path)\(filename)")
                    let attr = try fileManager.attributesOfItem(atPath: "\(path)\(filename)")
                    
                    let fileDate = attr[FileAttributeKey.modificationDate] as! Date;
                    
                    if fileDate.timeIntervalSinceNow > 60 * 60 * 24 {
                        log.enqueue("GROUP cache expired")
                       
                    } else {
                        do {
                            
                            let file: FileHandle? = FileHandle(forReadingAtPath: "\(path)\(filename)")
                            if file != nil {
                                // Read all the data
                                let data = file?.readDataToEndOfFile()
                                if let jsonObject: Any? =  try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) {
                                    allGroups.removeAll()
                                    
                                    if let jsonGroups = jsonObject as? Array<Any> {
                                        for jsonG in jsonGroups{
                                            let group = Group.init(json: jsonG as! Dictionary<String, AnyObject>)
                                                
                                            allGroups.append(group)
                                            
                                        }
                                    }
                                }
                            }
                            shouldDownload = false;
                        } catch {
                            
                        }
                    }
                } catch {
                    
                }
            } else {
                var isDir : ObjCBool = false
                if !fileManager.fileExists(atPath: path, isDirectory:&isDir) {
                    do {
                        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                    } catch {
                        print ("can't create directory \(path)")
                    }
                }
                shouldDownload = true
            }
        }
        
        if (shouldDownload == true || cached == false){
            self.clearCache()
            connection.getGroups()
        }
    }
    
    func getTrackData(_ track:Track) {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true);
        let filename = "\(track.groupId)-\(track.u).gpx"
        let path =  "\(paths[0])/channelsgpx/"
        let fileManager = FileManager.default;
        var shouldDownload = true;
        print(track.url)
        
        if fileManager.fileExists(atPath: "\(path)\(filename)") {
            do {
                let attr = try fileManager.attributesOfItem(atPath: "\(path)\(filename)")
                let fileSize:Int = attr[FileAttributeKey.size] as! Int
                if fileSize == track.size {
                    shouldDownload = false
                    print("Found cached track \(path)\(filename)")
                }
            } catch {
            
            }
        } else {
            var isDir : ObjCBool = false
            if !fileManager.fileExists(atPath: path, isDirectory:&isDir) {
                do {
                    try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print ("can't create directory \(path)")
                }
            }
        }
        if shouldDownload == true {
            if let url = URL(string: track.url){
                ConnectionHelper.downloadRequest(url, completed: {result, data in
                    if result {
                        let fileURL = URL(fileURLWithPath: "\(path)\(filename)")
                        do {
                            try data?.write(to: fileURL)
                            print("Saved file \(path)\(filename)")
                            self.trackDownloaded.notify((track))
                        } catch{
                            print("Error saving \(path)\(filename)")
                        }
                    }
                })
            }
        }
    }
 

    open func getUser(_ group:  Int, user: Int) -> User? {
        let foundGroup = allGroups.filter{$0.u == "\(group)"}.first
        return foundGroup?.users.filter{$0.u == "\(user)"}.first
    }
    
    open func getPoint(_ group:  Int, point: Int) -> Point? {
        let foundGroup = allGroups.filter{$0.u == "\(group)"}.first
        return foundGroup?.points.filter{$0.u == point}.first
    }
    
    open func getTrack(_ group:  Int, track: Int) -> Track? {
        let foundGroup = allGroups.filter{$0.u == "\(group)"}.first
        return foundGroup?.tracks.filter{$0.u == track}.first
    }
}
