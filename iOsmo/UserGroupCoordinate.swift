//
//  UserGroupCoordinate.swift
//  iOsmo
//
//  Created by Olga Grineva on 28/04/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation
open class UserGroupCoordinate{
    
    let groupId: Int
    let userId: Int //Уникалльный ID
    let location: LocationModel

    init(group: Int, user: Int, location: LocationModel){
        self.groupId = group
        self.userId = user
        self.location = location
    }
    
}
