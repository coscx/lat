//
//  ConversationDB.m
//  flt_im_plugin
//
//  Created by wan on 2021/1/23.
//

#import "ConversationDB.h"

@implementation ConversationDB
+(ConversationDB*)instance {
    static ConversationDB *m;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!m) {
            m = [[ConversationDB alloc] init];
        }
    });
    return m;
}
-(id)init {
    self = [super init];
    if (self) {
        self.secret = NO;
    }
    return self;
}


-(void)saveMessageAttachment:(IMessage*)msg address:(NSString*)address {
    //以附件的形式存储，以免第二次查询
    [self updateMessageContent:msg.msgId content:msg.rawContent];
}

-(BOOL)saveMessage:(IMessage*)msg {
    NSAssert(msg.isOutgoing, @"");
    return [self insertMessage:msg uid:msg.receiver];
}
@end
