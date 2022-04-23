/*
 Copyright (c) 2014-2015, GoBelieve
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import "SQLGroupMessageDB.h"
#import "NSString+JSMessagesView.h"

@interface SQLGroupMessageIterator : NSObject<IMessageIterator>
-(SQLGroupMessageIterator*)initWithDB:(FMDatabaseQueue*)db gid:(int64_t)gid;
-(SQLGroupMessageIterator*)initWithDB:(FMDatabaseQueue*)db gid:(int64_t)gid position:(int)msgID;
-(SQLGroupMessageIterator*)initWithDB:(FMDatabaseQueue*)db gid:(int64_t)gid middle:(int)msgID;
-(SQLGroupMessageIterator*)initWithDB:(FMDatabaseQueue*)db gid:(int64_t)gid last:(int)msgID;

@property(nonatomic) FMResultSet *rs;
@end

@implementation SQLGroupMessageIterator

//thread safe problem
-(void)dealloc {
    [self.rs close];
}

-(SQLGroupMessageIterator*)initWithDB:(FMDatabaseQueue*)db gid:(int64_t)gid {
    
    
    self = [super init];
    if (self) {
        [db inDatabase:^(FMDatabase *db) {
            NSString *sql = @"SELECT id, sender, group_id, timestamp, flags, content FROM group_message WHERE group_id=? ORDER BY id DESC";
            self.rs = [db executeQuery:sql, @(gid)];
        }];
    }
    return self;
    
    
}

-(SQLGroupMessageIterator*)initWithDB:(FMDatabaseQueue*)db gid:(int64_t)gid position:(int)msgID {
    
    self = [super init];

    if (self) {
        [db inDatabase:^(FMDatabase *db) {
            NSString *sql = @"SELECT id, sender, group_id, timestamp, flags, content FROM group_message WHERE group_id=? AND id < ? ORDER BY id DESC";
            self.rs = [db executeQuery:sql, @(gid), @(msgID)];
        }];
    }
    return self;
    
}

-(SQLGroupMessageIterator*)initWithDB:(FMDatabaseQueue*)db gid:(int64_t)gid middle:(int)msgID {
    
    self = [super init];
    if (self) {
        [db inDatabase:^(FMDatabase *db) {
            NSString *sql = @"SELECT id, sender, group_id, timestamp, flags, content FROM group_message WHERE group_id=? AND id > ? AND id < ? ORDER BY id DESC";
            self.rs = [db executeQuery:sql, @(gid), @(msgID-10), @(msgID+10)];
        }];
    }
    return self;
   
}

//上拉刷新
-(SQLGroupMessageIterator*)initWithDB:(FMDatabaseQueue*)db gid:(int64_t)gid last:(int)msgID {
    
    self = [super init];

    if (self) {
        [db inDatabase:^(FMDatabase *db) {
            NSString *sql = @"SELECT id, sender, group_id, timestamp, flags, content FROM group_message WHERE group_id=? AND id>? ORDER BY id";
            self.rs = [db executeQuery:sql, @(gid), @(msgID)];
        }];
    }
    return self;
    

}

-(IMessage*)next {
    BOOL r = [self.rs next];
    if (!r) {
        return nil;
    }
    
    IMessage *msg = [[IMessage alloc] init];
    msg.sender = [self.rs longLongIntForColumn:@"sender"];
    msg.receiver = [self.rs longLongIntForColumn:@"group_id"];
    msg.timestamp = [self.rs intForColumn:@"timestamp"];
    msg.flags = [self.rs intForColumn:@"flags"];
    msg.rawContent = [self.rs stringForColumn:@"content"];
    msg.msgLocalID = [self.rs intForColumn:@"id"];
    return msg;
}

@end



@implementation SQLGroupMessageDB

+(SQLGroupMessageDB*)instance {
    static SQLGroupMessageDB *m;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!m) {
            m = [[SQLGroupMessageDB alloc] init];
        }
    });
    return m;
}

-(id)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}


-(id<IMessageIterator>)newMessageIterator:(int64_t)gid {
    return [[SQLGroupMessageIterator alloc] initWithDB:self.db gid:gid];
}

-(id<IMessageIterator>)newForwardMessageIterator:(int64_t)gid last:(int)lastMsgID {
    return [[SQLGroupMessageIterator alloc] initWithDB:self.db gid:gid position:lastMsgID];
}

-(id<IMessageIterator>)newMiddleMessageIterator:(int64_t)gid messageID:(int)messageID {
    return [[SQLGroupMessageIterator alloc] initWithDB:self.db gid:gid middle:messageID];
}

-(id<IMessageIterator>)newBackwardMessageIterator:(int64_t)gid messageID:(int)messageID {
    return [[SQLGroupMessageIterator alloc] initWithDB:self.db gid:gid last:messageID];
}


-(BOOL)clearConversation:(int64_t)gid {
    
    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
        @try {
            
            [db executeUpdate:@"DELETE FROM group_message WHERE group_id=?", @(gid)];
           
           
            
        } @catch (NSException *exception) {
            NSLog(@"error = %@", [exception reason]);
            *rollback = YES;
        } @finally {
            isSuccess = TRUE;
            *rollback = NO;
            
        }
        
    }];
    return  isSuccess;

}


-(BOOL)clear {
    
    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
        @try {
            
            [db executeUpdate:@"DELETE FROM group_message"];
           
           
            
        } @catch (NSException *exception) {
            NSLog(@"error = %@", [exception reason]);
            *rollback = YES;
        } @finally {
            isSuccess = TRUE;
            *rollback = NO;
            
        }
        
    }];
    return  isSuccess;

}

-(BOOL)updateMessageContent:(int)msgLocalID content:(NSString*)content {
    
    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
        @try {
            
            [db executeUpdate:@"UPDATE group_message SET content=? WHERE id=?", content, @(msgLocalID)];
           
           
            
        } @catch (NSException *exception) {
            NSLog(@"error = %@", [exception reason]);
            *rollback = YES;
        } @finally {
            isSuccess = TRUE;
            *rollback = NO;
            
        }
        
    }];
    return  isSuccess;
    
}

-(BOOL)insertMessages:(NSArray*)msgs {
    
    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
        @try {
            for (IMessage *msg in msgs) {
                NSString *uuid = msg.uuid ? msg.uuid : @"";
                [db executeUpdate:@"INSERT INTO group_message (sender, group_id, timestamp, flags, uuid, content) VALUES (?, ?, ?, ?, ?, ?)",
                          @(msg.sender), @(msg.receiver), @(msg.timestamp),@(msg.flags), uuid, msg.rawContent];
              
                
                int64_t rowID = [db lastInsertRowId];
                msg.msgId = rowID;
                
                if (msg.textContent) {
                    NSString *text = [msg.textContent.text tokenizer];
                    [db executeUpdate:@"INSERT INTO group_message_fts (docid, content) VALUES (?, ?)", @(rowID), text];
                }
            }
           
           
            
        } @catch (NSException *exception) {
            NSLog(@"error = %@", [exception reason]);
            *rollback = YES;
        } @finally {
            isSuccess = TRUE;
            *rollback = NO;
            
        }
        
    }];
    return  isSuccess;
  

}

-(BOOL)insertMessage:(IMessage*)msg {
    
    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
        @try {
           
                NSString *uuid = msg.uuid ? msg.uuid : @"";
                [db executeUpdate:@"INSERT INTO group_message (sender, group_id, timestamp, flags, uuid, content) VALUES (?, ?, ?, ?, ?, ?)",
                          @(msg.sender), @(msg.receiver), @(msg.timestamp),@(msg.flags), uuid, msg.rawContent];
              
                
                int64_t rowID = [db lastInsertRowId];
                msg.msgId = rowID;
                
                if (msg.textContent) {
                    NSString *text = [msg.textContent.text tokenizer];
                    [db executeUpdate:@"INSERT INTO group_message_fts (docid, content) VALUES (?, ?)", @(rowID), text];
                }
            
           
           
            
        } @catch (NSException *exception) {
            NSLog(@"error = %@", [exception reason]);
            *rollback = YES;
        } @finally {
            isSuccess = TRUE;
            *rollback = NO;
            
        }
        
    }];
    return  isSuccess;
  

}

-(BOOL)removeMessage:(int)msgLocalID {

    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
        @try {
            
            [db executeUpdate:@"DELETE FROM group_message WHERE id=?", @(msgLocalID)];
            [db executeUpdate:@"DELETE FROM group_message_fts WHERE rowid=?", @(msgLocalID)];
           
            
        } @catch (NSException *exception) {
            NSLog(@"error = %@", [exception reason]);
            *rollback = YES;
        } @finally {
            isSuccess = TRUE;
            *rollback = NO;
            
        }
        
    }];
    return  isSuccess;

}

-(BOOL)removeMessageIndex:(int)msgLocalID {
    
    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
        @try {
            
            [db executeUpdate:@"DELETE FROM group_message_fts WHERE rowid=?", @(msgLocalID)];
           
            
        } @catch (NSException *exception) {
            NSLog(@"error = %@", [exception reason]);
            *rollback = YES;
        } @finally {
            isSuccess = TRUE;
            *rollback = NO;
            
        }
        
    }];
    return  isSuccess;

}

-(NSArray*)search:(NSString*)key {
    
    NSMutableArray *array = [NSMutableArray array];
    [self.db inDatabase:^(FMDatabase *db) {
            
        NSString* keys = [key stringByReplacingOccurrencesOfString:@"'" withString:@"\'"];
        keys = [keys tokenizer];
        NSString *sql = [NSString stringWithFormat:@"SELECT rowid FROM group_message_fts WHERE group_message_fts MATCH '%@'", keys];
        
        FMResultSet *rs = [db executeQuery:sql];
        NSMutableArray *array = [NSMutableArray array];
        while ([rs next]) {
            int64_t msgID = [rs longLongIntForColumn:@"rowid"];
            IMessage *msg = [self getMessage:msgID];
            if (msg) {
                [array addObject:msg];
            }
        }
        
        [rs close];
    }];
  
    return array;

}

-(IMessage*)getLastMessage:(int64_t)gid {
    
    __block IMessage *msg = [[IMessage alloc] init];
    [self.db inDatabase:^(FMDatabase *db) {
         
        FMResultSet *rs = [db executeQuery:@"SELECT id, sender, group_id, timestamp, flags, content FROM group_message WHERE group_id= ? ORDER BY id DESC", @(gid)];
        if ([rs next]) {
            
            msg.sender = [rs longLongIntForColumn:@"sender"];
            msg.receiver = [rs longLongIntForColumn:@"group_id"];
            msg.timestamp = [rs intForColumn:@"timestamp"];
            msg.flags = [rs intForColumn:@"flags"];
            msg.rawContent = [rs stringForColumn:@"content"];
            msg.msgLocalID = [rs intForColumn:@"id"];
            [rs close];
        
        }else{
            msg = nil;
        }
        [rs close];
    }];
    return msg;
    
}

-(int)getMessageId:(NSString*)uuid {
    
    __block int msgId = 0;
    [self.db inDatabase:^(FMDatabase *db) {
            
        FMResultSet *rs = [db executeQuery:@"SELECT id FROM group_message WHERE uuid= ?", uuid];
        if ([rs next]) {
            msgId = (int)[rs longLongIntForColumn:@"id"];
            [rs close];
           
        }
        [rs close];
    }];
    return msgId;
 
}

-(IMessage*)getMessage:(int64_t)msgID {
    
    __block IMessage *msg = [[IMessage alloc] init];
    [self.db inDatabase:^(FMDatabase *db) {
            
        
        FMResultSet *rs = [db executeQuery:@"SELECT id, sender, group_id, timestamp, flags, content FROM group_message WHERE id= ?", @(msgID)];
        if ([rs next]) {
    
            msg.sender = [rs longLongIntForColumn:@"sender"];
            msg.receiver = [rs longLongIntForColumn:@"group_id"];
            msg.timestamp = [rs intForColumn:@"timestamp"];
            msg.flags = [rs intForColumn:@"flags"];
            msg.rawContent = [rs stringForColumn:@"content"];
            msg.msgLocalID = [rs intForColumn:@"id"];
           
        }else{
            msg = nil;
        }
        [rs close];
        
    }];
    return msg;

}

-(BOOL)acknowledgeMessage:(int)msgLocalID {
    return [self addFlag:msgLocalID flag:MESSAGE_FLAG_ACK];
}

-(BOOL)markMessageFailure:(int)msgLocalID {
    return [self addFlag:msgLocalID flag:MESSAGE_FLAG_FAILURE];
}

-(BOOL)markMesageListened:(int)msgLocalID {
    return [self addFlag:msgLocalID flag:MESSAGE_FLAG_LISTENED];
}


-(BOOL)addFlag:(int)msgLocalID flag:(int)f {
    
    __block BOOL isSuccess = NO;

    __block FMResultSet *rs =nil;
    [self.db inDatabase:^(FMDatabase *db) {
            
        rs = [db executeQuery:@"SELECT flags FROM group_message WHERE id=?", @(msgLocalID)];
 
    }];
    if (!rs) {
        return isSuccess;
    }
    if ([rs next]) {
        int flags = [rs intForColumn:@"flags"];
        flags |= f;
        
        [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
                
            @try {

                [db executeUpdate:@"UPDATE group_message SET flags= ? WHERE id= ?", @(flags), @(msgLocalID)];
                      
            } @catch (NSException *exception) {
                NSLog(@"error = %@", [exception reason]);
                *rollback = YES;
            } @finally {
                isSuccess = TRUE;
                *rollback = NO;
                
            }
            
        }];
    }
    
    [rs close];
    return isSuccess;

}


-(BOOL)eraseMessageFailure:(int)msgLocalID {
    
    __block BOOL isSuccess = NO;
    __block FMResultSet *rs =nil;
    [self.db inDatabase:^(FMDatabase *db) {
            
        rs = [db executeQuery:@"SELECT flags FROM group_message WHERE id=?", @(msgLocalID)];
 
    }];
    if (!rs) {
        return isSuccess;
    }
    if ([rs next]) {
        int flags = [rs intForColumn:@"flags"];
        
        int f = MESSAGE_FLAG_FAILURE;
        flags &= ~f;
        
        [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
                
            @try {

                [db executeUpdate:@"UPDATE group_message SET flags= ? WHERE id= ?", @(flags), @(msgLocalID)];
                      
            } @catch (NSException *exception) {
                NSLog(@"error = %@", [exception reason]);
                *rollback = YES;
            } @finally {
                isSuccess = TRUE;
                *rollback = NO;
                
            }
            
        }];
    }
    
    [rs close];
    return isSuccess;
    
    
}

-(BOOL)updateFlags:(int)msgLocalID flags:(int)flags {
    
    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
        @try {

            [db executeUpdate:@"UPDATE group_message SET flags= ? WHERE id= ?", @(flags), @(msgLocalID)];
                  
        } @catch (NSException *exception) {
            NSLog(@"error = %@", [exception reason]);
            *rollback = YES;
        } @finally {
            isSuccess = TRUE;
            *rollback = NO;
            
        }
        
    }];
    return  isSuccess;

}


-(void)saveMessageAttachment:(IMessage*)msg address:(NSString*)address {
    //以附件的形式存储，以免第二次查询
    MessageAttachmentContent *att = [[MessageAttachmentContent alloc] initWithAttachment:msg.msgLocalID address:address];
    IMessage *attachment = [[IMessage alloc] init];
    attachment.sender = msg.sender;
    attachment.receiver = msg.receiver;
    attachment.rawContent = att.raw;
    [self saveMessage:attachment];
}

-(BOOL)saveMessage:(IMessage*)msg {
    return [self insertMessage:msg];
}

@end

