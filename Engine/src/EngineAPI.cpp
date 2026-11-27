#include "EngineAPI.hpp"

#include <chrono>

namespace jiagu {

uint64_t EngineAPI::nowEpochSec() {
    auto now = std::chrono::system_clock::now().time_since_epoch();
    return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::seconds>(now).count());
}

bool EngineAPI::initialize(const std::string& lexiconPath, const std::string& userStorageDir) {
    bool ok = sysLex_.loadMmap(lexiconPath.c_str());
    userLex_.load(userStorageDir);
    return ok;
}

void EngineAPI::flushUserLexicon() {
    userLex_.flushToDisk();
}

void EngineAPI::clearUserLexicon() {
    userLex_.clearAll();
    hasLastCommit_ = false;
}

bool EngineAPI::forgetUserWord(const std::string& wordText) {
    return userLex_.forgetWord(wordText);
}

uint32_t EngineAPI::userLearnedCount() const {
    return userLex_.learnedWordCount();
}

void EngineAPI::setConfig(const DecoderConfig& config) {
    config_ = config;
}

void EngineAPI::setCustomPhrases(std::vector<CustomPhrase> phrases) {
    customPhrases_ = std::move(phrases);
}

void EngineAPI::setPrevCommittedWord(const std::string& word) {
    prevCommittedWord_ = word;
}

void EngineAPI::pushKeyStroke(const KeyStroke& stroke) {
    strokes_.push_back(stroke);
}

void EngineAPI::popKeyStroke() {
    if (!strokes_.empty()) {
        strokes_.pop_back();
    }
    if (strokes_.empty()) {
        pendingSegments_.clear();
    }
}

void EngineAPI::clearStrokes() {
    strokes_.clear();
    pendingSegments_.clear();
}

std::string EngineAPI::rawInputString() const {
    std::string s;
    s.reserve(strokes_.size());
    for (const auto& k : strokes_) s.push_back(k.primaryKey);
    return s;
}

std::string EngineAPI::optimisticPreedit() const {
    if (strokes_.empty()) return {};
    if (config_.mode == InputMode::XiaoheShuangpin) {
        const auto& st = SyllableTable::instance();
        std::string out;
        size_t i = 0;
        while (i < strokes_.size()) {
            if (!out.empty()) out.push_back(' ');
            char c1 = strokes_[i].primaryKey;
            if (c1 == '\'') { ++i; continue; }
            if (i + 1 < strokes_.size() && strokes_[i + 1].primaryKey != '\'') {
                char c2 = strokes_[i + 1].primaryKey;
                const auto& ids = st.lookupXiaohe(c1, c2);
                if (!ids.empty() && config_.xiaoheShowExpandedPreedit) {
                    out += std::string(st.name(ids[0]));
                } else {
                    out.push_back(c1);
                    out.push_back(c2);
                }
                i += 2;
            } else {
                out.push_back(c1);
                i += 1;
            }
        }
        return out;
    }
    return rawInputString();
}

uint32_t EngineAPI::nextLetterMask() const {
    return decoder_.predictNextLetterMask(strokes_, config_);
}

uint64_t EngineAPI::bumpGeneration() {
    return generation_.fetch_add(1, std::memory_order_acq_rel) + 1;
}

DecodeOutput EngineAPI::decodeCurrent(uint64_t expectedGeneration) const {
    return decoder_.decode(strokes_, config_, prevCommittedWord_, customPhrases_,
                           generation_, expectedGeneration, nowEpochSec());
}

SelectionResult EngineAPI::commitCandidate(const CandidateItem& candidate) {
    SelectionResult res;
    res.committedText = candidate.text;

    if (candidate.text.empty()) return res;

    // Record individual selection in UserLexicon (skip custom phrases)
    if (!candidate.isCustomPhrase && !candidate.syllables.empty()) {
        lastCommitEvent_ = userLex_.recordSelection(prevCommittedWord_, candidate.text, candidate.syllables, false);
        lastCommittedText_ = candidate.text;
        hasLastCommit_ = true;
    } else {
        hasLastCommit_ = false;
    }

    if (!candidate.isCustomPhrase && !candidate.syllables.empty()) {
        pendingSegments_.push_back({candidate.text, candidate.syllables});
    }

    // Consume strokes covered by this candidate
    uint8_t consumed = candidate.consumedKeys;
    if (consumed >= strokes_.size()) {
        strokes_.clear();
        res.compositionFinished = true;

        // Synthesize multi-segment phrase if user selected >= 2 segments sequentially
        if (pendingSegments_.size() >= 2) {
            std::string fullText;
            std::vector<uint16_t> fullSyls;
            for (const auto& seg : pendingSegments_) {
                fullText += seg.text;
                fullSyls.insert(fullSyls.end(), seg.syllables.begin(), seg.syllables.end());
            }
            if (fullSyls.size() <= 8) {
                lastCommitEvent_ = userLex_.recordSelection(prevCommittedWord_, fullText, fullSyls, true);
                lastCommittedText_ = fullText;
                hasLastCommit_ = true;
                res.synthesizedPhrase = fullText;
            }
        }
        pendingSegments_.clear();
    } else if (consumed > 0) {
        strokes_.erase(strokes_.begin(), strokes_.begin() + consumed);
        // Strip leading separators
        while (!strokes_.empty() && strokes_.front().primaryKey == '\'') {
            strokes_.erase(strokes_.begin());
        }
        res.compositionFinished = strokes_.empty();
    }

    prevCommittedWord_ = candidate.text;
    return res;
}

void EngineAPI::notifyBackspaceAfterCommit() {
    if (hasLastCommit_) {
        userLex_.rollbackRegret(lastCommitEvent_);
        hasLastCommit_ = false;
    }
}

void EngineAPI::clearRegretHistory() {
    hasLastCommit_ = false;
}

} // namespace jiagu
