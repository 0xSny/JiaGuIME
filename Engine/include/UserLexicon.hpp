#pragma once

#include <cstdint>
#include <mutex>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace jiagu {

struct UserWordRecord {
    std::string text;
    std::vector<uint16_t> syllables;
    std::string initials;
    uint32_t freq = 1;
    uint64_t lastUsedEpochSec = 0;
    bool isAutoPhrase = false;
};

struct UserContextEvent {
    std::string prevWord;
    std::string currWord;
    uint32_t prevCountDelta = 1;
    std::string committedText;
    std::vector<uint16_t> committedSyllables;
    bool createdNewPhrase = false;
    uint32_t previousFreq = 0;
    uint64_t previousTimestamp = 0;
};

class UserLexicon {
public:
    UserLexicon() = default;

    // Load snapshot + replay WAL from directory (safe if directory doesn't exist yet)
    bool load(const std::string& storageDir);

    // Flush WAL or compact snapshot to disk (called only when keyboard resigns/backgrounds)
    bool flushToDisk();

    // Clear all learned words and context bigrams
    void clearAll();

    uint32_t learnedWordCount() const;

    // Record user selection (in-memory only, zero disk I/O)
    UserContextEvent recordSelection(std::string_view prevWord,
                                     std::string_view text,
                                     const std::vector<uint16_t>& syllables,
                                     bool isAutoPhrase);

    // Regret rollback: undo or heavily penalize a word that user immediately backspaced
    void rollbackRegret(const UserContextEvent& event);

    // Forget / reset a specific learned word (e.g., long-press candidate delete)
    bool forgetWord(std::string_view text);

    // Query exact syllable sequence matches
    void queryExact(const std::vector<uint16_t>& syllables,
                    uint64_t nowSec,
                    std::vector<std::pair<std::string, float>>& outResults) const;

    // Query Jianpin initials matches
    void queryInitials(std::string_view initials,
                       uint64_t nowSec,
                       std::vector<std::pair<std::string, float>>& outResults) const;

    // Query personal context bigram bonus
    float queryBigramBonus(std::string_view prevWord, std::string_view currWord, uint64_t nowSec) const;

private:
    mutable std::mutex mutex_;
    std::string storageDir_;
    bool dirty_ = false;
    uint32_t walOpsSinceCompact_ = 0;

    // Key: UTF-8 text + '\t' + comma-joined syllable IDs
    std::unordered_map<std::string, UserWordRecord> records_;
    // Index by syllable key -> record keys
    std::unordered_map<std::string, std::vector<std::string>> sylIndex_;
    // Index by initials -> record keys
    std::unordered_map<std::string, std::vector<std::string>> initIndex_;
    // Personal context bigrams: "prev\tcurr" -> (count, lastUsedSec)
    struct BigramStat {
        uint32_t count = 0;
        uint64_t lastUsedSec = 0;
    };
    std::unordered_map<std::string, BigramStat> bigrams_;

    // Pending WAL lines written on flushToDisk()
    std::vector<std::string> pendingWalLines_;

    static std::string makeSylKey(const std::vector<uint16_t>& syllables);
    static std::string makeRecordKey(std::string_view text, const std::vector<uint16_t>& syllables);
    static float computeDecayedScore(uint32_t freq, uint64_t lastUsedSec, uint64_t nowSec, bool isAutoPhrase);

    bool loadSnapshotLocked(const std::string& path);
    bool replayWalLocked(const std::string& path);
    bool writeSnapshotLocked(const std::string& path);
    void indexRecordLocked(const std::string& rkey, const UserWordRecord& rec);
};

} // namespace jiagu
