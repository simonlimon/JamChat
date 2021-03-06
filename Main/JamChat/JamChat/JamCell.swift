//
//  JamCell.swift
//  JamChat
//
//  Created by Simon Posada Fishman on 7/12/16.
//  Copyright © 2016 Jammers. All rights reserved.
//

import UIKit
import UICollectionViewRightAlignedLayout
import TFGRelativeDateFormatter

class JamCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource {
    
    @IBOutlet weak var userCollection: UICollectionView!
    @IBOutlet weak var colorView: UIView!
    @IBOutlet weak var jamNameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    var users: [User] = []
    var jam: Jam? {
        didSet {
            userCollection.reloadData()
            jamNameLabel.text = jam!.title
            
            users = []
            for user in jam!.users {
                if user.facebookID != User.currentUser!.facebookID {
                    users.append(user)
                }
            }
            
            let dateString = TFGRelativeDateFormatter.sharedFormatter().stringForDate(jam!.updatedAt)
            dateLabel.text = dateString

            self.setColor()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        userCollection.dataSource = self
        userCollection.delegate = self
        
        let layout = UICollectionViewRightAlignedLayout()
        layout.minimumInteritemSpacing = 5.0
        layout.itemSize = CGSizeMake(29, 29)
        layout.minimumLineSpacing = 0.0
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        userCollection.collectionViewLayout = layout
        
        self.layer.cornerRadius = 20
    }

    func setColor() {
        let number = 100 - Double(jam!.tracks.count) * 10
        let r = number<50 ? 255 : floor(255-(number*2-100)*255/100);
        let g = number>50 ? 255 : floor((number*2)*255/100);
        
        colorView.backgroundColor = UIColor.init(red: CGFloat(r/255), green: CGFloat(g/255), blue: 0, alpha: 0.2)
    }
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return users.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = userCollection.dequeueReusableCellWithReuseIdentifier("UserCell", forIndexPath: indexPath) as! UserCell
        cell.user = users[indexPath.row]
        return cell
    }

}
