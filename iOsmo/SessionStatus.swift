//
//  SessionStatus.swift
//  iOsmo
//
//  Created by Olga Grineva on 29/03/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation
enum SessionStatus: Int16 {
    
    case Started = 0
    case Finished = 1
    case Paused = 2
    case Saved = 3
    case Restored = 4
    
}