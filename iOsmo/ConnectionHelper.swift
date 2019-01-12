//
//  ConnectionHelper.swift
//  iOsmo
//
//  Created by Olga Grineva on 23/03/15.
//  Modified by Alexey Sirotkin on 08/08/16.
//  Copyright (c) 2015 Olga Grineva, (c) 2019 Alexey Sirotkin. All rights reserved.
//

import Foundation

enum DataRequestResult<T> {
    case success(T)
    case failure(Error)
}

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
    
    var onCompleted: (( URL, Data) -> ())?
    
    // MARK: - Singleton
    static let shared = ConnectionHelper()

    // MARK: - Init
    
    override init() {
        super.init()
        
        let configuration = URLSessionConfiguration.background(withIdentifier: "iosmo.background.download.session")
        configuration.sessionSendsLaunchEvents = true
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - postRequest
    func backgroundRequest (_ url: URL, requestBody: NSString  ) {
        LogQueue.sharedLogQueue.enqueue("CH.backgroundRequest for \(url)")
        let configuration = URLSessionConfiguration.background(withIdentifier:"bgSessionConfiguration")

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        var urlReq = URLRequest(url: url);
        
        urlReq.httpMethod = "POST"
        urlReq.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        urlReq.httpBody = requestBody.data(using: String.Encoding.utf8.rawValue)
        let task = session.downloadTask(with: urlReq)
        task.resume()
    }
    
    static func downloadRequest (_ url: URL, completed : @escaping (_ succeeded: Bool, _ res: Data?) -> ()) {
        let session = URLSession.shared;
        var urlReq = URLRequest(url: url);
        
        urlReq.httpMethod = "GET"
        urlReq.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        let task = session.downloadTask(with: urlReq, completionHandler:  {(url, response, error) in
            if url != nil {
                
                do {
                    let data:Data! = try? Data(contentsOf: url!)
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
        var data: Data = Data();
        do {
            data = try Data(contentsOf: location)
        } catch {
            
        }
        DispatchQueue.main.async {
            
            self.onCompleted?(location, data)
            
        }
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
