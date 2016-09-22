//
//  ConnectionProtocol.swift
//  iOsmo
//
//  Created by Olga Grineva on 13/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import Foundation

public protocol ConnectionProtocol{
    
    func connect(_ token: Token)
    
    func openSession()
    
    func closeSession()
    
    func send(_ request: String)
    
    var sessionUrlParsed: String {get}
    
}
