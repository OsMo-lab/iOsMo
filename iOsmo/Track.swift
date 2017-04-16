//
//  Track.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 16.04.17.
//  Copyright © 2017 Alexey Sirotkin. All rights reserved.
//

import Foundation

open class Track {
    var u: Int
    var type: String = "0"
    var descr: String = ""
    var km: String = ""
    var color: String = "#ffffff"
    var name: String = ""
    var url: String = ""
    var size: Int = 0
    var start: Date?
    var finish: Date?
    
    init(u: Int, name: String, type: String, color: String, url: String, size: Int){
        self.u = u;

        self.name = name;
        self.url = url
        self.color = color;
        self.type = type;
        self.size = size;
        
    }
    
    open func getTrackData() -> XML? {
        var paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true);
        let filename = "\(u).gpx"
        let path =  "\(paths[0])/channelsgpx/"
        let file: FileHandle? = FileHandle(forReadingAtPath: "\(path)\(filename)")
        if file != nil {
            // Read all the data
            let data = file?.readDataToEndOfFile()
            
            // Close the file
            file?.closeFile()
            
            let xml = XML(data: data!)
            return xml;
        }
        else {
            return nil
        }
        /*
        let fileURL = URL(string: "\(path)\(filename)")
        
        do {
            let data = try Data.init(contentsOf: fileURL!)
            let xml = XML(data: data)
            return xml;
        } catch {
            return nil
        }
 */
        
    }
    
}
