//
//  SecondViewController.swift
//  iOsmo
//
//  Created by Olga Grineva on 07/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import UIKit

class LogViewController: UIViewController {

    required init?(coder aDecoder: NSCoder) {
        logQueue = LogQueue.sharedLogQueue
        
        super.init(coder: aDecoder)
       

    }

    var logQueue: LogQueue
    var countValue = 100
    var page = 1
    var lastCount = 0

    @IBOutlet weak var logBox: UITextView!
    @IBOutlet weak var count: UITextField!
    
    
    @IBAction func onEditingEnd(_ sender: AnyObject) {
    }
    @IBAction func Load(_ sender: AnyObject) {
    
        self.page = 1
        self.logBox.text = ""
        lastCount = logQueue.count
        
        let countToGet = (lastCount < countValue) ? lastCount : countValue
        
        let toDisplay = logQueue.getArray(lastCount - countToGet, count: countToGet)
        /*
        for i in stride(from: toDisplay.count, to: 1, by: -1) {
            //if let str = toDisplay[i-1] as? String { self.logMessage(str) }
            self.logMessage(toDisplay[i-1] as String)
        } 
         */
        let l = toDisplay.joined(separator: "\n")
        self.logBox.text = l
        
    }
    @IBAction func Next(_ sender: AnyObject) {
        
        let others = lastCount - page*countValue
        let countToGet = (others > countValue) ? countValue : (others > 0) ? others : 0
        
        let toDisplay = logQueue.getArray(lastCount - page*countValue - countToGet, count: countToGet)
        
        /*for i in stride(from: toDisplay.count, to: 1, by: -1){
            self.logMessage(toDisplay[i-1] as String)
        }*/
        let l = toDisplay.joined(separator: "\n")
        self.logBox.text = l
    
        if toDisplay.count == countValue {page += 1}
    
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.Load(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        //let countValue = Int (count.text!);
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func logMessage (_ message: String){
        
        let newLineStr = "\n"
        //let text = "\(self.logBox.text) \(message)\(newLineStr)"
        let text = "\(self.logBox.text ?? "")test\(newLineStr)"
        self.logBox.text = text
       
    }


}

