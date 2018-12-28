//
//  DCChatTableCell.h
//  Discord Classic
//
//  Created by Julian Triveri on 4/7/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DCChatTableCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UILabel *authorLabel;
@property (weak, nonatomic) IBOutlet UIImageView *profileImage;
@property (strong, nonatomic) IBOutlet UITextView *contentTextView;
@end
