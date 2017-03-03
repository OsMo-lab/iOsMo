//
//  GroupsManager.swift
//  iOsmo
//
//  Created by Olga Grineva on 08/04/15.
//  Copyright (c) 2015 Olga Grineva, (c) 2017 Alexey Sirotkin All rights reserved.
//

import Foundation
open class GroupManager{

    
    var groupsOnMap: [Int] = [Int]()
    var allGroups: [Group]?
    var monitoringGroupsHandler: ObserverSetEntry<[UserGroupCoordinate]>?
    var monitoringGroupsUpdated = ObserverSet<[UserGroupCoordinate]>()
 
    var groupListUpdated = ObserverSet<[Group]>()
    var groupEntered = ObserverSet<(Bool, String)>()
    var groupLeft = ObserverSet<(Bool, String)>()
    var groupActivated = ObserverSet<(Bool, String)>()
    var groupDeactivated = ObserverSet<(Bool, String)>()
    var groupCreated = ObserverSet<(Bool, String)>()
    
    var onGroupListUpdated: ObserverSetEntry<[Group]>?
    
    var onActivateGroup : ObserverSetEntry<(Bool, String)>?
    var onDeactivateGroup : ObserverSetEntry<(Bool, String)>?
    
    fileprivate let log = LogQueue.sharedLogQueue
    
    class var sharedGroupManager : GroupManager {
    
        struct Static {
            static let instance: GroupManager = GroupManager()
        }
        
        return Static.instance
    }
    
    let connection = ConnectionManager.sharedConnectionManager

    
    open func activateGroup(_ name: String){
        
        self.onActivateGroup = connection.groupActivated.add{
            
            self.groupActivated.notify($0, $1)
            
            print("ACTIVATED! \($0) ")
            
            self.connection.groupActivated.remove(self.onActivateGroup!)
        }
        connection.activateGroup(name)


    }
    
    open func deactivateGroup(_ name: String) {
        self.onDeactivateGroup = connection.groupDeactivated.add{
            
            self.groupDeactivated.notify($0, $1)
            
            print("DEACTIVATED \(name)! \($0) ")
            if($0) {
                for group in self.allGroups! {
                    if group.u == name {
                        group.active = false;
                        break;
                    }
                }
            }
            
            
            self.connection.groupDeactivated.remove(self.onDeactivateGroup!)
        }
        
        connection.deactivateGroup(name)
    }
    
    open func groupsSwitch(_ s: Int) {
        connection.groupsSwitch(s)
    }

    
    var onEnterGroup : ObserverSetEntry<(Bool, String)>?
    var onLeaveGroup : ObserverSetEntry<(Bool, String)>?
    var onCreateGroup : ObserverSetEntry<(Bool, String)>?

    open func createGroup(_ name: String, email: String, phone: String, gtype: String, priv: Bool){
        
        self.onCreateGroup = connection.groupCreated.add{
            if (!$0) {
                self.groupList()
            }
            self.groupCreated.notify(!$0, $1)
            
            print("CREATED! \(!$0) ")
            
            self.connection.groupCreated.remove(self.onCreateGroup!)
        }
        connection.createGroup(name, email: email, phone: phone, gtype: gtype, priv: priv)
    }
    
    open func enterGroup(_ name: String, nick: String){
    
        self.onEnterGroup = connection.groupEntered.add{
        
            self.groupEntered.notify($0, $1)
            
            print("ENTERED! \($0) ")
            
            self.connection.groupEntered.remove(self.onEnterGroup!)
        }
        connection.enterGroup(name, nick: nick)
    }
    
    open func leaveGroup(_ u: String) {
        
        self.onLeaveGroup = connection.groupLeft.add{
            
            self.groupLeft.notify($0, $1)
            
            print("LEFT! \($0) ")
            
            self.connection.groupLeft.remove(self.onLeaveGroup!)
        }
        connection.leaveGroup(u)
    }
    
    open func groupList(){
        
        if self.onGroupListUpdated == nil {
            self.onGroupListUpdated = connection.groupList.add{
                
                self.allGroups = $0
                self.groupListUpdated.notify($0)
               
            }
        }
        
        connection.getGroups()
    }
    
   
    
    open func updateGroupsOnMap(_ groups: [Int]){
        
        groupsOnMap = groups
        connection.monitoringGroups = groups
        
        if groups.count > 0 && self.monitoringGroupsHandler == nil {
            
            self.monitoringGroupsHandler = connection.monitoringGroupsUpdated.add({self.monitoringGroupsUpdated.notify($0)})
        }
        if groups.count == 0 && self.monitoringGroupsHandler != nil {
            
            connection.monitoringGroupsUpdated.remove(self.monitoringGroupsHandler!)
            self.monitoringGroupsHandler = nil
        }
    }
    

    open func getUser(_ group:  Int, user: Int) -> User? {
        
        let foundGroup = allGroups?.filter{$0.u == "\(group)"}.first
        //return foundGroup?.users.filter{$0.device == "\(user)"}.first
        return foundGroup?.users.filter{$0.id == "\(user)"}.first
    }
}
