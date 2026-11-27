#import "JiaGuEngineBridge.h"
#include "EngineAPI.hpp"

#include <mutex>
#include <vector>

@interface JiaGuCandidateObjC ()
@property (nonatomic, copy, readwrite) NSString *text;
@property (nonatomic, assign, readwrite) NSInteger consumedKeys;
@property (nonatomic, assign, readwrite) NSInteger tier;
@property (nonatomic, assign, readwrite) BOOL isUserWord;
@property (nonatomic, assign, readwrite) BOOL isCustomPhrase;
@property (nonatomic, assign) jiagu::CandidateItem cppItem;
@end

@implementation JiaGuCandidateObjC
@end

@interface JiaGuDecodeResultObjC ()
@property (nonatomic, copy, readwrite) NSString *preeditDisplay;
@property (nonatomic, copy, readwrite) NSArray<JiaGuCandidateObjC *> *candidates;
@property (nonatomic, assign, readwrite) uint32_t nextLetterMask;
@end

@implementation JiaGuDecodeResultObjC
@end

@implementation JiaGuEngineBridge {
    jiagu::EngineAPI _engine;
    std::mutex _engineMutex;
    dispatch_queue_t _decodeQueue;
    BOOL _loaded;
    std::vector<jiagu::CandidateItem> _lastCandidates;
}

- (instancetype)initWithLexiconPath:(NSString *)lexiconPath userStorageDir:(NSString *)userDir {
    self = [super init];
    if (self) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0
        );
        _decodeQueue = dispatch_queue_create("com.custom.ime.decode", attr);
        _loaded = _engine.initialize(lexiconPath.UTF8String ?: "", userDir.UTF8String ?: "");
    }
    return self;
}

- (BOOL)isLexiconLoaded {
    return _loaded;
}

- (void)configureMode:(NSInteger)mode
            fuzzyMask:(uint32_t)fuzzyMask
   spatialSensitivity:(float)spatialSensitivity
xiaoheExpandedPreedit:(BOOL)expandedPreedit {
    std::lock_guard<std::mutex> lock(_engineMutex);
    jiagu::DecoderConfig cfg;
    cfg.mode = (mode == 1) ? jiagu::InputMode::XiaoheShuangpin : jiagu::InputMode::FullPinyin;
    cfg.fuzzyMask = fuzzyMask;
    cfg.spatialWeight = spatialSensitivity;
    cfg.enableTransposition = true;
    cfg.xiaoheShowExpandedPreedit = expandedPreedit;
    _engine.setConfig(cfg);
}

- (void)setCustomPhrases:(NSArray<NSDictionary<NSString *, NSString *> *> *)phrases {
    std::vector<jiagu::CustomPhrase> list;
    list.reserve(phrases.count);
    for (NSDictionary<NSString *, NSString *> *dict in phrases) {
        NSString *abbr = dict[@"abbr"];
        NSString *text = dict[@"text"];
        if (abbr.length > 0 && text.length > 0) {
            list.push_back({abbr.lowercaseString.UTF8String, text.UTF8String});
        }
    }
    std::lock_guard<std::mutex> lock(_engineMutex);
    _engine.setCustomPhrases(std::move(list));
}

- (void)setPrevCommittedWord:(NSString *)word {
    std::lock_guard<std::mutex> lock(_engineMutex);
    _engine.setPrevCommittedWord(word.UTF8String ?: "");
}

- (void)pushStrokePrimary:(unichar)primaryChar
                 alt1Char:(unichar)alt1Char
              alt1LogProb:(float)alt1LogProb
                 alt2Char:(unichar)alt2Char
              alt2LogProb:(float)alt2LogProb {
    jiagu::KeyStroke ks;
    ks.primaryKey = static_cast<char>(primaryChar);
    ks.alternatives.push_back({ks.primaryKey, 0.0f});
    if (alt1Char >= 'a' && alt1Char <= 'z') {
        ks.alternatives.push_back({static_cast<char>(alt1Char), alt1LogProb});
    }
    if (alt2Char >= 'a' && alt2Char <= 'z') {
        ks.alternatives.push_back({static_cast<char>(alt2Char), alt2LogProb});
    }
    std::lock_guard<std::mutex> lock(_engineMutex);
    _engine.pushKeyStroke(ks);
}

- (void)popStroke {
    std::lock_guard<std::mutex> lock(_engineMutex);
    _engine.popKeyStroke();
}

- (void)clearStrokes {
    std::lock_guard<std::mutex> lock(_engineMutex);
    _engine.clearStrokes();
    _lastCandidates.clear();
}

- (NSInteger)strokeCount {
    std::lock_guard<std::mutex> lock(_engineMutex);
    return static_cast<NSInteger>(_engine.strokeCount());
}

- (NSString *)rawInputString {
    std::lock_guard<std::mutex> lock(_engineMutex);
    return [NSString stringWithUTF8String:_engine.rawInputString().c_str()] ?: @"";
}

- (NSString *)optimisticPreedit {
    std::lock_guard<std::mutex> lock(_engineMutex);
    return [NSString stringWithUTF8String:_engine.optimisticPreedit().c_str()] ?: @"";
}

- (void)requestAsyncDecode:(void (^)(JiaGuDecodeResultObjC *result))completion {
    uint64_t gen = _engine.bumpGeneration();
    __weak JiaGuEngineBridge *weakSelf = self;
    dispatch_async(_decodeQueue, ^{
        __strong JiaGuEngineBridge *strongSelf = weakSelf;
        if (!strongSelf) return;

        jiagu::DecodeOutput out;
        uint32_t nextMask = 0;
        {
            std::lock_guard<std::mutex> lock(strongSelf->_engineMutex);
            out = strongSelf->_engine.decodeCurrent(gen);
            if (!out.cancelled) {
                nextMask = strongSelf->_engine.nextLetterMask();
                strongSelf->_lastCandidates = out.candidates;
            }
        }
        if (out.cancelled) return;

        NSMutableArray<JiaGuCandidateObjC *> *arr = [NSMutableArray arrayWithCapacity:out.candidates.size()];
        for (const auto& c : out.candidates) {
            JiaGuCandidateObjC *obj = [[JiaGuCandidateObjC alloc] init];
            obj.text = [NSString stringWithUTF8String:c.text.c_str()] ?: @"";
            obj.consumedKeys = c.consumedKeys;
            obj.tier = c.tier;
            obj.isUserWord = c.isUserWord;
            obj.isCustomPhrase = c.isCustomPhrase;
            obj.cppItem = c;
            [arr addObject:obj];
        }

        JiaGuDecodeResultObjC *res = [[JiaGuDecodeResultObjC alloc] init];
        res.preeditDisplay = [NSString stringWithUTF8String:out.preeditDisplay.c_str()] ?: @"";
        res.candidates = arr;
        res.nextLetterMask = nextMask;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (strongSelf->_engine.currentGeneration() == gen && completion) {
                completion(res);
            }
        });
    });
}

- (NSString *)commitCandidateAtIndex:(NSInteger)index
                 compositionFinished:(BOOL *)compositionFinished
                   synthesizedPhrase:(NSString * _Nullable * _Nullable)synthesizedPhrase {
    std::lock_guard<std::mutex> lock(_engineMutex);
    if (index < 0 || static_cast<size_t>(index) >= _lastCandidates.size()) {
        if (compositionFinished) *compositionFinished = YES;
        return @"";
    }
    jiagu::SelectionResult sel = _engine.commitCandidate(_lastCandidates[static_cast<size_t>(index)]);
    if (compositionFinished) *compositionFinished = sel.compositionFinished;
    if (synthesizedPhrase && !sel.synthesizedPhrase.empty()) {
        *synthesizedPhrase = [NSString stringWithUTF8String:sel.synthesizedPhrase.c_str()];
    }
    return [NSString stringWithUTF8String:sel.committedText.c_str()] ?: @"";
}

- (void)notifyBackspaceAfterCommit {
    std::lock_guard<std::mutex> lock(_engineMutex);
    _engine.notifyBackspaceAfterCommit();
}

- (void)clearRegretHistory {
    std::lock_guard<std::mutex> lock(_engineMutex);
    _engine.clearRegretHistory();
}

- (void)flushUserLexiconAsync {
    dispatch_async(_decodeQueue, ^{
        std::lock_guard<std::mutex> lock(self->_engineMutex);
        self->_engine.flushUserLexicon();
    });
}

- (void)clearUserLexicon {
    std::lock_guard<std::mutex> lock(_engineMutex);
    _engine.clearUserLexicon();
}

- (BOOL)forgetUserWord:(NSString *)wordText {
    std::lock_guard<std::mutex> lock(_engineMutex);
    return _engine.forgetUserWord(wordText.UTF8String ?: "");
}

- (NSUInteger)userLearnedCount {
    std::lock_guard<std::mutex> lock(_engineMutex);
    return static_cast<NSUInteger>(_engine.userLearnedCount());
}

@end
