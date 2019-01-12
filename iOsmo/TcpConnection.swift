//
//  TcpConnectionNew.swift
//  iOsmo
//
//  Created by Olga Grineva on 25/03/15.
//  Copyright (c) 2015 Olga Grineva, (c) 2017 Alexey Sirotkin. All rights reserved.
//

import Foundation
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


open class TcpConnection: BaseTcpConnection {
    let answerObservers = ObserverSet<(String)>()

    open override func connect(_ token: Token){
        super.tcpClient.callbackOnParse = parseOutput
        super.connect(token)

    }
  
    open func parseOutput(_ output: String){
        answerObservers.notify(output)
    }
}
