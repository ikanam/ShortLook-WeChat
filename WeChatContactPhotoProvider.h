#import "ShortLook-API.h"
#import <sqlite3.h>

@interface WeChatContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding> {
    sqlite3 *db;
}
- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification;
@end
