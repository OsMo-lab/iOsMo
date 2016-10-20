//
//  LocationModel.swift
//  iOsmo
//
//  Created by Olga Grineva on 13/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import Foundation
public struct LocationModel{
    
    var lat: Double
    var lon: Double
    var speed: Double = 0.0
    var alt: Int = 0
    var course: Float = 0.0
    var accuracy: Int = 0
    
    
    let coordFormat = "%.6f"
    let speedFormat = "%.2f"
    
    
    init(lat: Double, lon: Double){
        self.lat = lat
        self.lon = lon
    }
    
    init(coordString: String){
        
        //G:1578|["17397|L59.852968:30.373739S0","47580|L37.330178:-122.032674S3"]
        let parts = coordString.components(separatedBy: "S")
        self.speed = atof(parts[1])
        
        let coordinatesMerged = parts[0].substring(from: parts[0].characters.index(parts[0].startIndex, offsetBy: 1))
        let coordinates = coordinatesMerged.components(separatedBy: ":")
        self.lat = atof(coordinates[0])
        self.lon = atof(coordinates[1])
        
    }
    
    var getCoordinateRequest: String{
        
        var isSimulated = false

        if UIDevice.current.model == "iPhone Simulator" {
            isSimulated = true
        }
        
        
        let formatedSpeed = speed > 0 ? (NSString(format:speedFormat as NSString, speed)): "0"
        let toSend = "\(TagsOld.coordinate.rawValue)|L\(NSString(format:coordFormat as NSString, lat)):\(NSString(format:coordFormat as NSString, lon))S\(formatedSpeed)A\(isSimulated ? randRange(5, upper: 125) : alt)H\(accuracy)"

        return toSend
    }
    
    
    fileprivate func randRange (_ lower: UInt32 , upper: UInt32) -> Int {
        return (Int)(lower + arc4random_uniform(upper - lower + 1))
    }

}
