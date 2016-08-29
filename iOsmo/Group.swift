//
//  Group.swift
//  iOsmo
//
//  Created by Olga Grineva on 09/04/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation
public class Group{
    var id: String
    var name: String
    var descr: String = ""
    var active: Bool
    var policy: String = ""
    var users: [User] = [User]()
    
    init(id: String, name: String,  active: Bool){
        self.id = id
        self.name = name
        self.active = active
    }
}
