//
//  Coordinate.swift
//  iOsmo
//
//  Created by Olga Grineva on 27/04/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation
open class Coordinate{
    
    var groupId: Int
    var userId: Int
    var location: LocationModel
    
    init(group: Int, user: Int, location: LocationModel){
        self.groupId = group
        self.userId = user
        self.location = location
    }
}
