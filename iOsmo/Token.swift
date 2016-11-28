//
//  Token.swift
//  iOsmo
//
//  Created by Olga Grineva on 15/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2016 Alexey Sirotkin All rights reserved.
//

import Foundation

open class Token{
    
    var token: NSString
    var device_key: NSString
    var address: NSString
    var port: Int
    open var error: String = ""
    
    init(tokenString: NSString, address: NSString, port: Int, key: NSString){
        self.token = tokenString
        self.address = address
        self.port = port
        self.device_key = key
    }
    
}
