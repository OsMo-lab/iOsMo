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

    var id: String!
    var name: String
    var color: String
    var state: Int = 0
    var online: Int = 0
    var connected: Double //time of connected in UNIX time format
    var lat: Double = -3000
    var lon: Double = -3000
    
    public var subtitle: String? = ""
    
    init(json:Dictionary<String, AnyObject>) {
        print(json)
        var uId = json["u"] as? String
        if (uId == nil) {
            let uIdInt = json["u"] as! Int
            uId = "\(uIdInt)"
        }
        self.id = uId
        self.name = json["name"] as! String
        self.connected = (json["connected"] as? Double) ?? 0
        self.color = (json["color"] as? String) ?? ""
        self.online = (json["online"] as? Int) ?? 0
        self.state = (json["state"] as? Int) ?? 0

        if let lat = json["lat"] as? String, let lon = json["lon"] as? String {
            self.lat = atof(lat);
            self.lon = atof(lon);
        }
    }
    
    init(id: String!, name: String, color: String, connected: Double){
        self.id = id
        self.name = name
        self.color = color
        self.connected = connected
    }
    
    public static func == (left: User, right: User) -> Bool {
        return left.id == right.id
    }
    
    open var title: String? {
        return name;
    }
    
    open var coordinate : CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: lat, longitude: lon);
    }
}

