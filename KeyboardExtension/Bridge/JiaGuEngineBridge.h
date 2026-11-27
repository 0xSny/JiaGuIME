#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JiaGuCandidateObjC : NSObject
@property (nonatomic, copy, readonly) NSString *text;
@property (nonatomic, assign, readonly) NSInteger consumedKeys;
@property (nonatomic, assign, readonly) NSInteger tier;
@property (nonatomic, assign, readonly) BOOL isUserWord;
@property (nonatomic, assign, readonly) BOOL isCustomPhrase;
@end

@interface JiaGuDecodeResultObjC : NSObject
@property (nonatomic, copy, readonly) NSString *preeditDisplay;
@property (nonatomic, copy, readonly) NSArray<JiaGuCandidateObjC *> *candidates;
@property (nonatomic, assign, readonly) uint32_t nextLetterMask;
@end

@interface JiaGuEngineBridge : NSObject

- (instancetype)initWithLexiconPath:(NSString *)lexiconPath userStorageDir:(NSString *)userDir;

@property (nonatomic, assign, readonly) BOOL isLexiconLoaded;

- (void)configureMode:(NSInteger)mode
            fuzzyMask:(uint32_t)fuzzyMask
   spatialSensitivity:(float)spatialSensitivity
xiaoheExpandedPreedit:(BOOL)expandedPreedit;

- (void)setCustomPhrases:(NSArray<NSDictionary<NSString *, NSString *> *> *)phrases;
- (void)setPrevCommittedWord:(NSString *)word;

- (void)pushStrokePrimary:(unichar)primaryChar
                 alt1Char:(unichar)alt1Char
              alt1LogProb:(float)alt1LogProb
                 alt2Char:(unichar)alt2Char
              alt2LogProb:(float)alt2LogProb;

- (void)popStroke;
- (void)clearStrokes;

- (NSInteger)strokeCount;
- (NSString *)rawInputString;
- (NSString *)optimisticPreedit;

- (void)requestAsyncDecode:(void (^)(JiaGuDecodeResultObjC *result))completion;

// Returns committed text; sets *compositionFinished and *synthesizedPhrase
- (NSString *)commitCandidateAtIndex:(NSInteger)index
                 compositionFinished:(BOOL *)compositionFinished
                   synthesizedPhrase:(NSString * _Nullable * _Nullable)synthesizedPhrase;

- (void)notifyBackspaceAfterCommit;
- (void)clearRegretHistory;
- (void)flushUserLexiconAsync;
- (void)clearUserLexicon;
- (BOOL)forgetUserWord:(NSString *)wordText;
- (NSUInteger)userLearnedCount;

@end

NS_ASSUME_NONNULL_END
