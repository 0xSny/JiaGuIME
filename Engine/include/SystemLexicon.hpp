#pragma once

#include "LexiconFormat.hpp"
#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace jiagu {

class SystemLexicon {
public:
    SystemLexicon() = default;
    ~SystemLexicon();

    SystemLexicon(const SystemLexicon&) = delete;
    SystemLexicon& operator=(const SystemLexicon&) = delete;

    bool loadMmap(const char* path);
    void unload();

    bool isLoaded() const { return base_ != nullptr; }
    uint32_t wordCount() const { return header_ ? header_->numWords : 0; }
    uint32_t bigramCount() const { return header_ ? header_->numBigrams : 0; }

    // Node & word accessors (zero-copy views into mmap)
    const TrieNode* rootNode() const;
    const TrieNode* nodeAt(uint32_t idx) const;
    const TrieNode* findChild(const TrieNode* parent, uint16_t syllableId) const;

    const WordEntry* wordAt(uint32_t wordId) const;
    std::string_view wordText(uint32_t wordId) const;
    std::string_view wordText(const WordEntry& entry) const;

    // Reconstruct canonical syllable IDs for a word by walking parentIndex
    void getWordSyllables(uint32_t wordId, std::vector<uint16_t>& outSyllables) const;

    // Best word ID for a given exact UTF-8 text (via trie or fallback linear? Used sparingly)
    uint32_t findBigramScore(uint32_t prevWordId, uint32_t currWordId) const;

    // Lookup Jianpin (initial letters, 2..6 chars) top word IDs
    void lookupInitials(std::string_view initials, std::vector<uint32_t>& outWordIds) const;

    // Collect top prefix-extended words under a TrieNode (up to maxDepthDelta extra syllables)
    void collectPrefixWords(const TrieNode* startNode,
                            uint32_t maxExtraDepth,
                            uint32_t limit,
                            std::vector<uint32_t>& outWordIds) const;

private:
    const uint8_t* base_ = nullptr;
    size_t fileSize_ = 0;
    int fd_ = -1;

    const LexiconHeader* header_ = nullptr;
    const TrieNode* nodes_ = nullptr;
    const WordEntry* words_ = nullptr;
    const BigramEntry* bigrams_ = nullptr;
    const InitTrieNode* initNodes_ = nullptr;
    const uint32_t* initRefs_ = nullptr;
    const char* strings_ = nullptr;
    size_t stringsSize_ = 0;
};

} // namespace jiagu
