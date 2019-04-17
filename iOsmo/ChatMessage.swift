//
//  ChatMessage.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 03.03.2019.
//  Copyright © 2019 Alexey Sirotkin. All rights reserved.
//

import Foundation

class ChatMessage : NSObject {
    var time: Date;
    var text: String;
    var user: String;
    
    init(json: Dictionary<String, AnyObject>) {
        self.text = json["text"] as? String ?? ""
        self.user = json["name"] as? String ?? ""
        let uTime = (json["time"] as? Double) ?? 0
        if uTime > 0 {
            self.time = Date(timeIntervalSince1970: uTime)
        } else {
            self.time = Date()
        }
    }
    
    init(text:String) {
        self.text = text;
        self.time = Date()
        self.user = SettingsManager.getKey(SettingKeys.user)! as String
    }
}
