//
//  Token.swift
//  iOsmo
//
//  Created by Olga Grineva on 15/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2016 Alexey Sirotkin All rights reserved.
//

import Foundation

open class Token{
    
    var token: String
    var device_key: String
    var address: String
    var port: Int
    open var error: String = ""
    
    init(tokenString: String, address: String, port: Int, key: String){
        self.token = tokenString
        self.address = address
        self.port = port
        self.device_key = key
    }
    
}
