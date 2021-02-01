#import "SQLConversionsDB.h"
#import "Conversation.h"
#import "NSString+JSMessagesView.h"

@interface SQLConversionsIterator : NSObject<IConversationIterator>

-(SQLConversionsIterator*)initWithDB:(FMDatabase*)db peer:(int64_t)peer secret:(BOOL)secret;

-(SQLConversionsIterator*)initWithDB:(FMDatabase*)db peer:(int64_t)peer position:(int)msgID secret:(BOOL)secret;

@property(nonatomic, strong) FMResultSet *rs;
@end

@implementation SQLConversionsIterator

//thread safe problem
-(void)dealloc {
    [self.rs close];
}
-(SQLConversionsIterator*)initWithDB:(FMDatabase*)db {
    self = [super init];
    if (self) {
    
        NSString *sql = @"SELECT * FROM conversation   ORDER BY id DESC";
        self.rs = [db executeQuery:sql];
    }
    return self;
}
-(SQLConversionsIterator*)initWithDB:(FMDatabase*)db peer:(int64_t)peer secret:(BOOL)secret {
    self = [super init];
    if (self) {
        int s = secret ? 1 : 0;
        NSString *sql = @"SELECT id, sender, receiver, timestamp, secret, flags, content FROM peer_message WHERE peer = ? AND secret = ? ORDER BY id DESC";
        self.rs = [db executeQuery:sql, @(peer), @(s)];
    }
    return self;
}

-(SQLConversionsIterator*)initWithDB:(FMDatabase*)db peer:(int64_t)peer position:(int)msgID secret:(BOOL)secret {
    self = [super init];
    if (self) {
        int s = secret ? 1 : 0;
        NSString *sql = @"SELECT id, sender, receiver, timestamp, secret, flags, content FROM peer_message WHERE peer = ? AND secret = ? AND id < ? ORDER BY id DESC";
        self.rs = [db executeQuery:sql, @(peer), @(s), @(msgID)];
    }
    return self;
}


//上拉刷新
-(SQLConversionsIterator*)initWithDB:(FMDatabase*)db peer:(int64_t)peer last:(int)msgID secret:(BOOL)secret {
    self = [super init];
    if (self) {
        int s = secret ? 1 : 0;
        NSString *sql = @"SELECT id, sender, receiver, timestamp, secret, flags, content FROM peer_message WHERE peer = ? AND secret = ? AND id>? ORDER BY id";
        self.rs = [db executeQuery:sql, @(peer), @(s), @(msgID)];
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
    FMDatabase *db = self.db;
    
    [db beginTransaction];
   
    BOOL r = [db executeUpdate:@"INSERT INTO conversation (cid, type, name, state, unread) VALUES (?, ?, ?, ?, ?)",
              @(con.cid), @(con.type), con.name, @(0), @(con.newMsgCount)];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        [db rollback];
        return NO;
    }
    
    int64_t rowID = [self.db lastInsertRowId];
  
    r = [db commit];
    return r;
}
-(BOOL)removeConversation:(Conversation *)con {
    FMDatabase *db = self.db;
    BOOL r = [db executeUpdate:@"DELETE FROM conversation WHERE id=?",  [con id];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        return NO;
    }
    return YES;
}
-(Conversation*)getConversation:(int)cid type:(int)type {
    FMResultSet *rs = [self.db executeQuery:@"SELECT * FROM conversation WHERE cid = ? AND type = ?", @(cid), @(type)];
    if ([rs next]) {
        Conversation *con = [[Conversation alloc] init];
        con.type = CONVERSATION_PEER;
        con.id = [rs longLongIntForColumn:@"id"];
        con.cid = [rs longLongIntForColumn:@"cid"];
        con.type = [rs intForColumn:@"type"];
        con.name = [rs stringForColumn:@"name"];
        con.newMsgCount = [rs intForColumn:@"unread"];
        return  con;
    }
    [rs close];
    return nil;
}
-(BOOL)setNewCount:(int)cid count:(int)count {
    FMDatabase *db = self.db;

    BOOL r = [db executeUpdate:@"UPDATE conversation SET unread=? WHERE cid=?", @(count), @(cid)];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        return NO;
    }

    return [db changes] == 1;
}

-(BOOL)setState:(int)id state:(int)state {
    FMDatabase *db = self.db;

    BOOL r = [db executeUpdate:@"UPDATE conversation SET state=? WHERE id=?", @(state), @(id)];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        return NO;
    }

    return [db changes] == 1;
}
-(BOOL)resetState:(int)state {
    FMDatabase *db = self.db;

    BOOL r = [db executeUpdate:@"UPDATE conversation SET state=? ", @(state)];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        return NO;
    }

    return [db changes] == 1;
}

-(BOOL)insertMessage:(IMessage*)msg uid:(int64_t)uid{
    FMDatabase *db = self.db;
    
    [db beginTransaction];
    int secret = self.secret ? 1 : 0;
    NSString *uuid = msg.uuid ? msg.uuid : @"";
    BOOL r = [db executeUpdate:@"INSERT INTO peer_message (peer, sender, receiver, timestamp, secret, flags, uuid, content) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
              @(uid), @(msg.sender), @(msg.receiver), @(msg.timestamp), @(secret), @(msg.flags), uuid, msg.rawContent];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        [db rollback];
        return NO;
    }
    
    int64_t rowID = [self.db lastInsertRowId];
    msg.msgId = rowID;
    
    if (msg.textContent) {
        NSString *text = [msg.textContent.text tokenizer];
        [db executeUpdate:@"INSERT INTO peer_message_fts (docid, content) VALUES (?, ?)", @(rowID), text];
    }
    
    r = [db commit];
    return r;
}

-(BOOL)removeMessage:(int)msgLocalID {
    FMDatabase *db = self.db;
    BOOL r = [db executeUpdate:@"DELETE FROM peer_message WHERE id=?", @(msgLocalID)];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        return NO;
    }
    
    r = [db executeUpdate:@"DELETE FROM peer_message_fts WHERE rowid=?", @(msgLocalID)];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        return NO;
    }
    return YES;
}

-(BOOL)removeMessageIndex:(int)msgLocalID {
    FMDatabase *db = self.db;
    BOOL r = [db executeUpdate:@"DELETE FROM peer_message_fts WHERE rowid=?", @(msgLocalID)];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        return NO;
    }
    return YES;
}

-(BOOL)clearConversation:(int64_t)uid {
    FMDatabase *db = self.db;
    int secret = self.secret ? 1 : 0;
    BOOL r = [db executeUpdate:@"DELETE FROM peer_message WHERE peer=? AND secret=?", @(uid), @(secret)];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        return NO;
    }
    return YES;
}

-(BOOL)clear {
    FMDatabase *db = self.db;
    BOOL r = [db executeUpdate:@"DELETE FROM peer_message"];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        return NO;
    }
    return YES;
}

-(BOOL)updateMessageContent:(int)msgLocalID content:(NSString*)content {
    FMDatabase *db = self.db;
    
    BOOL r = [db executeUpdate:@"UPDATE peer_message SET content=? WHERE id=?", content, @(msgLocalID)];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        return NO;
    }

    return [db changes] == 1;
}

-(NSArray*)search:(NSString*)key {
    FMDatabase *db = self.db;
    
    key = [key stringByReplacingOccurrencesOfString:@"'" withString:@"\'"];
    key = [key tokenizer];
    NSString *sql = [NSString stringWithFormat:@"SELECT rowid FROM peer_message_fts WHERE peer_message_fts MATCH '%@'", key];
    
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
    return array;
}

-(IMessage*)getLastMessage:(int64_t)uid {
    int s = self.secret ? 1 : 0;
    FMResultSet *rs = [self.db executeQuery:@"SELECT id, sender, receiver, timestamp, secret, flags, content FROM peer_message WHERE peer = ? AND secret = ? ORDER BY id DESC", @(uid), @(s)];
    if ([rs next]) {
        IMessage *msg = [[IMessage alloc] init];
        msg.sender = [rs longLongIntForColumn:@"sender"];
        msg.receiver = [rs longLongIntForColumn:@"receiver"];
        msg.timestamp = [rs intForColumn:@"timestamp"];
        msg.flags = [rs intForColumn:@"flags"];
        msg.secret = [rs intForColumn:@"secret"] == 1;
        msg.rawContent = [rs stringForColumn:@"content"];
        msg.msgLocalID = [rs intForColumn:@"id"];
        [rs close];
        return msg;
    }
    [rs close];
    return nil;
}

-(int)getMessageId:(NSString*)uuid {
    FMResultSet *rs = [self.db executeQuery:@"SELECT id FROM peer_message WHERE uuid=?", uuid];
    if ([rs next]) {
        int msgId = (int)[rs longLongIntForColumn:@"id"];
        [rs close];
        return msgId;
    }
    [rs close];
    return 0;
}

-(IMessage*)getMessage:(int64_t)msgID {
    FMResultSet *rs = [self.db executeQuery:@"SELECT id, sender, receiver, timestamp, secret, flags, content FROM peer_message WHERE id= ?", @(msgID)];
    if ([rs next]) {
        IMessage *msg = [[IMessage alloc] init];
        msg.sender = [rs longLongIntForColumn:@"sender"];
        msg.receiver = [rs longLongIntForColumn:@"receiver"];
        msg.timestamp = [rs intForColumn:@"timestamp"];
        msg.flags = [rs intForColumn:@"flags"];
        msg.secret = [rs intForColumn:@"secret"] == 1;
        msg.rawContent = [rs stringForColumn:@"content"];
        msg.msgLocalID = [rs intForColumn:@"id"];
        return msg;
    }
    return nil;
    
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
    FMDatabase *db = self.db;
    FMResultSet *rs = [db executeQuery:@"SELECT flags FROM peer_message WHERE id=?", @(msgLocalID)];
    if (!rs) {
        return NO;
    }
    if ([rs next]) {
        int flags = [rs intForColumn:@"flags"];
        flags |= f;
        
        
        BOOL r = [db executeUpdate:@"UPDATE peer_message SET flags= ? WHERE id= ?", @(flags), @(msgLocalID)];
        if (!r) {
            NSLog(@"error = %@", [db lastErrorMessage]);
            return NO;
        }
    }
    
    [rs close];
    return YES;
}


-(BOOL)eraseMessageFailure:(int)msgLocalID {
    FMDatabase *db = self.db;
    FMResultSet *rs = [db executeQuery:@"SELECT flags FROM peer_message WHERE id=?", @(msgLocalID)];
    if (!rs) {
        return NO;
    }
    if ([rs next]) {
        int flags = [rs intForColumn:@"flags"];
        
        int f = MESSAGE_FLAG_FAILURE;
        flags &= ~f;
        
        BOOL r = [db executeUpdate:@"UPDATE peer_message SET flags= ? WHERE id= ?", @(flags), @(msgLocalID)];
        if (!r) {
            NSLog(@"error = %@", [db lastErrorMessage]);
            return NO;
        }
    }
    
    [rs close];
    return YES;
    
}

-(BOOL)updateFlags:(int)msgLocalID flags:(int)flags {
    FMDatabase *db = self.db;
    
    BOOL r = [db executeUpdate:@"UPDATE peer_message SET flags= ? WHERE id= ?", @(flags), @(msgLocalID)];
    if (!r) {
        NSLog(@"error = %@", [db lastErrorMessage]);
        return NO;
    }
    
    return YES;
}

-(id<IConversationIterator>)getConvIterator:(int64_t)uid {
    return [[SQLConversionsIterator alloc] initWithDB:self.db];
}



@end


