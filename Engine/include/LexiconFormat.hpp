#pragma once

#include <cstddef>
#include <cstdint>

namespace jiagu {

static constexpr char kLexiconMagic[8] = {'J', 'G', 'L', 'E', 'X', '0', '1', '\0'};
static constexpr uint32_t kLexiconVersion = 1;

#pragma pack(push, 1)

struct LexiconHeader {
    char magic[8];
    uint32_t version;
    uint32_t headerSize;
    uint32_t flags;
    uint32_t crc32;
    uint64_t totalSize;
    uint32_t numSyllables;
    uint32_t numNodes;
    uint32_t numWords;
    uint32_t numBigrams;
    uint32_t numInitNodes;
    uint32_t numInitRefs;
    uint32_t offsetNodes;
    uint32_t offsetWords;
    uint32_t offsetBigrams;
    uint32_t offsetInitNodes;
    uint32_t offsetInitRefs;
    uint32_t offsetStrings;
};

struct TrieNode {
    uint16_t syllableId;
    uint16_t depth;
    uint32_t parentIndex;
    uint32_t childStart;
    uint32_t childCount;
    uint32_t wordStart;
    uint32_t wordCount;
    uint32_t maxSubtreeFreq;
};

struct WordEntry {
    uint32_t textOffset;
    uint16_t textByteLen;
    uint8_t charCount;
    uint8_t flags;
    uint32_t logFreq;
    uint32_t nodeIndex;
};

struct BigramEntry {
    uint32_t prevWordId;
    uint32_t currWordId;
    uint32_t logProb;
    uint32_t reserved;
};

struct InitTrieNode {
    uint8_t letter;
    uint8_t depth;
    uint16_t reserved;
    uint32_t childStart;
    uint32_t childCount;
    uint32_t refStart;
    uint32_t refCount;
    uint32_t reserved2;
};

#pragma pack(pop)

static_assert(sizeof(LexiconHeader) == 80, "LexiconHeader must be 80 bytes");
static_assert(sizeof(TrieNode) == 28, "TrieNode must be 28 bytes");
static_assert(sizeof(WordEntry) == 16, "WordEntry must be 16 bytes");
static_assert(sizeof(BigramEntry) == 16, "BigramEntry must be 16 bytes");
static_assert(sizeof(InitTrieNode) == 24, "InitTrieNode must be 24 bytes");

} // namespace jiagu
