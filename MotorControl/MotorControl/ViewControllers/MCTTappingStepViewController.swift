//
//  MCTTappingStepViewController.swift
//  MotorControl
//
//  Copyright © 2015 Apple Inc.
//  Ported to Swift from ResearchKit/ResearchKit 1.5
//
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import UIKit


/// The tapping step view controller sets up gesture listeners that are used to track the button taps.
public class MCTTappingStepViewController: MCTActiveStepViewController {
    
    /// Button in the view on the left.
    @IBOutlet public var leftButton: UIButton!
    
    /// Button in the view on the right.
    @IBOutlet public var rightButton: UIButton!
    
    /// Label for tracking the tapping count.
    @IBOutlet public var tappingCountLabel: UILabel!
    
    /// Label for the "tap count" unit label.
    @IBOutlet public var tappingUnitLabel: UILabel!
    
    /// UIGestureRecognizer for taps outside the buttons.
    var touchDownRecognizer: UIGestureRecognizer!
    
    // Private vars
    private var _samples: [MCTTappingSample] = []
    private var _tappingStart: TimeInterval = 0
    private var _expired: Bool = false
    private var _buttonRect1: CGRect!
    private var _buttonRect2: CGRect!
    private var _viewSize: CGSize!
    private var _hitButtonCount: Int = 0
    private var _lastTappedButton: MCTTappingButtonIdentifier?
    private var _lastSample: [MCTTappingButtonIdentifier: MCTTappingSample] = [:]
    
    /// The number formatter to use to format the count for the count label.
    lazy open var countFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.allowsFloats = false
        numberFormatter.generatesDecimalNumbers = true
        return numberFormatter
    }()
    
    /// Override to fire the timer every 100 milliseconds.
    public override var timerInterval: TimeInterval {
        return 0.1
    }

    /// Override viewDidLoad to setup the touch actions in case they aren't in the nib.
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        // Add the touch down gesture recognizer.
        touchDownRecognizer = UIGestureRecognizer()
        touchDownRecognizer.delegate = self
        self.view.addGestureRecognizer(touchDownRecognizer)
        
        // Add the targets for the left and right buttons.
        if !leftButton.allTargets.contains(self) {
            leftButton.addTarget(self, action: #selector(buttonPressed(_:for:)), for: .touchDown)
            leftButton.addTarget(self, action: #selector(buttonReleased(_:for:)), for: [.touchUpInside, .touchUpOutside])
        }
        if !rightButton.allTargets.contains(self) {
            rightButton.addTarget(self, action: #selector(buttonPressed(_:for:)), for: .touchDown)
            rightButton.addTarget(self, action: #selector(buttonReleased(_:for:)), for: [.touchUpInside, .touchUpOutside])
        }
        
        // Hide the next button to begin with.
        self.nextButton?.isHidden = true
    }

    /// Override view will appear to set the unit label text.
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tappingUnitLabel?.text = Localization.localizedString("TAP_COUNT_LABEL")
        self.nextButton?.alpha = 0
        self._setContinueButtonLabel()
    }
    
    private func _setContinueButtonLabel() {
        let handOrder = self.handOrder() ?? [.right]
        let hand = self.whichHand() ?? .right
        var buttonTitle: String? = nil
        if hand != handOrder.last,
           let otherHand = hand.otherHand {
            buttonTitle = Localization.localizedStringWithFormatKey("TAPPING_CONTINUE_WITH_%@", otherHand.rawValue)
        } else {
            buttonTitle = Localization.localizedString("TAPPING_CONTINUE")
        }
        
        self.nextButton?.setTitle(buttonTitle, for: UIControl.State.normal)
    }
    
    /// Override view did appear to set up the button rects.
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.tappingCountLabel.text = countFormatter.string(from: NSNumber(value: _hitButtonCount))
        _viewSize = self.view.bounds.size
        _buttonRect1 = self.view.convert(leftButton.bounds, from: leftButton)
        _buttonRect2 = self.view.convert(rightButton.bounds, from: rightButton)
    }
    
    open override func setupViews() {
        super.setupViews()
        
        tappingCountLabel?.font = self.designSystem.fontRules.font(for: .largeNumber, compatibleWith: traitCollection)
        tappingUnitLabel?.font = self.designSystem.fontRules.baseFont(for: .largeHeader)  // NOT DYNAMIC
    }

    /// Update the step result associated with this step view controller.
    func updateTappingResult() {
        
        let previousResult = self.stepViewModel.findStepResult()
        
        // Look for an existing tapping result, otherwise create new.
        var tappingResult: MCTTappingResultObject = {
            if let tapResult = previousResult as? MCTTappingResultObject {
                return tapResult
            } else {
                var tapResult = MCTTappingResultObject(identifier: self.step.identifier)
                tapResult.startDate = previousResult?.startDate ?? Date()
                return tapResult
            }
        }()
        
        // update the values.
        tappingResult.endDate = Date()
        tappingResult.buttonRect1 = _buttonRect1
        tappingResult.buttonRect2 = _buttonRect2
        tappingResult.stepViewSize = _viewSize
        tappingResult.samples = _samples
        tappingResult.tapCount = _hitButtonCount
        
        if let collectionResult = previousResult as? RSDCollectionResult {
            // Add the tapping result to the collection result.
            var stepResult = collectionResult
            stepResult.appendInputResults(with: tappingResult)
            self.stepViewModel.taskResult.appendStepHistory(with: stepResult)
        } else {
            // Set the tapping result to the step history.
            self.stepViewModel.taskResult.appendStepHistory(with: tappingResult)
        }
    }
    
    /// Handle the touch down event.
    func receivedTouch(_ touch: UITouch, on button: MCTTappingButtonIdentifier) {
        guard !_expired, _tappingStart != 0, let clock = self.clock else { return }

        // create the sample and add to queue.
        
        let sample = MCTTappingSample(uptime: clock.relativeUptime(to: touch.timestamp),
                                      timestamp: touch.timestamp - _tappingStart,
                                      stepPath: self.stepViewModel.stepPath,
                                      buttonIdentifier: button,
                                      location: touch.location(in: self.view),
                                      duration: 0)
        _samples.append(sample)
        _lastSample[button] = sample
        
        // Update the tap count if the button is *not* the "none" case and either the previous button is nil
        // or the previous button matches this button.
        let nextButton: MCTTappingButtonIdentifier? = {
            if let previousButton = _previousButton {
                return (previousButton == .left) ? .right : .left
            }
            else {
                return (button != .none) ? button : nil
            }
        }()
        if let next = nextButton, next == button {
            _hitButtonCount += 1
            _previousButton = nextButton
        }
        
        self.tappingCountLabel.text = countFormatter.string(from: NSNumber(value: _hitButtonCount))
    }
    private var _previousButton: MCTTappingButtonIdentifier?
    
    /// Handle the touch up event.
    func releaseTouch(_ touch: UITouch, on button: MCTTappingButtonIdentifier) {
        guard !_expired, _tappingStart != 0 else { return }
        
        updateLastSample(touch.timestamp, on: button)
    }
    
    /// Update the sample that is being held as the last sample for each button.
    func updateLastSample(_ timestamp: TimeInterval, on button: MCTTappingButtonIdentifier) {
        guard let lastSample = _lastSample[button],
              let idx = _samples.lastIndex(where: { $0.uptime == lastSample.uptime && $0.buttonIdentifier == button }),
              let clock = self.clock
            else {
                return
        }
        var sample = lastSample
        _lastSample[button] = nil
        sample.duration = clock.relativeUptime(to: timestamp) - sample.uptime
        _samples.replaceSubrange(idx...idx, with: [sample])
    }
    
    override public func timerFinished(_ duration: TimeInterval) {

        // update the results
        _expired = true
        if let startSystemUptime = self.clock?.startSystemUptime {
            let timestamp = startSystemUptime + duration
            updateLastSample(timestamp, on: .left)
            updateLastSample(timestamp, on: .right)
        }
        updateTappingResult()
        
        super.timerFinished(duration)
    }

    // MARK: buttonAction
    
    /// This action should be set up for both the left button and right button for the touch down event. This is
    /// handled automatically in viewDidLoad() if not hooked up in the storyboard or nib.
    @IBAction func buttonPressed( _ button: UIButton, for event: UIEvent) {
        guard let touch = event.touches(for: button)?.first else { return }
        
        // If this is the first tap then start the timer
        if _tappingStart == 0 {
            _hitButtonCount = 0
            _tappingStart = touch.timestamp
            self.clock = RSDClock()
            updateTappingResult()
            start()
        }
        
        // Get which button was tapped.
        let buttonIdentifier: MCTTappingButtonIdentifier = (button == leftButton) ? .left : .right
        
        // Say the word "tap" if accessibility voice is turned on.
        if _lastTappedButton != buttonIdentifier {
            UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: Localization.localizedString("TAP_BUTTON_TITLE"))
        }
        _lastTappedButton = buttonIdentifier
        
        // Record the touch down.
        self.receivedTouch(touch, on: buttonIdentifier)
    }

    /// This action should be set up for both the left button and right button for touch up inside and touch up
    /// outside events. This is handled automatically in viewDidLoad() if not hooked up in the storyboard or
    /// nib.
    @IBAction func buttonReleased( _ button: UIButton, for event: UIEvent) {
        guard let touch = event.touches(for: button)?.first else { return }
        let buttonIdentifier: MCTTappingButtonIdentifier = (button == leftButton) ? .left : .right
        self.releaseTouch(touch, on: buttonIdentifier)
    }
}

extension MCTTappingStepViewController: UIGestureRecognizerDelegate {
    
    /// Listen to the gesture recognizer should receive method and always return false.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        
        // If this is outside the area of either button, then tap should recognize as "none"
        // Note: this assumes that once the view is displayed that the button locations are **not** going to
        // change. View must be set up to handle this. syoung 04/10/2018
        let location = touch.location(in: self.view)
        if touch.phase == .began, !(_buttonRect1.contains(location) || _buttonRect2.contains(location)) {
            self.receivedTouch(touch, on: .none)
        }
    
        // always return false to allow the button touch to recognize.
        return false
    }
}
