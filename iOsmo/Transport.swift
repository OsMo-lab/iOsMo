//
//  Transport.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 08.02.2021.
//  Copyright © 2021 Alexey Sirotkin. All rights reserved.
//


import Foundation

class Transport : NSObject {
    var id: Int;
    var type: Int;
    var name: String;
    
    init(json: Dictionary<String, AnyObject>) {
        self.name = json["name"] as? String ?? ""
        self.id = (json["id"] as? Int) ?? Int(json["id"] as? String ?? "0")!
        self.type = (json["type"] as? Int) ?? Int(json["type"] as? String ?? "0")!
    }
}
