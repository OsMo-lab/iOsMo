//
//  Extensions.swift
//  iOsmo
//
//  Created by Olga Grineva on 28/05/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation

extension NSURL{
    func queryParams() -> [String:AnyObject] {
        var info : [String:AnyObject] = [String:AnyObject]()
        if let queryString = self.query{
            for parameter in queryString.componentsSeparatedByString("&"){
                let parts = parameter.componentsSeparatedByString("=")
                if parts.count > 1{
                    let key = (parts[0] as String).stringByRemovingPercentEncoding
                    let value = (parts[1] as String).stringByRemovingPercentEncoding
                    if key != nil && value != nil{
                        info[key!] = value
                    }
                }
            }
        }
        return info
    }
    
    
}

extension UIView {
    
    func roundCorners(corners:UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.CGPath
        self.layer.mask = mask
    }
}