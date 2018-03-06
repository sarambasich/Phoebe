//
//  ParticleGenerator.swift
//  Phoebe
//
//  Created by Stefan Arambasich on 12/26/2015.
//
//  Copyright (c) 2015-2018 Stefan Arambasich. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


import Foundation
import UIKit

/// The type for a particle - a typialias for `UIBezierPath`
typealias Particle = UIBezierPath


// MARK: -
// MARK: ParticleGenerator

/// Coordinates with `ParticleFactory` to generate particles on a reoccuring basis.
open class ParticleGenerator {

    /// How many particles to generate at one unit of time; that is, when the next frame is
    /// rendered, it shall contain `parcelSize` particles.
    open var parcelSize = 10

    /// Desired colors of the particles
    open var colors = [UIColor]()

    /// Minimum acceptable radius size
    open var minimumRadius = 1.0

    /// Maximum acceptable radius size
    open var maxRadius = 8.0

    /// A weak reference to the view these particles are generated in
    open weak var view: UIView?


    /// Tells whether the generator is running or not
    public var started: Bool {
        return displayLink != nil
    }

    /// The amount of time to use between generations of new particles
    fileprivate var lastTimestamp: TimeInterval = 0.0

    /// Strong ref to the current display link object to coordinate drawing with screen.
    private var displayLink: CADisplayLink?

    // MARK: -
    // MARK: Methods
    
    /// Starts the generating of particles.
    open func start(with displayLink: CADisplayLink? = nil) {
        self.displayLink = displayLink ?? CADisplayLink(target: self, selector: #selector(update(_:)))
        self.displayLink?.add(to: .current, forMode: .defaultRunLoopMode)
    }
    
    /**`
        Stops the generator from generating more particles.
    */
    open func stop() {
        displayLink?.remove(from: .current, forMode: .defaultRunLoopMode)
        displayLink?.invalidate()
        displayLink = nil
    }

}

private extension ParticleGenerator {

    /// Generates a parcel of particles according to the options.
    ///
    /// - Returns: A collection of particles.
    func makeParcel() -> [Particle] {
        return (0 ..< parcelSize).map { _ in
            let x = CGFloat(arc4random_uniform(UInt32(view?.frame.size.width ?? 0.0))),
                y: CGFloat = 0.0,
                size = CGFloat(arc4random_uniform(UInt32(maxRadius))) + CGFloat(minimumRadius)

            let rect = CGRect(x: x, y: y, width: size, height: size)
            return ParticleFactory.particle(with: rect)
        }
    }

    @objc func update(_ displayLink: CADisplayLink) {
        guard
            displayLink.timestamp - lastTimestamp >= 1.0,
            let view = view else {
                return
        }

        lastTimestamp = displayLink.timestamp
        let particleLayers: [CAShapeLayer] = makeParcel().map {
            let layer = CAShapeLayer()
            layer.contentsGravity = "center"
            layer.frame = CGRect(x: 0.0, y: 0.0, width: maxRadius, height: maxRadius)
            layer.path = $0.cgPath
            layer.fillColor = colors.random?.cgColor ?? UIColor.red.cgColor
            return layer
        }
        _ = particleLayers.map {
            ParticleAnimator.animation(forLayer: $0)
            FrameAnimator.animation(forLayer: $0, in: view.frame)
            view.layer.insertSublayer($0, at: 0)
        }
    }

}


// MARK: -
// MARK: ParticleFactory

/// Creates new particles with configurable options
struct ParticleFactory {

    /// Creates a particle (`UIBezierPath`) with the given rect and color.
    ///
    /// - Parameter rect: The desired rectangle of the particle.
    /// - Returns: The particle's color.
    static func particle(with rect: CGRect) -> Particle {
        return UIBezierPath(ovalIn: rect)
    }

}


// MARK: -
// MARK: ParticleAnimationFactory

/// Puts together animations for a particle.
struct ParticleAnimationFactory {

    /// Returns an animation suitable for a particle.
    ///
    /// - Returns: A `CAAnimation` object represeting a particle's animation.
    static func particleAnimation() -> CAAnimation {
        let animation: CAAnimation
        switch arc4random_uniform(3) {
        default:
            animation = opacityAnimation()
        }
        return animation
    }
    
    /// Creates a repeating opacity fade in and out animation oscillating between a minimum and
    /// a maximum opacity value. This is responsible for the "twinkle"
    /// effect seen on the particles.
    ///
    /// - Parameters:
    ///   - minOpacity: The lowest desirable opacity. Defaults to 0.15.
    ///   - maxOpacity: The highest desirable opacity. Defaults to 0.75.
    /// - Returns: A `CAAnimation` object representing the "twinkle" animation.
    static func opacityAnimation(minOpacity: CGFloat = 0.15, maxOpacity: CGFloat = 0.75) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.beginTime = CACurrentMediaTime() + 1.0 / (CFTimeInterval(arc4random_uniform(5)) * 0.5)
        animation.fromValue = 0.15
        animation.toValue = 0.75
        animation.duration = max(0.3, CFTimeInterval(arc4random_uniform(50) / 10)) // TODO: Add customization
        animation.autoreverses = true
        animation.repeatCount = Float(CGFloat.greatestFiniteMagnitude)
        return animation
    }

}


// MARK: -
// MARK: ParticleAnimator

/// Creates animations for the particles themselves.
struct ParticleAnimator {

    static func animation(forLayer layer: CALayer) {
        layer.add(ParticleAnimationFactory.particleAnimation(), forKey: "particle.animations")
    }

}


// MARK: -
// MARK: FrameAnimator

/// Creates animations for particles in frame.
struct FrameAnimator {

    /// Creates a translation animation that moves the particles upwards along the y-axis of the
    /// parent view. Applies this animation to the layer.
    ///
    /// - Parameters:
    ///   - layer: The layer to create an animation on.
    ///   - rect: The frame in which the animation should be valid.
    static func animation(forLayer layer: CALayer, in rect: CGRect) {
        @objc class AnimationDelegate: NSObject, CAAnimationDelegate {

            private weak var layer: CALayer?

            init(layer: CALayer) {
                self.layer = layer

                super.init()
            }
            
            func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
                layer?.removeFromSuperlayer()
            }
        }

        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.transform))
        animation.valueFunction = CAValueFunction(name: kCAValueFunctionTranslateY)
        animation.fromValue = rect.size.height + (layer.frame.size.height * (1.0 + CGFloat(arc4random_uniform(10)) / 10.0))
        animation.toValue = -layer.frame.size.height
        animation.duration = CFTimeInterval(arc4random_uniform(200) + 60) / 10.0 // TODO: Allow customization

        let animationDelegate = AnimationDelegate(layer: layer)
        animation.delegate = animationDelegate
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        
        layer.add(animation, forKey: "particle.translation")
    }

}


// MARK: -
// MARK: Extensions

private extension Array {

    /// Find random element in array or nil
    var random: Array.Element? {
        return count > 0 ? self[Int(arc4random_uniform(UInt32(count)))] : nil
    }

}
