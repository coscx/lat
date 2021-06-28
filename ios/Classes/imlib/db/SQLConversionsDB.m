#import "SQLConversionsDB.h"
#import "Conversation.h"
#import "NSString+JSMessagesView.h"

@interface SQLConversionsIterator : NSObject<IConversationIterator>

-(SQLConversionsIterator*)initWithDB:(FMDatabaseQueue*)db peer:(int64_t)peer secret:(BOOL)secret;

-(SQLConversionsIterator*)initWithDB:(FMDatabaseQueue*)db peer:(int64_t)peer position:(int)msgID secret:(BOOL)secret;

@property(nonatomic, strong) FMResultSet *rs;
@end

@implementation SQLConversionsIterator

//thread safe problem
-(void)dealloc {
    [self.rs close];
}
-(SQLConversionsIterator*)initWithDB:(FMDatabaseQueue*)db {
    
    self = [super init];
    if (self) {
        [db inDatabase:^(FMDatabase *db) {
            NSString *sql = @"SELECT * FROM conversation   ORDER BY id DESC";
            FMResultSet *rs = [db executeQuery:sql];
            self.rs=rs;
            [rs close];
        }];
    }
    return self;
    
}
-(SQLConversionsIterator*)initWithDB:(FMDatabaseQueue*)db peer:(int64_t)peer secret:(BOOL)secret {
    
    self = [super init];
    if (self) {
        [db inDatabase:^(FMDatabase *db) {
            int s = secret ? 1 : 0;
            NSString *sql = @"SELECT id, sender, receiver, timestamp, secret, flags, content FROM peer_message WHERE peer = ? AND secret = ? ORDER BY id DESC";
            FMResultSet *rs = [db executeQuery:sql, @(peer), @(s)];
            self.rs=rs;
            [rs close];
        }];
    }
    return self;

}

-(SQLConversionsIterator*)initWithDB:(FMDatabaseQueue*)db peer:(int64_t)peer position:(int)msgID secret:(BOOL)secret {
    
    self = [super init];
    __block BOOL secrets = secret;
    if (self) {
        [db inDatabase:^(FMDatabase *db) {
            int s = secrets ? 1 : 0;
            NSString *sql = @"SELECT id, sender, receiver, timestamp, secret, flags, content FROM peer_message WHERE peer = ? AND secret = ? AND id < ? ORDER BY id DESC";
            FMResultSet *rs = [db executeQuery:sql, @(peer), @(s), @(msgID)];
            self.rs=rs;
            [rs close];
        }];
    }
    return self;
 
}


//上拉刷新
-(SQLConversionsIterator*)initWithDB:(FMDatabaseQueue*)db peer:(int64_t)peer last:(int)msgID secret:(BOOL)secret {
    self = [super init];
    if (self) {
        [db inDatabase:^(FMDatabase *db) {
            int s = secret ? 1 : 0;
            NSString *sql = @"SELECT id, sender, receiver, timestamp, secret, flags, content FROM peer_message WHERE peer = ? AND secret = ? AND id>? ORDER BY id";
            FMResultSet *rs = [db executeQuery:sql, @(peer), @(s), @(msgID)];
            self.rs=rs;
            [rs close];
        }];
    }
    return self;

}

-(Conversation*)next {
    BOOL r = [self.rs next];
    if (!r) {
        return nil;
    }

    Conversation *con = [[Conversation alloc] init];
    con.type = CONVERSATION_PEER;
    con.id = [self.rs longLongIntForColumn:@"id"];
    con.cid = [self.rs longLongIntForColumn:@"cid"];
    con.type = [self.rs intForColumn:@"type"];
    con.name = [self.rs stringForColumn:@"name"];
    con.newMsgCount = [self.rs intForColumn:@"unread"];
    return  con;
    
}

@end



@implementation SQLConversionsDB

-(BOOL)addConversation:(Conversation *)con{
   
    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
        @try {
            
            [db executeUpdate:@"INSERT INTO conversation (cid, type, name, state, unread) VALUES (?, ?, ?, ?, ?)",
                      @(con.cid), @(con.type), con.name, @(0), @(con.newMsgCount)];
            
           
            
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
-(BOOL)removeConversation:(Conversation *)con {

    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
        @try {
            
            [db executeUpdate:@"DELETE FROM conversation WHERE id=?",  [con id]];
            
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
-(Conversation*)getConversation:(int)cid type:(int)type {
    __block    Conversation *con = [[Conversation alloc] init];
    [self.db inDatabase:^(FMDatabase *db) {
            
        FMResultSet *rs = [db executeQuery:@"SELECT * FROM conversation WHERE cid = ? AND type = ?", @(cid), @(type)];
        if ([rs next]) {
         
            con.type = CONVERSATION_PEER;
            con.id = [rs longLongIntForColumn:@"id"];
            con.cid = [rs longLongIntForColumn:@"cid"];
            con.type = [rs intForColumn:@"type"];
            con.name = [rs stringForColumn:@"name"];
            con.newMsgCount = [rs intForColumn:@"unread"];
    
        
        }else{
            con = nil;
        }
        [rs close];
    }];
    return con;

}
-(NSMutableArray*)getConversations:(int)cid {
    NSMutableArray *convs = [NSMutableArray arrayWithCapacity:30];
    [self.db inDatabase:^(FMDatabase *db) {
            
        NSString *sql = @"SELECT * FROM conversation   ORDER BY id DESC";
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            Conversation *con = [[Conversation alloc] init];
            con.type = CONVERSATION_PEER;
            con.id = [rs longLongIntForColumn:@"id"];
            con.cid = [rs longLongIntForColumn:@"cid"];
            con.type = [rs intForColumn:@"type"];
            con.name = [rs stringForColumn:@"name"];
            con.newMsgCount = [rs intForColumn:@"unread"];
            [convs addObject:con];
            
        }

        [rs close];
    }];
    return convs;

}
-(BOOL)setNewCount:(int)rowid count:(int)count {

    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
        @try {

            [db executeUpdate:@"UPDATE conversation SET unread=? WHERE id=?", @(count), @(rowid)];
                  
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

-(BOOL)setState:(int)id state:(int)state {

    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
        @try {

            [db executeUpdate:@"UPDATE conversation SET state=? WHERE id=?", @(state), @(id)];
                  
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
-(BOOL)resetState:(int)state {
    
    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
        @try {

            [db executeUpdate:@"UPDATE conversation SET state=? ", @(state)];
                  
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

-(BOOL)insertMessage:(IMessage*)msg uid:(int64_t)uid{
   
    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
        @try {
            
            int secret = self.secret ? 1 : 0;
            NSString *uuid = msg.uuid ? msg.uuid : @"";
            [db executeUpdate:@"INSERT INTO peer_message (peer, sender, receiver, timestamp, secret, flags, uuid, content) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                      @(uid), @(msg.sender), @(msg.receiver), @(msg.timestamp), @(secret), @(msg.flags), uuid, msg.rawContent];
            
            
            int64_t rowID = [db lastInsertRowId];
            msg.msgId = rowID;
            
            if (msg.textContent) {
                NSString *text = [msg.textContent.text tokenizer];
                [db executeUpdate:@"INSERT INTO peer_message_fts (docid, content) VALUES (?, ?)", @(rowID), text];
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
            
            [db executeUpdate:@"DELETE FROM peer_message WHERE id=?", @(msgLocalID)];
         
            [db executeUpdate:@"DELETE FROM peer_message_fts WHERE rowid=?", @(msgLocalID)];
           
           
            
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

            [db executeUpdate:@"DELETE FROM peer_message_fts WHERE rowid=?", @(msgLocalID)];
                  
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

-(BOOL)clearConversation:(int64_t)uid {
    
    int secret = self.secret ? 1 : 0;
    __block BOOL isSuccess = NO;
    [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
        @try {

            [db executeUpdate:@"DELETE FROM peer_message WHERE peer=? AND secret=?", @(uid), @(secret)];
                  
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

            [db executeUpdate:@"DELETE FROM peer_message"];
                  
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

            [db executeUpdate:@"UPDATE peer_message SET content=? WHERE id=?", content, @(msgLocalID)];
                  
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
            
        NSString*  keys = [key stringByReplacingOccurrencesOfString:@"'" withString:@"\'"];
        keys = [keys tokenizer];
        NSString *sql = [NSString stringWithFormat:@"SELECT rowid FROM peer_message_fts WHERE peer_message_fts MATCH '%@'", keys];
        
        FMResultSet *rs = [db executeQuery:sql];
        
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

-(IMessage*)getLastMessage:(int64_t)uid {
    __block IMessage *msg = [[IMessage alloc] init];
    [self.db inDatabase:^(FMDatabase *db) {
            
        int s = self.secret ? 1 : 0;
        FMResultSet *rs = [db executeQuery:@"SELECT id, sender, receiver, timestamp, secret, flags, content FROM peer_message WHERE peer = ? AND secret = ? ORDER BY id DESC", @(uid), @(s)];
        if ([rs next]) {
            
            msg.sender = [rs longLongIntForColumn:@"sender"];
            msg.receiver = [rs longLongIntForColumn:@"receiver"];
            msg.timestamp = [rs intForColumn:@"timestamp"];
            msg.flags = [rs intForColumn:@"flags"];
            msg.secret = [rs intForColumn:@"secret"] == 1;
            msg.rawContent = [rs stringForColumn:@"content"];
            msg.msgLocalID = [rs intForColumn:@"id"];
          
        
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
            
        FMResultSet *rs = [db executeQuery:@"SELECT id FROM peer_message WHERE uuid=?", uuid];
        if ([rs next]) {
            msgId = (int)[rs longLongIntForColumn:@"id"];
            
           
        }
        [rs close];
    }];
    return msgId;
}

-(IMessage*)getMessage:(int64_t)msgID {

    __block IMessage *msg = [[IMessage alloc] init];
    [self.db inDatabase:^(FMDatabase *db) {
            
        FMResultSet *rs = [db executeQuery:@"SELECT id, sender, receiver, timestamp, secret, flags, content FROM peer_message WHERE id= ?", @(msgID)];
        if ([rs next]) {
    
            msg.sender = [rs longLongIntForColumn:@"sender"];
            msg.receiver = [rs longLongIntForColumn:@"receiver"];
            msg.timestamp = [rs intForColumn:@"timestamp"];
            msg.flags = [rs intForColumn:@"flags"];
            msg.secret = [rs intForColumn:@"secret"] == 1;
            msg.rawContent = [rs stringForColumn:@"content"];
            msg.msgLocalID = [rs intForColumn:@"id"];
           
        }else{
            msg = nil;
        }
        [rs close];
        
    }];
    return msg;
    
}

-(BOOL)acknowledgeMessage:(int)msgLocalID{
    return [self addFlag:msgLocalID flag:MESSAGE_FLAG_ACK];
}

-(BOOL)markMessageFailure:(int)msgLocalID {
    return [self addFlag:msgLocalID flag:MESSAGE_FLAG_FAILURE];
}

-(BOOL)markMesageListened:(int)msgLocalID {
    return [self addFlag:msgLocalID  flag:MESSAGE_FLAG_LISTENED];
}

-(BOOL)addFlag:(int)msgLocalID flag:(int)f {
    __block BOOL isSuccess = NO;
    __block FMResultSet *rs =nil;
    [self.db inDatabase:^(FMDatabase *db) {
            
        rs = [db executeQuery:@"SELECT flags FROM peer_message WHERE id=?", @(msgLocalID)];
 
    }];
    if (!rs) {
        return isSuccess;
    }
    if ([rs next]) {
        int flags = [rs intForColumn:@"flags"];
        flags |= f;
        
        [self.db inTransaction:^(FMDatabase *db, BOOL *rollback) {
                
            @try {

                [db executeUpdate:@"UPDATE peer_message SET flags= ? WHERE id= ?", @(flags), @(msgLocalID)];
                      
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
            
        rs = [db executeQuery:@"SELECT flags FROM peer_message WHERE id=?", @(msgLocalID)];
 
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

                [db executeUpdate:@"UPDATE peer_message SET flags= ? WHERE id= ?", @(flags), @(msgLocalID)];
                      
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

            [db executeUpdate:@"UPDATE peer_message SET flags= ? WHERE id= ?", @(flags), @(msgLocalID)];
                  
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

-(id<IConversationIterator>)getConvIterator:(int64_t)uid {
    return [[SQLConversionsIterator alloc] initWithDB:self.db];
}



@end


