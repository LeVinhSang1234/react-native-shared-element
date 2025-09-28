//
//  AVPlayerViewController.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 28/9/25.
//
#import "AVPlayerViewController.h"

@implementation CustomPlayerViewController

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  if (self.isBeingDismissed && self.onDismiss) {
    self.onDismiss();
  }
}
@end
