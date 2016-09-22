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
    var device: String
    var name: String
    var color: String
    var connected: String //time of connected in UNIX time format
    
    init(id: String, device: String, name: String, color: String, connected: String){
        self.id = id
        self.device = device
        self.name = name
        self.color = color
        self.connected = connected
    }
    
    
}
