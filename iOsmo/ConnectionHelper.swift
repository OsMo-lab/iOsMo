//
//  ConnectionHelper.swift
//  iOsmo
//
//  Created by Olga Grineva on 23/03/15.
//  Modified by Alexey Sirotkin on 08/08/16.
//  Copyright (c) 2015 Olga Grineva, (c) 2019 Alexey Sirotkin. All rights reserved.
//

import Foundation

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}

class ConnectionHelper: NSObject {
    var backgroundCompletionHandler: (() -> Void)?
    private var session: URLSession!
    private var backgroundTask: URLSessionDownloadTask?;
    
    var onCompleted: (( URL, Data?) -> ())?
    
    // MARK: - Singleton
    static let shared = ConnectionHelper()

    // MARK: - Init
    
    override init() {
        super.init()
        
        let configuration = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).background.download.session")
        configuration.sessionSendsLaunchEvents = true
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - postRequest
    func backgroundRequest (_ url: URL, requestBody: NSString  ) {
        LogQueue.sharedLogQueue.enqueue("CH.backgroundRequest for \(url)")
        if backgroundTask != nil {
            LogQueue.sharedLogQueue.enqueue("CH.backgroundRequest canceling last backgroundtask")
            backgroundTask?.cancel()
            backgroundTask = nil
        }
        let configuration = URLSessionConfiguration.background(withIdentifier:"bgSessionConfiguration")

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        var urlReq = URLRequest(url: url);
        
        urlReq.httpMethod = "POST"
        urlReq.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        urlReq.httpBody = requestBody.data(using: String.Encoding.utf8.rawValue)
        backgroundTask = session.downloadTask(with: urlReq)
        backgroundTask!.resume()
    }
    
    static func downloadRequest (_ url: URL, completed : @escaping (_ succeeded: Bool, _ res: Data?) -> ()) {
        let session = URLSession.shared;
        var urlReq = URLRequest(url: url);
        
        urlReq.httpMethod = "GET"
        urlReq.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        let task = session.downloadTask(with: urlReq, completionHandler:  {(url, response, error) in
            if url != nil {
                do {
                    let data:Data! = try Data(contentsOf: url!)
                    completed(true, data)
                } catch {
                    completed(false, nil)
                }
            }
        })
        task.resume()
    }
}


// MARK: - URLSessionDelegate
extension ConnectionHelper: URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            LogQueue.sharedLogQueue.enqueue("CH.urlSessionDidFinishEvents")
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension ConnectionHelper: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        LogQueue.sharedLogQueue.enqueue("CH.didFinishDownloadingTo")
        var data: Data;
        do {
            data = try Data(contentsOf: location)
            DispatchQueue.main.async {
                self.onCompleted?(location, data)
            }
        } catch {
            LogQueue.sharedLogQueue.enqueue("DATA INVALID")
            DispatchQueue.main.async {
                self.onCompleted?(location, nil)
            }
        }
        backgroundTask = nil;
    }
    /*
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let originalRequestURL = downloadTask.originalRequest?.url, let downloadItem = context.loadDownloadItem(withURL: originalRequestURL) else {
            return
        }
        
        print("Downloaded: \(downloadItem.remoteURL)")
        
        do {
            try fileManager.moveItem(at: location, to: downloadItem.filePathURL)
            
            downloadItem.foregroundCompletionHandler?(.success(downloadItem.filePathURL))
        } catch {
            downloadItem.foregroundCompletionHandler?(.failure(APIError.invalidData))
        }
        
        context.deleteDownloadItem(downloadItem)
    }
 */
}
