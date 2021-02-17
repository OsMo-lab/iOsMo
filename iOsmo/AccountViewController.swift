//
//  AccountViewController.swift
//  iOsmo
//
//  Created by Olga Grineva on 22/12/14.
//  Copyright (c) 2014 Olga Grineva, © 2018 Alexey Sirotkin. All rights reserved.
//

import UIKit

class AccountViewController: UIViewController, AuthResultProtocol, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
   
    var connectionManager = ConnectionManager.sharedConnectionManager
    var groupManager = GroupManager.sharedGroupManager
    
    let groupCell = "groupCell"
    let newGroupCell = "newGroupCell"
    let enterGroupCell = "enterGroupCell"
    let section = ["Add group", "Joing group", "Groups"]
    
    var successLogin: Bool = false
    
    var groupAction = GroupActions.view
    var groupToEnter = ""
    var groupType = "1"
    
    @IBOutlet weak var btnEnterGroup: UIButton!
    @IBOutlet weak var btnAddGroup: UIButton!
    @IBOutlet weak var userIcon: UIImageView!
    
    var onConnectionRun: ObserverSetEntry<(Int, String)>?
    //var onGroupCreated: ObserverSetEntry<[Group]>?
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var userName: UILabel!
    @IBOutlet weak var loginBtn: UIButton!
    var selectedGroup : Group?

    public func btnEnterGroupPress(_sender: AnyObject, _ group: String?) {
        groupToEnter = group!;
        if groupAction != GroupActions.enter {
            if (groupAction == GroupActions.new) {
                btnAddGroup.isHidden = false
            }
            
            groupAction = GroupActions.enter
            btnEnterGroup.isHidden = true
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.tableView.scrollToRow(at: IndexPath(item:0, section: 1), at: .top, animated: true)
            }
           
        }
    }
    
    @IBAction func btnGroupType(_ sender: UIButton) {
        //Create the AlertController
        let actionSheetController: UIAlertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        var typeAction: UIAlertAction = UIAlertAction(title: Group.getTypeName(GroupType.Simple.rawValue), style: .default) { action -> Void in
            self.groupType = GroupType.Simple.rawValue
            self.tableView.reloadData()
        }
        actionSheetController.addAction(typeAction)
        
        typeAction = UIAlertAction(title: Group.getTypeName(GroupType.Family.rawValue), style: .default) { action -> Void in
            self.groupType = GroupType.Family.rawValue
            self.tableView.reloadData()
        }
        actionSheetController.addAction(typeAction)

        typeAction = UIAlertAction(title: Group.getTypeName(GroupType.POI.rawValue), style: .default) { action -> Void in
            self.groupType = GroupType.POI.rawValue
            self.tableView.reloadData()
        }
        actionSheetController.addAction(typeAction)
                
        //We need to provide a popover sourceView when using it on iPad
        actionSheetController.popoverPresentationController?.sourceView = sender as UIView
        
        
        self.present(actionSheetController, animated: true, completion: nil)
    }
    
    @IBAction func btnGroupAdd(_ sender: UIButton) {
        let cell = sender.superview?.superview as! UITableViewCell
        if let indexPath = self.tableView.indexPath(for: cell) {
            let row = (indexPath as NSIndexPath).row
            let section = (indexPath as NSIndexPath).section
            sender.isEnabled = false
            if (row == 0 && section == 0) {
                if let gName = cell.contentView.viewWithTag(1) as? UITextField,
                    let priv = cell.contentView.viewWithTag(2) as? UISwitch,
                    let email = cell.contentView.viewWithTag(5) as? UITextField,
                    let nick = cell.contentView.viewWithTag(6) as? UITextField {
                    self.groupManager.createGroup(gName.text!, email: email.text!, nick: nick.text!, gtype: self.groupType, priv: priv.isOn)
                }
            
            }
        }

    }
    
    @IBAction func btnGroupCellAdd(_ sender: UIButton) {
        if groupAction != GroupActions.new {
            if (groupAction == GroupActions.enter) {
                btnEnterGroup.isHidden = false
            }
            groupAction = GroupActions.new
            btnAddGroup.isHidden = true
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.tableView.scrollToRow(at: IndexPath(item:0, section: 0), at: .top, animated: true)
                
            }
        }
    }
    
    @IBAction func btnEnterCellAdd(_ sender: AnyObject) {
        btnEnterGroupPress(_sender: sender, "")
    }

    @IBAction func activateSwitched(_ sender: UISwitch) {
        
        if let indexPath = self.tableView.indexPath(for: sender.superview?.superview as! UITableViewCell) {
            let row = (indexPath as NSIndexPath).row
            
            if ((groupAction == GroupActions.enter  || groupAction == GroupActions.new) && row == 0) {
            } else {
                let group = (groupAction == GroupActions.enter  || groupAction == GroupActions.new) ? groupManager.allGroups[row - 1]: groupManager.allGroups[row]
                if group.active {
                    groupManager.deactivateGroup(group.u)
                } else {
                    groupManager.activateGroup(group.u)
                }
            }
        }
    }
    
    
    @IBAction func btnGroupsClicked(_ sender: AnyObject) {
        groupManager.groupList(false)
    }
    
 

    
    override func viewDidAppear(_ animated: Bool) {
        setLoginControls()
    
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView(frame: CGRect.zero)
        // subscribe once
        if self.onConnectionRun == nil {
            self.onConnectionRun = connectionManager.connectionRun.add{
                if $0.0 == 0 {
                    self.setLoginControls()
                } else {
                    print($0.1)
                }
            }
        }

        _ = groupManager.groupListUpdated.add{
            let _ = $0
            DispatchQueue.main.async {
                self.setLoginControls()
                self.tableView.reloadData()
            }
        }
        
        _ = groupManager.groupEntered.add{
            if ($0.0 == 0) {
                self.groupAction = GroupActions.view
                self.groupManager.groupList(false)
                self.btnEnterGroup.isHidden = false
            } else {
                self.alert(NSLocalizedString("Error on enter group", comment:"Alert title for error on enter group"), message: $0.1)
                
                if let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 1)),
                    let indicator = cell.contentView.viewWithTag(3) as? UIActivityIndicatorView {
                        
                        indicator.stopAnimating()
                        
                        if let gName = cell.contentView.viewWithTag(1) as? UITextField,
                            let nick = cell.contentView.viewWithTag(2) as? UITextField {
                                gName.text = self.groupToEnter
                                gName.isEnabled = true
                                nick.text = self.userName.text
                                nick.isEnabled = true
                        }
                        
                        if let btn = cell.contentView.viewWithTag(4) as? UIButton {
                            btn.isHidden = false
                        }

                }
            }
        }
        _ = groupManager.groupCreated.add{
            if ($0.0 == 0 ) {
                self.groupAction = GroupActions.view
                self.btnAddGroup.isHidden = false
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            } else {
                if let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)),
                    let addButton = cell.contentView.viewWithTag(4) as? UIButton {
                    addButton.isEnabled = true
                }
                self.alert(NSLocalizedString("Error on create group", comment:"Alert title for error on create group"), message: $0.1)
            }
        }
        _ = groupManager.groupLeft.add{
            if ($0.0 == 0) {
                //self.groupManager.groupList(true)
            } else {
                self.alert(NSLocalizedString("Error on leave group", comment:"Alert title for error on leave group"), message: $0.1)
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        
        _ = groupManager.groupActivated.add{
            if ($0.0 == 0) {

            } else {
                self.alert(NSLocalizedString("Error on activate group", comment:"Alert title for error on activate group"), message: $0.1)
                
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        
        _ = groupManager.groupDeactivated.add{
            if ($0.0 == 0) {

            } else {
                self.alert(NSLocalizedString("Error on deactivate group", comment:"Alert title for error on deactivate group"), message: $0.1)
                
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toAuth" {
            if let vC = segue.destination as? AuthViewController { vC.delegate = self}
        } else if segue.identifier == "toChat" {
            if let vC = segue.destination as? ChatViewController, let group = self.selectedGroup {
                vC.group = group
                if (group.messages.count == 0) {
                    self.connectionManager.getChatMessages(u: (Int(group.u) ?? 0))
                }
            }
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
        if identifier == "toAuth" {
            if successLogin {
                if connectionManager.sessionOpened {
                    alert(NSLocalizedString("Error on logout", comment:"Alert title for Error on logout"), message: NSLocalizedString("Stop current trip, before logout", comment:"Stop current trip, before logout"))
                } else {
                    SettingsManager.clearKeys()
                    connectionManager.closeConnection()
                    connectionManager.connect()
                }
                return false
            } else {
                return true
            }

        } else if identifier == "toChat" {
            if (self.selectedGroup != nil)  {
                return true
            } else {
                return false
            }        }
        //by default
        return true
    }
    
    func succesfullLoginWithToken (_ controller: AuthViewController, info : AuthInfo) -> Void {
        SettingsManager.setKey(info.accountName as NSString, forKey: SettingKeys.user)

        connectionManager.closeConnection()
        connectionManager.connect()
        
        userName.text = NSLocalizedString("Connecting...", comment:"Connecting status")
        controller.dismiss(animated: true, completion: nil)
        //groupManager.groupList(false)
        
    }
    
    func setLoginControls(){
        if let user = SettingsManager.getKey(SettingKeys.user) {
            if user.length > 0 {
                userName.text = String(user)
                userIcon.alpha = 1;
                loginBtn.setTitle(NSLocalizedString("Logout", comment:"Logout button"), for: UIControl.State())
                self.successLogin = true
                return;
            }
        }
        userIcon.alpha = 0.3;
        userName.text = NSLocalizedString("Unknown", comment:"Unknown user")
        loginBtn.setTitle(NSLocalizedString("Login", comment:"Login button"), for: UIControl.State())
        self.successLogin = false
    }
    
    func loginCancelled (_ controller: AuthViewController) -> Void {
        controller.dismiss(animated: true, completion: nil)
    }
    
    // MARK UITableViewDataSource
    @IBAction func btnEnterGroupClicked(_ sender: AnyObject) {

        if let firstRow = tableView.cellForRow(at: IndexPath(row: 0, section: 1)),
               let gName = firstRow.contentView.viewWithTag(1) as? UITextField,
               let nick = firstRow.contentView.viewWithTag(2) as? UITextField,
               let indicator = firstRow.contentView.viewWithTag(3) as? UIActivityIndicatorView,
               let btn = firstRow.contentView.viewWithTag(4) as? UIButton
        {
            
            if !gName.text!.isEmpty && !nick.text!.isEmpty {
                gName.isEnabled = false
                nick.isEnabled = false
                btn.isHidden = true
                indicator.startAnimating()
                
                groupManager.enterGroup(gName.text!, nick: nick.text!)
            }
        
        }
 
    }
    
    @IBAction func GoByLink(_ sender: UIButton) {
        if let sessionUrl = sender.titleLabel?.text, let url = sessionUrl.addingPercentEncoding (withAllowedCharacters: CharacterSet.urlQueryAllowed) {
            
            if let checkURL = URL(string: url) {
                let safariActivity = SafariActivity()
                let activityViewController = UIActivityViewController(activityItems: [checkURL], applicationActivities: [safariActivity])
                activityViewController.popoverPresentationController?.sourceView = tableView
                //activityViewController.popoverPresentationController?.sourceView = self.view
                self.present(activityViewController, animated: true, completion: {})
                
            }
        } else {
            print("error: invalid url")
        }
        
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.section.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (section) {
        case 0:
            if groupAction == GroupActions.new{
                return 1;
            } else {
                return 0;
            }
        case 1:
            if groupAction == GroupActions.enter{
                return 1;
            } else {
                return 0;
            }
        case 2:
            return groupManager.allGroups.count;
        default:
            return 0;
        }
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude;
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0{
            if groupAction == GroupActions.new{
                return 150;
            } else {
                return 85;
            }
        } else {
            return 85;
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = (indexPath as NSIndexPath).row
        let section = (indexPath as NSIndexPath).section
        
        var cell: UITableViewCell?
        
        if (section == 1 && row == 0) {

           cell = tableView.dequeueReusableCell(withIdentifier: enterGroupCell, for: indexPath)
            if (cell == nil) {
                cell = UITableViewCell(style:UITableViewCell.CellStyle.subtitle, reuseIdentifier:enterGroupCell)
            }
           if let gName = cell!.contentView.viewWithTag(1) as? UITextField,
                let nick = cell!.contentView.viewWithTag(2) as? UITextField,
                let btn = cell!.contentView.viewWithTag(4) as? UIButton {
                
                gName.text = groupToEnter
                gName.isEnabled = true
                if let user = SettingsManager.getKey(SettingKeys.user) {
                    if user.length > 0 {
                        nick.text = user as String;
                    } else {
                        nick.text = "";
                    }
                }
                nick.isEnabled = true
                btn.isHidden = false
                
           }
        } else if (section == 0 && row == 0) {

            cell = tableView.dequeueReusableCell(withIdentifier: newGroupCell, for: indexPath)
            if (cell == nil) {
                cell = UITableViewCell(style:UITableViewCell.CellStyle.default, reuseIdentifier:newGroupCell)
                
            }
            if let typeBtn = cell!.contentView.viewWithTag(7) as? UIButton,
                let email = cell!.contentView.viewWithTag(5) as? UITextField,
                let nick = cell!.contentView.viewWithTag(6) as? UITextField,
                let emailLabel = cell!.contentView.viewWithTag(8) as? UILabel,
                let nickLabel = cell!.contentView.viewWithTag(9) as? UILabel{
                typeBtn.setTitle(Group.getTypeName(groupType), for: UIControl.State.normal)
                
                if let user = SettingsManager.getKey(SettingKeys.user) {
                    if user.length > 0 {
                        nick.text = user as String;
                    } else {
                        nick.text = "";
                    }
                }

                email.isHidden = false;
                emailLabel.isHidden = false;
                nick.isHidden = false;
                nickLabel.isHidden = false;
            }
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: groupCell, for: indexPath)
            if (cell == nil) {
                cell = UITableViewCell(style:UITableViewCell.CellStyle.subtitle, reuseIdentifier:groupCell)
                
            }
            let group = groupManager.allGroups[row]

            if let groupName = cell!.contentView.viewWithTag(1) as? UILabel,
                let activeSwitch = cell!.contentView.viewWithTag(5) as? UISwitch,
                //let indicator = cell!.contentView.viewWithTag(3) as? UIActivityIndicatorView,
                let btnURL = cell!.contentView.viewWithTag(4) as? UIButton{
                groupName.text = "\(group.name)(\(group.nick))"
                btnURL.setTitle("https://osmo.mobi/g/\(group.url)", for: UIControl.State.normal)
                activeSwitch.isOn = group.active
            }
            
        }
        return cell!
    }

    // MARK UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = (indexPath as NSIndexPath).row
        let section = (indexPath as NSIndexPath).section
        
        if (section < 2) {
            tableView.deselectRow(at: indexPath, animated: true)
        } else {
            self.selectedGroup = groupManager.allGroups[row]
            if let group = self.selectedGroup {
                if (group.active == true) {
                    performSegue(withIdentifier: "toChat", sender: self)
                }
                
            }
            
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        //return !(groupAction == GroupActions.enter && (indexPath as NSIndexPath).row == 0)
        return true;
    }

    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        let section = (indexPath as NSIndexPath).section
        if (section < 2) {
            return NSLocalizedString("Cancel", comment:"Cancel")
        } else {
            return NSLocalizedString("Leave", comment:"Leave group")
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let section = (indexPath as NSIndexPath).section
        if editingStyle == UITableViewCell.EditingStyle.delete {
            
            if (section < 2) {

                groupAction = GroupActions.view
                btnEnterGroup.isHidden = false
                btnAddGroup.isHidden = false
                tableView.reloadData()
                
            }else {
                if let curRow = tableView.cellForRow(at: indexPath), let indicator = curRow.contentView.viewWithTag(3) as? UIActivityIndicatorView {
                    
                    indicator.startAnimating()
                }
                
                let group = groupManager.allGroups[(indexPath as NSIndexPath).row]
                groupManager.leaveGroup(group.u)
                
            }
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
        let myAlert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        myAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment:"OK"), style: .default, handler: nil))
        self.present(myAlert, animated: true, completion: nil)
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
