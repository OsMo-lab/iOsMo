//
//  UserGroup.swift
//  iOsmo
//
//  Created by Olga Grineva on 09/04/15.
//  Copyright (c) 2015 Olga Grineva, © 2017 Alexey Sirotkin All rights reserved.
//

import Foundation
import MapKit

public class User:NSObject, MKAnnotation {

    var u: String!
    var name: String
    var groupId: Int = 0
    var color: String
    var state: Int = 0
    var online: Int = 0
    var time: Date = Date()
    var connected: Double //time of connected in UNIX time format
    public dynamic var coordinate : CLLocationCoordinate2D;

    public dynamic var speed: Double = -1.0
    var track = [CLLocationCoordinate2D]()
    
    public dynamic var subtitle: String? = ""
    
    init(json:Dictionary<String, AnyObject>) {
        var uId = json["u"] as? String
        if (uId == nil) {
            let uIdInt = json["u"] as! Int
            uId = "\(uIdInt)"
        }
        self.u = uId
        self.name = json["name"] as! String
        self.connected = (json["connected"] as? Double) ?? 0
        self.color = (json["color"] as? String) ?? ""
        self.online = (json["online"] as? Int) ?? 0
        self.state = (json["state"] as? Int) ?? 0
        let uTime = (json["time"] as? Double) ?? 0
        if uTime > 0 {
            self.time = Date(timeIntervalSince1970: uTime)
        }

        if let lat = json["lat"] as? String, let lon = json["lon"] as? String {
            self.coordinate = CLLocationCoordinate2D(latitude: atof(lat), longitude: atof(lon))
        } else {
            self.coordinate = CLLocationCoordinate2D(latitude: -3000, longitude: -3000)
        }
    }
    
    init(u: String!, name: String, color: String, connected: Double){
        self.u = u
        self.name = name
        self.color = color
        self.connected = connected
        self.coordinate = CLLocationCoordinate2D(latitude: -3000, longitude: -3000)
    }
    
    public static func == (left: User, right: User) -> Bool {
        return left.u == right.u
    }
    
    open var title: String? {
        return name;
    }
    
    open var mapId: String! {
        return "u\(u!)";
    }

}

