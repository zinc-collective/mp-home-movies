//
//  TitleViewController.swift
//  Home Movies
//
//  Created by Sean Hess on 6/3/16.
//  Copyright © 2016 HomeMoviesDev. All rights reserved.
//

import UIKit

class TitleViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var textField: UITextField!
    @IBOutlet var nextItem: UIBarButtonItem!
    
    @IBOutlet weak var noTitleButton: UIButton!
    
    // I have to pass this forward because the old design was bad
    var videoView:VideoView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .Done, target: nil, action: nil)

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        
        if let str = textField.text {
            nextItem.enabled = str.characters.count > 0
        }
        else {
            nextItem.enabled = false
        }
        noTitleButton.enabled = !nextItem.enabled
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        // remove this view controller from the stack
        if let nav = self.navigationController {
            let vcs = nav.viewControllers.filter {(vc) in
                return (vc as? TitleViewController) == nil
            }
            
            self.navigationController?.setViewControllers(vcs, animated: false)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func tappedNoTitle(sender: AnyObject) {
        nextPlayer(nil)
    }
    
    @IBAction func tappedAddTitle(sender: AnyObject) {
        nextPlayer(textField.text)
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        var str : NSString = ""
        if let old = textField.text {
            str = old as NSString
        }
        
        let newString = str.stringByReplacingCharactersInRange(range, withString: string)
        
        if (newString.characters.count > 40) {
            self.navigationItem.prompt = "Title too long. Maximum 40 characters."
            return false
        }
        else {
            self.navigationItem.prompt = nil
        }
        
        nextItem.enabled = (newString.characters.count > 0)
        noTitleButton.enabled = !nextItem.enabled
        
        return true
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldShouldClear(textField: UITextField) -> Bool {
        nextItem.enabled = false
        noTitleButton.enabled = true
        return true
    }
    
    func nextPlayer(movieTitle:String?) {
        self.performSegueWithIdentifier("VideoPlayerController", sender: movieTitle)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let videoPlayer = segue.destinationViewController as? VideoPlayerController {
            let movieTitle = sender as? String
            videoPlayer.movieTitle = movieTitle
            videoPlayer.videoView = videoView
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
