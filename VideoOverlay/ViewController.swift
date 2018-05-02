//
//  ViewController.swift
//  VideoOverlay
//
//  Created by Adam Kaplan on 5/13/17.
//  Copyright © 2017 Adam Kaplan. All rights reserved.
//

import Cocoa
import AVFoundation

class ViewController: NSViewController {

    let inputUrl = URL(fileURLWithPath: "/Users/adamkaplan/Desktop/GOPR3682.MP4")
    
    let outputUrl = URL(fileURLWithPath: "/Users/adamkaplan/Desktop/out.mp4")

    lazy var movie: AVMutableMovie = {
        return AVMutableMovie(url: self.inputUrl)
    }()
    
    lazy var playerLayer: AVPlayerLayer = {
        let playerItem = AVPlayerItem(asset: self.movie)
        let player = AVPlayer(playerItem: playerItem)
        return AVPlayerLayer(player: player)
    }()
    
    var player: AVPlayer? {
        return self.playerLayer.player
    }
    
    var naturalMovieSize: CGSize {
        return movie.tracks(withMediaType: AVMediaTypeVideo).reduce(CGSize.zero) { (accum: CGSize, track: AVMutableMovieTrack) in
            var size = accum
            if size.width < track.naturalSize.width {
                size.width = track.naturalSize.width
            }
            
            if size.height < track.naturalSize.height {
                size.height = track.naturalSize.height
            }
            return size
        }
    }
    
    var exportWorkGroup = DispatchGroup()
    var exportSession: AVAssetExportSession?
    var exportProgessReporter: ExportProgressReporter?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        playerLayer.frame = self.view.bounds
        self.view.layer?.addSublayer(playerLayer)
        
        try! FileManager.default.removeItem(at: outputUrl)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTimeMake(1, self.movie.timescale)
        videoComposition.renderSize = self.naturalMovieSize
        videoComposition.customVideoCompositorClass = OverlayCompositor.self // Use the custom compositor
        
        // Get the video track and set it in the composition instruction so that
        // the compositor knows which asset to use.
        guard let videoTrack = movie.tracks(withMediaType: AVMediaTypeVideo).first
            else { assert(false); return }
        let instruction = OverlayCompositorInstruction(forTrack: videoTrack, timeRange: videoTrack.timeRange)
        videoComposition.instructions = [ instruction ]
        
        /*
        guard let player = self.player,
            let playerItem = player.currentItem
            else { return }
        playerItem.videoComposition = videoComposition
        player.volume = 0
        player.play()
        */
        
        self.exportSession = AVAssetExportSession(asset: self.movie, presetName: AVAssetExportPresetAppleM4V1080pHD)
        guard let exportSession = self.exportSession
            else { return }
        exportSession.videoComposition = videoComposition
        exportSession.outputURL = self.outputUrl
        exportSession.outputFileType = AVFileTypeAppleM4V
        // FIXME: cap time range for the sake of my laptop battery and sanity
        exportSession.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(2.5, self.movie.duration.timescale))
        
        self.exportProgessReporter = ExportProgressReporter(withExportSession: exportSession, reportInterval: 0.25)
        
        exportWorkGroup.enter()
        self.exportProgessReporter?.start()
        exportSession.exportAsynchronously { [weak self] in
            self?.exportWorkGroup.leave()
            self?.exportProgessReporter?.stop()
        }
        
    }
}

