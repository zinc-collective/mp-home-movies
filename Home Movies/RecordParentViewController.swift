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
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .done, target: nil, action: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let orientation = UIDevice.current.orientation
        
        // if the orientation is different from how it was designed, rotate it around without an animation
        // causing it to remain in place while the surrounding view controller rotates
        if orientation == .landscapeRight {
            self.recordView.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
        }
        else {
            
            self.recordView.transform = CGAffineTransform.identity
        }
    }
    
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // prevent all animations until the transition is complete
        UIView.setAnimationsEnabled(false)
        coordinator.animate(alongsideTransition: { context in
            
            let orientation = UIDevice.current.orientation
            
            // if the orientation is different from how it was designed, rotate it around without an animation
            // causing it to remain in place while the surrounding view controller rotates
            if orientation == .landscapeRight {
                self.recordView.transform = CGAffineTransform(rotationAngle: CGFloat(Float.pi))
            }
            else {
                
                self.recordView.transform = CGAffineTransform.identity
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
    
    override var shouldAutorotate : Bool {
        return true
    }
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return [.landscapeLeft, .landscapeRight]
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
