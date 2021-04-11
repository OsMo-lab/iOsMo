//
//  Private.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 11.04.2021.
//  Copyright © 2021 Alexey Sirotkin. All rights reserved.
//

/*
 Тип приватности поездки
 Список приходит в ответе AUTH
 */

import Foundation

class Private : NSObject {
    var id: Int;
    var name: String;
    
    init(json: Dictionary<String, AnyObject>) {
        self.name = json["name"] as? String ?? ""
        self.id = (json["id"] as? Int) ?? Int(json["id"] as? String ?? "0")!
    }
}
