//
//  SimpleTransitionViewController.swift
//  Example
//
//  Created by cocoatoucher on 03/08/16.
//  Copyright © 2016 cocoatoucher. All rights reserved.
//

import UIKit
import AICustomViewControllerTransition

class SimpleTransitionViewController: UIViewController {
	
	// Create a transitioning delegate for simple transition
	var customTransitioningDelegate: SimpleTransitioningDelegate = SimpleTransitioningDelegate()
	// Create a view controller to display
	lazy var detailViewController: ModalViewController = {
		let vc = self.storyboard?.instantiateViewController(withIdentifier: "detailViewController") as! ModalViewController
		// Hide indicator when pan to dismiss is enabled
		// See ExpandingCellsTableViewController and PanToViewTransitionViewController examples where this is enabled
		vc.isPanIndicatorHidden = true
		
		vc.modalPresentationStyle = .custom
		vc.transitioningDelegate = self.customTransitioningDelegate
		return vc
	}()
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		// Here only transitionDismiss is provided, modal view controller is dismissed with faded style, while it is presented in cover vertical style
		// Default value is used for transitionPresent defined in AICustomViewControllerTransition
		customTransitioningDelegate.transitionDismiss = { (fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, transitionType: TransitionType, completion: @escaping () -> Void) in
			
			UIView.animate(withDuration: defaultTransitionAnimationDuration, animations: {
				
				fromViewController.view.alpha = 0.0
				
				}, completion: { (finished) in
					completion()
					// Reset value, since we are using a lazy var for viewController
					fromViewController.view.alpha = 1.0
			})
		}
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	@IBAction func presentAction(_ sender: AnyObject) {
		self.present(self.detailViewController, animated: true, completion: nil)
	}

}
