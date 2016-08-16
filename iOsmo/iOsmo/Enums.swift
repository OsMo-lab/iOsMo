//
//  Enums.swift
//  iOsmo
//
//  Created by Olga Grineva on 13/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import Foundation

enum TagsOld: String{
    case token = "TOKEN|"
    case openSession = "TRACKER_SESSION_OPEN|"
    case closeSession = "TRACKER_SESSION_CLOSE"
    case ping = "P"
    case pong = "PP"
    case kick = "KICK|"
    case remotePP = "REMOTE_CONTROL|PP"
    case coordinate = "T"
}

enum Tags: String {
    case token = "INIT|"
    case auth = "AUTH|"
    case openSession = "TO"
    case closeSession = "TC"
    case ping = "P"
    case getGroups = "GROUP"
    case enterGroup = "GE:"
    case leaveGroup = "GL:"
    case activateAllGroup = "GAA"
    case deactivateAllGroup = "GDA"
    //case activatePoolGroup = "PG"
}

enum KeysOld: String{
    case trackerId = "tracker_id"
    case sessionUrl = "url"
    case key = "key"
    case token = "token"
    case address = "address"
}

enum Keys: String{
    case token = "token"
    case address = "address"
    case uid = "uid"
    case name = "name"
    case key = "device"
    case error = "error"
    case errorDesc = "error_description"
}

enum ParseKeys: String{
    case sessionUrl = "url"
    case getGroups = "GROUP"
    case status = "status"
    case gda = "GDA"
    case gaa = "GAA"
}


enum AnswTags: String{
    case openedSession = "TO|"
    case getGroups = "GROUP"
    case enterGroup = "GE:"
    case leaveGroup = "GL:"
    //case activatePG = "PG"
    case kick = "BYE|"
    case pong = "PP"
    case coordinate = "T|"
    case closeSession = "TC|"
    case token = "INIT|"
    case auth = "AUTH|"
    case allGroupsEnabled = "allGroupsEnabled" //TODO another solution to notify about group enabled flag
    case gda = "GDA|"
    case gaa = "GAA|"
    case grCoord = "G:"
}

enum UpdatesEnum: String {
    
   // case OpenConnection = "connected"
    case SessionStarted = "sessionOpened"
    
}

enum SettingKeys: String {
    case device = "deviceKey"
    case auth = "authKey"
    case isStayAwake = "isStayAwake"
    case user = "user"
}

enum GroupActions: String {
    case view = "view" //default
    case enter = "enter"
    case new = "new"
    case leave = "leave"
}