#import "WeChatContactPhotoProvider.h"
#import <CommonCrypto/CommonDigest.h>

@interface FBApplicationInfo
-(NSURL *)dataContainerURL;
@end

@interface LSApplicationProxy
+(id)applicationProxyForIdentifier:(id)arg1;
@end

@implementation WeChatContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
    FBApplicationInfo *appinfo = [LSApplicationProxy applicationProxyForIdentifier:@"com.tencent.xin"];
    NSString *appPath = [[appinfo dataContainerURL] path];
    NSString *contactID = notification.applicationUserInfo[@"u"];
    if (!contactID) return nil;
    
    NSString *loginInfoPath = [NSString stringWithFormat:@"%@/Documents/LocalInfo.lst", appPath];
    NSDictionary *loginInfo = [NSDictionary dictionaryWithContentsOfFile:loginInfoPath];
    NSString *userID = loginInfo[@"$objects"][2];
    NSString *userDataName = [self md5:userID];
    NSString *userContactsDBPath = [NSString stringWithFormat:@"%@/Documents/%@/DB/WCDB_Contact.sqlite", appPath, userDataName];
    
    if (sqlite3_open([userContactsDBPath UTF8String], &db) != SQLITE_OK) {
        sqlite3_close(db);
        return nil;
    }
    
    NSString *profileURLStr;
    
    NSString *sqlQuery = [NSString stringWithFormat:@"SELECT dbContactHeadImage FROM Friend WHERE userName = '%@'", contactID];
    sqlite3_stmt * statement;
    
    if (sqlite3_prepare_v2(db, [sqlQuery UTF8String], -1, &statement, nil) == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            const void *head = sqlite3_column_blob(statement, 0);
            int size = sqlite3_column_bytes(statement, 0);
            NSData *data = [[NSData alloc] initWithBytes:head length:size];
            profileURLStr = [self getAvatarURLInData:data];
        }
    }
    sqlite3_close(db);
    
    NSRange range = [profileURLStr rangeOfString:@"/132" options:NSBackwardsSearch];
    if (range.location != NSNotFound) {
        //替换为高清头像
        profileURLStr = [profileURLStr stringByReplacingCharactersInRange:range withString:@"/0"];
    }
    
    if (!profileURLStr) return nil;
    NSURL *profileURL = [NSURL URLWithString:profileURLStr];
    if (!profileURL) return nil;
    
    return [NSClassFromString(@"DDNotificationContactPhotoPromiseOffer") offerDownloadingPromiseWithPhotoIdentifier:profileURLStr fromURL:profileURL];
}

- (NSString *)getAvatarURLInData:(NSData *)data{
    if (!data || data.length <= 8) {
        return @"";
    }
    
    int begin = 0;
    int end = 0;
    
    Byte *byteData = (Byte *)[data bytes];
    for(int i=0;i<[data length];i++){
        if (byteData[i] == 104 && begin == 0) {
            begin = i;
        }
        
        if (byteData[i] == 26 && end == 0) {
            end = i;
        }
    }
    
    if (begin > 0 && end > 0) {
        int len = end - begin;
        NSData* tempData = [data subdataWithRange:NSMakeRange(begin, len)];
        NSString* str = [[NSString alloc]initWithData:tempData encoding:NSASCIIStringEncoding];
        
        return str;
    }
    
    return @"";
}

- (NSString *)md5:(NSString *)input {
    
    const char *cStr = [input UTF8String];
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5( cStr, strlen(cStr), digest ); // This is the md5 call
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}

@end
