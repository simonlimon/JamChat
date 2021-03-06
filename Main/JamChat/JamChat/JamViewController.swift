//
//  JamViewController.swift
//  JamChat
//
//  Created by Simon Posada Fishman on 7/14/16.
//  Copyright © 2016 Jammers. All rights reserved.
//

import UIKit
import KTCenterFlowLayout
import FDWaveformView
import AudioKit
import CircleMenu
import NVActivityIndicatorView
import BAPulseView
import AVFoundation

class JamViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UIGestureRecognizerDelegate, CircleMenuDelegate {
    
    var jam: Jam!
    var users: [User] = []
    var tempoTimer = NSTimer()
    var countdown = 4
    var inKeyboard: Bool = true
    var inMicrophone: Bool = false
    var inLoop: Bool = false
    
    @IBInspectable var loadingColor: UIColor = UIColor.grayColor()
    
    @IBOutlet weak var keyboardButton: UIButton!
    @IBOutlet weak var measuresView: UIView!
    @IBOutlet weak var progressIndicator: UIView!
    @IBOutlet weak var loopContainer: UIView!
    @IBOutlet weak var keyboardContainer: UIView!
    @IBOutlet weak var jamNameLabel: UILabel!
    @IBOutlet weak var userCollection: UICollectionView!
    @IBOutlet weak var microphoneContainer: UIView!
    @IBOutlet weak var waveformContainer: UIView!
    @IBOutlet weak var menuButton: CircleMenu!
    @IBOutlet weak var loadingIndicatorView: NVActivityIndicatorView!
    @IBOutlet weak var sendingMessageView: NVActivityIndicatorView!
    @IBOutlet weak var recordView: BAPulseView!
    @IBOutlet weak var countdownLabel: UILabel!
    @IBOutlet weak var loopButton: UIButton!
    @IBOutlet weak var microphoneButton: UIButton!
    @IBOutlet weak var dragAndDropLabel: UILabel!
    @IBOutlet weak var selectedView: UIView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSNotificationCenter.defaultCenter().addObserverForName("new_message", object: nil, queue: nil) { (notification: NSNotification) in
            let data = notification.object as! [String]
            if data[1] == self.jam.id {
                self.jam.fetchTrack(data[0], completion: { (track: Track) in
                    track.loadMedia({
                        self.addWaveform(track)
                        }, failure: { (error: NSError) in
                            print(error.localizedDescription)
                    })
                })
            }
        }
        
        menuButton.delegate = self
        menuButton.layer.cornerRadius = menuButton.frame.size.width / 2.0
        menuButton.setImage(UIImage(named: "icon_menu"), forState: .Normal)
        menuButton.setImage(UIImage(named: "icon_close"), forState: .Selected)
        
        loadingIndicatorView.hidesWhenStopped = true
        loadingIndicatorView.type = .LineScaleParty
        loadingIndicatorView.color = loadingColor
        
        sendingMessageView.hidesWhenStopped = true
        sendingMessageView.type = .LineScale
        sendingMessageView.color = loadingColor
        
        selectedView.layer.cornerRadius = selectedView.frame.size.width / 2.0
        
        loopButton.backgroundColor = loopButton.backgroundColor?.colorWithAlphaComponent(0.0)
        microphoneButton.backgroundColor = microphoneButton.backgroundColor?.colorWithAlphaComponent(0.0)
        keyboardButton.backgroundColor = keyboardButton.backgroundColor?.colorWithAlphaComponent(0.0)
        
        self.sendingMessageView.transform = CGAffineTransformMakeRotation(CGFloat(-M_PI_2))
        
        progressIndicator.layer.cornerRadius = progressIndicator.frame.width/2
        
        dragAndDropLabel.hidden = true
        
        layoutMeasureBars()
        
        // Set up user collection view:
        userCollection.dataSource = self
        userCollection.delegate = self
        let layout = KTCenterFlowLayout()
        layout.minimumInteritemSpacing = 5.0
        layout.itemSize = CGSizeMake(60, 70)
        layout.minimumLineSpacing = 0.0
        userCollection.collectionViewLayout = layout
        jamNameLabel.text = jam.title
        
        //Creates recording view
        recordView.layer.cornerRadius = recordView.frame.size.width/2
        let floatWidth = Float(recordView.frame.size.width)
        recordView.pulseCornerRadius = floatWidth/2
        recordView.backgroundColor = UIColor(red: 1, green: 0, blue: 0.298, alpha: 1.0)
        recordView.pulseStrokeColor = UIColor(red: 0.9569, green: 0.4471, blue: 0, alpha: 1.0).CGColor
        let tap = UITapGestureRecognizer(target: self, action: #selector(JamViewController.onRecord(_:)))
        tap.delegate = self
        recordView.addGestureRecognizer(tap)
        
        //customizes loop button to be a circle
        loopButton.layer.cornerRadius = 0.5 * loopButton.bounds.size.width
        keyboardButton.layer.cornerRadius = 0.5 * loopButton.bounds.size.width
        
        //customizes microphone button to be a circle
        microphoneButton.layer.cornerRadius = 0.5 * microphoneButton.bounds.size.width
        microphoneContainer.alpha = 0
        
        for user in jam!.users {
            if user.facebookID != User.currentUser!.facebookID {
                users.append(user)
            }
        }
        
        loadingIndicatorView.startAnimation()
        
        inKeyboard = false
        onKeyboard(self)
                
        drawWaveforms()
    }
    
    override func viewDidLayoutSubviews() {
        if inKeyboard {
            selectedView.frame = keyboardButton.frame
        } else if inMicrophone {
            selectedView.frame = microphoneButton.frame
        } else {
            selectedView.frame = loopButton.frame
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        jam.stop()
    }
    
    func layoutMeasureBars() {
        var measureImage: UIView
        
        for i in 1...jam.numMeasures!-1 {
            measureImage = UIView(frame:CGRectMake((measuresView.frame.width/CGFloat(jam.numMeasures!))*CGFloat(i), ((measuresView.frame.height)/2)-12, 1, 24));
            measureImage.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.2)
            measureImage.layer.cornerRadius = 0.5
            measuresView.addSubview(measureImage)
        }
        
        measureImage = UIView(frame:CGRectMake(0, ((measuresView.frame.height)/2), measuresView.frame.width, 1));
        measureImage.backgroundColor = UIColor.darkGrayColor().colorWithAlphaComponent(0.2)
        measuresView.addSubview(measureImage)
    }
    
    var selectedLoopView: UIView?
    func dragLoop(view: UIView, sender: UIPanGestureRecognizer) {
        
        switch sender.state{
        case .Began:
            selectedLoopView = view
            selectedLoopView?.backgroundColor = UIColor.clearColor()
            self.view.addSubview(selectedLoopView!)
        case .Changed:
            UIView.animateWithDuration(2, animations: {() -> Void in
                self.selectedLoopView?.transform = CGAffineTransformTranslate(self.selectedLoopView!.transform, 20, 100)
            })
        default:
            selectedLoopView?.removeFromSuperview()
        }
    }
    
    func addWaveform(track: Track) {
        let waveformView = FDWaveformView(frame: self.waveformContainer.frame)
        
        waveformView.frame.origin.y = 0
        let fileURL = NSURL(fileURLWithPath: track.filepath)
        waveformView.audioURL = fileURL
        waveformView.doesAllowScrubbing = false
        waveformView.doesAllowScroll = false
        waveformView.doesAllowStretch = false
        waveformView.wavesColor = track.color.colorWithAlphaComponent(0.6)
        
        self.waveformContainer.addSubview(waveformView)
        
        let waveTap = UITapGestureRecognizer(target: self, action: #selector(JamViewController.onPlay(_:)))
        self.waveformContainer.subviews.last!.addGestureRecognizer(waveTap)
        
        self.waveformContainer.bringSubviewToFront(self.progressIndicator)
        self.view.bringSubviewToFront(self.measuresView)
        
    }
    
    func drawWaveforms() {
        AudioKit.stop()
        
        for subview in self.waveformContainer.subviews {
            if let waveform = subview as? FDWaveformView {
                waveform.removeFromSuperview()
            }
        }
        
        if jam.tracks.count > 0 {
            let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
            dispatch_async(dispatch_get_global_queue(priority, 0)) {
                
                self.jam.loadTracks({
                    for track in (self.jam.tracks) {
                        if let filepath = track.filepath {
                            
                            let fileURL = NSURL(fileURLWithPath: filepath)
                            
                            let waveformView = FDWaveformView(frame: self.waveformContainer.frame)
                            
                            waveformView.frame.origin.y = 0
                            waveformView.audioURL = fileURL
                            waveformView.doesAllowScrubbing = false
                            waveformView.doesAllowScroll = false
                            waveformView.doesAllowStretch = false
                            waveformView.wavesColor = track.color.colorWithAlphaComponent(0.6)
                            
                            dispatch_async(dispatch_get_main_queue()) {
                                self.waveformContainer.addSubview(waveformView)
                            }
                        }
                    }
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        self.measuresView.hidden = false
                        self.loadingIndicatorView.stopAnimation()
                        let keyboardController = self.childViewControllers[0] as! KeyboardViewController
                        keyboardController.instrument.reload()
                        
                        let waveTap = UITapGestureRecognizer(target: self, action: #selector(JamViewController.onPlay(_:)))
                        self.waveformContainer.subviews.last!.addGestureRecognizer(waveTap)
                        
                        self.waveformContainer.bringSubviewToFront(self.progressIndicator)
                        self.view.bringSubviewToFront(self.measuresView)
                        AudioKit.start()
                    }
                })
                
                
            }
        } else {
            AudioKit.start()
            let keyboardController = self.childViewControllers[0] as! KeyboardViewController
            keyboardController.instrument.reload()
            self.loadingIndicatorView.stopAnimation()
        }
    }
    
    //Plays chat when wave is tapped
    func onPlay(sender: UITapGestureRecognizer? = nil) {
        if jam.isPlaying {
            stopAnimatingCursor()
            jam.stop()
        } else {
            self.jam.play({
                self.startAnimatingCursor()
            })
        }
    }
    
    var progressTimer: NSTimer?
    var refreshTime = 0.052
    func startAnimatingCursor() {
        
        if jam.tracks.count > 0 {
            progressTimer =  NSTimer.scheduledTimerWithTimeInterval(refreshTime, target: self, selector: #selector(updateProgressView), userInfo: nil, repeats: true)
        } else {
            UIView.animateWithDuration(jam.duration, delay: 0.0, options: [.CurveLinear], animations: {
                self.progressIndicator.frame.origin.x = self.view.frame.width
                }, completion: nil)
        }
    }
    
    private var previousProgress: CGFloat = 0
    func updateProgressView() {
        let progress = CGFloat(Double(self.view.frame.width) * jam.playthroughProgress)
        
        if progress < previousProgress {
            self.progressIndicator.frame.origin.x = progress
        } else {
            UIView.animateWithDuration(refreshTime, delay: 0.0, options: [.CurveLinear], animations: {
                self.progressIndicator.frame.origin.x = progress
                }, completion: nil)
        }
        
        previousProgress = progress
    }
    
    func stopAnimatingCursor() {
        progressTimer?.invalidate()
        progressIndicator.layer.removeAllAnimations()
        progressIndicator.frame.origin.x = -2
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return users.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = userCollection.dequeueReusableCellWithReuseIdentifier("UserCell", forIndexPath: indexPath) as! UserCell
        cell.user = users[indexPath.row]
        return cell
    }
    
    let items: [(icon: String, color: UIColor)] = [
        ("icon_home", UIColor(red:0.19, green:0.57, blue:1, alpha:1)),
        ("icon_search", UIColor(red:0.22, green:0.74, blue:0, alpha:1)),
        ("notifications-btn", UIColor(red:0.96, green:0.23, blue:0.21, alpha:1)),
        ("settings-btn", UIColor(red:0.51, green:0.15, blue:1, alpha:1)),
        ("nearby-btn", UIColor(red:1, green:0.39, blue:0, alpha:1)),
        ]
    
    let instruments: [Instrument] = [Instrument.acousticBass, Instrument.choir, Instrument.electricBass, Instrument.electricGuitar, Instrument.saxophone, Instrument.piano]
    
    func circleMenu(circleMenu: CircleMenu, willDisplay button: UIButton, atIndex: Int) {
        button.backgroundColor = instruments[atIndex].color
        button.setImage(instruments[atIndex].image, forState: .Normal)
        
        // set highlighted image
        let highlightedImage  = instruments[atIndex].image!.imageWithRenderingMode(.AlwaysTemplate)
        button.setImage(highlightedImage, forState: .Highlighted)
        button.tintColor = UIColor.init(colorLiteralRed: 0, green: 0, blue: 0, alpha: 0.3)
    }
    
    func circleMenu(circleMenu: CircleMenu, buttonWillSelected button: UIButton, atIndex: Int) {
        let keyboardController = self.childViewControllers[0] as! KeyboardViewController
        keyboardController.instrument = instruments[atIndex]
        menuButton.selected = false
    }
    
    var isCounting = false
    var isRecording = false
    
    func onRecord(sender: UITapGestureRecognizer) {
        
        jam.stop()
        stopAnimatingCursor()
        
        if isRecording {return}
        if isCounting {
            cancelCountdown()
        } else {
            startCountdown()
        }
    }
    
    func onBeat() {
        recordView.popAndPulse()
        
        if isCounting {
            countdown -= 1
            countdownLabel.text = String(countdown)
            
            if countdown == 0 {
                startRecording()
            }
        }
    }
    
    func startCountdown() {
        isCounting = true
        self.menuButton.hidden = true
        loopButton.hidden = true
        microphoneButton.hidden = true
        keyboardButton.hidden = true
        selectedView.alpha = 0
        countdownLabel.text = "\(countdown)"
        tempoTimer = NSTimer.scheduledTimerWithTimeInterval(60/jam.tempo!, target: self, selector: #selector(onBeat), userInfo: nil, repeats: true)
        metronome.play()
    }
    
    func cancelCountdown() {
        isCounting = false
        countdownLabel.text = "REC"
        tempoTimer.invalidate()
        isCounting = false
        metronome.stop()
        countdown = 4
        
        loopButton.hidden = false
        microphoneButton.hidden = false
        keyboardButton.hidden = false
        if self.inKeyboard {
            self.menuButton.hidden = false
        }
        selectedView.alpha = 1
    }
    
    var metronome: Metronome {
        switch jam.tempo! {
        case 110:
            return Metronome.metronomeBPM110
        case 140:
            return Metronome.metronomeBPM140
        default:
            return Metronome.metronomeBPM80
            
        }
    }
    
    func startRecording(){
        isRecording = true
        isCounting = false
        countdownLabel.text = ""
        countdown = 4
        
        onPlay()
        
        let microphoneController = self.childViewControllers[2] as! MicrophoneViewController
        microphoneController.redWaveform()
        
        
        delay(self.jam.duration) {
            self.tempoTimer.invalidate()
            self.sendingMessageView.startAnimation()
            self.onPlay()
            
            microphoneController.blackWaveform()
        }
        
        let keyboardController = self.childViewControllers[0] as! KeyboardViewController
        
        if inMicrophone {
            jam.recordSendVoice({
                
                microphoneController.reloadRecorderWaveform()
                
                self.sendingMessageView.stopAnimation()
                self.loopButton.hidden = false
                self.microphoneButton.hidden = false
                self.keyboardButton.hidden = false
                
                if self.inKeyboard {
                    self.menuButton.hidden = false
                }
                
                self.selectedView.alpha = 1

                print("Message sent!")
                
                self.isRecording = false
                self.countdownLabel.text = "REC"
                
                }, failure: { (error: NSError) in
                    
                    self.isRecording = false
                    self.countdownLabel.text = "REC"
                    
                    self.loopButton.hidden = false
                    self.microphoneButton.hidden = false
                    self.keyboardButton.hidden = false
                    if self.inKeyboard {
                        self.menuButton.hidden = false
                    }
                    self.selectedView.alpha = 1

                    
                    print(error.localizedDescription)
            })
        } else {
            jam.recordSend(keyboardController.instrument, success: {
                
                self.sendingMessageView.stopAnimation()
                self.loopButton.hidden = false
                self.microphoneButton.hidden = false
                self.keyboardButton.hidden = false
                if self.inKeyboard {
                    self.menuButton.hidden = false
                }
                self.selectedView.alpha = 1

                print("Message sent!")
                
                self.isRecording = false
                self.countdownLabel.text = "REC"
            }) { (error: NSError) in
                self.isRecording = false
                self.countdownLabel.text = "REC"
                
                self.loopButton.hidden = false
                self.microphoneButton.hidden = false
                self.keyboardButton.hidden = false
                if self.inKeyboard {
                    self.menuButton.hidden = false
                }
                self.selectedView.alpha = 1

                
                print(error.localizedDescription)
            }
            
            User.currentUser?.incrementInstrument(keyboardController.instrument)
        }
    }
    
    
    func delay(delay: Double, closure: ()->()) {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(delay * Double(NSEC_PER_SEC))
            ),
            dispatch_get_main_queue(),
            closure
        )
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "loopSegue") {
            let childViewController = segue.destinationViewController as! LoopsPagerViewController
            childViewController.jam = self.jam
            childViewController.waveformView = waveformContainer
            childViewController.loadingView = sendingMessageView
        }
    }
    
    @IBAction func onLoop(sender: AnyObject) {
        if inLoop {
            return
        }
        
        inLoop = true
        
        if inMicrophone {
            let microphoneController = self.childViewControllers[2] as! MicrophoneViewController
            microphoneController.unloadRecorder()
        }
        
        inMicrophone = false
        inKeyboard = false

        loopContainer.alpha = 1
        keyboardContainer.alpha = 0
        microphoneContainer.alpha = 0
        
        dragAndDropLabel.hidden = false
        menuButton.hidden = true
        recordView.hidden = true
        
        
        let overshootAmount : CGFloat = 2.0
        
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 3.0, options: [], animations: {
            self.selectedView.center.x = self.loopButton.center.x
            self.selectedView.backgroundColor = self.loopButton.backgroundColor?.colorWithAlphaComponent(1.0)
            
            self.selectedView.center.x -= overshootAmount
            self.selectedView.center.x += overshootAmount
            
            }, completion: nil)
        
    }
    
    @IBAction func onMicrophone(sender: AnyObject) {
        if inMicrophone {
            return
        }
        
        inKeyboard = false
        inLoop = false
        inMicrophone = true
        
        let microphoneController = self.childViewControllers[2] as! MicrophoneViewController
        microphoneController.loadRecorder()
        
        microphoneContainer.alpha = 1
        keyboardContainer.alpha = 0
        loopContainer.alpha = 0
        
        menuButton.hidden = true
        dragAndDropLabel.hidden = true
        recordView.hidden = false
        
        let overshootAmount : CGFloat = 2.0
        
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 3.0, options: [], animations: {
            self.selectedView.center.x = self.microphoneButton.center.x
            self.selectedView.backgroundColor = self.microphoneButton.backgroundColor?.colorWithAlphaComponent(1.0)
            
            self.selectedView.center.x -= overshootAmount
            self.selectedView.center.x += overshootAmount
            
            }, completion: nil)
        
    }
    
    @IBAction func onKeyboard(sender: AnyObject) {
        if inKeyboard {
            return
        }

        inKeyboard = true
        
        if inMicrophone {
            let microphoneController = self.childViewControllers[2] as! MicrophoneViewController
            microphoneController.unloadRecorder()
        }
        
        inLoop = false
        inMicrophone = false
        
        let keyboard = self.childViewControllers[0] as! KeyboardViewController
        keyboard.instrument.reload()
        
        microphoneContainer.alpha = 0
        keyboardContainer.alpha = 1
        loopContainer.alpha = 0
        
        menuButton.hidden = false
        dragAndDropLabel.hidden = true
        recordView.hidden = false
        
        let overshootAmount : CGFloat = 2.0
        
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 3.0, options: [], animations: {
            self.selectedView.center.x = self.keyboardButton.center.x
            self.selectedView.backgroundColor = self.keyboardButton.backgroundColor?.colorWithAlphaComponent(1.0)
            
            self.selectedView.center.x -= overshootAmount
            self.selectedView.center.x += overshootAmount
            
            }, completion: nil)
        
    }
    
}