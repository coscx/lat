//
//  Conversation.h
//  flt_im_plugin
//
//  Created by laijihua on 2020/10/23.
//


#import <Foundation/Foundation.h>
#import "IMessage.h"
//会话类型
#define CONVERSATION_PEER 1
#define CONVERSATION_GROUP 2
#define CONVERSATION_SYSTEM 3
#define CONVERSATION_CUSTOMER_SERVICE 4

@interface Conversation : NSObject
@property(nonatomic, assign) int64_t id;
@property(nonatomic) int type;
@property(nonatomic, assign) int64_t cid;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *avatarURL;
@property(nonatomic) IMessage *message;

@property(nonatomic) int newMsgCount;
@property(nonatomic, copy) NSString *detail;
@property(nonatomic) int timestamp;
@end

@interface IGroup : NSObject
@property(nonatomic, assign) int64_t gid;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *avatarURL;

//name为nil时，界面显示identifier字段
@property(nonatomic, copy) NSString *identifier;

@end
