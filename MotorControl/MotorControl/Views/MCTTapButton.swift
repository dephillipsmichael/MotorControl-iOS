//
//  MCTTapButton.swift
//  MotorControl
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

import Foundation

@IBDesignable public final class MCTTapButton : UIButton, RSDViewDesignable {

    /// Override layout subviews to draw a rounded button with a white border around it.
    override public func layoutSubviews() {
        super.layoutSubviews()
        layer.borderWidth = 4
        layer.borderColor = UIColor.white.cgColor
        layer.cornerRadius = self.bounds.height / 2.0
    }
    
    /// Override initializer to set the title to the localized button title.
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    /// Override initializer to set the title to the localized button title.
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    /// Performs the operations common to all initializers of this class.
    /// Default localizes the button's title.
    private func commonInit() {
        let title = Localization.localizedString("TAP_BUTTON_TITLE")
        self.setTitle(title, for: UIControl.State.normal)
        updateColors()
    }
    
    public private(set) var backgroundColorTile: RSDColorTile?
    
    public private(set) var designSystem: RSDDesignSystem?
    
    public func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        self.designSystem = designSystem
        self.backgroundColorTile = background
        updateColors()
    }
    
    func updateColors() {
        let designSystem = self.designSystem ?? RSDDesignSystem()
        let colorTile = designSystem.colorRules.palette.secondary.normal
        self.backgroundColor = colorTile.color
        
        // Set the title color for each of the states used by this button
        let states: [RSDControlState] = [.normal, .highlighted, .disabled]
        states.forEach {
            let titleColor = designSystem.colorRules.roundedButtonText(on: colorTile, with: .primary, forState: $0)
            setTitleColor(titleColor, for: $0.controlState)
        }
        
        // Set the title font to the font for a rounded button.
        titleLabel?.font = designSystem.fontRules.buttonFont(for: .primary, state: .normal)
    }
}
