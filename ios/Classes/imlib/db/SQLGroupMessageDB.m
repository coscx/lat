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
-(SQLGroupMessageIterator*)initWithDB:(FMDatabaseQueue*)db gid:(int64_t)gid position:(int64_t)msgID;
-(SQLGroupMessageIterator*)initWithDB:(FMDatabaseQueue*)db gid:(int64_t)gid middle:(int64_t)msgID;
-(SQLGroupMessageIterator*)initWithDB:(FMDatabaseQueue*)db gid:(int64_t)gid last:(int64_t)msgID;

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
            NSString *sql = @"SELECT id, sender, group_id, timestamp, flags, reader_count, reference_count, reference, content, tags FROM group_message WHERE group_id=? ORDER BY id DESC";
            self.rs = [db executeQuery:sql, @(gid)];
        }];
    }
    return self;
    
    
}

-(SQLGroupMessageIterator*)initWithDB:(FMDatabaseQueue*)db gid:(int64_t)gid position:(int)msgID {
    
    self = [super init];

    if (self) {
        [db inDatabase:^(FMDatabase *db) {
            NSString *sql = @"SELECT id, sender, group_id, timestamp, flags, reader_count, reference_count, reference, content, tags FROM group_message WHERE group_id=? AND id < ? ORDER BY id DESC";
            self.rs = [db executeQuery:sql, @(gid), @(msgID)];
        }];
    }
    return self;
    
}

-(SQLGroupMessageIterator*)initWithDB:(FMDatabaseQueue*)db gid:(int64_t)gid middle:(int)msgID {
    
    self = [super init];
    if (self) {
        [db inDatabase:^(FMDatabase *db) {
            NSString *sql = @"SELECT id, sender, group_id, timestamp, flags, reader_count, reference_count, reference, content, tags FROM group_message WHERE group_id=? AND id > ? AND id < ? ORDER BY id DESC";
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
            NSString *sql = @"SELECT id, sender, group_id, timestamp, flags, reader_count, reference_count, reference, content, tags FROM group_message WHERE group_id=? AND id>? ORDER BY id";
            self.rs = [db executeQuery:sql, @(gid), @(msgID)];
        }];
    }
    return self;
    

}
-(SQLGroupMessageIterator*)initWithDB:(FMDatabase*)db gid:(int64_t)gid topic:(NSString*)uuid {
    self = [super init];
    if (self) {
        [db inDatabase:^(FMDatabase *db) {
                NSString *sql = @"SELECT id, sender, group_id, timestamp, flags, reader_count, reference_count, reference, content, tags FROM group_message WHERE group_id=? AND reference = ? ORDER BY id DESC";
                self.rs = [db executeQuery:sql, @(gid), uuid];
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
    msg.msgId = [self.rs longLongIntForColumn:@"id"];
    msg.sender = [self.rs longLongIntForColumn:@"sender"];
    msg.receiver = [self.rs longLongIntForColumn:@"group_id"];
    msg.timestamp = [self.rs intForColumn:@"timestamp"];
    msg.flags = [self.rs intForColumn:@"flags"];
    msg.readerCount = [self.rs intForColumn:@"reader_count"];
    msg.referenceCount = [self.rs intForColumn:@"reference_count"];
    msg.reference = [self.rs stringForColumn:@"reference"];
    msg.rawContent = [self.rs stringForColumn:@"content"];
    NSString *tags = [self.rs stringForColumn:@"tags"];
    if (tags.length > 0) {
        msg.tags = [tags componentsSeparatedByString:@","];
    }
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


-(id<IMessageIterator>)newForwardMessageIterator:(int64_t)gid messageID:(int64_t)lastMsgID {
    return [[SQLGroupMessageIterator alloc] initWithDB:self.db gid:gid position:lastMsgID];
}

-(id<IMessageIterator>)newMiddleMessageIterator:(int64_t)gid messageID:(int64_t)messageID {
    return [[SQLGroupMessageIterator alloc] initWithDB:self.db gid:gid middle:messageID];
}

-(id<IMessageIterator>)newBackwardMessageIterator:(int64_t)gid messageID:(int64_t)messageID {
    return [[SQLGroupMessageIterator alloc] initWithDB:self.db gid:gid last:messageID];
}

-(id<IMessageIterator>)newTopicMessageIterator:(int64_t)gid topic:(NSString*)uuid {
    return [[SQLGroupMessageIterator alloc] initWithDB:self.db gid:gid topic:uuid];
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

-(BOOL)updateMessageContent:(int64_t)msgLocalID content:(NSString*)content {
    
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
               NSString *uuid = msg.uuid ? msg.uuid : nil;
                       NSString *ref = msg.reference.length > 0 ? msg.reference : nil;
                       BOOL r = [db executeUpdate:@"INSERT INTO group_message (sender, group_id, timestamp, flags, uuid, reference, content) VALUES (?, ?, ?, ?, ?, ?, ?)",
                                 @(msg.sender), @(msg.receiver), @(msg.timestamp),@(msg.flags), uuid, ref, msg.rawContent];
              
                
                int64_t rowID = [db lastInsertRowId];
                msg.msgId = rowID;
                
                if (msg.textContent) {
                    NSString *text = [msg.textContent.text tokenizer];
                    [db executeUpdate:@"INSERT INTO group_message_fts (docid, content) VALUES (?, ?)", @(rowID), text];
                }
                 if (msg.reference.length > 0) {
                            r = [db executeUpdate:@"UPDATE group_message SET reference_count=reference_count+1 WHERE uuid=?", msg.reference];
                            if (!r) {
                                //ignore the error
                                NSLog(@"error = %@", [db lastErrorMessage]);
                            }
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
           
               NSString *uuid = msg.uuid ? msg.uuid : nil;
                                      NSString *ref = msg.reference.length > 0 ? msg.reference : nil;
                                      BOOL r = [db executeUpdate:@"INSERT INTO group_message (sender, group_id, timestamp, flags, uuid, reference, content) VALUES (?, ?, ?, ?, ?, ?, ?)",
                                                @(msg.sender), @(msg.receiver), @(msg.timestamp),@(msg.flags), uuid, ref, msg.rawContent];
              
                
                int64_t rowID = [db lastInsertRowId];
                msg.msgId = rowID;
                
                if (msg.textContent) {
                    NSString *text = [msg.textContent.text tokenizer];
                    [db executeUpdate:@"INSERT INTO group_message_fts (docid, content) VALUES (?, ?)", @(rowID), text];
                }
               if (msg.reference.length > 0) {
                        r = [db executeUpdate:@"UPDATE group_message SET reference_count=reference_count+1 WHERE uuid=?", msg.reference];
                        if (!r) {
                            //ignore the error
                            NSLog(@"error = %@", [db lastErrorMessage]);
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

-(BOOL)removeMessage:(int64_t)msgLocalID {

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

-(BOOL)removeMessageIndex:(int64_t)msgLocalID {
    
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
         
        FMResultSet *rs = [db executeQuery:@"SELECT id, sender, group_id, timestamp, flags, reader_count, reference_count, reference, content, tags FROM group_message WHERE group_id= ? ORDER BY id DESC", @(gid)];
        if ([rs next]) {
            msg.msgId = [rs longLongIntForColumn:@"id"];
            msg.sender = [rs longLongIntForColumn:@"sender"];
            msg.receiver = [rs longLongIntForColumn:@"group_id"];
            msg.timestamp = [rs intForColumn:@"timestamp"];
            msg.flags = [rs intForColumn:@"flags"];
            msg.readerCount = [rs intForColumn:@"reader_count"];
            msg.referenceCount = [rs intForColumn:@"reference_count"];
            msg.reference = [rs stringForColumn:@"reference"];
            msg.rawContent = [rs stringForColumn:@"content"];
            NSString *tags = [rs stringForColumn:@"tags"];
            if (tags.length > 0) {
                msg.tags = [tags componentsSeparatedByString:@","];
            }

            [rs close];
        
        }else{
            msg = nil;
        }
        [rs close];
    }];
    return msg;
    
}

-(int64_t)getMessageId:(NSString*)uuid {
    
    __block int64_t msgId = 0;
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
            
        
        FMResultSet *rs = [db executeQuery:@"SELECT id, sender, group_id, timestamp, flags, reader_count, reference_count, reference, content, tags FROM group_message WHERE id= ?", @(msgID)];
        if ([rs next]) {
    
           msg.msgId = [rs longLongIntForColumn:@"id"];
           msg.sender = [rs longLongIntForColumn:@"sender"];
           msg.receiver = [rs longLongIntForColumn:@"group_id"];
           msg.timestamp = [rs intForColumn:@"timestamp"];
           msg.flags = [rs intForColumn:@"flags"];
           msg.readerCount = [rs intForColumn:@"reader_count"];
           msg.referenceCount = [rs intForColumn:@"reference_count"];
           msg.reference = [rs stringForColumn:@"reference"];
           msg.rawContent = [rs stringForColumn:@"content"];
           NSString *tags = [rs stringForColumn:@"tags"];
           
        }else{
            msg = nil;
        }
        [rs close];
        
    }];
    return msg;

}
-(int)getMessageReferenceCount:(NSString*)uuid {
    FMResultSet *rs = [self.db executeQuery:@"SELECT reference_count FROM group_message WHERE uuid=?", uuid];
    if ([rs next]) {
        int count = [rs intForColumn:@"reference_count"];
        [rs close];
        return count;
    }
    return 0;
}

-(int)getMessageReaderCount:(int64_t)msgID {
    FMResultSet *rs = [self.db executeQuery:@"SELECT reader_count FROM group_message WHERE id=?", @(msgID)];
    if ([rs next]) {
        int count = [rs intForColumn:@"reader_count"];
        [rs close];
        return count;
    }
    return 0;
}
-(BOOL)acknowledgeMessage:(int)msgLocalID {
    return [self addFlag:msgLocalID flag:MESSAGE_FLAG_ACK];
}

-(int)markMessageFailure:(int64_t)msgLocalID {
    return [self addFlag:msgLocalID flag:MESSAGE_FLAG_FAILURE];
}

-(int)markMesageListened:(int64_t)msgLocalID {
    return [self addFlag:msgLocalID flag:MESSAGE_FLAG_LISTENED];
}


-(int)addFlag:(int64_t)msgLocalID flag:(int)f {
    
    __block int isSuccess = 0;

    __block FMResultSet *rs =nil;
    [self.db inDatabase:^(FMDatabase *db) {
            
        rs = [db executeQuery:@"SELECT flags FROM group_message WHERE id=?", @(msgLocalID)];
 
    }];
    if (!rs) {
        return isSuccess;
    }
    if ([rs next]) {
        int flags = [rs intForColumn:@"flags"];
        if ((flags & f) == 0) {
                    flags |= f;

                     [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
                              @try {

                                  [db executeUpdate:@"UPDATE group_message SET flags= ? WHERE id= ?", @(flags), @(msgLocalID)];

                              } @catch (NSException *exception) {
                                  NSLog(@"error = %@", [exception reason]);
                                  *rollback = YES;
                              } @finally {
                                  isSuccess = [db changes];
                                  *rollback = NO;

                              }

                      }];
        }


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
        if (flags & f) {
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




-(BOOL)saveMessage:(IMessage*)msg {
    return [self insertMessage:msg];
}
-(BOOL)addMessage:(int64_t)msgId tag:(NSString*)tag {
    if (tag.length == 0) {
        return NO;
    }

    FMDatabase *db = self.db;
    FMResultSet *rs = [db executeQuery:@"SELECT tags FROM group_message WHERE id=?", @(msgId)];
    if (!rs) {
        return NO;
    }
    if ([rs next]) {
        NSString *tags = [rs stringForColumn:@"tags"];
        if (![tags containsString:tag]) {
            if (tags.length == 0) {
                tags = tag;
            } else {
                tags = [NSString stringWithFormat:@"%@,%@", tags, tag];
            }
            BOOL r = [db executeUpdate:@"UPDATE group_message SET tags= ? WHERE id= ?", tags, @(msgId)];
            if (!r) {
                NSLog(@"error = %@", [db lastErrorMessage]);
                return NO;
            }
        }
    }

    [rs close];
    return YES;
}

-(BOOL)removeMessage:(int64_t)msgId tag:(NSString*)tag {
    if (tag.length == 0) {
        return NO;
    }

    FMDatabase *db = self.db;
    FMResultSet *rs = [db executeQuery:@"SELECT tags FROM group_message WHERE id=?", @(msgId)];
    if (!rs) {
        return NO;
    }
    if ([rs next]) {
        NSString *tags = [rs stringForColumn:@"tags"];
        if ([tags containsString:tag]) {
            NSString *t = [NSString stringWithFormat:@"%@,", tag];
            tags = [tags stringByReplacingOccurrencesOfString:t withString:@""];
            tags = [tags stringByReplacingOccurrencesOfString:tag withString:@""];
            BOOL r = [db executeUpdate:@"UPDATE group_message SET tags = ? WHERE id= ?", tags, @(msgId)];
            if (!r) {
                NSLog(@"error = %@", [db lastErrorMessage]);
                return NO;
            }
        }
    }

    [rs close];
    return YES;
}


-(BOOL)addMessage:(int64_t)msgId reader:(int64_t)uid {
    FMDatabase *db = self.db;
    [db beginTransaction];
    BOOL r = [db executeUpdate:@"INSERT INTO group_message_readed (msg_id, uid) VALUES (?, ?)", @(msgId), @(uid)];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        [db rollback];
        return NO;
    }

    FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) as count FROM group_message_readed WHERE msg_id=?", @(msgId)];
    if (!rs) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        [db rollback];
        return NO;
    }

    int count = 0;
    if ([rs next]) {
        count = [rs intForColumn:@"count"];
    }
    [rs close];

    r = [db executeUpdate:@"UPDATE group_message SET reader_count = ? WHERE id= ?", @(count), @(msgId)];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        [db rollback];
        return NO;
    }
    [db commit];
    return YES;
}

-(NSArray*)getMessageReaders:(int64_t)msgId {
    FMDatabase *db = self.db;
    FMResultSet *rs = [db executeQuery:@"SELECT uid FROM group_message_readed WHERE msg_id = ?", @(msgId)];
    NSMutableArray *array = [NSMutableArray array];
    while ([rs next]) {
        int64_t uid = [rs longLongIntForColumn:@"uid"];
        [array addObject:@(uid)];
    }
    [rs close];
    return array;
}
@end

