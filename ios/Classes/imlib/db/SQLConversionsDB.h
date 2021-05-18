/*
 Copyright (c) 2014-2015, GoBelieve
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>
#import "IMessage.h"
#import "IConversationIterator.h"

#import <fmdb/FMDB.h>
#import "FMDatabaseQueue.h"
@interface SQLConversionsDB : NSObject



@property(nonatomic, strong) FMDatabaseQueue *db;
@property(nonatomic, assign) BOOL secret;


-(id<IConversationIterator>)getConvIterator:(int64_t)ids;
-(BOOL)addConversation:(Conversation*)conv;
-(BOOL)removeConversation:(Conversation*)conv;
-(Conversation*)getConversation:(int)cid type:(int)type;
-(BOOL)setNewCount:(int)rowid count: (int)count;
-(BOOL)setState:(int)rowid state:(int)state;
-(BOOL)resetState:(int)state;
//获取最新的消息
-(IMessage*)getLastMessage:(int64_t)uid;
-(IMessage*)getMessage:(int64_t)msgID;
-(int)getMessageId:(NSString*)uuid;
-(BOOL)insertMessage:(IMessage*)msg uid:(int64_t)uid;
-(BOOL)removeMessage:(int)msgLocalID;
-(BOOL)removeMessageIndex:(int)msgLocalID;
-(BOOL)clearConversation:(int64_t)uid;
-(BOOL)clear;
-(NSArray*)search:(NSString*)key;
-(BOOL)updateMessageContent:(int)msgLocalID content:(NSString*)content;
-(BOOL)acknowledgeMessage:(int)msgLocalID;
-(BOOL)markMessageFailure:(int)msgLocalID;
-(BOOL)markMesageListened:(int)msgLocalID;
-(BOOL)eraseMessageFailure:(int)msgLocalID;
-(BOOL)updateFlags:(int)msgLocalID flags:(int)flags;
@end
