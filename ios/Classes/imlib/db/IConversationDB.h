//
//  IMessageDB.h
//  gobelieve
//
//  Created by houxh on 2017/11/12.
//

#import <Foundation/Foundation.h>
#import "IMessage.h"
#import "IConversationIterator.h"

#define PAGE_COUNT 20
@protocol IConversitionDB<NSObject>
-(id<IConversationIterator>)getConvIterator:(int64_t)uid;
-(BOOL)addConversation:(Conversation*)conv;
-(IMessage*)getMessage:(int64_t)msgID;
-(void)saveMessageAttachment:(IMessage*)msg address:(NSString*)address;
-(BOOL)saveMessage:(IMessage*)msg;
-(BOOL)removeMessage:(int)msg;
-(BOOL)markMessageFailure:(int)msg;
-(BOOL)markMesageListened:(int)msg;
-(BOOL)eraseMessageFailure:(int)msg;

@end
