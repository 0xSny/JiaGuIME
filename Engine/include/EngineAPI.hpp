#pragma once

#include "Decoder.hpp"
#include "SystemLexicon.hpp"
#include "UserLexicon.hpp"

#include <atomic>
#include <cstdint>
#include <string>
#include <vector>

namespace jiagu {

struct SelectionResult {
    std::string committedText;
    bool compositionFinished = false;
    std::string synthesizedPhrase; // Non-empty if segmented selections formed a multi-part phrase
};

class EngineAPI {
public:
    EngineAPI() : decoder_(sysLex_, userLex_) {}

    bool initialize(const std::string& lexiconPath, const std::string& userStorageDir);
    void flushUserLexicon();
    void clearUserLexicon();
    bool forgetUserWord(const std::string& wordText);
    uint32_t userLearnedCount() const;

    void setConfig(const DecoderConfig& config);
    const DecoderConfig& config() const { return config_; }

    void setCustomPhrases(std::vector<CustomPhrase> phrases);
    void setPrevCommittedWord(const std::string& word);

    // Input session operations
    void pushKeyStroke(const KeyStroke& stroke);
    void popKeyStroke();
    void clearStrokes();
    size_t strokeCount() const { return strokes_.size(); }
    std::string rawInputString() const;

    // Fast optimistic preedit string for main-thread immediate echo
    std::string optimisticPreedit() const;

    // Next-letter bitmask for Voronoi prior
    uint32_t nextLetterMask() const;

    // Run full Viterbi + multi-tier decode (call from interactive serial queue with generation token)
    uint64_t bumpGeneration();
    uint64_t currentGeneration() const { return generation_.load(std::memory_order_acquire); }
    DecodeOutput decodeCurrent(uint64_t expectedGeneration) const;

    // Commit a candidate at index (handles partial segmented selection + auto-phrase synthesis)
    SelectionResult commitCandidate(const CandidateItem& candidate);

    // Regret rollback: call if user presses backspace immediately after a commit
    void notifyBackspaceAfterCommit();
    void clearRegretHistory();

private:
    SystemLexicon sysLex_;
    UserLexicon userLex_;
    Decoder decoder_;
    DecoderConfig config_;
    std::vector<CustomPhrase> customPhrases_;

    std::vector<KeyStroke> strokes_;
    std::string prevCommittedWord_;

    // Segmented selection tracking for automatic multi-segment phrase synthesis
    struct SegmentChoice {
        std::string text;
        std::vector<uint16_t> syllables;
    };
    std::vector<SegmentChoice> pendingSegments_;

    // Regret rollback state
    bool hasLastCommit_ = false;
    UserContextEvent lastCommitEvent_;
    std::string lastCommittedText_;

    std::atomic<uint64_t> generation_{0};

    static uint64_t nowEpochSec();
};

} // namespace jiagu
