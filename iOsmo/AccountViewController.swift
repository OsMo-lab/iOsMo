//
//  AccountViewController.swift
//  iOsmo
//
//  Created by Olga Grineva on 22/12/14.
//  Copyright (c) 2014 Olga Grineva, © 2016 Alexey Sirotkin. All rights reserved.
//

import UIKit

class AccountViewController: UIViewController, AuthResultProtocol, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    var groupsEnabled = true
    
    let groupCell = "groupCell"
    let newGroupCell = "newGroupCell"
    let enterGroupCell = "enterGroupCell"
    
    var groups: [Group] = [Group]()
    var successLogin: Bool = false
    
    var groupAction = GroupActions.view
    
    @IBOutlet weak var btnEnterGroup: UIButton!
    var onConnectionRun: ObserverSetEntry<(Bool, String)>?
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func btnCancelCellAdd(sender: AnyObject) {
        
        tableView.beginUpdates()
        
        tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow:0, inSection:0)], withRowAnimation: UITableViewRowAnimation.Automatic)
        
        groupAction = GroupActions.view
        tableView.endUpdates()
        btnEnterGroup.enabled = true
        
    }
    @IBAction func btnEnterCellAdd(sender: AnyObject) {
        
        groupAction = GroupActions.enter
        tableView.beginUpdates()
        
        tableView.insertRowsAtIndexPaths([NSIndexPath(forRow:0, inSection:0)], withRowAnimation: UITableViewRowAnimation.Automatic)
        
        tableView.endUpdates()
        btnEnterGroup.enabled = false
    }
    
    @IBOutlet weak var userName: UILabel!
    @IBOutlet weak var loginBtn: UIButton!
    @IBOutlet weak var activateSwitcher: UISwitch!

    @IBAction func activateAllSwitched(sender: AnyObject) {
        
        if let switcher = self.activateSwitcher {

            if switcher.on {
                groupManager.activateAllGroups()
            } else {
                groupManager.deactivateAllGroups()
            }
        }
    }
    
    
    @IBAction func btnGroupsClicked(sender: AnyObject) {
        groupManager.groupList()
    }
    
    
    
    var connectionManager = ConnectionManager.sharedConnectionManager
    var groupManager = GroupManager.sharedGroupManager
    
    
    override func viewDidAppear(animated: Bool) {
        setLoginControls()
    
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        connectionManager.groupsEnabled.add{
            
            self.activateSwitcher.on = $0
        }
        
        tableView.tableFooterView = UIView(frame: CGRectZero)
        // subscribe once
        if self.onConnectionRun == nil {
            
            self.onConnectionRun = connectionManager.connectionRun.add{
                if $0.0 {self.setLoginControls()}
                else { print($0.1) }
            }
        }
    
        //setLoginControls()
        
        groupManager.groupListUpdated.add{

            if  self.groups.count > 0{
                
                self.groups = [Group]()
                
            }
            
            self.groups = $0
            self.tableView.reloadData()
        }
        
        groupManager.groupEntered.add{
            
            if ($0.0) {
                
                self.groupAction = GroupActions.view
                self.groupManager.groupList()
                self.btnEnterGroup.enabled = true
            }
            else {
                self.alert("error on enter group", message: $0.1)
                
                if let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0)),
                    indicator = cell.contentView.viewWithTag(3) as? UIActivityIndicatorView {
                        
                        indicator.stopAnimating()
                        
                        if let gName = cell.contentView.viewWithTag(1) as? UITextField,
                            nick = cell.contentView.viewWithTag(2) as? UITextField {
                                
                                gName.text = ""
                                gName.enabled = true
                                nick.text = ""
                                nick.enabled = true
                        }
                        
                        if let btn = cell.contentView.viewWithTag(4) as? UIButton {
                            btn.hidden = false
                        }

                }
            }
        }
        
        groupManager.groupLeft.add{
            if ($0.0) {self.groupManager.groupList()}
        }
        
       
        groupManager.groupList()
        
        //read account state
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if segue.identifier == "toAuth" {
            
            if let vC = segue.destinationViewController as? AuthViewController { vC.delegate = self}
        }
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String?, sender: AnyObject?) -> Bool {
        if identifier == "toAuth" {
            
            if successLogin {
                SettingsManager.setKey("", forKey: SettingKeys.user)
                SettingsManager.setKey("", forKey: SettingKeys.auth)
                connectionManager.connect()
                return false
            }
            else {return true}
        }
        
        //by default
        return true
    }
    
    func succesfullLoginWithToken (controller: AuthViewController, info : AuthInfo) -> Void {
       
        SettingsManager.setKey(info.accountName, forKey: SettingKeys.user)
        
        
        connectionManager.connect()
        userName.text = "connecting.."
        controller.dismissViewControllerAnimated(true, completion: nil)
        
    }
    
    func setLoginControls(){
        
        if let user = SettingsManager.getKey(SettingKeys.user) {
            
            if user.length > 0 {
                userName.text = String(user)
                loginBtn.setImage(UIImage(named: "exit-32"), forState: UIControlState.Normal)
                self.successLogin = true
            }
            else {
                
                userName.text = "Unknown"
                loginBtn.setImage(UIImage(named: "enter-32"), forState: UIControlState.Normal)
                self.successLogin = false
            }
        }
        else {
            
            userName.text = "Unknown"
            loginBtn.setImage(UIImage(named: "enter-32"), forState: UIControlState.Normal)
            self.successLogin = false
        }
    }
    
    func loginCancelled (controller: AuthViewController) -> Void {
        
        controller.dismissViewControllerAnimated(true, completion: nil)
       
    }
    
    // MARK UITableViewDataSource
    @IBAction func btnEnterGroupClicked(sender: AnyObject) {

        if let firstRow = tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0)),
               gName = firstRow.contentView.viewWithTag(1) as? UITextField,
               nick = firstRow.contentView.viewWithTag(2) as? UITextField,
               indicator = firstRow.contentView.viewWithTag(3) as? UIActivityIndicatorView,
               btn = firstRow.contentView.viewWithTag(4) as? UIButton
        {
            
            if !gName.text!.isEmpty && !nick.text!.isEmpty {
                
                // change ui control state
                gName.enabled = false
                nick.enabled = false
                btn.hidden = true
                indicator.startAnimating()
                
                groupManager.enterGroup(gName.text!, nick: nick.text!)
            }
        
        }
 
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let additionalRows = (self.groupAction == GroupActions.enter) ? 1 : 0
        return groups.count + additionalRows
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let row = indexPath.row
        var cell: UITableViewCell?
        
        if groupAction == GroupActions.enter && row == 0 {

           cell = tableView.dequeueReusableCellWithIdentifier(enterGroupCell, forIndexPath: indexPath)
            if let gName = cell!.contentView.viewWithTag(1) as? UITextField,
                   nick = cell!.contentView.viewWithTag(2) as? UITextField,
                   btn = cell!.contentView.viewWithTag(4) as? UIButton {
                
                    gName.text = ""
                    gName.enabled = true
                    nick.text = ""
                    nick.enabled = true
                    btn.hidden = false
                    
            }
        }
        else {
            cell = tableView.dequeueReusableCellWithIdentifier(groupCell, forIndexPath: indexPath)
            if (cell == nil) {
                cell = UITableViewCell(style:UITableViewCellStyle.Subtitle, reuseIdentifier:groupCell)
            }
            if let groupName = cell!.contentView.viewWithTag(1) as? UILabel {
                
                groupName.text = (groupAction == GroupActions.enter) ? self.groups[row - 1].name : self.groups[row].name
            }
            //cell.textLabel?.text = ""
            
        }
        cell!.selectionStyle = UITableViewCellSelectionStyle.None
        return cell!
    }

    // MARK UITableViewDelegate
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        _ = indexPath.row
        
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return !(groupAction == GroupActions.enter && indexPath.row == 0)
    }

    func tableView(tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath indexPath: NSIndexPath) -> String? {
        return "leave"
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == UITableViewCellEditingStyle.Delete {
        
            if let curRow = tableView.cellForRowAtIndexPath(indexPath), indicator = curRow.contentView.viewWithTag(3) as? UIActivityIndicatorView {
                
                indicator.startAnimating()
            }
            
            let group = groups[indexPath.row]
            groupManager.leaveGroup(group.id)
            
            tableView.setEditing(false, animated: true)
            
        }
    }

    //MARK UITextFieldDelegate
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
     override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    func alert(title: String, message: String) {
        if let getModernAlert: AnyClass = NSClassFromString("UIAlertController") { // iOS 8
            let myAlert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
            myAlert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
            self.presentViewController(myAlert, animated: true, completion: nil)
        } else { // iOS 7
            let alert: UIAlertView = UIAlertView()
            alert.delegate = self
            
            alert.title = title
            alert.message = message
            alert.addButtonWithTitle("OK")
            
            alert.show()
        }
    }

    
}

class AuthInfo{
    
    var accountName: String
    var key: String
    
    init(accountName: String, key: String){
        self.accountName = accountName
        self.key = key
    }
}
