//
//  ExportProgressReporter.swift
//  VideoOverlay
//
//  Created by Adam Kaplan on 5/20/17.
//  Copyright © 2017 Adam Kaplan. All rights reserved.
//

import Foundation
import AVFoundation

final class ExportProgressReporter {
    
    var exportProgressTimer: DispatchSourceTimer?
    
    public let exportSession: AVAssetExportSession
    
    /// How often to report progress on the export
    public let reportInterval: TimeInterval
    
    /// Initialize with an export session and optional report interval
    init(withExportSession exportSession: AVAssetExportSession, reportInterval: TimeInterval = 0.250) {
        self.exportSession = exportSession
        self.reportInterval = reportInterval
        
        let timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0),
                                                   queue: DispatchQueue.global())
        timer.scheduleRepeating(deadline: .now(), interval: .milliseconds(250))
        timer.setEventHandler {
            ExportProgressReporter.report(exportSession)
        }
        self.exportProgressTimer = timer
    }
    
    /// Begin reporting. Multiple calls to this method without calling stop()
    /// have no effect.
    func start() {
        // Start only if not already started
        guard let timer = exportProgressTimer else {
            return
        }
        
        timer.resume()
    }
    
    /// Stop reporting. If reporting is already stopped, this method does nothing.
    func stop() {
        guard let timer = self.exportProgressTimer,
            timer.isCancelled == false
            else {
            return
        }
        
        timer.cancel()
        self.exportProgressTimer = nil
    }
    
    static func report(_ exportSession: AVAssetExportSession) {
            var status: String = "?"
        
            switch exportSession.status {
            case .waiting:
                status = "pending"
            case .exporting:
                status = "exporting: \(exportSession.progress * 100)%"
            case .completed:
                status = "done"
            case .cancelled:
                status = "canceled"
            case .failed:
                status = "failed!"
            case .unknown:
                status = "unknown error"
            }
            
        //            switch exportWorkGroup.wait(timeout: .now() + .milliseconds(100)) {
        //    case .timedOut:
        print("\(status)")
        //    case .success:
        //        print("complete")
        //    }
    }
    
}
