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
        let gName = json["name"] as? String ?? ""
        let gDescr = (json["description"] as? String) ?? ""
        let gPolicy = (json["policy"] as? String) ?? ""
        let gNick = (json["nick"] as? String) ?? ""
        let gColor = (json["color"] as? String) ?? ""
        var gPermanent = (json["permanent"] as? String)
        if (gPermanent == nil ){
            let gPermentntInt = json["permanent"] as? Int

            gPermanent = "\(gPermentntInt)"
        }
        
        let gURL = json["url"] as! String
        var gType = json["type"] as? String
        if (gType == nil ){
            gType = "\(json["type"] as? Int)"
        }
        let gActive = (json["active"] as? String ?? "") == "1"
        var gU = json["u"] as? String
        if (gU == nil ){
            let gUint = json["u"] as! Int
            gU = "\(gUint)"
        }
        
        self.u =  gU!
        self.name = gName

        self.active = gActive
        self.descr = gDescr
        self.policy = gPolicy
        self.nick = gNick
        self.color = gColor
        self.url = gURL
        if (gPermanent != nil) {
            self.permanent = gPermanent!
        }

        self.type = gType!;

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
