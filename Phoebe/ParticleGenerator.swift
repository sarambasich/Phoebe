//
//  ParticleGenerator.swift
//  Phoebe
//
//  Created by Stefan Arambasich on 12/26/2015.
//
//  Copyright (c) 2015-2016 Stefan Arambasich. All rights reserved.
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

/// The type for a particle (typealias)
typealias Particle = UIBezierPath

/**
    Coordinates with `ParticleFactory` to generate particles on a 
    reoccuring basis.
*/
open class ParticleGenerator {

    /// How many particles to generate at one unit (parcel) of time;
    /// that is to say when the next frame is rendered, it shall contain 
    /// `parcelSize` particles
    open var parcelSize = 10
    /// Desired colors of the particles
    open var colors = [UIColor]()
    /// Minimum acceptable radius size
    open var minimumRadius = 1.0
    /// Minimum acceptable radius size
    open var maxRadius = 8.0
    /// The view these particles are generated in
    open weak var view: UIView?
    
    /// Tells whether the generator is running or not
    public var started: Bool {
        return displayLink != nil
    }

    public init() { }

    fileprivate var lastTimestamp: CFTimeInterval = 0.0
    
    
    /// Strong ref to displaylink to coordinate drawing with screen
    fileprivate var displayLink: CADisplayLink?
    
    /**
        Start the generating of particles.
    */
    open func start() {
        displayLink = CADisplayLink(target: self, selector: #selector(ParticleGenerator.update(_:)))
        displayLink?.add(to: RunLoop.current, forMode: .commonModes)
    }
    
    /**
        Stops the generator from generating more particles.
    */
    open func stop() {
        displayLink?.remove(from: RunLoop.current, forMode: .commonModes)
        displayLink?.invalidate()
        displayLink = nil
    }
}

extension ParticleGenerator {

    /**
        Generates a parcel of particles accordinng to the options.
     
        - returns: A collection of particles.
    */
    fileprivate func makeParcel() -> [Particle] {
        var result = [Particle]()
        for _ in 0 ..< parcelSize {
            let x = CGFloat(arc4random_uniform(UInt32(view?.frame.size.width ?? 0.0))),
                y = CGFloat(arc4random_uniform(UInt32(maxRadius))),
                size = CGFloat(arc4random_uniform(UInt32(self.maxRadius))) + CGFloat(self.minimumRadius),
                rect = CGRect(x: x, y: y, width: size, height: size)
            
            result.append(ParticleFactory.particleWithRect(rect))
        }
        return result
    }
    
    @objc func update(_ displayLink: CADisplayLink) {
        if displayLink.timestamp - lastTimestamp >= 1.0 {
            lastTimestamp = displayLink.timestamp
            
            let particleLayers: [CAShapeLayer] = makeParcel().map {
                let l = CAShapeLayer()
                l.contentsGravity = "center"
                l.frame = CGRect(x: 0.0, y: 0.0, width: maxRadius, height: maxRadius)
                l.path = $0.cgPath
                l.fillColor = colors.random?.cgColor ?? UIColor.red.cgColor
                return l
            }
            _ = particleLayers.map {
                ParticleAnimator.animationForLayer($0)
                FrameAnimator.animationForLayer($0, inRect: view!.frame)
                view?.layer.insertSublayer($0, at: 0)
            }
        }
    }
}

/**
    Creates new particles with configurable options
*/
struct ParticleFactory {

    /**
        Creates a particle (`UIBezierPath`) with the given rect and color.
     
        - parameter rect: The desired rectangle of the particle.
        - parameter color: The particle's color
     
        - returns: A particle according to the parameters.
    */
    static func particleWithRect(_ rect: CGRect) -> Particle {
        return UIBezierPath(ovalIn: rect)
    }
}

/**
    Puts together animations for a particle
*/
struct ParticleAnimationFactory {

    static func particleAnimation(_ rect: CGRect) -> CAAnimation {
        let animation: CAAnimation
        switch arc4random_uniform(3) {
        default:
            animation = opacityAnimation()
        }
        return animation
    }
    
    fileprivate static func opacityAnimation(_ minOpacity: CGFloat = 0.15, maxOpacity: CGFloat = 0.75) -> CAAnimation {
        let a = CABasicAnimation(keyPath: "opacity")
        a.beginTime = CACurrentMediaTime() + 1.0 / CFTimeInterval(arc4random_uniform(5))
        a.fromValue = minOpacity
        a.toValue = maxOpacity
        a.duration = max(0.3, CFTimeInterval(arc4random_uniform(50) / 10))
        a.autoreverses = true
        a.repeatCount = Float(CGFloat.greatestFiniteMagnitude)
        return a
    }
}

/**
    Creates animations for particles selves.
*/
struct ParticleAnimator {

    static func animationForLayer(_ layer: CALayer) {
        let a = ParticleAnimationFactory.particleAnimation(layer.frame)
//        layer.opacity = 0.0
        layer.add(a, forKey: "particle.animations")
    }
}

/**
    Creates animations for particles in frame.
*/
struct FrameAnimator {

    static func animationForLayer(_ layer: CALayer, inRect rect: CGRect) {
        @objc class Responder: NSObject, CAAnimationDelegate {
            fileprivate weak var layer: CALayer?
            
            fileprivate func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
                layer?.removeFromSuperlayer()
            }
        }
        let a = CABasicAnimation(keyPath: "transform.translation.y")
        a.fromValue = rect.size.height + 44.0
        a.toValue = 0.0
        a.duration = CFTimeInterval(arc4random_uniform(200) + 60) / 10.0
        a.isRemovedOnCompletion = true
        let r = Responder()
        r.layer = layer
        a.delegate = r
        a.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        
        layer.add(a, forKey: "particle.translation")
    }
}

private extension Array {

    /// Find random element in array or nil
    var random: Array.Element? {
        return count > 0 ? self[Int(arc4random_uniform(UInt32(count)))] : nil
    }
}
