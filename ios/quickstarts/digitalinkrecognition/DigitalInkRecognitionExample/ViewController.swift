import UIKit

import MLKit

/// The `ViewController` manages the display seen by the user. The drawing canvas is actually two
/// overlapping image views. The top one contains the ink that the user is drawing before it is sent
/// to the recognizer. It can be thought of as a temporary buffer for ink in progress. When the user
/// presses the "Recognize" button, the ink is transferred to the other canvas, which displays a
/// grayed out version of the ink together with the recognition result.
///
/// The management of the interaction with the recognizer happens in `StrokeManager`.
/// `ViewController` just takes care of receiving user events, rendering the temporary ink, and
/// handles redraw requests from the `StrokeManager` when the ink is recognized. This latter request
/// comes through the `StrokeManagerDelegate` protocol.
///
/// The `ViewController` provides a number of buttons for controlling the `StrokeManager` which allow
/// for selecting the recognition language, downloading or deleting the recognition model, triggering
/// recognition, and clearing the ink.
@objc(ViewController)
class ViewController: UIViewController, StrokeManagerDelegate {
    
    /** Constant defining how to render strokes. */
    private var kBrushWidth: CGFloat = 2.0
        /**
     * Object that takes care of the logic of saving the ink, sending ink to the recognizer after a
     * long enough pause, and storing the recognition results.
     */
    private var strokeManager: StrokeManager!
    
    /** Coordinates of the previous touch point as the user is drawing ink. */
    private var lastPoint: CGPoint!
    
    /** This view shows only the ink that is currently being drawn, before sending for recognition. */
    @IBOutlet private var drawnImage: UIImageView!
        
    /** Text region used to display status messages to the user about the results of their actions. */
    @IBOutlet private var messageLabel: UILabel!
    
    /** Initializes the view, in turn creating the StrokeManager and recognizer. */
    override func viewDidLoad() {
        super.viewDidLoad()
        // Create a `StrokeManager` to store the drawn ink. This also creates the recognizer object.
        strokeManager = StrokeManager.init(delegate: self)
        addRandomView()
    }
    
    func addRandomView() {
        let randomView: UIView = {
            let view = UIView()
            view.backgroundColor = .blue
            return view
        }()
        self.view.addSubview(randomView)
        randomView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            randomView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            randomView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            randomView.widthAnchor.constraint(equalTo: self.view.widthAnchor),
            randomView.heightAnchor.constraint(equalToConstant: 125)
        ])
        
        print("=== width of iPAD: " , self.view.frame.width)
        
        
    }
    
    /** Clear button clears the canvases and also tells the `StrokeManager` to delete everything. */
    @IBAction func didPressClear() {
        drawnImage.image = nil
        strokeManager!.clear()
        displayMessage(message: "")
    }
    
    /** Relays the recognize ink command to the `StrokeManager`. */
    @IBAction func didPressRecognize() {
        strokeManager!.recognizeInk()
    }
    
    /** Handle start of stroke: Draw the point, and pass it along to the `StrokeManager`. */
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        // Since this is a new stroke, make last point the same as the current point.
        lastPoint = touch!.location(in: drawnImage)
        let time = touch!.timestamp
        drawLineSegment(touch: touch)
        strokeManager!.startStrokeAtPoint(point: lastPoint!, t: time)
    }
    
    /** Handle continuing a stroke: Draw the line segment, and pass along to the `StrokeManager`. */
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        drawLineSegment(touch: touch)
        strokeManager!.continueStrokeAtPoint(point: lastPoint!, t: touch!.timestamp)
    }
    
    /** Handle end of stroke: Draw the line segment, and pass along to the `StrokeManager`. */
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        drawLineSegment(touch: touch)
        strokeManager!.endStrokeAtPoint(point: lastPoint!, t: touch!.timestamp)
    }
    
    /** Displays a status message from the `StrokeManager` to the user. */
    func displayMessage(message: String) {
        messageLabel!.text = message
    }
    
    /**
     * Clear temporary ink in progress. This is invoked by the `StrokeManager` when the temporary ink is
     * sent to the recognizer.
     */
    func clearInk() {
        drawnImage.image = nil
    }
        
        
    /**
     * Draws a line segment from `self.lastPoint` to the current touch point given in the argument
     * to the temporary ink canvas.
     */
    func drawLineSegment(touch: UITouch!) {
        let currentPoint = touch.location(in: drawnImage)
        
        UIGraphicsBeginImageContext(drawnImage.frame.size)
        drawnImage.image?.draw(
            in: CGRect(
                x: 0, y: 0, width: drawnImage.frame.size.width, height: drawnImage.frame.size.height))
        let ctx: CGContext! = UIGraphicsGetCurrentContext()
        ctx.move(to: lastPoint!)
        ctx.addLine(to: currentPoint)
        ctx.setLineCap(CGLineCap.round)
        ctx.setLineWidth(kBrushWidth)
        // Unrecognized strokes are drawn in blue.
        ctx.setStrokeColor(red: 0, green: 0, blue: 1, alpha: 1)
        ctx.setBlendMode(CGBlendMode.normal)
        ctx.strokePath()
        ctx.flush()
        drawnImage.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        lastPoint = currentPoint
    }
}
