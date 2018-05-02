//
//  OverlayVideoCompositor.swift
//  VideoOverlay
//
//  Created by Adam Kaplan on 5/13/17.
//  Copyright © 2017 Adam Kaplan. All rights reserved.
//

import AppKit
import AVFoundation

class OverlayCompositor: NSObject, AVVideoCompositing {
    
    enum Errors: Error {
        case renderContextFrameBufferFailed
        case invalidCompositionInstruction
    }
    
    let widgets = [ TextWidget() ]
    
    /// Flag that indicates if the compositor is running. If false, asynchronous
    /// render tasks should abort their work as soon as practical.
    var enabled = true
    
    /// The current render context provided by the composition
    var renderContext: AVVideoCompositionRenderContext?
    
    /// Dispatch queue that will be handling concurrent frame rendering
    let queue = DispatchQueue(label: "com.r9design.render.overlay",
                              qos: .default,
                              attributes: .concurrent,
                              autoreleaseFrequency: .inherit)
    
    /// All offloaded frame computations run in the dispatch group so that they
    /// may be canceled to conform with the requirements of `cancelAllPendingVideoCompositionRequests`
    let workGroup = DispatchGroup()
    
    
    /// Required configuration parameters for the source buffers
    public var sourcePixelBufferAttributes: [String : Any]? = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]
    
    /// Required configuration parameters for the render context
    public var requiredPixelBufferAttributesForRenderContext: [String : Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]
    
    /*!
     @method			renderContextChanged:
    	@abstract       Called to notify the custom compositor that a composition will switch to a different render context
    	@param			newRenderContext
     The render context that will be handling the video composition from this point
     @discussion
     Instances of classes implementing the AVVideoComposting protocol can implement this method to be notified when
     the AVVideoCompositionRenderContext instance handing a video composition changes. AVVideoCompositionRenderContext instances
     being immutable, such a change will occur every time there is a change in the video composition parameters.
     */
    public func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        self.renderContext = newRenderContext
    }
    
    /*!
    	@method			startVideoCompositionRequest:
    	@abstract		Directs a custom video compositor object to create a new pixel buffer composed asynchronously from a collection of sources.
    	@param			asyncVideoCompositionRequest
     An instance of AVAsynchronousVideoCompositionRequest that provides context for the requested composition.
    	@discussion
     The custom compositor is expected to invoke, either subsequently or immediately, either:
     -[AVAsynchronousVideoCompositionRequest finishWithComposedVideoFrame:] or
     -[AVAsynchronousVideoCompositionRequest finishWithError:]. If you intend to finish rendering the frame after your
     handling of this message returns, you must retain the instance of AVAsynchronousVideoCompositionRequest until after composition is finished.
     Note that if the custom compositor's implementation of -startVideoCompositionRequest: returns without finishing the composition immediately,
     it may be invoked again with another composition request before the prior request is finished; therefore in such cases the custom compositor should
     be prepared to manage multiple composition requests.
     
     If the rendered frame is exactly the same as one of the source frames, with no letterboxing, pillboxing or cropping needed,
     then the appropriate source pixel buffer may be returned (after CFRetain has been called on it).
     */
    public func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        queue.async(group: workGroup, qos: .unspecified, flags: .noQoS) { [weak self] in
            guard self != nil else { return }
            
            do {
                let buffer = try self!.renderFrame(forRequest: asyncVideoCompositionRequest)
                asyncVideoCompositionRequest.finish(withComposedVideoFrame: buffer)
            } catch {
                // some logging would be nice
            }
        }
    }
    
    
    /*!
    	@method			cancelAllPendingVideoCompositionRequests
    	@abstract		Directs a custom video compositor object to cancel or finish all pending video composition requests
    	@discussion
     When receiving this message, a custom video compositor must block until it has either cancelled all pending frame requests,
     and called the finishCancelledRequest callback for each of them, or, if cancellation is not possible, finished processing of all the frames
     and called the finishWithComposedVideoFrame: callback for each of them.
     */
    public func cancelAllPendingVideoCompositionRequests() {
        // Disable frame processing and then block for all pending requests to
        // flush out. Before returning from this synchronous method, processing
        // should be re-enabled. This may occur during renderContext changes
        self.enabled = false
        defer {
            self.enabled = true
        }
        
        self.workGroup.wait()
    }
    
    /*!
     @property supportsWideColorSourceFrames
     @abstract
    	Indicates that clients can handle frames that contains wide color properties.
     
     @discussion
    	Controls whether the client will receive frames that contain wide color information. Care should be taken to avoid clamping.
     */
    //optional public var supportsWideColorSourceFrames: Bool { get }
    
    func renderFrame(forRequest request: AVAsynchronousVideoCompositionRequest) throws -> CVPixelBuffer {
        // If we're disabled, return empty pixel buffer
        guard self.enabled else { return try! self.createEmptyPixelBuffer() }
        
        // Ensure the instruction is of the correct type and cast it
        guard let instruction = request.videoCompositionInstruction as? OverlayCompositorInstruction
            else { throw Errors.invalidCompositionInstruction }
        
        // Grab the source frame for the target track
        guard let frameBuffer = request.sourceFrame(byTrackID: instruction.sourceTrack.trackID)
            else { return try! self.createEmptyPixelBuffer() }
        
        // The graphics frame buffer must be locked during manipulation operations
        // Additionally, `CVPixelBufferGetBaseAddress` returns NULL unless locked
        CVPixelBufferLockBaseAddress(frameBuffer, CVPixelBufferLockFlags(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(frameBuffer, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        let width = CVPixelBufferGetWidth(frameBuffer),
        height = CVPixelBufferGetHeight(frameBuffer)
        
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(frameBuffer),
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(frameBuffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            else { return frameBuffer }
        
        context.setLineWidth(100)
        context.setStrokeColor(NSColor.green.cgColor)
        context.strokeLineSegments(between: [ CGPoint(x: 0, y: 0),
                                              CGPoint(x: width,
                                                      y: height) ])
        
        for widget in widgets {
            widget.frame = CGRect(x: 50, y: 50, width: 100, height: 50)
            widget.string = "\(request.compositionTime)"
            widget.draw(in: context)
        }

        return frameBuffer
    }
    
    
    func createEmptyPixelBuffer() throws -> CVPixelBuffer {
        guard let renderContext = self.renderContext else {
            return try! self.createPixelBuffer(fromRenderContext: AVVideoCompositionRenderContext())
        }
        
        return try! self.createPixelBuffer(fromRenderContext: renderContext)
    }
    
    
    func createPixelBuffer(fromRenderContext renderContext: AVVideoCompositionRenderContext) throws -> CVPixelBuffer {
        guard let buffer = renderContext.newPixelBuffer() else {
            throw Errors.renderContextFrameBufferFailed
        }
        return buffer
    }
}

class TextWidget: CATextLayer {
    
    override init() {
        super.init()

        self.isOpaque = true
        self.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        self.foregroundColor = NSColor.white.cgColor
        self.font = NSFont.monospacedDigitSystemFont(ofSize: 25, weight: 0)
        self.borderColor = NSColor.white.cgColor
        self.borderWidth = 2.0
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

