//
//  ACArchiverCenter.m
//  xulinfeng
//
//  Created by xulinfeng on 2016/12/22.
//  Copyright © 2016年 xulinfeng. All rights reserved.
//

#import <objc/runtime.h>

#import "ACArchiverCenter.h"

NSString * const ACArchiverCenterRootFolderPath = @"com.archiver.center.archives";
NSString * const ACArchiverCenterStorageNamesFilename = @"com.archiver.center.storage.names";

NSString * const ACArchiverCenterDefaultName = @"com.archiver.center.default";
NSString * const ACArchiverStorageDefaultName = @"com.archiver.storage.default";

NSString * const ACArchiveStorageSetterPredicateString = @"^set[A-Z]([a-z]|[A-Z])*:forKey:$";
NSString * const ACArchiveStorageGetterPredicateString = @"^[a-z]([a-z]|[A-Z])*ForKey:$";

#define ACArchiverCenterRetain(obj)     if (@available(iOS 8, *)) CFRetain((__bridge void *)obj)

id ACArchiverCenterBoxValue(const char *type, ...) {
    va_list v;
    va_start(v, type);
    id obj = nil;
    if (strcmp(type, @encode(id)) == 0) {
        id actual = va_arg(v, id);
        obj = actual;
    } else if (strcmp(type, @encode(CGPoint)) == 0) {
        CGPoint actual = (CGPoint)va_arg(v, CGPoint);
        obj = [NSValue value:&actual withObjCType:type];
    } else if (strcmp(type, @encode(CGSize)) == 0) {
        CGSize actual = (CGSize)va_arg(v, CGSize);
        obj = [NSValue value:&actual withObjCType:type];
    } else if (strcmp(type, @encode(UIEdgeInsets)) == 0) {
        UIEdgeInsets actual = (UIEdgeInsets)va_arg(v, UIEdgeInsets);
        obj = [NSValue value:&actual withObjCType:type];
    } else if (strcmp(type, @encode(double)) == 0) {
        double actual = (double)va_arg(v, double);
        obj = [NSNumber numberWithDouble:actual];
    } else if (strcmp(type, @encode(float)) == 0) {
        float actual = (float)va_arg(v, double);
        obj = [NSNumber numberWithFloat:actual];
    } else if (strcmp(type, @encode(int)) == 0) {
        int actual = (int)va_arg(v, int);
        obj = [NSNumber numberWithInt:actual];
    } else if (strcmp(type, @encode(long)) == 0) {
        long actual = (long)va_arg(v, long);
        obj = [NSNumber numberWithLong:actual];
    } else if (strcmp(type, @encode(long long)) == 0) {
        long long actual = (long long)va_arg(v, long long);
        obj = [NSNumber numberWithLongLong:actual];
    } else if (strcmp(type, @encode(short)) == 0) {
        short actual = (short)va_arg(v, int);
        obj = [NSNumber numberWithShort:actual];
    } else if (strcmp(type, @encode(char)) == 0) {
        char actual = (char)va_arg(v, int);
        obj = [NSNumber numberWithChar:actual];
    } else if (strcmp(type, @encode(bool)) == 0) {
        bool actual = (bool)va_arg(v, int);
        obj = [NSNumber numberWithBool:actual];
    } else if (strcmp(type, @encode(unsigned char)) == 0) {
        unsigned char actual = (unsigned char)va_arg(v, unsigned int);
        obj = [NSNumber numberWithUnsignedChar:actual];
    } else if (strcmp(type, @encode(unsigned int)) == 0) {
        unsigned int actual = (unsigned int)va_arg(v, unsigned int);
        obj = [NSNumber numberWithUnsignedInt:actual];
    } else if (strcmp(type, @encode(unsigned long)) == 0) {
        unsigned long actual = (unsigned long)va_arg(v, unsigned long);
        obj = [NSNumber numberWithUnsignedLong:actual];
    } else if (strcmp(type, @encode(unsigned long long)) == 0) {
        unsigned long long actual = (unsigned long long)va_arg(v, unsigned long long);
        obj = [NSNumber numberWithUnsignedLongLong:actual];
    } else if (strcmp(type, @encode(unsigned short)) == 0) {
        unsigned short actual = (unsigned short)va_arg(v, unsigned int);
        obj = [NSNumber numberWithUnsignedShort:actual];
    }
    va_end(v);
    return obj;
}

@interface ACArchiveStorage () {
    NSMutableDictionary *_keyValues;
    dispatch_queue_t _queue;
    void *_queueTag;
}

@end

@implementation ACArchiveStorage
@synthesize name = _name, filePath = _filePath;

+ (instancetype)archiveStorageWithName:(NSString *)name filePath:(NSString *)filePath {
    return [[self alloc] initWithName:name filePath:filePath];
}

- (instancetype)initWithName:(NSString *)name filePath:(NSString *)filePath {
    if (self = [super init]) {
        _name = name;
        _filePath = filePath;
        _keyValues = [NSMutableDictionary dictionary];

        _queueTag = &_queueTag;
        _queue = dispatch_queue_create([[@"com.archive.center.storage." stringByAppendingString:name] UTF8String], DISPATCH_QUEUE_SERIAL);
        
        dispatch_queue_set_specific(_queue, _queueTag, _queueTag, NULL);
        [self reload];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [self init]) {
        _keyValues = [coder decodeObjectForKey:@"mutableKeyValues"] ?: [NSMutableDictionary dictionary];
        _name = [coder decodeObjectForKey:@"name"];
        _filePath = [coder decodeObjectForKey:@"filePath"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    __block id copy = nil;
    [self _sync:^ {
        copy = [self _copyWithZone:zone];
    }];
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [self _sync:^ {
        [self _encodeWithCoder:coder];
    }];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    __block BOOL invoked = NO;
    [self _sync:^ {
        invoked = [self _forwardInvocation:anInvocation];
    }];

    if (!invoked) {
        [super forwardInvocation:anInvocation];
    }
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return NO;
}

#pragma mark - public

- (NSArray<NSString *> *)allKeys {
    __block NSArray<NSString *> *allKeys = nil;
    [self _sync:^ {
        allKeys = _keyValues.allKeys;
    }];
    return allKeys;
}

- (NSArray *)allValues {
    __block NSArray *allValues = nil;
    [self _sync:^ {
        allValues = _keyValues.allValues;
    }];
    return allValues;
}

- (NSDictionary<NSString *, id<NSObject, NSCopying, NSCoding>> *)dictionary {
    __block NSDictionary<NSString *, id<NSObject, NSCopying, NSCoding>> *dictionary = nil;
    [self _sync:^ {
        dictionary = _keyValues.copy;
    }];
    return dictionary;
}

- (NSUInteger)count{
    __block NSUInteger count = 0;
    [self _sync:^ {
        count = _keyValues.count;
    }];
    return count;
}

- (NSArray<NSString *> *)allKeysForObject:(id)anObject{
    __block NSArray<NSString *> *allKeys = nil;
    [self _sync:^ {
        allKeys = [_keyValues allKeysForObject:anObject];
    }];
    return allKeys;
}

- (NSArray<NSObject, NSCopying, NSCoding> *)objectsForKeys:(NSArray<NSString *> *)keys notFoundMarker:(id)marker {
    __block NSArray<NSObject, NSCopying, NSCoding> *objects = nil;
    [self _sync:^ {
        objects = [_keyValues objectsForKeys:keys notFoundMarker:marker];
    }];
    return objects;
}

- (NSString *)stringForKey:(NSString *)aKey {
    id object = [self objectForKey:aKey];
    if ([object isKindOfClass:[NSString class]]) {
        return object;
    } else if ([object respondsToSelector:@selector(stringValue)]) {
        return [object stringValue];
    } else {
        return [object description];
    }
}

- (NSDate *)dateForKey:(NSString *)aKey {
    id object = [self objectForKey:aKey];
    if ([object isKindOfClass:[NSDate class]]) {
        return object;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    } else if ([object respondsToSelector:@selector(dateValue)]) {
        return [object performSelector:@selector(dateValue)];
#pragma clang diagnostic pop
    } else if ([object isKindOfClass:[NSNumber class]] || [object isKindOfClass:[NSString class]]) {
        return [NSDate dateWithTimeIntervalSince1970:[object floatValue]];
    } else {
        return nil;
    }
}

- (NSData *)dataForKey:(NSString *)aKey {
    id object = [self objectForKey:aKey];
    if ([object isKindOfClass:[NSData class]]) {
        return object;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    } else if ([object respondsToSelector:@selector(dataValue)]) {
        return [object performSelector:@selector(dataValue)];
#pragma clang diagnostic pop
    } else if ([object isKindOfClass:[NSString class]]) {
        return [object dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([object isKindOfClass:[NSNumber class]]) {
        return [[object stringValue] dataUsingEncoding:NSUTF8StringEncoding];
    } else {
        return nil;
    }
}

- (NSURL *)URLForKey:(NSString *)aKey {
    id object = [self objectForKey:aKey];
    if ([object isKindOfClass:[NSURL class]]) {
        return object;
    } else if ([object respondsToSelector:@selector(URL)]) {
        return [object URL];
    } else if ([object isKindOfClass:[NSString class]]) {
        return [NSURL URLWithString:object];
    } else {
        return nil;
    }
}

- (id<NSObject, NSCopying, NSCoding>)objectForKey:(NSString *)aKey {
    __block id object = nil;
    [self _sync:^ {
        object = [self _objectForKey:aKey];
    }];
    return object;
}

- (void)setObject:(id<NSObject, NSCopying, NSCoding>)anObject forKey:(NSString *)aKey {
    [self setObject:anObject forKey:aKey synchronized:NO];
}

- (void)syncSetObject:(id<NSObject, NSCopying, NSCoding>)anObject forKey:(NSString *)aKey {
    [self setObject:anObject forKey:aKey synchronized:YES];
}

- (void)setObject:(id<NSObject, NSCopying, NSCoding>)anObject forKey:(NSString *)aKey synchronized:(BOOL)synchronized{
    [self saveSynchronized:synchronized block:^{
        [self _setObject:anObject forKey:aKey];
    }];
}

- (void)removeObjectForKey:(NSString *)aKey{
    [self saveSynchronized:NO block:^ {
        [_keyValues removeObjectForKey:aKey];
    }];
}

- (void)reload {
    [self _sync:^ {
        _keyValues = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePath]] ?: [NSMutableDictionary dictionary];
    }];
}

- (BOOL)save {
    __block BOOL result = NO;
    [self _sync:^ {
        result = [self _save];
    }];
    return result;
}

- (BOOL)synchronize {
    __block BOOL result = NO;
    [self _sync:^ {
        result = YES;
    }];
    return result;
}

- (NSString *)description{
    __block NSString *description = nil;
    [self _sync:^ {
        description = [_keyValues description];
    }];
    return description;
}

- (void)saveSynchronized:(BOOL)synchronized block:(dispatch_block_t)block {
    dispatch_block_t saving = ^{
        [self _save];
    };

    dispatch_block_t innerBlock = ^{
        block();

        if (synchronized) saving();
        else [self _async:saving];
    };
    [self _sync:innerBlock];
}

#pragma mark - subscript

- (void)setObject:(id<NSObject, NSCopying, NSCoding>)anObject forKeyedSubscript:(NSString *)aKey{
    [self setObject:anObject forKey:aKey synchronized:NO];
}

- (id)objectForKeyedSubscript:(NSString *)key{
    return [self objectForKey:key];
}

#pragma mark - private

- (id)_copyWithZone:(NSZone *)zone {
    ACArchiveStorage *copy = [[ACArchiveStorage allocWithZone:zone] init];
    copy->_keyValues = [_keyValues mutableCopy] ?: [NSMutableDictionary dictionary];
    copy->_name = [_name copy];
    copy->_filePath = [_filePath copy];

    return copy;
}

- (void)_encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_keyValues forKey:@"mutableKeyValues"];
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_filePath forKey:@"filePath"];
}

- (BOOL)_forwardInvocation:(NSInvocation *)anInvocation {
    BOOL invoked = [self _invokeSetterInvocation:anInvocation];
    if (!invoked) {
        invoked = [self _invokeGetterInvocation:anInvocation];
    }
    return invoked;
}

- (void)_async:(dispatch_block_t)block {
    if (dispatch_get_specific(_queueTag)) {
        block();
    } else {
        dispatch_async(_queue, block);
    }
}

- (void)_sync:(dispatch_block_t)block {
    if (dispatch_get_specific(_queueTag)) {
        block();
    } else {
        dispatch_sync(_queue, block);
    }
}

- (BOOL)_save {
    return [NSKeyedArchiver archiveRootObject:_keyValues toFile:_filePath];
}

- (BOOL)_invokeSetterInvocation:(NSInvocation *)invocation {
    NSMethodSignature *signature = [invocation methodSignature];
    NSString *selectorString = NSStringFromSelector([invocation selector]);

    NSPredicate *setterPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", ACArchiveStorageSetterPredicateString];

    BOOL setter = [setterPredicate evaluateWithObject:selectorString];
    if (!setter) return NO;

    const char *type = [signature getArgumentTypeAtIndex:2];
    void *value = NULL; NSString *key = nil;
    [invocation getArgument:&value atIndex:2];
    [invocation getArgument:&key atIndex:3];
    ACArchiverCenterRetain(key);

    NSString *copiedKey = [key copy];
    id result = ACArchiverCenterBoxValue(type, value);
    [self _setObject:result forKey:copiedKey];

    invocation.target = nil;
    [invocation invoke];

    return YES;
}

- (BOOL)_invokeGetterInvocation:(NSInvocation *)invocation {
    NSString *selectorString = NSStringFromSelector([invocation selector]);

    NSPredicate *getterPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", ACArchiveStorageGetterPredicateString];
    BOOL getter = [getterPredicate evaluateWithObject:selectorString];

    if (!getter) return NO;

    NSString *getterString = [selectorString substringToIndex:[selectorString rangeOfString:@"ForKey:"].location];
    getterString = [getterString hasSuffix:@"Value"] ? getterString : [getterString stringByAppendingString:@"Value"];

    NSString *key = nil;
    [invocation getArgument:&key atIndex:2];
    ACArchiverCenterRetain(key);

    NSString *copiedKey = [key copy];
    BOOL valid = [copiedKey isKindOfClass:[NSString class]] && [copiedKey length];
    if (!valid) return NO;

    id object = [self _objectForKey:copiedKey];
    if (object && [object respondsToSelector:NSSelectorFromString(getterString)]) {
        invocation.selector = NSSelectorFromString(getterString);
    }

    if (object) {
        [invocation invokeWithTarget:object];
    } else {
        invocation.target = nil;
        [invocation invoke];
    }
    return YES;
}

- (void)_setObject:(id<NSObject, NSCopying, NSCoding>)anObject forKey:(NSString *)aKey {
    if (!anObject || ![aKey length]) return;
    if (![anObject respondsToSelector:@selector(copyWithZone:)]) return;
    if (![anObject respondsToSelector:@selector(encodeWithCoder:)]) return;
    if (![anObject respondsToSelector:@selector(initWithCoder:)]) return;

    [self willChangeValueForKey:aKey];

    _keyValues[aKey] = anObject;

    [self didChangeValueForKey:aKey];
}

- (id<NSObject, NSCopying, NSCoding>)_objectForKey:(NSString *)aKey {
    return _keyValues[aKey];;
}

@end

@interface ACArchiverCenter () {
    NSMutableDictionary<NSString*, id<ACArchiveStorage>> *_cachedStorages;
    NSMutableArray<NSString *> *_storageNames;

    NSString *_rootFolderPath;
    NSString *_storageNamesFilePath;

    NSRecursiveLock *_lock;
}

@end

@implementation ACArchiverCenter
@synthesize directory = _directory, uniqueIdentifier = _uniqueIdentifier;

+ (id)defaultCenter {
    static ACArchiverCenter *center = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *rootFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        center = [[self alloc] initWithUniqueIdentifier:ACArchiverCenterDefaultName directory:rootFolder];
    });
    return center;
}

+ (id<ACArchiveStorage>)defaultStorage {
    return [[self defaultCenter] defaultStorage];
}

- (id<ACArchiveStorage>)defaultStorage {
    return [self requireStorageWithName:ACArchiverStorageDefaultName];
}

- (instancetype)initWithUniqueIdentifier:(NSString *)uniqueIdentifier directory:(NSString *)directory {
    if (self = [super init]) {
        _directory = directory;
        _uniqueIdentifier = uniqueIdentifier;
        _storageNames = [NSMutableArray array];
        _cachedStorages = [NSMutableDictionary dictionary];

        _rootFolderPath = [NSString stringWithFormat:@"%@/%@/%@", _directory, ACArchiverCenterRootFolderPath, _uniqueIdentifier];
        _storageNamesFilePath = [self _storageFilePathWithName:ACArchiverCenterStorageNamesFilename folderPath:_rootFolderPath];

        _lock = [[NSRecursiveLock alloc] init];

        [self _reloadAll];
    }
    return self;
}

#pragma mark = accessor

- (NSArray<NSString *> *)storageNames {
    __block NSArray<NSString *> *storageNames = nil;
    [self _synchronzie:^{
        storageNames = [_storageNames copy];
    }];
    return storageNames;
}

- (NSString *)directory {
    __block NSString *directory = nil;
    [self _synchronzie:^{
        directory = [_directory copy];
    }];
    return directory;
}

- (NSString *)uniqueIdentifier {
    __block NSString *uniqueIdentifier = nil;
    [self _synchronzie:^{
        uniqueIdentifier = [_uniqueIdentifier copy];
    }];
    return uniqueIdentifier;
}

#pragma mark - private

- (void)_synchronzie:(void (^)(void))block {
    [_lock lock];
    block();
    [_lock unlock];
}

- (NSString *)_storageFilePathWithName:(NSString *)name folderPath:(NSString *)folderPath {
    return [NSString stringWithFormat:@"%@/%@.archiver", folderPath, name];
}

- (BOOL)_saveStorageNames {
    return [NSKeyedArchiver archiveRootObject:_storageNames toFile:_storageNamesFilePath];
}

- (void)_readStorageNames {
    NSString *folder = _rootFolderPath;

    BOOL isDirectory = NO;
    void (^createDirectoryHandler)(void) = ^{
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"Failed to create directorr with error : %@", error);
        }
    };
    BOOL exist = [[NSFileManager defaultManager] fileExistsAtPath:folder isDirectory:&isDirectory];
    if (exist) {
        if (!isDirectory) {
            NSError *error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:folder error:&error];
            if (error) {
                NSLog(@"Failed to remove file path with error : %@", error);
            }
            createDirectoryHandler();
        }
    } else {
        createDirectoryHandler();
    }

    _storageNames = [NSKeyedUnarchiver unarchiveObjectWithFile:_storageNamesFilePath] ?: [NSMutableArray array];
}

#pragma mark - private

- (id<ACArchiveStorage>)_requireStorageWithName:(NSString *)name {
    NSParameterAssert([name length]);
    id<ACArchiveStorage> (^newStorage)(NSString *storageName) = ^(NSString *storageName){
        // New an storage from archive file.
        NSString *filePath = [self _storageFilePathWithName:storageName folderPath:_rootFolderPath];

        id<ACArchiveStorage> storage = [ACArchiveStorage archiveStorageWithName:storageName filePath:filePath];
        if (storage) _cachedStorages[name] = storage;

        return storage;
    };
    // Append name if the storage hasn't loaded.
    id<ACArchiveStorage> result = nil;
    if (![_storageNames containsObject:name] || (result = _cachedStorages[name]) == nil) {
        result = newStorage(name);
    }

    if (result && ![_storageNames containsObject:name]) {
        [_storageNames addObject:name];
        [self _saveStorageNames];
    }

    return result;
}

- (void)_reloadAll {
    [_storageNames removeAllObjects];

    for (id<ACArchiveStorage> storage in [_cachedStorages allValues]) {
        [storage reload];
    }
    [self _readStorageNames];
}

- (void)_saveAll {
    for (id<ACArchiveStorage> storage in [_cachedStorages allValues]) {
        [storage save];
    }
    [self _saveStorageNames];
}

#pragma mark - public

- (id<ACArchiveStorage>)requireStorageWithName:(NSString *)name {
    __block id<ACArchiveStorage> result = nil;
    [self _synchronzie:^{
        result = [self _requireStorageWithName:name];
    }];
    return result;
}

- (void)reloadAll {
    [self _synchronzie:^{
        [self _reloadAll];
    }];
}

- (void)saveAll {
    [self _synchronzie:^{
        [self _saveAll];
    }];
}

@end
