//
//  SettingsViewController.swift
//  iOsmo
//
//  Created by Olga Grineva on 10/01/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController {

    @IBOutlet weak var awakeModeSwitcher: UISwitch!
    
    @IBAction func AwakeModeChanged(sender: AnyObject) {
    
        SettingsManager.setKey(self.awakeModeSwitcher.on ? "1" : "0", forKey: SettingKeys.isStayAwake)
        
        UIApplication.sharedApplication().idleTimerDisabled = awakeModeSwitcher.on
    
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let isStayAwake = SettingsManager.getKey(SettingKeys.isStayAwake) {
            
            awakeModeSwitcher.setOn(isStayAwake.boolValue, animated: false)
        }
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
