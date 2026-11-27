#include "UserLexicon.hpp"
#include "SyllableTable.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <sstream>
#include <sys/stat.h>

namespace jiagu {

static constexpr double kDecayHalfLifeSec = 14.0 * 86400.0; // 14-day exponential decay

static uint64_t currentEpochSec() {
    auto now = std::chrono::system_clock::now().time_since_epoch();
    return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::seconds>(now).count());
}

std::string UserLexicon::makeSylKey(const std::vector<uint16_t>& syllables) {
    std::string k;
    k.reserve(syllables.size() * 4);
    for (size_t i = 0; i < syllables.size(); ++i) {
        if (i > 0) k.push_back(',');
        k += std::to_string(syllables[i]);
    }
    return k;
}

std::string UserLexicon::makeRecordKey(std::string_view text, const std::vector<uint16_t>& syllables) {
    std::string k(text);
    k.push_back('\t');
    k += makeSylKey(syllables);
    return k;
}

float UserLexicon::computeDecayedScore(uint32_t freq, uint64_t lastUsedSec, uint64_t nowSec, bool isAutoPhrase) {
    double dt = (nowSec > lastUsedSec) ? static_cast<double>(nowSec - lastUsedSec) : 0.0;
    double decay = std::exp(-dt / kDecayHalfLifeSec);
    double effectiveFreq = static_cast<double>(freq) * decay;
    double baseBoost = isAutoPhrase ? 28.0 : 18.0;
    return static_cast<float>(baseBoost + std::log1p(effectiveFreq) * 14.0);
}

void UserLexicon::indexRecordLocked(const std::string& rkey, const UserWordRecord& rec) {
    std::string sk = makeSylKey(rec.syllables);
    auto& svec = sylIndex_[sk];
    if (std::find(svec.begin(), svec.end(), rkey) == svec.end()) {
        svec.push_back(rkey);
    }
    if (rec.initials.size() >= 2 && rec.initials.size() <= 8) {
        auto& ivec = initIndex_[rec.initials];
        if (std::find(ivec.begin(), ivec.end(), rkey) == ivec.end()) {
            ivec.push_back(rkey);
        }
    }
}

bool UserLexicon::load(const std::string& storageDir) {
    std::lock_guard<std::mutex> lock(mutex_);
    storageDir_ = storageDir;
    records_.clear();
    sylIndex_.clear();
    initIndex_.clear();
    bigrams_.clear();
    pendingWalLines_.clear();
    dirty_ = false;
    walOpsSinceCompact_ = 0;

    if (storageDir_.empty()) return false;
    mkdir(storageDir_.c_str(), 0755);

    loadSnapshotLocked(storageDir_ + "/user_snapshot.dat");
    replayWalLocked(storageDir_ + "/user_wal.log");
    return true;
}

bool UserLexicon::loadSnapshotLocked(const std::string& path) {
    std::ifstream in(path);
    if (!in.is_open()) return false;
    std::string line;
    while (std::getline(in, line)) {
        if (line.empty()) continue;
        std::istringstream iss(line);
        std::string kind;
        if (!std::getline(iss, kind, '\t')) continue;
        if (kind == "W") {
            std::string text, sylStr, initStr, freqStr, tsStr, autoStr;
            if (!std::getline(iss, text, '\t') ||
                !std::getline(iss, sylStr, '\t') ||
                !std::getline(iss, initStr, '\t') ||
                !std::getline(iss, freqStr, '\t') ||
                !std::getline(iss, tsStr, '\t') ||
                !std::getline(iss, autoStr, '\t')) continue;

            UserWordRecord rec;
            rec.text = text;
            rec.initials = initStr;
            rec.freq = static_cast<uint32_t>(std::stoul(freqStr));
            rec.lastUsedEpochSec = static_cast<uint64_t>(std::stoull(tsStr));
            rec.isAutoPhrase = (autoStr == "1");

            std::istringstream siss(sylStr);
            std::string tok;
            while (std::getline(siss, tok, ',')) {
                if (!tok.empty()) rec.syllables.push_back(static_cast<uint16_t>(std::stoul(tok)));
            }
            if (!rec.text.empty() && !rec.syllables.empty()) {
                std::string rkey = makeRecordKey(rec.text, rec.syllables);
                records_[rkey] = rec;
                indexRecordLocked(rkey, rec);
            }
        } else if (kind == "B") {
            std::string p, c, cntStr, tsStr;
            if (!std::getline(iss, p, '\t') ||
                !std::getline(iss, c, '\t') ||
                !std::getline(iss, cntStr, '\t') ||
                !std::getline(iss, tsStr, '\t')) continue;
            BigramStat st;
            st.count = static_cast<uint32_t>(std::stoul(cntStr));
            st.lastUsedSec = static_cast<uint64_t>(std::stoull(tsStr));
            bigrams_[p + "\t" + c] = st;
        }
    }
    return true;
}

bool UserLexicon::replayWalLocked(const std::string& path) {
    std::ifstream in(path);
    if (!in.is_open()) return false;
    std::string line;
    while (std::getline(in, line)) {
        if (line.empty()) continue;
        ++walOpsSinceCompact_;
        std::istringstream iss(line);
        std::string op;
        if (!std::getline(iss, op, '\t')) continue;
        if (op == "U") {
            std::string text, sylStr, initStr, freqStr, tsStr, autoStr;
            if (!std::getline(iss, text, '\t') ||
                !std::getline(iss, sylStr, '\t') ||
                !std::getline(iss, initStr, '\t') ||
                !std::getline(iss, freqStr, '\t') ||
                !std::getline(iss, tsStr, '\t') ||
                !std::getline(iss, autoStr, '\t')) continue;
            std::vector<uint16_t> syls;
            std::istringstream siss(sylStr);
            std::string tok;
            while (std::getline(siss, tok, ',')) {
                if (!tok.empty()) syls.push_back(static_cast<uint16_t>(std::stoul(tok)));
            }
            if (text.empty() || syls.empty()) continue;
            std::string rkey = makeRecordKey(text, syls);
            auto& rec = records_[rkey];
            rec.text = text;
            rec.syllables = syls;
            rec.initials = initStr;
            rec.freq = static_cast<uint32_t>(std::stoul(freqStr));
            rec.lastUsedEpochSec = static_cast<uint64_t>(std::stoull(tsStr));
            rec.isAutoPhrase = (autoStr == "1");
            indexRecordLocked(rkey, rec);
        } else if (op == "D") {
            std::string text;
            if (!std::getline(iss, text, '\t')) continue;
            for (auto it = records_.begin(); it != records_.end(); ) {
                if (it->second.text == text) it = records_.erase(it);
                else ++it;
            }
        } else if (op == "B") {
            std::string p, c, cntStr, tsStr;
            if (!std::getline(iss, p, '\t') ||
                !std::getline(iss, c, '\t') ||
                !std::getline(iss, cntStr, '\t') ||
                !std::getline(iss, tsStr, '\t')) continue;
            bigrams_[p + "\t" + c] = {
                static_cast<uint32_t>(std::stoul(cntStr)),
                static_cast<uint64_t>(std::stoull(tsStr))
            };
        }
    }
    return true;
}

bool UserLexicon::writeSnapshotLocked(const std::string& path) {
    std::string tmpPath = path + ".tmp";
    std::ofstream out(tmpPath, std::ios::trunc);
    if (!out.is_open()) return false;
    for (const auto& kv : records_) {
        const auto& r = kv.second;
        out << "W\t" << r.text << "\t" << makeSylKey(r.syllables) << "\t"
            << r.initials << "\t" << r.freq << "\t" << r.lastUsedEpochSec << "\t"
            << (r.isAutoPhrase ? "1" : "0") << "\n";
    }
    for (const auto& kv : bigrams_) {
        out << "B\t" << kv.first << "\t" << kv.second.count << "\t" << kv.second.lastUsedSec << "\n";
    }
    out.flush();
    out.close();
    return std::rename(tmpPath.c_str(), path.c_str()) == 0;
}

bool UserLexicon::flushToDisk() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (storageDir_.empty()) return false;
    if (!dirty_ && pendingWalLines_.empty()) return true;

    std::string walPath = storageDir_ + "/user_wal.log";
    std::string snapPath = storageDir_ + "/user_snapshot.dat";

    if (walOpsSinceCompact_ + pendingWalLines_.size() >= 200) {
        if (writeSnapshotLocked(snapPath)) {
            std::remove(walPath.c_str());
            pendingWalLines_.clear();
            walOpsSinceCompact_ = 0;
            dirty_ = false;
            return true;
        }
    }

    if (!pendingWalLines_.empty()) {
        std::ofstream wal(walPath, std::ios::app);
        if (!wal.is_open()) return false;
        for (const auto& line : pendingWalLines_) {
            wal << line << "\n";
        }
        wal.flush();
        walOpsSinceCompact_ += static_cast<uint32_t>(pendingWalLines_.size());
        pendingWalLines_.clear();
    }
    dirty_ = false;
    return true;
}

void UserLexicon::clearAll() {
    std::lock_guard<std::mutex> lock(mutex_);
    records_.clear();
    sylIndex_.clear();
    initIndex_.clear();
    bigrams_.clear();
    pendingWalLines_.clear();
    walOpsSinceCompact_ = 0;
    dirty_ = false;
    if (!storageDir_.empty()) {
        std::remove((storageDir_ + "/user_snapshot.dat").c_str());
        std::remove((storageDir_ + "/user_wal.log").c_str());
    }
}

uint32_t UserLexicon::learnedWordCount() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return static_cast<uint32_t>(records_.size());
}

UserContextEvent UserLexicon::recordSelection(std::string_view prevWord,
                                              std::string_view text,
                                              const std::vector<uint16_t>& syllables,
                                              bool isAutoPhrase) {
    UserContextEvent ev;
    if (text.empty() || syllables.empty()) return ev;

    std::lock_guard<std::mutex> lock(mutex_);
    uint64_t now = currentEpochSec();

    std::string rkey = makeRecordKey(text, syllables);
    auto it = records_.find(rkey);
    if (it == records_.end()) {
        UserWordRecord rec;
        rec.text = std::string(text);
        rec.syllables = syllables;
        const auto& st = SyllableTable::instance();
        for (uint16_t sid : syllables) {
            char ic = st.initialChar(sid);
            if (ic) rec.initials.push_back(ic);
        }
        rec.freq = isAutoPhrase ? 2 : 1;
        rec.lastUsedEpochSec = now;
        rec.isAutoPhrase = isAutoPhrase;
        records_[rkey] = rec;
        indexRecordLocked(rkey, rec);

        ev.createdNewPhrase = true;
        ev.previousFreq = 0;
        ev.previousTimestamp = 0;
        pendingWalLines_.push_back(
            "U\t" + rec.text + "\t" + makeSylKey(rec.syllables) + "\t" + rec.initials +
            "\t" + std::to_string(rec.freq) + "\t" + std::to_string(rec.lastUsedEpochSec) +
            "\t" + (rec.isAutoPhrase ? "1" : "0"));
    } else {
        ev.createdNewPhrase = false;
        ev.previousFreq = it->second.freq;
        ev.previousTimestamp = it->second.lastUsedEpochSec;
        it->second.freq += 1;
        it->second.lastUsedEpochSec = now;
        if (isAutoPhrase) it->second.isAutoPhrase = true;
        const auto& rec = it->second;
        pendingWalLines_.push_back(
            "U\t" + rec.text + "\t" + makeSylKey(rec.syllables) + "\t" + rec.initials +
            "\t" + std::to_string(rec.freq) + "\t" + std::to_string(rec.lastUsedEpochSec) +
            "\t" + (rec.isAutoPhrase ? "1" : "0"));
    }

    ev.committedText = std::string(text);
    ev.committedSyllables = syllables;

    if (!prevWord.empty()) {
        std::string bkey = std::string(prevWord) + "\t" + std::string(text);
        auto& bstat = bigrams_[bkey];
        bstat.count += 1;
        bstat.lastUsedSec = now;
        ev.prevWord = std::string(prevWord);
        ev.currWord = std::string(text);
        ev.prevCountDelta = 1;
        pendingWalLines_.push_back(
            "B\t" + bkey + "\t" + std::to_string(bstat.count) + "\t" + std::to_string(now));
    }

    dirty_ = true;
    return ev;
}

void UserLexicon::rollbackRegret(const UserContextEvent& event) {
    if (event.committedText.empty() || event.committedSyllables.empty()) return;
    std::lock_guard<std::mutex> lock(mutex_);

    std::string rkey = makeRecordKey(event.committedText, event.committedSyllables);
    auto it = records_.find(rkey);
    if (it != records_.end()) {
        if (event.createdNewPhrase || event.previousFreq == 0) {
            records_.erase(it);
            pendingWalLines_.push_back("D\t" + event.committedText);
        } else {
            it->second.freq = event.previousFreq;
            it->second.lastUsedEpochSec = event.previousTimestamp;
            const auto& rec = it->second;
            pendingWalLines_.push_back(
                "U\t" + rec.text + "\t" + makeSylKey(rec.syllables) + "\t" + rec.initials +
                "\t" + std::to_string(rec.freq) + "\t" + std::to_string(rec.lastUsedEpochSec) +
                "\t" + (rec.isAutoPhrase ? "1" : "0"));
        }
        dirty_ = true;
    }

    if (!event.prevWord.empty() && !event.currWord.empty()) {
        std::string bkey = event.prevWord + "\t" + event.currWord;
        auto bit = bigrams_.find(bkey);
        if (bit != bigrams_.end()) {
            if (bit->second.count <= event.prevCountDelta) {
                bigrams_.erase(bit);
            } else {
                bit->second.count -= event.prevCountDelta;
            }
            dirty_ = true;
        }
    }
}

bool UserLexicon::forgetWord(std::string_view text) {
    if (text.empty()) return false;
    std::lock_guard<std::mutex> lock(mutex_);
    bool erased = false;
    for (auto it = records_.begin(); it != records_.end(); ) {
        if (it->second.text == text) {
            it = records_.erase(it);
            erased = true;
        } else {
            ++it;
        }
    }
    if (erased) {
        pendingWalLines_.push_back("D\t" + std::string(text));
        dirty_ = true;
    }
    return erased;
}

void UserLexicon::queryExact(const std::vector<uint16_t>& syllables,
                             uint64_t nowSec,
                             std::vector<std::pair<std::string, float>>& outResults) const {
    outResults.clear();
    if (syllables.empty()) return;
    std::lock_guard<std::mutex> lock(mutex_);
    std::string sk = makeSylKey(syllables);
    auto it = sylIndex_.find(sk);
    if (it == sylIndex_.end()) return;
    for (const auto& rkey : it->second) {
        auto rit = records_.find(rkey);
        if (rit == records_.end()) continue;
        float sc = computeDecayedScore(rit->second.freq, rit->second.lastUsedEpochSec, nowSec, rit->second.isAutoPhrase);
        outResults.emplace_back(rit->second.text, sc);
    }
    std::sort(outResults.begin(), outResults.end(),
              [](const auto& a, const auto& b) { return a.second > b.second; });
}

void UserLexicon::queryInitials(std::string_view initials,
                                uint64_t nowSec,
                                std::vector<std::pair<std::string, float>>& outResults) const {
    outResults.clear();
    if (initials.size() < 2) return;
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = initIndex_.find(std::string(initials));
    if (it == initIndex_.end()) return;
    for (const auto& rkey : it->second) {
        auto rit = records_.find(rkey);
        if (rit == records_.end()) continue;
        float sc = computeDecayedScore(rit->second.freq, rit->second.lastUsedEpochSec, nowSec, rit->second.isAutoPhrase);
        outResults.emplace_back(rit->second.text, sc);
    }
    std::sort(outResults.begin(), outResults.end(),
              [](const auto& a, const auto& b) { return a.second > b.second; });
}

float UserLexicon::queryBigramBonus(std::string_view prevWord, std::string_view currWord, uint64_t nowSec) const {
    if (prevWord.empty() || currWord.empty()) return 0.0f;
    std::lock_guard<std::mutex> lock(mutex_);
    std::string bkey = std::string(prevWord) + "\t" + std::string(currWord);
    auto it = bigrams_.find(bkey);
    if (it == bigrams_.end()) return 0.0f;
    double dt = (nowSec > it->second.lastUsedSec) ? static_cast<double>(nowSec - it->second.lastUsedSec) : 0.0;
    double decay = std::exp(-dt / kDecayHalfLifeSec);
    return static_cast<float>(std::log1p(it->second.count * decay) * 10.0);
}

} // namespace jiagu
