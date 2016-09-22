//
//  Extensions.swift
//  iOsmo
//
//  Created by Olga Grineva on 28/05/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation

extension URL{
    func queryParams() -> [String:Any] {
        var info : [String:Any] = [String:Any]()
        if let queryString = self.query{
            for parameter in queryString.components(separatedBy: "&"){
                let parts = parameter.components(separatedBy: "=")
                if parts.count > 1{
                    let key = (parts[0] as NSString).removingPercentEncoding
                    let value = (parts[1] as NSString).removingPercentEncoding
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
    
    func roundCorners(_ corners:UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        self.layer.mask = mask
    }
}
