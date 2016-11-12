//
//  ChannelListViewController.m
//  Twilio Chat Demo
//
//  Copyright (c) 2011-2016 Twilio. All rights reserved.
//

#import "ChannelListViewController.h"
#import "ChannelTableViewCell.h"
#import "ChannelViewController.h"
#import "ChatManager.h"
#import "DemoHelpers.h"

@interface ChannelListViewController () <TwilioChatClientDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, weak) IBOutlet UITableView *tableView;

@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSMutableOrderedSet *channels;
@end

@implementation ChannelListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 48.0f;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.tableView addSubview:self.refreshControl];
    [self.refreshControl addTarget:self
                            action:@selector(refreshChannels)
                  forControlEvents:UIControlEventValueChanged];

    TwilioChatClient *client = [[ChatManager sharedManager] client];
    if (client) {
        client.delegate = self;
        
        if (client.synchronizationStatus == TCHClientSynchronizationStatusCompleted) {
            [self populateChannels];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"viewChannel"]) {
        ChannelViewController *vc = segue.destinationViewController;
        vc.channel = sender;
    }
}

- (IBAction)returnFromChannel:(UIStoryboardSegue *)segue {
    [self.tableView reloadData];
}

- (IBAction)logoutTapped:(id)sender {
    [[ChatManager sharedManager] logout];
    [[ChatManager sharedManager] presentRootViewController];
}

- (IBAction)newChannelTapped:(id)sender {
    UIAlertController *newChannelActionSheet = [UIAlertController alertControllerWithTitle:@"New Channel"
                                                                                   message:nil
                                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [self configurePopoverPresentationController:newChannelActionSheet.popoverPresentationController];

    [newChannelActionSheet addAction:[UIAlertAction actionWithTitle:@"Public Channel"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
                                                                [self newChannelPrivate:NO];
                                                            }]];
    
    [newChannelActionSheet addAction:[UIAlertAction actionWithTitle:@"Private Channel"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
                                                                [self newChannelPrivate:YES];
                                                            }]];
    
    [newChannelActionSheet addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                         style:UIAlertActionStyleCancel
                                                       handler:nil]];

    [self presentViewController:newChannelActionSheet
                       animated:YES
                     completion:nil];
}

- (void)newChannelPrivate:(BOOL)isPrivate {
    UIAlertController *newChannelDialog = [UIAlertController alertControllerWithTitle:@"New Channel"
                                                                              message:@"What would you like to call the new channel?"
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    
    [newChannelDialog addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Channel Name";
    }];
    
    [newChannelDialog addAction:[UIAlertAction actionWithTitle:@"Create"
                                                         style:UIAlertActionStyleDefault
                                                       handler:
                                 ^(UIAlertAction *action) {
                                     UITextField *newChannelNameTextField = newChannelDialog.textFields[0];

                                     NSMutableDictionary *options = [NSMutableDictionary dictionary];
                                     if (newChannelNameTextField &&
                                         newChannelNameTextField.text &&
                                         ![newChannelNameTextField.text isEqualToString:@""]) {
                                         options[TCHChannelOptionFriendlyName] = newChannelNameTextField.text;
                                     }
                                     if (isPrivate) {
                                         options[TCHChannelOptionType] = @(TCHChannelTypePrivate);
                                     }
                                     
                                     TCHChannels *channelsList = [[[ChatManager sharedManager] client] channelsList];
                                     [channelsList createChannelWithOptions:options
                                                                      completion:^(TCHResult *result, TCHChannel *channel) {
                                                                          if (result.isSuccessful) {
                                                                              [DemoHelpers displayToastWithMessage:@"Channel Created"
                                                                                                            inView:self.view];
                                                                          } else {
                                                                              [DemoHelpers displayToastWithMessage:@"Channel Create Failed"
                                                                                                            inView:self.view];
                                                                              NSLog(@"%s: %@", __FUNCTION__, result.error);
                                                                          }
                                                                      }];
                                 }]];
    
    [newChannelDialog addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                         style:UIAlertActionStyleCancel
                                                       handler:nil]];
    
    [self presentViewController:newChannelDialog
                       animated:YES
                     completion:nil];
}

- (void)displayOperationsForChannel:(TCHChannel *)channel
                        calledFromSwipe:(BOOL)calledFromSwipe {
    __weak __typeof(self) weakSelf = self;
    
    UIAlertController *channelActions = [UIAlertController alertControllerWithTitle:@"Channel"
                                                                            message:nil
                                                                     preferredStyle:UIAlertControllerStyleActionSheet];
    [self configurePopoverPresentationController:channelActions.popoverPresentationController];

    if (channel.status == TCHChannelStatusJoined) {
        [channelActions addAction:[UIAlertAction actionWithTitle:@"Set All Messages Consumed"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             [weakSelf setAllMessagesConsumed:channel];
                                                         }]];
        [channelActions addAction:[UIAlertAction actionWithTitle:@"Set No Messages Consumed"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             [weakSelf setNoMessagesConsumed:channel];
                                                         }]];
        [channelActions addAction:[UIAlertAction actionWithTitle:@"Leave"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             [weakSelf leaveChannel:channel];
                                                         }]];
    }
    
    if (channel.status == TCHChannelStatusInvited) {
        [channelActions addAction:[UIAlertAction actionWithTitle:@"Decline Invite"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             [weakSelf declineInviteOnChannel:channel];
                                                         }]];
    }
    
    if (channel.status == TCHChannelStatusInvited || channel.status == TCHChannelStatusNotParticipating) {
        [channelActions addAction:[UIAlertAction actionWithTitle:@"Join"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             [weakSelf joinChannel:channel];
                                                         }]];
    }

    if (!calledFromSwipe) {
        [channelActions addAction:[UIAlertAction actionWithTitle:@"Destroy"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *action) {
                                                             [weakSelf destroyChannel:channel];
                                                         }]];
    }
    
    [channelActions addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil]];
    
    [self presentViewController:channelActions
                       animated:YES
                     completion:nil];
}

- (void)refreshChannels {
    [self populateChannels];

    [self.refreshControl endRefreshing];
}

#pragma mark - Demo helpers

- (void)populateChannels {
    self.channels = nil;
    [self.tableView reloadData];

    TCHChannels *channelsList = [[[ChatManager sharedManager] client] channelsList];
    if (channelsList) {
        __block NSMutableOrderedSet *newChannels = [[NSMutableOrderedSet alloc] init];
        
        void __block (^_completion)();
        TCHChannelPaginatorCompletion completion = ^(TCHResult *result, TCHChannelPaginator *paginator) {
            [newChannels addObjectsFromArray:[paginator items]];
            
            if ([paginator hasNextPage]) {
                [paginator requestNextPageWithCompletion:_completion];
            } else {
                // reached last page
                
                [self sortChannels:newChannels];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.channels = newChannels;
                    [self.tableView reloadData];
                });
            }
        };
        _completion = completion;
        
        [channelsList userChannelsWithCompletion:completion];
    }
}



- (void)setAllMessagesConsumed:(TCHChannel *)channel {
    [channel synchronizeWithCompletion:^(TCHResult *result) {
        if ([result isSuccessful]) {
            [channel.messages setAllMessagesConsumed];
        } else {
            [DemoHelpers displayToastWithMessage:@"Set all messages consumed failed."
                                          inView:self.view];
            NSLog(@"%s: %@", __FUNCTION__, result.error);
        }
    }];
}

- (void)setNoMessagesConsumed:(TCHChannel *)channel {
    [channel synchronizeWithCompletion:^(TCHResult *result) {
        if ([result isSuccessful]) {
            [channel.messages setNoMessagesConsumed];
        } else {
            [DemoHelpers displayToastWithMessage:@"Set no messages consumed failed."
                                          inView:self.view];
            NSLog(@"%s: %@", __FUNCTION__, result.error);
        }
    }];
}

- (void)leaveChannel:(TCHChannel *)channel {
    [channel leaveWithCompletion:^(TCHResult *result) {
        if (result.isSuccessful) {
            [DemoHelpers displayToastWithMessage:@"Channel left."
                                          inView:self.view];
        } else {
            [DemoHelpers displayToastWithMessage:@"Channel leave failed."
                                          inView:self.view];
            NSLog(@"%s: %@", __FUNCTION__, result.error);
        }
        [self.tableView reloadData];
    }];
}

- (void)destroyChannel:(TCHChannel *)channel {
    [channel destroyWithCompletion:^(TCHResult *result) {
        if (result.isSuccessful) {
            [DemoHelpers displayToastWithMessage:@"Channel destroyed."
                                          inView:self.view];
        } else {
            [DemoHelpers displayToastWithMessage:@"Channel destroy failed."
                                          inView:self.view];
            NSLog(@"%s: %@", __FUNCTION__, result.error);
        }
        [self.tableView reloadData];
    }];
}

- (void)joinChannel:(TCHChannel *)channel {
    [channel joinWithCompletion:^(TCHResult *result) {
        if (result.isSuccessful) {
            [DemoHelpers displayToastWithMessage:@"Channel joined."
                                          inView:self.view];
        } else {
            [DemoHelpers displayToastWithMessage:@"Channel join failed."
                                          inView:self.view];
            NSLog(@"%s: %@", __FUNCTION__, result.error);
        }
        [self.tableView reloadData];
    }];
}

- (void)declineInviteOnChannel:(TCHChannel *)channel {
    [channel declineInvitationWithCompletion:^(TCHResult *result) {
        if (result.isSuccessful) {
            [DemoHelpers displayToastWithMessage:@"Invite declined."
                                          inView:self.view];
        } else {
            [DemoHelpers displayToastWithMessage:@"Invite declined failed."
                                          inView:self.view];
            NSLog(@"%s: %@", __FUNCTION__, result.error);
        }
        [self.tableView reloadData];
    }];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!self.channels) {
        return 1;
    }
    
    return self.channels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    
    if (!self.channels) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"loading"];
    } else {
        ChannelTableViewCell *channelCell = [tableView dequeueReusableCellWithIdentifier:@"channel"];
        
        TCHChannel *channel = self.channels[indexPath.row];

        NSString *nameLabel = channel.friendlyName;
        if (channel.friendlyName.length == 0) {
            nameLabel = @"(no friendly name)";
        }
        if (channel.type == TCHChannelTypePrivate) {
            nameLabel = [nameLabel stringByAppendingString:@" (private)"];
        }
        
        channelCell.nameLabel.text = nameLabel;
        channelCell.sidLabel.text = channel.sid;

        UIColor *channelColor = nil;
        switch (channel.status) {
            case TCHChannelStatusInvited:
                channelColor = [UIColor blueColor];
                break;
            case TCHChannelStatusJoined:
                channelColor = [UIColor greenColor];
                break;
            case TCHChannelStatusNotParticipating:
                channelColor = [UIColor grayColor];
                break;
        }
        channelCell.nameLabel.textColor = channelColor;
        channelCell.sidLabel.textColor = channelColor;
        
        cell = channelCell;
    }
    
    [cell layoutIfNeeded];
    
    return cell;
}

#pragma mark - UITableViewDelegate methods

- (TCHChannel *)channelForIndexPath:(NSIndexPath *)indexPath {
    if (!self.channels || indexPath.row >= self.channels.count) {
        return nil;
    }
    
    return self.channels[indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // Are we just showing loading?
    if (!self.channels) {
        return;
    }
    
    TCHChannel *channel = [self channelForIndexPath:indexPath];
    
    if (channel.status == TCHChannelStatusJoined) {
        // synchronize will be a noop and call the completion immediately if the channel is ready
        [channel synchronizeWithCompletion:^(TCHResult *result) {
            [self performSegueWithIdentifier:@"viewChannel" sender:channel];
        }];
    } else {
        [self displayOperationsForChannel:channel
                          calledFromSwipe:NO];
    }
}

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *actions = [NSMutableArray array];
    TCHChannel *channel = [self channelForIndexPath:indexPath];

    __weak __typeof(self) weakSelf = self;
    [actions addObject:[UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                          title:@"Destroy"
                                                        handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
                                                            weakSelf.tableView.editing = NO;
                                                            [self destroyChannel:channel];
    }]];
    
    [actions addObject:[UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                          title:@"Actions"
                                                        handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
                                                            weakSelf.tableView.editing = NO;
                                                            [self displayOperationsForChannel:channel
                                                                              calledFromSwipe:YES];
                                                        }]];
    
    return actions;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        TCHChannel *channel = [self channelForIndexPath:indexPath];
        [self destroyChannel:channel];
    }
}

#pragma mark - Internal methods

- (void)sortChannels:(NSMutableOrderedSet *)channels {
    [channels sortUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"friendlyName"
                                                                 ascending:YES
                                                                  selector:@selector(localizedCaseInsensitiveCompare:)]]];
}

- (void)configurePopoverPresentationController:(UIPopoverPresentationController *)popoverPresentationController {
    popoverPresentationController.sourceView = self.view;
    popoverPresentationController.sourceRect = (CGRect){
        .origin = self.tableView.center,
        .size = CGSizeZero
    };
    popoverPresentationController.permittedArrowDirections = 0;
}

#pragma mark - TwilioChatClientDelegate

- (void)chatClient:(TwilioChatClient *)client synchronizationStatusChanged:(TCHClientSynchronizationStatus)status {
    if (status == TCHClientSynchronizationStatusCompleted) {
        [self populateChannels];
    }
}

- (void)chatClient:(TwilioChatClient *)client channelAdded:(TCHChannel *)channel {
    [self.channels addObject:channel];
    [self sortChannels:self.channels];
    [self.tableView reloadData];
}

- (void)chatClient:(TwilioChatClient *)client channelChanged:(TCHChannel *)channel {
    [self.tableView reloadData];
}

- (void)chatClient:(TwilioChatClient *)client channelDeleted:(TCHChannel *)channel {
    [self.channels removeObject:channel];
    [self.tableView reloadData];
}

- (void)chatClient:(TwilioChatClient *)client errorReceived:(TCHError *)error {
    [DemoHelpers displayToastWithMessage:[NSString stringWithFormat:@"Error received: %@", error] inView:self.view];
}

- (void)chatClient:(TwilioChatClient *)client toastReceivedOnChannel:(TCHChannel *)channel message:(TCHMessage *)message {
    [DemoHelpers displayToastWithMessage:[NSString stringWithFormat:@"New message on channel '%@'.", channel.friendlyName] inView:self.view];
}

- (void)chatClient:(TwilioChatClient *)client toastRegistrationFailedWithError:(TCHError *)error {
    // you can bring failures in registration for pushes to user's attention here
}

@end
