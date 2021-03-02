//
//  Group.swift
//  iOsmo
//
//  Created by Olga Grineva on 09/04/15.
//  Copyright (c) 2015 Olga Grineva, (c) 2017 Alexey Sirotkin All rights reserved.
//

import Foundation
open class Group: Equatable{
    
    var u: String
    var name: String
    var descr: String = ""
    var url: String = ""
    var active: Bool = true
    var type: String = "1"
    var policy: String = ""
    var color: String = "#ffffff"
    var nick: String = ""
    var permanent: String = "0"
    var users: [User] = [User]()
    var points: [Point] = [Point]()
    var tracks: [Track] = [Track]()
    var messages: [ChatMessage] = [ChatMessage]()
    
    init(u: String, name: String,  active: Bool){
        self.u = u
        self.name = name
        self.active = active
    }
    
    init (json: Dictionary<String, AnyObject>) {
        self.u = json["u"] as? String ?? ("\(json["u"] as? Int ?? 0)")
        self.name = json["name"] as? String ?? ""
        self.active =  (json["active"] as? String ?? ("\(json["active"] as? Int ?? 0)")) == "1"
        self.descr = (json["description"] as? String) ?? ""
        self.policy = (json["policy"] as? String) ?? ""
        self.nick = (json["nick"] as? String) ?? ""
        self.color = (json["color"] as? String) ?? ""
        self.url = json["url"] as! String
        self.permanent = json["permanent"] as? String ?? "\(json["permanent"] as? Int ?? 0)"
        self.type = json["type"] as? String ?? "\(json["type"] as? Int ?? 0)";

        if let jsonUsers = json["users"] as? Array<AnyObject> {
            for jsonU in jsonUsers{
                let user = User(json:jsonU as! Dictionary<String, AnyObject>)
                user.groupId = Int(self.u) ?? 0
                self.users.append(user)
            }
        }
        
        if let jsonPoints = json["point"] as? Array<AnyObject> {
            for jsonP in jsonPoints{
                let point = Point (json:jsonP as! Dictionary<String, AnyObject>)
                point.groupId = Int(self.u) ?? 0
                point.mapId = "p-\(self.u)-\(point.u)"
                self.points.append(point)
                
            }
        }
        if let jsonTracks = json["track"] as? Array<AnyObject> {
            for jsonT in jsonTracks{
                let track = Track(json:jsonT as! Dictionary<String, AnyObject>)
                track.groupId = Int(self.u) ?? 0
                self.tracks.append(track)
            }
        }

    }
    
    class func getTypeName(_ code:String) -> String {
        switch code {
        case GroupType.Simple.rawValue:
            return "Simple"
        case GroupType.Family.rawValue:
            return "Family"
        case GroupType.POI.rawValue:
            return "POI"
        default:
            return "Invalid"
        }
    }
    
    public static func == (left: Group, right: Group) -> Bool {
        return left.u == right.u
    }
}
