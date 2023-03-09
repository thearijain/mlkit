import Foundation
import UIKit

import MLKit

/// Protocol used by the `StrokeManager` to send requests back to the `ViewController` to update the
/// display.
protocol StrokeManagerDelegate: class {
    /** Clears any temporary ink managed by the caller. */
    func clearInk()
    /** Display the given message to the user. */
    func displayMessage(message: String)
}

/// The `StrokeManager` object is responsible for storing the ink and recognition results, and
/// managing the interaction with the recognizer. It receives the touch points as the user is drawing
/// from the `ViewController` (which takes care of rendering the ink), and stores them into an array
/// of `Stroke`s. When the user taps "recognize", the strokes are collected together into an `Ink`
/// object, and passed to the recognizer. The `StrokeManagerDelegate` protocol is used to inform the
/// `ViewController` when the display needs to be updated.
///
/// The `StrokeManager` provides additional methods to handle other buttons in the UI, including
/// selecting a recognition language, downloading or deleting the recognition model, or clearing the
/// ink.
class StrokeManager {
    
    /**
     * Array of `RecognizedInk`s that have been sent to the recognizer along with any recognition
     * results.
     */
    var recognizedInks: [RecognizedInk]
    
    /**
     * Conversion factor between `TimeInterval` and milliseconds, which is the unit used by the
     * recognizer.
     */
    private var kMillisecondsPerTimeInterval = 1000.0
    
    /** Arrays used to keep the piece of ink that is currently being drawn. */
    private var strokes: [Stroke] = []
    private var points: [StrokePoint] = []
    
    /** The recognizer that will translate the ink into text. */
    private var recognizer: DigitalInkRecognizer! = nil
    
    /** The view that handles UI stuff. */
    private weak var delegate: StrokeManagerDelegate?
    
    /** Properties to track and manage the selected language and recognition model. */
    private var model: DigitalInkRecognitionModel?
    private var modelManager: ModelManager
    
    /**
     * Initialization of internal variables as well as creating the model manager and setting up
     * observers of the recognition model downloading status.
     */
    init(delegate: StrokeManagerDelegate) {
        self.delegate = delegate
        modelManager = ModelManager.modelManager()
        recognizedInks = []
        
        setupDefaultLanguage()
        
        // Add observers for download notifications, and reflect the status back to the user.
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.mlkitModelDownloadDidSucceed, object: nil,
            queue: OperationQueue.main,
            using: {
                [unowned self]
                (notification) in
                if notification.userInfo![ModelDownloadUserInfoKey.remoteModel.rawValue]
                    as? DigitalInkRecognitionModel == self.model
                {
                    self.delegate?.displayMessage(message: "Model download succeeded")
                }
            })
        // MARK: Need to handle download failing
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.mlkitModelDownloadDidFail, object: nil,
            queue: OperationQueue.main,
            using: {
                [unowned self]
                (notification) in
                if notification.userInfo![ModelDownloadUserInfoKey.remoteModel.rawValue]
                    as? DigitalInkRecognitionModel == self.model
                {
                    self.delegate?.displayMessage(message: "Model download failed")
                }
            })
    }
    
    // Setup english as default language
    func setupDefaultLanguage() {    
        let identifier = DigitalInkRecognitionModelIdentifier(forLanguageTag: "en")
        model = DigitalInkRecognitionModel.init(modelIdentifier: identifier!)
        
        let options: DigitalInkRecognizerOptions = DigitalInkRecognizerOptions.init(model: model!)
        recognizer = DigitalInkRecognizer.digitalInkRecognizer(options: options)
        
        
        
        
        
        self.delegate?.displayMessage(message: "Selected language with tag en")
        
        modelManager.download(
            model!,
            conditions: ModelDownloadConditions.init(
                allowsCellularAccess: true,
                allowsBackgroundDownloading: true
            )
        )
    }
    
    /**
     * Actually carries out the recognition. The recognition may happen asynchronously so there's a
     * callback that handles the results when they are ready.
     */
    func recognizeInk() {
        if strokes.isEmpty {
            delegate?.displayMessage(message: "No ink to recognize")
            return
        }
        if !modelManager.isModelDownloaded(model!) {
            delegate?.displayMessage(message: "Recognizer model not downloaded")
            return
        }
        
        // Turn the list of strokes into an `Ink`, and add this ink to the `recognizedInks` array.
        let ink = Ink.init(strokes: strokes)
        let recognizedInk = RecognizedInk.init(ink: ink)
        recognizedInks.append(recognizedInk)
        // Clear the currently being drawn ink, and display the ink from `recognizedInks` (which results
        // in it changing color).
        delegate?.clearInk()
        strokes = []
        // Setup writing height
        let context = DigitalInkRecognitionContext(
            preContext: "",
            writingArea: WritingArea(width: 834, height: 125)
        )
        // Start the recognizer. Callback function will store the recognized text and tell the
        // `ViewController` to redraw the screen to show it.
        recognizer.recognize(
            ink: ink,
            context: context,
            completion: {
                [unowned self, recognizedInk]
                (result: DigitalInkRecognitionResult?, error: Error?) in
                for candidate in result!.candidates {
                    print("=== ", candidate.text)
                }
                if let result = result, let candidate = result.candidates.first {
                    recognizedInk.text =    candidate.text
                    // MARK: Candidate.text is the new text
                    print("=== ", candidate.text)
                    var message = "Recognized: \(candidate.text)"
                    if candidate.score != nil {
                        message += " score \(candidate.score!.floatValue)"
                    }
                    self.delegate?.displayMessage(message: message)
                } else {
                    recognizedInk.text = "error"
                    self.delegate?.displayMessage(message: "Recognition error " + String(describing: error))
                }
            })
    }
    
    /** Clear out all the ink and other state. */
    func clear() {
        recognizedInks = []
        strokes = []
        points = []
    }
    
    /** Begins a new stroke when the user touches the screen. */
    func startStrokeAtPoint(point: CGPoint, t: TimeInterval) {
        points = [
            StrokePoint.init(
                x: Float(point.x), y: Float(point.y), t: Int(t * kMillisecondsPerTimeInterval))
        ]
    }
    
    /** Adds an additional point to the stroke when the user moves their finger. */
    func continueStrokeAtPoint(point: CGPoint, t: TimeInterval) {
        points.append(
            StrokePoint.init(
                x: Float(point.x), y: Float(point.y),
                t: Int(t * kMillisecondsPerTimeInterval)))
    }
    
    /** Completes a stroke when the user lifts their finger. */
    func endStrokeAtPoint(point: CGPoint, t: TimeInterval) {
        points.append(
            StrokePoint.init(
                x: Float(point.x), y: Float(point.y),
                t: Int(t * kMillisecondsPerTimeInterval)))
        // Create an array of strokes if it doesn't exist already, and add this stroke to it.
        strokes.append(Stroke.init(points: points))
        points = []
    }
}
