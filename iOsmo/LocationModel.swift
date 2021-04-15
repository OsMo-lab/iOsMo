//
//  LocationModel.swift
//  iOsmo
//
//  Created by Olga Grineva on 13/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2017 Alexey Sirotkin All rights reserved.
//

import Foundation

public struct LocationModel{
    var lat: Double
    var lon: Double
    var speed: Double = -1.0
    var alt: Int = 0
    var course: Float = 0.0
    var accuracy: Int = 0
    var time: Date
    
    let coordFormat = "%.6f"
    let speedFormat = "S%.2f"
    let courseFormat = "C%.0f"
    let timeFormat = "T%.0f"
    
    init(lat: Double, lon: Double){
        self.lat = lat
        self.lon = lon
        self.time = Date()
    }
    
    init(coordString: String){
        //G:1578|["17397|L59.852968:30.373739S0","47580|L37.330178:-122.032674S3"]
        //G:9938|["21542|L46.654809:31.020692S3A48","21646|L46.484945:30.689059S7A78"]
        let parts = coordString.components(separatedBy: "S")
        self.speed = atof(parts[1])
        
        let coordinatesMerged = parts[0][parts[0].index(parts[0].startIndex, offsetBy: 1)...]
        let coordinates = coordinatesMerged.components(separatedBy: ":")
        self.lat = atof(coordinates[0])
        self.lon = atof(coordinates[1])
        
        let tparts = coordString.components(separatedBy: "T")
        if tparts.count>1 {
            self.time = Date(timeIntervalSince1970: atof(tparts[1]))
        } else {
            self.time = Date()
        }
    }
    
    var getCoordinateRequest: String{
        var isSimulated = false

        if UIDevice.current.model == "iPhone Simulator" {
            isSimulated = true
        }
        var formatedTime = ""

        let t:TimeInterval = time.timeIntervalSince1970
        formatedTime = NSString(format:timeFormat as NSString, t) as String

        let formatedSpeed = speed > 0 ? (NSString(format:speedFormat as NSString, speed)): ""
        let formatedCourse = (speed > 5 && course > 0)  ? (NSString(format:courseFormat as NSString, course)): ""
        let toSend = "L\(NSString(format:coordFormat as NSString, lat)):\(NSString(format:coordFormat as NSString, lon))\(formatedSpeed)A\(isSimulated ? randRange(5, upper: 125) : alt)\(formatedCourse)H\(accuracy)\(formatedTime)"

        return toSend
    }
    
    fileprivate func randRange (_ lower: UInt32 , upper: UInt32) -> Int {
        return (Int)(lower + arc4random_uniform(upper - lower + 1))
    }

}
