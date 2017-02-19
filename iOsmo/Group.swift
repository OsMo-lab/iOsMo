//
//  Group.swift
//  iOsmo
//
//  Created by Olga Grineva on 09/04/15.
//  Copyright (c) 2015 Olga Grineva, (c) 2017 Alexey Sirotkin All rights reserved.
//

import Foundation
open class Group{
    
    var u: String
    var name: String
    var id: String = ""
    var descr: String = ""
    var url: String = ""
    var active: Bool
    var type: String = "1"
    var policy: String = ""
    var color: String = "#ffffff"
    var nick: String = ""
    var users: [User] = [User]()
    
    init(u: String, name: String,  active: Bool){
        self.u = u
        self.name = name
        self.active = active
    }
    
    class func getTypeName(_ code:String) -> String {
        switch code {
        case GroupType.Simple.rawValue:
            return "Simple"
        case GroupType.Family.rawValue:
            return "Family"
        case GroupType.POI.rawValue:
            return "POI"
        case GroupType.Trip.rawValue:
            return "Trip"
        default:
            return "Invalid"
        }
    }
}
