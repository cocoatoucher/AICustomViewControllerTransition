//
//  AICustomViewControllerTransition.swift
//  AICustomViewControllerTransition
//
//  Created by cocoatoucher on 09/07/16.
//  Copyright © 2016 cocoatoucher. All rights reserved.
//

import UIKit

/**
	Transition type
	Whether the transition is Simple or Interactive, and additional information if interactive
*/
public enum TransitionType {
	/** 
		Non-interactive transition
	*/
	case Simple
	/**
		Interactive transition
		- parameter isCancelled: true if transition is cancelled, false if transition is finished
		- parameter lastPercentage: last percentage value of the transition when it is cancelled or finished
	*/
	case Interactive(isCancelled: Bool, lastPercentage: CGFloat)
	
	/**
		Handy var for interactive transtion cancelled status
		true or false if the transition is interactive
		nil if the transition is simple
	*/
	public var isInteractiveTransitionCancelled: Bool? {
		if case let .Interactive(isCancelled, _) = self {
			return isCancelled
		}
		return nil
	}
	
	/**
		Handy var for last percentage of the interactive transition
		nil if the transition is simple
		non-nil if the transition is interactive
	*/
	public var lastPercentage: CGFloat? {
		if case let .Interactive(_, lastPercentage) = self {
			return lastPercentage
		}
		return nil
	}
	
}

/**
	Transition handling closure

	- parameter fromViewController: Currently visible view controller
	- parameter toViewController: View controller to be displayed after the transition
	- parameter containerView: Transition view which will contain both fromViewController and toViewController's views. Place any temporary animated views on this view. During the animation, fromViewController and toViewController's views are subviews of containerView.
	- parameter transitionType: Whether the transition is Simple or Interactive, and additional information if interactive
	- parameter completion: This closure should be called at the end of your transition animation to finalize the transition
*/
public typealias TransitionViewController = ((fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, transitionType: TransitionType, completion: () -> Void) -> Void)

/**
	Interactive transition percentage handling closure

	- parameter fromViewController: Currently visible view controller
	- parameter toViewController: View controller to display
	- parameter percentage: Percentage of the transition phase. This will reflect the percentage value provided via updateInteractiveTransition(_:) of InteractiveTransitioningDelegate class
	- parameter containerView: Transition view which will contain both fromViewController and toViewController's views. Place any temporary animated views on this view
*/
public typealias PercentTransitionViewController = ((fromViewController: UIViewController, toViewController: UIViewController, percentage: CGFloat, containerView: UIView) -> Void)

/**
	Animation duration used within default transition animation closure values
*/
public let defaultTransitionAnimationDuration: NSTimeInterval = 0.3
/**
	Maximum percentage value used for percent driven interactive transition
*/
public let maximumInteractiveTransitionPercentage: CGFloat = 1.0
/**
	Minimum percentage value used for percent driven interactive transition
*/
public let minimumTransitionPercentage: CGFloat = 0.0

/**
	Transition directions
*/
private enum TransitionDirection {
	/**
		No transition
	*/
	case None
	/**
		Transitioning delegate is presenting a view controller
	*/
	case Presenting
	/**
		Transitioning delegate is dismissing a view controller
	*/
	case Dismissing
}

//MARK: - TransitionState
/**
	Transition states
*/
private enum TransitionState {
	/**
		No transition state
	*/
	case None
	/**
		Interactive transition has started either presenting or dismissing which can either be interactive or simple
		- parameter transitionType: Whether the transition is Simple or Interactive, and additional information if interactive
	*/
	case Start(transitionType: TransitionType)
	/**
		State of an interactive transition, either presentation or dismissal, is changing percentage
		- parameter currentPercentage: Current percentage of interactive transition phase
	*/
	case InteractivePercentage(currentPercentage: CGFloat)
	/**
		Interactive transition has completed either presenting or dismissing which can either be interactive or simple
		- parameter transitionType: Whether the transition is Simple or Interactive, and additional information if interactive
	*/
	case Finish(transitionType: TransitionType)
	/**
		Interactive transition has cancelled either presenting or dismissing a view controller in an interactive way
		- parameter lastPercentage: Last percentage value of transition phase when the interactive transition is cancelled
	*/
	case CancelInteractive(lastPercentage: CGFloat)
	
	/**
		Handy var to get whether the transition state is none
	*/
	var isNone: Bool {
		if case .None = self {
			return true
		}
		return false
	}
	
	/**
		Handy var to get whether the transition type is interactive
	*/
	var isInteractive: Bool {
		switch self {
		case .Start(let transitionType):
			if case .Interactive = transitionType {
				return true
			}
			return false
		case .InteractivePercentage:
			return true
		case .Finish(let transitionType):
			if case .Interactive = transitionType {
				return true
			}
			return false
		case .CancelInteractive(_):
			return true
		default:
			return false
		}
	}
	
	/**
		Handy var to get the percentage value of the transition state
		nil if the transition is Simple
	*/
	var percentage: CGFloat? {
		switch self {
		case .Start(let transitionType):
			switch transitionType {
			case .Interactive(_, let lastPercentage):
				return lastPercentage
			default:
				return nil
			}
		case .InteractivePercentage(let currentPercentage):
			return currentPercentage
		case .Finish(let transitionType):
			switch transitionType {
			case .Interactive(_, let lastPercentage):
				return lastPercentage
			default:
				return nil
			}
		case .CancelInteractive(let lastPercentage):
			return lastPercentage
		default:
			return nil
		}
	}
	
	/**
		A transition state is considered percent driven in two cases
		1. Transition has started interactively, with percentage 0
		2. Transition is progressing with changing percentage in interactive state
	*/
	var isPercentDriven: Bool {
		switch self {
		case .Start(let transitionType):
			if case .Interactive = transitionType {
				return true
			}
			return false
		case .InteractivePercentage:
			return true
		default:
			return false
		}
	}
	
	/**
		Handy var to get whether the transition has started
	*/
	var didTransitionStart: Bool {
		if case .Start = self {
			return true
		}
		return false
	}
	
	/**
		Handy var to get whether the transition has ended
	*/
	var didTransitionEnd: Bool {
		switch self {
		case .Finish, .CancelInteractive:
			return true
		default:
			return false
		}
	}
	
	/**
		Handy var to get whether the transition has cancelled
	*/
	var isInteractiveTransitionCancelled: Bool {
		if case .CancelInteractive = self {
			return true
		}
		return false
	}
}

//MARK: - ViewControllerTransitionHelper
/**
	Helper class which implements UIViewControllerAnimatedTransitioning
*/
private class ViewControllerTransitionHelper : NSObject,  UIViewControllerAnimatedTransitioning {
	
	/**
		Default closure for handling prensentation transition animation with similar transition to iOS cover vertical transition style.
		This will be overriden by the user of the owner class, SimpleTransitioningDelegate or InteractiveTransitioningDelegate for custom animation.
	*/
	var transitionPresent: TransitionViewController = {(fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, transitionType: TransitionType, completion: () -> Void) in
		
		if case .Interactive = transitionType {
			// Set initial frame only if the transition is not interactive
			let beginFrame = CGRectOffset(containerView.bounds, 0, CGRectGetHeight(containerView.bounds))
			toViewController.view.frame = beginFrame
		}
		
		let endFrame: CGRect = containerView.bounds
		
		UIView.animateWithDuration(defaultTransitionAnimationDuration, animations: {
			toViewController.view.frame = endFrame
			}, completion: { (finished) in
				completion()
		})
	}
	/**
		Default closure for handling dismiss transition animation with similar transition to iOS cover vertical transition style.
		This will be overriden by the user of the owner class, SimpleTransitioningDelegate or InteractiveTransitioningDelegate for custom animation.
	*/
	var transitionDismiss: TransitionViewController = {(fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, transitionType: TransitionType, completion: () -> Void) in
		
		let endFrame = CGRectOffset(containerView.bounds, 0, CGRectGetHeight(containerView.bounds))
		
		UIView.animateWithDuration(defaultTransitionAnimationDuration, animations: {
			fromViewController.view.frame = endFrame
			}, completion: { (finished) in
				completion()
		})
	}
	/**
		Default closure for handling presentation transition percentage change.
		This will be overriden by the user of the owner class, InteractiveTransitioningDelegate for custom animation.
	*/
	var transitionPercentPresent: PercentTransitionViewController? = {(fromViewController: UIViewController, toViewController: UIViewController, percentage: CGFloat, containerView: UIView) in
		
		let endFrame = CGRectOffset(containerView.bounds, 0, CGRectGetHeight(containerView.bounds) * (maximumInteractiveTransitionPercentage - percentage))
		toViewController.view.frame = endFrame
	}
	/**
		Default closure for handling dismissal transition percentage change.
		This will be overriden by the user of the owner class, InteractiveTransitioningDelegate for custom animation.
	*/
	var transitionPercentDismiss: PercentTransitionViewController? = {(fromViewController: UIViewController, toViewController: UIViewController, percentage: CGFloat, containerView: UIView) in
		
		let endFrame = CGRectOffset(containerView.bounds, 0, CGRectGetHeight(containerView.bounds) * percentage)
		fromViewController.view.frame = endFrame
	}
	
	/**
		Current direction of the transition, default is no transition
	*/
	var transitionDirection: TransitionDirection = .None
	/**
		Transition context provided by either simple or interactive transitioning delegate
	*/
	var transitionContext: UIViewControllerContextTransitioning?
	
	/**
		Handles placing transitioning view controllers' views in transitionContext's containerView and performing the actual animation using transitionPresent, transitionDismiss, transitionPercentPresent and transitionPercentDismiss depending on the transitionState using the current transitionDirection.
	*/
	var transitionState: TransitionState = .None {
		didSet {
			
			guard !self.transitionState.isNone else {
				return
			}
			
			guard let transitionContext = self.transitionContext else {
				// Shouldn't be a case where transitionContext is nil
				return
			}
			
			let containerView = transitionContext.containerView()!
			
			// Making transitionState conditions more readable with these booleans
			let didTransitionStart = self.transitionState.didTransitionStart
			let isPercentDriven = self.transitionState.isPercentDriven
			let didTransitionEnd = self.transitionState.didTransitionEnd
			let isInteractiveTransitionCancelled = self.transitionState.isInteractiveTransitionCancelled
			let isInteractive = self.transitionState.isInteractive
			let percentage = self.transitionState.percentage
			
			let fromViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)!
			let toViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!
			
			// Place transitioning view controllers' views in containerView
			switch self.transitionDirection {
			case .Presenting:
				if didTransitionStart {
					containerView.addSubview(fromViewController.view)
					containerView.addSubview(toViewController.view)
				} else if didTransitionEnd && !isInteractive {
					containerView.addSubview(toViewController.view)
				}
			case .Dismissing:
				if didTransitionStart {
					
					// Setting presenting view controller's frame as containerView bounds. This helps with fixing misalignment if the containerView bounds changed after the initial transition, e.g. with in-call status bar.
					toViewController.view.frame = containerView.bounds
					
					if !isInteractive {
						containerView.insertSubview(toViewController.view, atIndex: 0)
					} else {
						containerView.insertSubview(toViewController.view, atIndex: 0)
						containerView.addSubview(fromViewController.view)
					}
				}
			default:
				break
			}
			
			// Presenting view controller's user interaction should be disabled during transition to prevent possible colliding interaction
			fromViewController.view.userInteractionEnabled = false
			
			// This closure is to be called at the end of provided transitionPresent and transitionDismiss callback closures
			let completion = {
				if transitionContext.transitionWasCancelled() {
					if isInteractive {
						transitionContext.cancelInteractiveTransition()
					}
					
					transitionContext.completeTransition(false)
					
					fromViewController.view.frame = containerView.frame
					UIApplication.sharedApplication().keyWindow?.addSubview(fromViewController.view)
				} else {
					if isInteractive {
						transitionContext.finishInteractiveTransition()
					}
					
					transitionContext.completeTransition(true)
					
					toViewController.view.frame = containerView.frame
					UIApplication.sharedApplication().keyWindow?.addSubview(toViewController.view)
				}
				
				fromViewController.view.userInteractionEnabled = true
				
				// Cleaning up
				self.transitionDirection = .None
				self.transitionContext = nil
				self.transitionState = .None
			}
			
			if (!isPercentDriven) {
				var animatePresenting = self.transitionDirection == .Presenting
				var reverseFromAndToViewControllers = false
				
				if (isInteractiveTransitionCancelled) {
					reverseFromAndToViewControllers = true
					
					switch self.transitionDirection {
					case .Presenting:
						animatePresenting = false
					case .Dismissing:
						animatePresenting = true
					default:
						break
					}
				}
				
				let reversedFromViewController = (reverseFromAndToViewControllers) ? toViewController : fromViewController
				let reversedToViewController = (reverseFromAndToViewControllers) ? fromViewController : toViewController
				
				let transitionType: TransitionType = (isInteractive) ? .Interactive(isCancelled: isInteractiveTransitionCancelled, lastPercentage: percentage!) : .Simple
				
				if animatePresenting {
					self.transitionPresent(fromViewController: reversedFromViewController, toViewController: reversedToViewController, containerView: containerView, transitionType: transitionType, completion: completion)
				} else {
					self.transitionDismiss(fromViewController: reversedFromViewController, toViewController: reversedToViewController, containerView: containerView, transitionType: transitionType, completion: completion)
				}
			} else {
				switch self.transitionDirection {
				case .Presenting:
					self.transitionPercentPresent?(fromViewController: fromViewController, toViewController: toViewController, percentage: percentage!, containerView: containerView)
				case .Dismissing:
					self.transitionPercentDismiss?(fromViewController: fromViewController, toViewController: toViewController, percentage: percentage!, containerView: containerView)
				default:
					break
				}
				
				// Because there is no completion for percent driven callbacks, user interaction is enabled after each callback execution
				fromViewController.view.userInteractionEnabled = true
			}
		}
	}
	
	//MARK: UIViewControllerAnimatedTransitioning
	/**
		This is ignored, since the actual transition duration is specified in transition callback closures provided by transitioningDelegate classes
	*/
	@objc private func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
		return 0.0
	}
	
	/**
		This is used by SimpleTransitioningDelegate as in the protocol implementation. On the other hand, setting transitionContext and calling setTransitionState is manually handled by InteractiveTransitioningDelegate.
	*/
	@objc private func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
		
		guard !transitionContext.isInteractive() else {
			return
		}
		
		self.transitionContext = transitionContext
		switch self.transitionDirection {
		case .Presenting:
			self.transitionState = .Finish(transitionType: .Simple)
		case .Dismissing:
			self.transitionState = .Start(transitionType: .Simple)
		default:
			break
		}
	}
	
}

//MARK: - SimpleTransitioningDelegate
/**
	SimpleTransitioningDelegate
	Use for simple view controller transitions that doesn't require user interaction driven transition by providing your animation blocks with its callback closure properties.
	Implements UIViewControllerTransitioningDelegate
*/
public class SimpleTransitioningDelegate : NSObject, UIViewControllerTransitioningDelegate {
	
	/**
		Whether the modal view controller is being presented or not
	*/
	public var isPresenting: Bool {
		return self.transitionHelper.transitionDirection == .Presenting
	}
	
	/**
		Whether the modal view controller is being dismissed or not
	*/
	public var isDismissing: Bool {
		return self.transitionHelper.transitionDirection == .Dismissing
	}
	
	/**
		Callback closure for handling prensentation transition animation. Default value is similar transition to iOS cover vertical transition style.
	*/
	public var transitionPresent: TransitionViewController {
		get {
			return self.transitionHelper.transitionPresent
		}
		set {
			self.transitionHelper.transitionPresent = newValue
		}
	}
	/**
		Callback closure for handling dismiss transition animation. Default value is similar transition to iOS cover vertical transition style.
	*/
	public var transitionDismiss: TransitionViewController {
		get {
			return self.transitionHelper.transitionDismiss
		}
		set {
			self.transitionHelper.transitionDismiss = newValue
		}
	}
	
	/**
		UIViewControllerAnimatedTransitioning helper
	*/
	private let transitionHelper: ViewControllerTransitionHelper = ViewControllerTransitionHelper()
	
	//MARK: UIViewControllerTransitioningDelegate
	/**
		This method shouldn't be called
	*/
	public func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		self.transitionHelper.transitionDirection = .Presenting
		return self.transitionHelper
	}
	/**
		This method shouldn't be called
	*/
	public func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		self.transitionHelper.transitionDirection = .Dismissing
		return self.transitionHelper
	}
}

//MARK: - InteractiveTransitioningDelegate
/**
	InteractiveTransitioningDelegate
	Use for user interaction driven transitions by providing your animation blocks with its callback closure properties.
	Subclasses UIPercentDrivenInteractiveTransition
	Implements UIViewControllerTransitioningDelegate
*/
public class InteractiveTransitioningDelegate : UIPercentDrivenInteractiveTransition, UIViewControllerTransitioningDelegate {
	
	/**
		Whether the modal view controller is being presented or not
	*/
	public var isPresenting: Bool {
		return self.transitionHelper.transitionDirection == .Presenting
	}
	
	/**
		Whether the modal view controller is being dismissed or not
	*/
	public var isDismissing: Bool {
		return self.transitionHelper.transitionDirection == .Dismissing
	}
	
	/**
		Callback closure for handling prensentation transition animation. Default value is similar transition to iOS cover vertical transition style.
	*/
	public var transitionPresent: TransitionViewController {
		get {
			return self.transitionHelper.transitionPresent
		}
		set {
			self.transitionHelper.transitionPresent = newValue
		}
	}
	
	/**
		Callback closure for handling dismiss transition animation. Default value is similar transition to iOS cover vertical transition style.
	*/
	public var transitionDismiss: TransitionViewController {
		get {
			return self.transitionHelper.transitionDismiss
		}
		set {
			self.transitionHelper.transitionDismiss = newValue
		}
	}
	
	/**
		Callback function for handling interactive presentation transition
	*/
	public var transitionPercentPresent: PercentTransitionViewController? {
		get {
			return self.transitionHelper.transitionPercentPresent
		}
		set {
			self.transitionHelper.transitionPercentPresent = newValue
		}
	}
	
	/**
		Callback function for handling interactive dismissal transition
	*/
	public var transitionPercentDismiss: PercentTransitionViewController? {
		get {
			return self.transitionHelper.transitionPercentDismiss
		}
		set {
			self.transitionHelper.transitionPercentDismiss = newValue
		}
	}
	
	/**
		UIViewControllerAnimatedTransitioning helper
	*/
	private let transitionHelper: ViewControllerTransitionHelper = ViewControllerTransitionHelper()
	
	/**
		Internal flag to keep track of interactive state before a transitionContext is created
	*/
	private var isInteractiveTransition: Bool = false
	
	/**
		Starts presenting the modal view controller in a percent driven way.
		Call this method to get provided transitionPercentPresent method called with current percentage while presenting. Percentage will be provided via calling updateInteractiveTransition(percentComplete) method.
	
		- parameter viewController: Modal view controller to present
		- parameter fromViewController: Parent view controller
	*/
	public func beginPresenting(viewController viewController: UIViewController, fromViewController: UIViewController) {
		
		// Prevent executing duplicate calls
		if (self.transitionHelper.transitionContext != nil && self.transitionHelper.transitionContext!.isInteractive()) {
			return
		}
		
		// Flag to mark that the modal view controller is going to be presented in a percent driven way
		self.isInteractiveTransition = true
		
		// Present the modal view controller in the regular way
		fromViewController.presentViewController(viewController, animated: true, completion: nil)
	}
	
	/**
		Starts dismissing the modal view controller in a percent driven way.
		Call this method to get provided transitionPercentDismiss method called with current percentage while presenting. Percentage will be provided via calling updateInteractiveTransition(percentComplete) method.
	
		- parameter viewController: Modal view controller to dismiss
	*/
	public func beginDismissing(viewController viewController: UIViewController) {
		
		// Prevent executing duplicate calls
		if (self.transitionHelper.transitionContext != nil && self.transitionHelper.transitionContext!.isInteractive()) {
			return
		}
		
		// Flag to mark that the modal view controller is going to be dismissed in a percent driven way
		self.isInteractiveTransition = true
		
		// Dismiss the modal view controller in the regular way
		viewController.dismissViewControllerAnimated(true, completion: nil)
	}
	
	/**
		Call this method to finalize after presenting or dismissing the view controller in a percent driven way.
	
		- parameter finished: true if the transtion is completed(e.g. interactively changed percentage exceeded the required threshold to present the view controller), false if the the transition is cancelled
	*/
	public func finalizeInteractiveTransition(isTransitionCompleted completed: Bool) {
		if completed {
			self.finishInteractiveTransition()
		} else {
			self.cancelInteractiveTransition()
		}
	}
	
	//MARK: UIViewControllerTransitioningDelegate
	/**
		This method shouldn't be called
	*/
	public func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		
		if self.isInteractiveTransition {
			// If an interactive transition already started, return the transition helper
			return self.transitionHelper
		}
		
		if self.transitionHelper.transitionDirection != .Presenting {
			// Starting animated(non-percent driven) presentation
			self.transitionHelper.transitionDirection = .Presenting
			return self.transitionHelper
		}
		
		return nil
	}
	
	/**
		This method shouldn't be called
	*/
	public func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		
		if self.isInteractiveTransition {
			// If an interactive transition already started, return the transition helper
			return self.transitionHelper
		}
		
		if self.transitionHelper.transitionDirection != .Dismissing {
			// Starting animated(non-percent driven) dismissal
			self.transitionHelper.transitionDirection = .Dismissing
			return self.transitionHelper
		}
		
		return nil
	}
	
	/**
		This method shouldn't be called
	*/
	public func interactionControllerForPresentation(animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
		
		if self.transitionHelper.transitionDirection != .Presenting {
			// Mark the transition state while beginning an interactive presentation
			self.transitionHelper.transitionDirection = .Presenting
			return self
		}
		
		return nil
	}
	
	/**
		This method shouldn't be called
	*/
	public func interactionControllerForDismissal(animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
		
		if self.transitionHelper.transitionDirection != .Dismissing {
			// Mark the transition state while beginning an interactive dismissal
			self.transitionHelper.transitionDirection = .Dismissing
			return self
		}
		
		return nil
	}
	
	//MARK: UIPercentDrivenInteractiveTransition
	/**
		This method shouldn't be called
	*/
	public override func startInteractiveTransition(transitionContext: UIViewControllerContextTransitioning) {
		
		// Initialize the transitionContext of transitionHelper
		self.transitionHelper.transitionContext = transitionContext
		
		self.transitionHelper.transitionState = .Start(transitionType: .Interactive(isCancelled: false, lastPercentage: 0))
	}
	
	/**
		Call this method in order to update percentage of presentation or dismissal
	*/
	public override func updateInteractiveTransition(percentComplete: CGFloat) {
		super.updateInteractiveTransition(percentComplete)
		
		self.transitionHelper.transitionState = .InteractivePercentage(currentPercentage: percentComplete)
	}
	
	/**
		This method shouldn't be called
	*/
	public override func finishInteractiveTransition() {
		// End interactive transition state
		// Because the transition has ended, isInteractiveTransition flag can be marked false
		self.isInteractiveTransition = false
		self.transitionHelper.transitionState = .Finish(transitionType: .Interactive(isCancelled: false, lastPercentage: self.percentComplete))
		
		super.finishInteractiveTransition()
	}
	
	/**
		This method shouldn't be called
	*/
	public override func cancelInteractiveTransition() {
		// End interactive transition state
		// Because the transition has ended, isInteractiveTransition flag can be marked false
		self.isInteractiveTransition = false
		self.transitionHelper.transitionState = .CancelInteractive(lastPercentage: self.percentComplete)
		
		super.cancelInteractiveTransition()
	}
	
}
