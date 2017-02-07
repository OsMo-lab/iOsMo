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
    var policy: String = ""
    var color: String = "#ffffff"
    var nick: String = ""
    var users: [User] = [User]()
    
    init(u: String, name: String,  active: Bool){
        self.u = u
        self.name = name
        self.active = active
    }
}
