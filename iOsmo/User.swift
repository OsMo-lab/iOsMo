//
//  UserGroup.swift
//  iOsmo
//
//  Created by Olga Grineva on 09/04/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation
open class User{

    var id: String
    var name: String
    var color: String
    var connected: Double //time of connected in UNIX time format
    
    init(id: String, name: String, color: String, connected: Double){
        self.id = id
        self.name = name
        self.color = color
        self.connected = connected
    }
    
    
}
