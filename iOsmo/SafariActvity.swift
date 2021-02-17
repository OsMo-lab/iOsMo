//
//  SafariActvity.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 14.02.17.
//  Copyright © 2017 Alexey Sirotkin. All rights reserved.
//

import UIKit


class SafariActivity: UIActivity {
    var url: NSURL?
    
     override var activityImage: UIImage? {
        return UIImage(named: "safari")!
    }
    
    override var activityTitle: String? {
        return "Safari"
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        for item in activityItems {
            if let url = item as? NSURL, UIApplication.shared.canOpenURL(url as URL) {
                return true
            }
        }
        return false
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        for item in activityItems {
            if let url = item as? NSURL, UIApplication.shared.canOpenURL(url as URL) {
                self.url = url
            }
        }
    }
    
    override func perform() {
        var completed = false
        
        if let url = self.url {
            completed = UIApplication.shared.open(url as URL)
        }
        
        activityDidFinish(completed)
    }
}
