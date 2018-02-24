//
//  GroupsManager.swift
//  iOsmo
//
//  Created by Olga Grineva on 08/04/15.
//  Copyright (c) 2015 Olga Grineva, (c) 2017 Alexey Sirotkin All rights reserved.
//

import Foundation
open class GroupManager{
    var groupsOnMap: [Int] = [Int]()
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
    var onGroupListUpdated: ObserverSetEntry<[Group]>?
    
    var onActivateGroup : ObserverSetEntry<(Int, String)>?
    var onDeactivateGroup : ObserverSetEntry<(Int, String)>?
    var onUpdateGroup : ObserverSetEntry<(Int, Any)>?
    var trackDownloaded : ObserverSet<(Track)>?
    
    fileprivate let log = LogQueue.sharedLogQueue
    
    class var sharedGroupManager : GroupManager {
    
        struct Static {
            static let instance: GroupManager = GroupManager()
        }
        
        return Static.instance
    }
    
    fileprivate let connection = ConnectionManager.sharedConnectionManager

    
    open func activateGroup(_ name: String){
        
        self.onActivateGroup = connection.groupActivated.add{
            
            self.groupActivated.notify($0, $1)
            
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
            
            self.groupDeactivated.notify($0, $1)
            
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

    
    var onEnterGroup : ObserverSetEntry<(Int, String)>?
    var onLeaveGroup : ObserverSetEntry<(Int, String)>?
    var onCreateGroup : ObserverSetEntry<(Int, String)>?

    open func createGroup(_ name: String, email: String, nick: String, gtype: String, priv: Bool){
        
        self.onCreateGroup = connection.groupCreated.add{
            if ($0 != 0) {
                self.groupList(false)
            }
            self.groupCreated.notify($0, $1)
            
            print("CREATED! \($0) ")
            
            self.connection.groupCreated.remove(self.onCreateGroup!)
        }
        connection.createGroup(name, email: email, nick: nick, gtype: gtype, priv: priv)
    }
    
    open func enterGroup(_ name: String, nick: String){
    
        self.onEnterGroup = connection.groupEntered.add{
        
            self.groupEntered.notify($0, $1)
            
            print("ENTERED! \($0) ")
            
            self.connection.groupEntered.remove(self.onEnterGroup!)
        }
        connection.enterGroup(name, nick: nick)
    }
    
    open func leaveGroup(_ u: String) {
        self.onLeaveGroup = connection.groupLeft.add{
            
            self.groupLeft.notify($0, $1)
            if $0 == 0 {
                let foundGroup = self.allGroups.filter{$0.u == "\(u)"}.first
                let idx = self.allGroups.index(of: foundGroup!)
                if idx! > -1 {
                    self.allGroups.remove(at: idx!);
                    self.saveCache()
                }
            }
            
            print("LEFT! \($0) ")
            
            self.connection.groupLeft.remove(self.onLeaveGroup!)
        }
        connection.leaveGroup(u)
    }
    
    open func saveCache() {
        if self.allGroups.count > 0 {
            var paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true);
            let path =  "\(paths[0])/GROUP.json"
            do {
                var jsonInfo : [NSDictionary] = [NSDictionary]()
                for g in self.allGroups {
                    var users : [NSDictionary] = [NSDictionary]()
                    for u in g.users {
                        let user : NSDictionary =
                            ["u": u.id, "name": u.name, "connected": u.connected, "color": u.color, "state": u.state, "online": u.online, "lat": "\(u.coordinate.latitude)", "lon": "\(u.coordinate.longitude)"];
                        users.append(user)
                        
                    }
                    
                    var points : [NSDictionary] = [NSDictionary]()
                    for p in g.points {
                        let point : NSDictionary =
                            ["u": p.u, "name": p.name, "description": p.descr, "color": p.color, "lat": "\(p.lat)", "lon": "\(p.lon)"];
                        points.append(point)
                    }
                    
                    var tracks : [NSDictionary] = [NSDictionary]()
                    for t in g.tracks {
                        let track : NSDictionary =
                            ["u": t.u, "name": t.name, "description": t.descr, "color": t.color, "size": "\(t.size)", "url": t.url, "type": t.type];
                        tracks.append(track)
                    }

                    
                    let jsonGroup : NSDictionary =
                        ["u": g.u, "url": g.url, "name": g.name, "description": g.descr, "id": g.id
                        ,"active": (g.active ? "1" : "0"), "type": g.type, "color": g.color, "policy": g.policy
                        ,"nick": g.nick
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
    
    open func clearCache() {
        log.enqueue("Clearing GROUP cache")
        var paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true);
        let path =  "\(paths[0])/GROUP.json"
        let fileManager = FileManager.default;

        do {
            try fileManager.removeItem(atPath: path)
        } catch {
            
        }
        
    }
    
    open func groupList(_ cached: Bool){
        if self.onGroupListUpdated == nil {
            self.onGroupListUpdated = connection.groupList.add{
                
                self.allGroups = $0
                self.groupListUpdated.notify($0)
                self.saveCache()
                for group in $0 {
                    for track in group.tracks{
                        self.downloadIfNeeded(track)
                    }
                }
            }
        }

        var shouldDownload = true;
        if (cached) {
            var paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true);
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
                                            do {
                                                let group = try Group.init(json: jsonG as! Dictionary<String, AnyObject>)
                                                
                                                allGroups.append(group)
                                            } catch {
                                                
                                            }
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
            connection.getGroups()
        }
        
    }
    
    func downloadIfNeeded(_ track:Track) {
        var paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true);
        let filename = "\(track.u).gpx"
        let path =  "\(paths[0])/channelsgpx/"
        let fileManager = FileManager.default;
        var shouldDownload = true;
        
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
                            self.trackDownloaded?.notify(track)
                            print("Saved file \(path)\(filename)")
                        } catch{
                            print("Error saving \(path)\(filename)")
                        }
                    }
                })
            }
        }
    }
 
    open func updateGroupsOnMap(_ groups: [Int]){
        groupsOnMap = groups
        connection.monitoringGroups = groups
        
        if groups.count > 0 && self.monitoringGroupsHandler == nil {
            self.monitoringGroupsHandler = connection.monitoringGroupsUpdated.add({self.monitoringGroupsUpdated.notify($0)})
            self.onUpdateGroup = connection.connection.groupsUpdated.add({
                let g = $1 as! Dictionary<String, AnyObject>
                let group = $0
                let foundGroup = self.allGroups.filter{$0.u == "\(group)"}.first

                if let jsonUsers = g["users"] as? Array<AnyObject> {
                    for jsonU in jsonUsers{
                        let u = jsonU as! Dictionary<String, AnyObject>
                        var uId = (u["u"] as? Int) ?? 0
                        if (uId == 0) {
                            uId = Int(u["u"] as! String)!
                        }
                        var uE = (u["e"] as? Int) ?? 0
                        if (uE == 0) {
                            uE = Int(u["e"] as! String)!
                        }

                        if let user = self.getUser($0,user: uId) {
                            if let uDeleted = u["deleted"] as? String {
                                let uIdx = foundGroup?.users.index(of: user)
                                if uIdx! > -1 {
                                    foundGroup?.users.remove(at: uIdx!)
                                }
                            } else {
                                if let uName = u["name"] as? String {
                                    let uConnected = (u["connected"] as? Double) ?? 0
                                    let uColor = u["color"] as! String
                                    let uState = (u["state"] as? Int) ?? 0
                                    user.state = uState
                                    user.color = uColor
                                    user.connected = uConnected
                                    user.name = uName
                                }
                            }
                        } else {
         
                            let nUser = User(json:jsonU as! Dictionary<String, AnyObject>)
                            foundGroup?.users.append(nUser)
                            
                        }
                        if uE > 0 {
                            self.connection.connection.sendUpdateGroupResponse(group: group, event: uE)
                        }
                    }
                } else if let jsonLeave = g["leave"] as? Array<AnyObject> {
                    for jsonL in jsonLeave{
                        let u = jsonL as! Dictionary<String, AnyObject>
                        var uId = (u["u"] as? Int) ?? 0
                        if (uId == 0) {
                            uId = Int(u["u"] as! String)!
                        }
                        
                        var uE = (u["e"] as? Int) ?? 0
                        if (uE == 0) {
                            uE = Int(u["e"] as! String)!
                        }
                        if let user = self.getUser($0,user: uId) {
                            let uIdx = foundGroup?.users.index(of: user)
                            if uIdx! > -1 {
                                foundGroup?.users.remove(at: uIdx!)
                            }
                        }
                        if uE > 0 {
                            self.connection.connection.sendUpdateGroupResponse(group: group, event: uE)
                        }

                    }
                } else if let jsonPoints = g["point"] as? Array<AnyObject> {
                    for jsonP in jsonPoints {
                        let u = jsonP as! Dictionary<String, AnyObject>
                        var uId = (u["u"] as? Int) ?? 0
                        if (uId == 0) {
                            uId = Int(u["u"] as! String)!
                        }
                        
                        var uE = (u["e"] as? Int) ?? 0
                        if (uE == 0) {
                            uE = Int(u["e"] as! String)!
                        }
                        if let point = self.getPoint($0,point: uId) {
                            if let uDeleted = u["deleted"] as? String {
                                let uIdx = foundGroup?.points.index(of: point)
                                if uIdx! > -1 {
                                    foundGroup?.points.remove(at: uIdx!)
                                }
                            } else {
   
                                let lat = atof(u["lat"] as! String)
                                let lon = atof(u["lon"] as! String)
                                let uName = u["name"] as? String
                                let descr = u["description"] as? String
                                let uColor = u["color"] as! String
                                
                                point.color = uColor
                                point.name = uName!
                                point.lat = lat
                                point.lon = lon
                                point.descr = descr!

                            }
                        } else {
                            let pointNew = Point (json: jsonP as! Dictionary<String, AnyObject>)
                            foundGroup?.points.append(pointNew)
                        }
                        if uE > 0 {
                            self.connection.connection.sendUpdateGroupResponse(group: group, event: uE)
                        }
                    }
                } else if let jsonTracks = g["track"] as? Array<AnyObject> {
                    for jsonT in jsonTracks {
                        let u = jsonT as! Dictionary<String, AnyObject>
                        var uId = (u["u"] as? Int) ?? 0
                        if (uId == 0) {
                            uId = Int(u["u"] as! String)!
                        }
                        
                        var uE = (u["e"] as? Int) ?? 0
                        if (uE == 0) {
                            uE = Int(u["e"] as! String)!
                        }
                        if let track = self.getTrack($0,track: uId) {
                            if let uDeleted = u["deleted"] as? String {
                                let uIdx = foundGroup?.tracks.index(of: track)
                                if uIdx! > -1 {
                                    foundGroup?.tracks.remove(at: uIdx!)
                                }
                            } else {
                                let uName = u["name"] as! String
                                let uColor = u["color"] as! String
                                track.name = uName
                                track.color = uColor
                            }
                        } else {
                            let track = Track(json:jsonT as! Dictionary<String, AnyObject>)
                            foundGroup?.tracks.append(track)
                        }
                        if uE > 0 {
                            self.connection.connection.sendUpdateGroupResponse(group: group, event: uE)
                        }
                    }
                }
                self.groupsUpdated.notify(($0,$1))
            })
        }
        if groups.count == 0 && self.monitoringGroupsHandler != nil {
            connection.monitoringGroupsUpdated.remove(self.monitoringGroupsHandler!)
            self.monitoringGroupsHandler = nil
            connection.connection.groupsUpdated.remove(self.onUpdateGroup!)
            self.onUpdateGroup = nil
            self.connection.activatePoolGroups(-1)
        }
    }
    

    open func getUser(_ group:  Int, user: Int) -> User? {
        let foundGroup = allGroups.filter{$0.u == "\(group)"}.first
        return foundGroup?.users.filter{$0.id == "\(user)"}.first
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
