//
//  RCTVideoPoster.h
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 27/9/25.
//

#import "Foundation/Foundation.h"
#import "UIKit/UIKit.h"

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoPoster : UIImageView
- (void)applyPoster:(NSString *)poster;
- (void)applyPosterResizeMode:(NSString *)posterResizeMode;
@end

NS_ASSUME_NONNULL_END
