#include "SystemLexicon.hpp"

#include <algorithm>
#include <cstring>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

namespace jiagu {

SystemLexicon::~SystemLexicon() {
    unload();
}

void SystemLexicon::unload() {
    if (base_ != nullptr && fileSize_ > 0) {
        munmap(const_cast<uint8_t*>(base_), fileSize_);
    }
    if (fd_ >= 0) {
        close(fd_);
    }
    base_ = nullptr;
    fileSize_ = 0;
    fd_ = -1;
    header_ = nullptr;
    nodes_ = nullptr;
    words_ = nullptr;
    bigrams_ = nullptr;
    initNodes_ = nullptr;
    initRefs_ = nullptr;
    strings_ = nullptr;
    stringsSize_ = 0;
}

bool SystemLexicon::loadMmap(const char* path) {
    unload();
    if (!path) return false;

    int fd = open(path, O_RDONLY);
    if (fd < 0) return false;

    struct stat st {};
    if (fstat(fd, &st) != 0 || st.st_size < static_cast<off_t>(sizeof(LexiconHeader))) {
        close(fd);
        return false;
    }

    size_t fsize = static_cast<size_t>(st.st_size);
    void* mapped = mmap(nullptr, fsize, PROT_READ, MAP_SHARED, fd, 0);
    if (mapped == MAP_FAILED) {
        close(fd);
        return false;
    }

    const uint8_t* ptr = static_cast<const uint8_t*>(mapped);
    const auto* hdr = reinterpret_cast<const LexiconHeader*>(ptr);

    if (std::memcmp(hdr->magic, kLexiconMagic, sizeof(kLexiconMagic)) != 0 ||
        hdr->version != kLexiconVersion ||
        hdr->headerSize != sizeof(LexiconHeader) ||
        hdr->totalSize != fsize) {
        munmap(mapped, fsize);
        close(fd);
        return false;
    }

    auto checkSpan = [&](uint64_t off, uint64_t count, size_t elemSize) -> bool {
        if (off < sizeof(LexiconHeader) || off > fsize) return false;
        uint64_t bytes = count * elemSize;
        return bytes <= fsize - off;
    };

    if (!checkSpan(hdr->offsetNodes, hdr->numNodes, sizeof(TrieNode)) ||
        !checkSpan(hdr->offsetWords, hdr->numWords, sizeof(WordEntry)) ||
        !checkSpan(hdr->offsetBigrams, hdr->numBigrams, sizeof(BigramEntry)) ||
        !checkSpan(hdr->offsetInitNodes, hdr->numInitNodes, sizeof(InitTrieNode)) ||
        !checkSpan(hdr->offsetInitRefs, hdr->numInitRefs, sizeof(uint32_t)) ||
        hdr->offsetStrings > fsize) {
        munmap(mapped, fsize);
        close(fd);
        return false;
    }

    fd_ = fd;
    base_ = ptr;
    fileSize_ = fsize;
    header_ = hdr;
    nodes_ = reinterpret_cast<const TrieNode*>(ptr + hdr->offsetNodes);
    words_ = reinterpret_cast<const WordEntry*>(ptr + hdr->offsetWords);
    bigrams_ = reinterpret_cast<const BigramEntry*>(ptr + hdr->offsetBigrams);
    initNodes_ = reinterpret_cast<const InitTrieNode*>(ptr + hdr->offsetInitNodes);
    initRefs_ = reinterpret_cast<const uint32_t*>(ptr + hdr->offsetInitRefs);
    strings_ = reinterpret_cast<const char*>(ptr + hdr->offsetStrings);
    stringsSize_ = fsize - hdr->offsetStrings;

    return true;
}

const TrieNode* SystemLexicon::rootNode() const {
    if (!nodes_ || !header_ || header_->numNodes == 0) return nullptr;
    return &nodes_[0];
}

const TrieNode* SystemLexicon::nodeAt(uint32_t idx) const {
    if (!nodes_ || !header_ || idx >= header_->numNodes) return nullptr;
    return &nodes_[idx];
}

const TrieNode* SystemLexicon::findChild(const TrieNode* parent, uint16_t syllableId) const {
    if (!parent || !nodes_ || parent->childCount == 0) return nullptr;
    uint32_t lo = parent->childStart;
    uint32_t hi = lo + parent->childCount;
    if (hi > header_->numNodes) return nullptr;

    while (lo < hi) {
        uint32_t mid = lo + ((hi - lo) >> 1);
        uint16_t sid = nodes_[mid].syllableId;
        if (sid == syllableId) return &nodes_[mid];
        if (sid < syllableId) lo = mid + 1;
        else hi = mid;
    }
    return nullptr;
}

const WordEntry* SystemLexicon::wordAt(uint32_t wordId) const {
    if (!words_ || !header_ || wordId >= header_->numWords) return nullptr;
    return &words_[wordId];
}

std::string_view SystemLexicon::wordText(uint32_t wordId) const {
    const WordEntry* w = wordAt(wordId);
    if (!w) return {};
    return wordText(*w);
}

std::string_view SystemLexicon::wordText(const WordEntry& entry) const {
    if (!strings_ || static_cast<size_t>(entry.textOffset) + entry.textByteLen > stringsSize_) {
        return {};
    }
    return std::string_view(strings_ + entry.textOffset, entry.textByteLen);
}

void SystemLexicon::getWordSyllables(uint32_t wordId, std::vector<uint16_t>& outSyllables) const {
    outSyllables.clear();
    const WordEntry* w = wordAt(wordId);
    if (!w) return;
    uint32_t cur = w->nodeIndex;
    while (cur != 0 && cur < header_->numNodes) {
        const TrieNode& n = nodes_[cur];
        if (n.syllableId != 0) outSyllables.push_back(n.syllableId);
        cur = n.parentIndex;
    }
    std::reverse(outSyllables.begin(), outSyllables.end());
}

uint32_t SystemLexicon::findBigramScore(uint32_t prevWordId, uint32_t currWordId) const {
    if (!bigrams_ || !header_ || header_->numBigrams == 0) return 0;
    uint32_t lo = 0;
    uint32_t hi = header_->numBigrams;
    while (lo < hi) {
        uint32_t mid = lo + ((hi - lo) >> 1);
        const BigramEntry& b = bigrams_[mid];
        if (b.prevWordId < prevWordId || (b.prevWordId == prevWordId && b.currWordId < currWordId)) {
            lo = mid + 1;
        } else if (b.prevWordId > prevWordId || (b.prevWordId == prevWordId && b.currWordId > currWordId)) {
            hi = mid;
        } else {
            return b.logProb;
        }
    }
    return 0;
}

void SystemLexicon::lookupInitials(std::string_view initials, std::vector<uint32_t>& outWordIds) const {
    outWordIds.clear();
    if (!initNodes_ || !initRefs_ || !header_ || header_->numInitNodes == 0) return;
    if (initials.size() < 2 || initials.size() > 6) return;

    const InitTrieNode* cur = &initNodes_[0];
    for (char ch : initials) {
        uint8_t target = static_cast<uint8_t>(ch);
        if (cur->childCount == 0) return;
        uint32_t lo = cur->childStart;
        uint32_t hi = lo + cur->childCount;
        if (hi > header_->numInitNodes) return;
        const InitTrieNode* found = nullptr;
        while (lo < hi) {
            uint32_t mid = lo + ((hi - lo) >> 1);
            uint8_t ltr = initNodes_[mid].letter;
            if (ltr == target) { found = &initNodes_[mid]; break; }
            if (ltr < target) lo = mid + 1;
            else hi = mid;
        }
        if (!found) return;
        cur = found;
    }

    uint32_t end = cur->refStart + cur->refCount;
    if (end > header_->numInitRefs) return;
    outWordIds.reserve(cur->refCount);
    for (uint32_t i = cur->refStart; i < end; ++i) {
        outWordIds.push_back(initRefs_[i]);
    }
}

void SystemLexicon::collectPrefixWords(const TrieNode* startNode,
                                       uint32_t maxExtraDepth,
                                       uint32_t limit,
                                       std::vector<uint32_t>& outWordIds) const {
    outWordIds.clear();
    if (!startNode || !nodes_ || !words_) return;

    struct QueueItem {
        const TrieNode* node;
        uint32_t depth;
    };
    std::vector<QueueItem> stack;
    stack.reserve(64);
    for (uint32_t i = 0; i < startNode->childCount; ++i) {
        const TrieNode* c = nodeAt(startNode->childStart + i);
        if (c) stack.push_back({c, 1});
    }
    // Sort children by maxSubtreeFreq descending
    std::sort(stack.begin(), stack.end(), [](const QueueItem& a, const QueueItem& b) {
        return a.node->maxSubtreeFreq > b.node->maxSubtreeFreq;
    });

    while (!stack.empty() && outWordIds.size() < limit * 2) {
        QueueItem top = stack.front();
        stack.erase(stack.begin());
        if (top.node->wordCount > 0) {
            uint32_t take = std::min<uint32_t>(top.node->wordCount, 4);
            for (uint32_t k = 0; k < take; ++k) {
                uint32_t wid = top.node->wordStart + k;
                if (wid < header_->numWords) outWordIds.push_back(wid);
            }
        }
        if (top.depth < maxExtraDepth) {
            for (uint32_t i = 0; i < top.node->childCount && i < 12; ++i) {
                const TrieNode* c = nodeAt(top.node->childStart + i);
                if (c) stack.push_back({c, top.depth + 1});
            }
            std::sort(stack.begin(), stack.end(), [](const QueueItem& a, const QueueItem& b) {
                return a.node->maxSubtreeFreq > b.node->maxSubtreeFreq;
            });
            if (stack.size() > 48) stack.resize(48);
        }
    }

    std::sort(outWordIds.begin(), outWordIds.end(), [&](uint32_t a, uint32_t b) {
        return words_[a].logFreq > words_[b].logFreq;
    });
    if (outWordIds.size() > limit) outWordIds.resize(limit);
}

} // namespace jiagu
