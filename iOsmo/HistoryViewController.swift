//
//  HistoryViewController.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 22.05.2019.
//  Copyright © 2019 Alexey Sirotkin. All rights reserved.
//

import Foundation

class HistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    var connectionManager = ConnectionManager.sharedConnectionManager
    var groupManager = GroupManager.sharedGroupManager
    var history: [History] = [History]()
    var onHistoryUpdated: ObserverSetEntry<(Int, Any)>?
    
    var task: URLSessionDownloadTask!
    var session: URLSession!
    var cache:NSCache<AnyObject, AnyObject>!
    private let refreshControl = UIRefreshControl()
    
    let trackCell = "trackCell"
    
    override func viewWillAppear(_ animated:Bool) {
        print("HistoryViewController WillApear")
        super.viewWillAppear(animated)
        getHistory()
    }
    
    private func getHistory() {
        history.removeAll()
        connectionManager.getHistory()
    }
    
    @objc private func refreshHistory(_ sender: Any) {
        getHistory()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("HistoryViewController viewDidLoad")
        session = URLSession.shared
        task = URLSessionDownloadTask()
        self.cache = NSCache()
        // Add Refresh Control to Table View

        if #available(iOS 10.0, *) {
            self.tableView.refreshControl = refreshControl
        } else {
            self.tableView.addSubview(refreshControl)
        }
        // Configure Refresh Control
        refreshControl.addTarget(self, action: #selector(refreshHistory(_:)), for: .valueChanged)
        
        self.onHistoryUpdated = self.connectionManager.historyReceived.add{
            let jsonarr = $1 as! Array<AnyObject>
            let res = $0
            
            //if let jsonarr = json as? Array<Any> {
                for m in jsonarr {
                    let track = History.init(json: m as! Dictionary<String, AnyObject>)
                    self.history.append(track) 
            }
            //}
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()
                //self.self.activityIndicatorView.stopAnimating()
                
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
        return history.count;
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude;
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.frame.width + 20;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = (indexPath as NSIndexPath).row
        let section = (indexPath as NSIndexPath).section
        
        var cell: UITableViewCell?
        if (section == 0) {
            
            cell = tableView.dequeueReusableCell(withIdentifier: trackCell, for: indexPath)
            if (cell == nil) {
                cell = UITableViewCell(style:UITableViewCell.CellStyle.default, reuseIdentifier:trackCell)
                
            }
            
            if let nameLabel = cell!.contentView.viewWithTag(1) as? UILabel{
                nameLabel.text = history[row].name
            }
            if let distanceLabel = cell!.contentView.viewWithTag(2) as? UILabel{
                distanceLabel.text = String(format:"%.3f", history[row].distantion)
            }
            if let dateLabel = cell!.contentView.viewWithTag(3) as? UILabel{
                let dateFormat = DateFormatter()
                dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let formatedTime = dateFormat.string(from: history[row].start!)
                dateLabel.text = "\(formatedTime)"
            }
            
            if let trackImage = cell!.contentView.viewWithTag(4) as? UIImageView{
                if (self.cache.object(forKey: (indexPath as NSIndexPath).row as AnyObject) != nil){
                    // 2
                    // Use cache
                    print("Cached image used, no need to download it")
                    trackImage.image = self.cache.object(forKey: (indexPath as NSIndexPath).row as AnyObject) as? UIImage
                }else{
                    // 3
                    let imageUrl = history[row].image
                    let url:URL! = URL(string: imageUrl)
                    task = session.downloadTask(with: url, completionHandler: { (location, response, error) -> Void in
                        if let data = try? Data(contentsOf: url){
                            // 4
                            DispatchQueue.main.async(execute: { () -> Void in
                                // 5
                                // Before we assign the image, check whether the current cell is visible
                                if let updateCell = tableView.cellForRow(at: indexPath) {
                                    let img:UIImage! = UIImage(data: data)
                                    let curTrackImage = updateCell.contentView.viewWithTag(4) as? UIImageView
                                    curTrackImage?.image = img
                                    self.cache.setObject(img, forKey: (indexPath as NSIndexPath).row as AnyObject)
                                }
                            })
                        }
                    })
                    task.resume()
                }
            }
            
 
        }
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = (indexPath as NSIndexPath).row
        let section = (indexPath as NSIndexPath).section
        let track = Track.init(track: history[indexPath.row])
        
        groupManager.getTrackData(track)
        
        let tbc:UITabBarController = self.tabBarController!
        let mvc: MapViewController = tbc.viewControllers![2] as! MapViewController;
        mvc.putHistoryOnMap(tracks: [track])
        tbc.selectedViewController = mvc;
    }
}
