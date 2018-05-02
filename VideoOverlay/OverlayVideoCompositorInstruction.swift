//
//  OverlayVideoCompositorInstruction.swift
//  VideoOverlay
//
//  Created by Adam Kaplan on 5/13/17.
//  Copyright © 2017 Adam Kaplan. All rights reserved.
//

import AppKit
import AVFoundation

/// Video composition instruction model for providing instances of
/// OverlayVideoCompositor with required configuration details
final class OverlayCompositorInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    
    /* Indicates the timeRange during which the instruction is effective. Note requirements for the timeRanges of instructions described in connection with AVVideoComposition's instructions key above. */
    public var timeRange: CMTimeRange
    
    
    /* If NO, indicates that post-processing should be skipped for the duration of this instruction.  YES by default.
     See +[AVVideoCompositionCoreAnimationTool videoCompositionToolWithPostProcessingAsVideoLayer:inLayer:].*/
    public let enablePostProcessing: Bool = true
    
    
    /* If YES, rendering a frame from the same source buffers and the same composition instruction at 2 different
     compositionTime may yield different output frames. If NO, 2 such compositions would yield the
     same frame. The media pipeline may me able to avoid some duplicate processing when containsTweening is NO */
    public let containsTweening: Bool = false
    
    
    /* Indicates the background color of the composition. Solid BGRA colors only are supported; patterns and other color refs that are not supported will be ignored.
     If the background color is not specified the video compositor will use a default backgroundColor of opaque black.
     If the rendered pixel buffer does not have alpha, the alpha value of the backgroundColor will be ignored. */
    public let backgroundColor: CGColor = NSColor.white.withAlphaComponent(0.0).cgColor
    
    
    /* Provides an array of instances of AVVideoCompositionLayerInstruction that specify how video frames from source tracks should be layered and composed.
     Tracks are layered in the composition according to the top-to-bottom order of the layerInstructions array; the track with trackID of the first instruction
     in the array will be layered on top, with the track with the trackID of the second instruction immediately underneath, etc.
     If this key is nil, the output will be a fill of the background color. */
    //open var layerInstructions: [AVVideoCompositionLayerInstruction] { get }
    
    
    /* List of video track IDs required to compose frames for this instruction. The value of this property is computed from the layer instructions. */
    public let sourceTrack: AVMovieTrack
    
    /* List of video track IDs required to compose frames for this instruction. If the value of this property is nil, all source tracks will be considered required for composition */
    public let requiredSourceTrackIDs: [NSValue]?
    
    
    /* If the video composition result is one of the source frames for the duration of the instruction, this property
     returns the corresponding track ID. The compositor won't be run for the duration of the instruction and the proper source
     frame will be used instead. The value of this property is computed from the layer instructions */
    public let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    
    init(forTrack track: AVMovieTrack, timeRange: CMTimeRange) {
        self.sourceTrack = track
        self.requiredSourceTrackIDs =  [NSNumber(value: track.trackID)]
        
        self.timeRange = timeRange
        super.init()
    }
}
