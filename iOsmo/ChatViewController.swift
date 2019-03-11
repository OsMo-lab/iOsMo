//
//  ChatViewController.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 03.03.2019.
//  Copyright © 2019 Alexey Sirotkin. All rights reserved.
//

import Foundation
import UIKit

class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    var connectionManager = ConnectionManager.sharedConnectionManager
    var groupManager = GroupManager.sharedGroupManager
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var message: UITextField!
    @IBOutlet weak var sendBtn: UIButton!
    var group: Group  = GroupManager.sharedGroupManager.allGroups[0];
    
    let messageCell = "messageCell"

    @IBAction func btnBackClicked(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func btnSendClicked(_ sender: AnyObject) {
        if let text = message.text {
            groupManager.sendChatMessage(group: Int(group.u) ?? 0, text: text)
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _ = groupManager.messagesUpdated.add{
            let _ = $0
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        _ = groupManager.messageSent.add {
            let _ = $0
            DispatchQueue.main.async {
                self.message.text = ""
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK UITableViewDelegate
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return group.messages.count;
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude;
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 85;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = (indexPath as NSIndexPath).row
        let section = (indexPath as NSIndexPath).section
        
        var cell: UITableViewCell?
        if (section == 0) {
            
            cell = tableView.dequeueReusableCell(withIdentifier: messageCell, for: indexPath)
            if (cell == nil) {
                cell = UITableViewCell(style:UITableViewCellStyle.default, reuseIdentifier:messageCell)
                
            }
            if let messageLabel = cell!.contentView.viewWithTag(1) as? UILabel{
                messageLabel.text = group.messages[row].text
            }
            if let userLabel = cell!.contentView.viewWithTag(2) as? UILabel{
                userLabel.text = group.messages[row].user
            }
            if let dateLabel = cell!.contentView.viewWithTag(3) as? UILabel{
                let dateFormat = DateFormatter()
                dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let formatedTime = dateFormat.string(from: group.messages[row].time)
                
                dateLabel.text = "\(formatedTime)"
            }
        }
        return cell!
    }
    

}


