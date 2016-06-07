//
//  RecordParentViewController.swift
//  Home Movies
//
//  Created by Sean Hess on 6/7/16.
//  Copyright © 2016 HomeMoviesDev. All rights reserved.
//

import UIKit

class RecordParentViewController: UIViewController {

    @IBOutlet weak var recordView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .Done, target: nil, action: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        let orientation = UIDevice.currentDevice().orientation
        
        // if the orientation is different from how it was designed, rotate it around without an animation
        // causing it to remain in place while the surrounding view controller rotates
        if orientation == .LandscapeRight {
            self.recordView.transform = CGAffineTransformMakeRotation(CGFloat(M_PI))
        }
        else {
            
            self.recordView.transform = CGAffineTransformIdentity
        }
    }
    
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        // prevent all animations until the transition is complete
        UIView.setAnimationsEnabled(false)
        coordinator.animateAlongsideTransition({ context in
            
            let orientation = UIDevice.currentDevice().orientation
            
            // if the orientation is different from how it was designed, rotate it around without an animation
            // causing it to remain in place while the surrounding view controller rotates
            if orientation == .LandscapeRight {
                self.recordView.transform = CGAffineTransformMakeRotation(CGFloat(M_PI))
            }
            else {
                
                self.recordView.transform = CGAffineTransformIdentity
            }
            
        }, completion: { context in
            
            // turn animations back on
            UIView.setAnimationsEnabled(true)
        })
    }
    
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return [.LandscapeLeft, .LandscapeRight]
    }

}


/*
 
 
        coordinator.animateAlongsideTransition({ context in
        }, completion: { context in
            var currentTransform = self.recordView.transform
            currentTransform.a = round(currentTransform.a)
            currentTransform.b = round(currentTransform.b)
            currentTransform.c = round(currentTransform.c)
            currentTransform.d = round(currentTransform.d)
            self.recordView.transform = currentTransform
        })
 */