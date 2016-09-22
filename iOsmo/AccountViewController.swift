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
    
    @IBAction func btnCancelCellAdd(_ sender: AnyObject) {
        
        tableView.beginUpdates()
        
        tableView.deleteRows(at: [IndexPath(row:0, section:0)], with: UITableViewRowAnimation.automatic)
        
        groupAction = GroupActions.view
        tableView.endUpdates()
        btnEnterGroup.isEnabled = true
        
    }
    @IBAction func btnEnterCellAdd(_ sender: AnyObject) {
        
        groupAction = GroupActions.enter
        tableView.beginUpdates()
        
        tableView.insertRows(at: [IndexPath(row:0, section:0)], with: UITableViewRowAnimation.automatic)
        
        tableView.endUpdates()
        btnEnterGroup.isEnabled = false
    }
    
    @IBOutlet weak var userName: UILabel!
    @IBOutlet weak var loginBtn: UIButton!
    @IBOutlet weak var activateSwitcher: UISwitch!

    @IBAction func activateAllSwitched(_ sender: AnyObject) {
        
        if let switcher = self.activateSwitcher {

            if switcher.isOn {
                groupManager.activateAllGroups()
            } else {
                groupManager.deactivateAllGroups()
            }
        }
    }
    
    
    @IBAction func btnGroupsClicked(_ sender: AnyObject) {
        groupManager.groupList()
    }
    
    
    
    var connectionManager = ConnectionManager.sharedConnectionManager
    var groupManager = GroupManager.sharedGroupManager
    
    
    override func viewDidAppear(_ animated: Bool) {
        setLoginControls()
    
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        connectionManager.groupsEnabled.add{
            
            self.activateSwitcher.isOn = $0
        }
        
        tableView.tableFooterView = UIView(frame: CGRect.zero)
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
                self.btnEnterGroup.isEnabled = true
            }
            else {
                self.alert("error on enter group", message: $0.1)
                
                if let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)),
                    let indicator = cell.contentView.viewWithTag(3) as? UIActivityIndicatorView {
                        
                        indicator.stopAnimating()
                        
                        if let gName = cell.contentView.viewWithTag(1) as? UITextField,
                            let nick = cell.contentView.viewWithTag(2) as? UITextField {
                                
                                gName.text = ""
                                gName.isEnabled = true
                                nick.text = ""
                                nick.isEnabled = true
                        }
                        
                        if let btn = cell.contentView.viewWithTag(4) as? UIButton {
                            btn.isHidden = false
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "toAuth" {
            
            if let vC = segue.destination as? AuthViewController { vC.delegate = self}
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
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
    
    func succesfullLoginWithToken (_ controller: AuthViewController, info : AuthInfo) -> Void {
       
        SettingsManager.setKey(info.accountName as NSString, forKey: SettingKeys.user)
        
        
        connectionManager.connect()
        userName.text = "connecting.."
        controller.dismiss(animated: true, completion: nil)
        
    }
    
    func setLoginControls(){
        
        if let user = SettingsManager.getKey(SettingKeys.user) {
            
            if user.length > 0 {
                userName.text = String(user)
                loginBtn.setImage(UIImage(named: "exit-32"), for: UIControlState())
                self.successLogin = true
            }
            else {
                
                userName.text = "Unknown"
                loginBtn.setImage(UIImage(named: "enter-32"), for: UIControlState())
                self.successLogin = false
            }
        }
        else {
            
            userName.text = "Unknown"
            loginBtn.setImage(UIImage(named: "enter-32"), for: UIControlState())
            self.successLogin = false
        }
    }
    
    func loginCancelled (_ controller: AuthViewController) -> Void {
        
        controller.dismiss(animated: true, completion: nil)
       
    }
    
    // MARK UITableViewDataSource
    @IBAction func btnEnterGroupClicked(_ sender: AnyObject) {

        if let firstRow = tableView.cellForRow(at: IndexPath(row: 0, section: 0)),
               let gName = firstRow.contentView.viewWithTag(1) as? UITextField,
               let nick = firstRow.contentView.viewWithTag(2) as? UITextField,
               let indicator = firstRow.contentView.viewWithTag(3) as? UIActivityIndicatorView,
               let btn = firstRow.contentView.viewWithTag(4) as? UIButton
        {
            
            if !gName.text!.isEmpty && !nick.text!.isEmpty {
                
                // change ui control state
                gName.isEnabled = false
                nick.isEnabled = false
                btn.isHidden = true
                indicator.startAnimating()
                
                groupManager.enterGroup(gName.text!, nick: nick.text!)
            }
        
        }
 
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let additionalRows = (self.groupAction == GroupActions.enter) ? 1 : 0
        return groups.count + additionalRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let row = (indexPath as NSIndexPath).row
        var cell: UITableViewCell?
        
        if groupAction == GroupActions.enter && row == 0 {

           cell = tableView.dequeueReusableCell(withIdentifier: enterGroupCell, for: indexPath)
            if let gName = cell!.contentView.viewWithTag(1) as? UITextField,
                   let nick = cell!.contentView.viewWithTag(2) as? UITextField,
                   let btn = cell!.contentView.viewWithTag(4) as? UIButton {
                
                    gName.text = ""
                    gName.isEnabled = true
                    nick.text = ""
                    nick.isEnabled = true
                    btn.isHidden = false
                    
            }
        }
        else {
            cell = tableView.dequeueReusableCell(withIdentifier: groupCell, for: indexPath)
            if (cell == nil) {
                cell = UITableViewCell(style:UITableViewCellStyle.subtitle, reuseIdentifier:groupCell)
            }
            if let groupName = cell!.contentView.viewWithTag(1) as? UILabel {
                
                groupName.text = (groupAction == GroupActions.enter) ? self.groups[row - 1].name : self.groups[row].name
            }
            //cell.textLabel?.text = ""
            
        }
        cell!.selectionStyle = UITableViewCellSelectionStyle.none
        return cell!
    }

    // MARK UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        _ = (indexPath as NSIndexPath).row
        
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !(groupAction == GroupActions.enter && (indexPath as NSIndexPath).row == 0)
    }

    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "leave"
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCellEditingStyle.delete {
        
            if let curRow = tableView.cellForRow(at: indexPath), let indicator = curRow.contentView.viewWithTag(3) as? UIActivityIndicatorView {
                
                indicator.startAnimating()
            }
            
            let group = groups[(indexPath as NSIndexPath).row]
            groupManager.leaveGroup(group.id)
            
            tableView.setEditing(false, animated: true)
            
        }
    }

    //MARK UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
     override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    func alert(_ title: String, message: String) {
        if let getModernAlert: AnyClass = NSClassFromString("UIAlertController") { // iOS 8
            let myAlert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            myAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(myAlert, animated: true, completion: nil)
        } else { // iOS 7
            let alert: UIAlertView = UIAlertView()
            alert.delegate = self
            
            alert.title = title
            alert.message = message
            alert.addButton(withTitle: "OK")
            
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
