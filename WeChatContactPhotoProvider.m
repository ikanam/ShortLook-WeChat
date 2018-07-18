#import "WeChatContactPhotoProvider.h"
#import <CommonCrypto/CommonDigest.h>

@implementation WeChatContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
    
    NSString *appPath = [self getApplicationPathWithBundleID:@"com.tencent.xin"];
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
    
    if (!profileURLStr) return nil;
    NSURL *profileURL = [NSURL URLWithString:profileURLStr];
    if (!profileURL) return nil;
    
    return [NSClassFromString(@"DDNotificationContactPhotoPromiseOffer") offerDownloadingPromiseWithPhotoIdentifier:profileURLStr fromURL:profileURL];
}

- (NSString*)getApplicationPathWithBundleID:(NSString*)bundleID {
    NSFileManager *fileManger = [NSFileManager defaultManager];
    NSArray *dirs = [fileManger contentsOfDirectoryAtPath:@"/private/var/mobile/Containers/Data/Application" error:nil];
    for (NSString *dirName in dirs) {
        NSString *appPath = [NSString stringWithFormat:@"/private/var/mobile/Containers/Data/Application/%@", dirName];
        NSString *appMetaDataPath = [NSString stringWithFormat:@"%@/.com.apple.mobile_container_manager.metadata.plist",appPath];
        BOOL isExist = [fileManger fileExistsAtPath:appMetaDataPath isDirectory:false];
        if (isExist) {
            NSDictionary *metadataInfo = [NSDictionary dictionaryWithContentsOfFile:appMetaDataPath];
            if (metadataInfo) {
                NSString *appBundleID = metadataInfo[@"MCMMetadataIdentifier"];
                if ([appBundleID isEqual:bundleID]) {
                    return appPath;
                }
            }
        }
    }
    return @"";
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
