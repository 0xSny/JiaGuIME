#include "Decoder.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <unordered_set>

namespace jiagu {

static inline bool isCancelled(const std::atomic<uint64_t>& currentGen, uint64_t myGen) {
    return currentGen.load(std::memory_order_acquire) != myGen;
}

Decoder::Decoder(const SystemLexicon& sysLex, const UserLexicon& userLex)
    : sysLex_(sysLex), userLex_(userLex) {}

void Decoder::buildFullPinyinEdges(const std::vector<KeyStroke>& strokes,
                                   const DecoderConfig& config,
                                   std::vector<SyllableEdge>& outEdges,
                                   std::vector<std::string>& outBestSegments) const {
    outEdges.clear();
    outBestSegments.clear();
    const size_t n = strokes.size();
    if (n == 0) return;

    const auto& st = SyllableTable::instance();
    std::vector<SyllableCandidate> fuzzyBuf;

    // DP for best segmentation display (greedy/DP longest valid exact syllable)
    std::vector<float> bestCost(n + 1, -1e9f);
    std::vector<int> bestPrev(n + 1, -1);
    std::vector<std::string> bestSegText(n + 1);
    bestCost[0] = 0.0f;

    for (size_t i = 0; i < n; ++i) {
        if (strokes[i].primaryKey == '\'') {
            // Separator costs 0 and advances by 1
            if (bestCost[i] > bestCost[i + 1]) {
                bestCost[i + 1] = bestCost[i];
                bestPrev[i + 1] = static_cast<int>(i);
                bestSegText[i + 1] = "";
            }
            continue;
        }

        size_t maxLen = std::min<size_t>(6, n - i);
        for (size_t len = 1; len <= maxLen; ++len) {
            bool hasSep = false;
            std::string sub;
            sub.reserve(len);
            for (size_t k = 0; k < len; ++k) {
                char pk = strokes[i + k].primaryKey;
                if (pk == '\'') { hasSep = true; break; }
                sub.push_back(pk);
            }
            if (hasSep) break;

            uint16_t exactId = st.findExact(sub);
            if (exactId != kInvalidSyllable) {
                // Exact primary match
                st.getFuzzyVariants(exactId, config.fuzzyMask, fuzzyBuf);
                for (const auto& fc : fuzzyBuf) {
                    SyllableEdge edge;
                    edge.start = static_cast<uint8_t>(i);
                    edge.end = static_cast<uint8_t>(i + len);
                    edge.syllableId = fc.syllableId;
                    edge.penalty = fc.isExact ? 0.0f : -fc.penalty;
                    edge.isExact = fc.isExact;
                    edge.isPartial = false;
                    outEdges.push_back(edge);
                }
                float segScore = bestCost[i] + static_cast<float>(len) * 2.0f + 1.5f;
                if (segScore > bestCost[i + len]) {
                    bestCost[i + len] = segScore;
                    bestPrev[i + len] = static_cast<int>(i);
                    bestSegText[i + len] = sub;
                }
            } else if (len >= 2 && config.enableTransposition) {
                // Adjacent transposition tolerance (e.g. ign -> ing, ui -> iu)
                for (size_t sw = 0; sw + 1 < len; ++sw) {
                    if (sub[sw] == sub[sw + 1]) continue;
                    std::string swapped = sub;
                    std::swap(swapped[sw], swapped[sw + 1]);
                    uint16_t tid = st.findExact(swapped);
                    if (tid != kInvalidSyllable) {
                        SyllableEdge edge;
                        edge.start = static_cast<uint8_t>(i);
                        edge.end = static_cast<uint8_t>(i + len);
                        edge.syllableId = tid;
                        edge.penalty = -4.5f;
                        edge.isExact = false;
                        edge.isPartial = false;
                        outEdges.push_back(edge);
                    }
                }
            }

            // Spatial alternative tolerance (only if primary didn't match or spatialWeight > 0)
            if (config.spatialWeight > 0.01f && len >= 2) {
                for (size_t pos = 0; pos < len; ++pos) {
                    const auto& alts = strokes[i + pos].alternatives;
                    for (size_t ai = 1; ai < alts.size() && ai < 3; ++ai) {
                        if (alts[ai].key < 'a' || alts[ai].key > 'z') continue;
                        std::string altSub = sub;
                        altSub[pos] = alts[ai].key;
                        uint16_t aid = st.findExact(altSub);
                        if (aid != kInvalidSyllable && aid != exactId) {
                            SyllableEdge edge;
                            edge.start = static_cast<uint8_t>(i);
                            edge.end = static_cast<uint8_t>(i + len);
                            edge.syllableId = aid;
                            edge.penalty = std::min(-2.8f, alts[ai].logProb * config.spatialWeight - 1.5f);
                            edge.isExact = false;
                            edge.isPartial = false;
                            outEdges.push_back(edge);
                        }
                    }
                }
            }
        }

        // Partial tail at end of input (e.g. "nih" -> "ni" + "h...")
        if (i + 1 <= n && bestCost[i] > -1e8f) {
            size_t rem = n - i;
            if (rem <= 5) {
                std::string tail;
                bool ok = true;
                for (size_t k = 0; k < rem; ++k) {
                    char pk = strokes[i + k].primaryKey;
                    if (pk == '\'') { ok = false; break; }
                    tail.push_back(pk);
                }
                if (ok && !tail.empty() && st.findExact(tail) == kInvalidSyllable && st.isValidPrefix(tail)) {
                    std::vector<uint16_t> pids;
                    st.findByPrefix(tail, pids, 8);
                    for (uint16_t pid : pids) {
                        SyllableEdge edge;
                        edge.start = static_cast<uint8_t>(i);
                        edge.end = static_cast<uint8_t>(n);
                        edge.syllableId = pid;
                        edge.penalty = -3.2f;
                        edge.isExact = false;
                        edge.isPartial = true;
                        outEdges.push_back(edge);
                    }
                    float segScore = bestCost[i] + 0.2f;
                    if (segScore > bestCost[n]) {
                        bestCost[n] = segScore;
                        bestPrev[n] = static_cast<int>(i);
                        bestSegText[n] = tail;
                    }
                }
            }
        }

        // Fallback single-char advance for segmentation display if stuck
        if (bestCost[i + 1] < -1e8f && bestCost[i] > -1e8f) {
            bestCost[i + 1] = bestCost[i] - 5.0f;
            bestPrev[i + 1] = static_cast<int>(i);
            bestSegText[i + 1] = std::string(1, strokes[i].primaryKey);
        }
    }

    // Reconstruct bestSegments
    int cur = static_cast<int>(n);
    while (cur > 0 && bestPrev[cur] >= 0) {
        if (!bestSegText[cur].empty()) {
            outBestSegments.push_back(bestSegText[cur]);
        }
        cur = bestPrev[cur];
    }
    std::reverse(outBestSegments.begin(), outBestSegments.end());
}

void Decoder::buildXiaoheEdges(const std::vector<KeyStroke>& strokes,
                               const DecoderConfig& config,
                               std::vector<SyllableEdge>& outEdges,
                               std::vector<std::string>& outBestSegments) const {
    outEdges.clear();
    outBestSegments.clear();
    const size_t n = strokes.size();
    if (n == 0) return;

    const auto& st = SyllableTable::instance();
    std::vector<SyllableCandidate> fuzzyBuf;

    size_t i = 0;
    while (i < n) {
        char c1 = strokes[i].primaryKey;
        if (c1 == '\'') {
            ++i;
            continue;
        }
        if (i + 1 < n && strokes[i + 1].primaryKey != '\'') {
            char c2 = strokes[i + 1].primaryKey;
            const auto& exactIds = st.lookupXiaohe(c1, c2);
            if (!exactIds.empty()) {
                for (uint16_t sid : exactIds) {
                    st.getFuzzyVariants(sid, config.fuzzyMask, fuzzyBuf);
                    for (const auto& fc : fuzzyBuf) {
                        SyllableEdge edge;
                        edge.start = static_cast<uint8_t>(i);
                        edge.end = static_cast<uint8_t>(i + 2);
                        edge.syllableId = fc.syllableId;
                        edge.penalty = fc.isExact ? 0.0f : -fc.penalty;
                        edge.isExact = fc.isExact;
                        edge.isPartial = false;
                        outEdges.push_back(edge);
                    }
                }
                if (config.xiaoheShowExpandedPreedit) {
                    outBestSegments.push_back(std::string(st.name(exactIds[0])));
                } else {
                    outBestSegments.push_back(std::string{c1, c2});
                }
            } else {
                // Tighter Shuangpin spatial recovery ONLY when primary pair is invalid
                bool recovered = false;
                if (config.spatialWeight > 0.01f) {
                    for (size_t a1 = 0; a1 < strokes[i].alternatives.size() && a1 < 2; ++a1) {
                        for (size_t a2 = 0; a2 < strokes[i + 1].alternatives.size() && a2 < 2; ++a2) {
                            if (a1 == 0 && a2 == 0) continue;
                            char k1 = strokes[i].alternatives[a1].key;
                            char k2 = strokes[i + 1].alternatives[a2].key;
                            const auto& altIds = st.lookupXiaohe(k1, k2);
                            if (!altIds.empty()) {
                                float p = (strokes[i].alternatives[a1].logProb +
                                           strokes[i + 1].alternatives[a2].logProb) * config.spatialWeight - 5.5f;
                                for (uint16_t sid : altIds) {
                                    SyllableEdge edge;
                                    edge.start = static_cast<uint8_t>(i);
                                    edge.end = static_cast<uint8_t>(i + 2);
                                    edge.syllableId = sid;
                                    edge.penalty = p;
                                    edge.isExact = false;
                                    edge.isPartial = false;
                                    outEdges.push_back(edge);
                                }
                                recovered = true;
                            }
                        }
                    }
                }
                if (!recovered) {
                    outBestSegments.push_back(std::string{c1, c2});
                } else {
                    outBestSegments.push_back(std::string{c1, c2});
                }
            }
            i += 2;
        } else {
            // Trailing single key in Xiaohe: treat as partial initial for prefix/char candidates
            std::vector<uint16_t> pids;
            st.findByPrefix(std::string_view(&c1, 1), pids, 8);
            for (uint16_t pid : pids) {
                SyllableEdge edge;
                edge.start = static_cast<uint8_t>(i);
                edge.end = static_cast<uint8_t>(i + 1);
                edge.syllableId = pid;
                edge.penalty = -3.5f;
                edge.isExact = false;
                edge.isPartial = true;
                outEdges.push_back(edge);
            }
            outBestSegments.push_back(std::string(1, c1));
            i += 1;
        }
    }
}

DecodeOutput Decoder::decode(const std::vector<KeyStroke>& strokes,
                             const DecoderConfig& config,
                             const std::string& prevCommittedWord,
                             const std::vector<CustomPhrase>& customPhrases,
                             const std::atomic<uint64_t>& currentGeneration,
                             uint64_t myGeneration,
                             uint64_t nowSec) const {
    DecodeOutput out;
    out.generation = myGeneration;
    if (strokes.empty()) return out;
    if (isCancelled(currentGeneration, myGeneration)) {
        out.cancelled = true;
        return out;
    }

    std::string rawInput;
    rawInput.reserve(strokes.size());
    for (const auto& s : strokes) rawInput.push_back(s.primaryKey);

    std::vector<SyllableEdge> edges;
    std::vector<std::string> bestSegments;
    if (config.mode == InputMode::XiaoheShuangpin) {
        buildXiaoheEdges(strokes, config, edges, bestSegments);
    } else {
        buildFullPinyinEdges(strokes, config, edges, bestSegments);
    }

    for (size_t i = 0; i < bestSegments.size(); ++i) {
        if (i > 0) out.preeditDisplay.push_back(' ');
        out.preeditDisplay += bestSegments[i];
    }

    if (isCancelled(currentGeneration, myGeneration)) {
        out.cancelled = true;
        return out;
    }

    std::vector<CandidateItem> pool;
    std::unordered_set<std::string> seenTexts;

    auto addCandidate = [&](CandidateItem&& item) {
        if (item.text.empty()) return;
        if (seenTexts.find(item.text) != seenTexts.end()) return;
        seenTexts.insert(item.text);
        pool.push_back(std::move(item));
    };

    // Tier 0: Custom user shortcut phrases (exact abbr match)
    for (const auto& cp : customPhrases) {
        if (cp.abbr == rawInput && !cp.text.empty()) {
            CandidateItem item;
            item.text = cp.text;
            item.score = 1e6f;
            item.consumedKeys = static_cast<uint8_t>(strokes.size());
            item.tier = 0;
            item.isCustomPhrase = true;
            addCandidate(std::move(item));
        }
    }

    // Group edges by start index for fast Trie/Viterbi traversal
    const size_t n = strokes.size();
    std::vector<std::vector<const SyllableEdge*>> edgesByStart(n);
    for (const auto& e : edges) {
        if (e.start < n) edgesByStart[e.start].push_back(&e);
    }

    // Lookup phrase matches in SystemLexicon & UserLexicon starting from position 0
    struct PhraseMatch {
        uint8_t endPos = 0;
        std::string text;
        std::vector<uint16_t> syllables;
        uint32_t sysWordId = 0;
        float score = 0.0f;
        bool isUserWord = false;
        bool isExact = true;
    };

    auto collectMatchesFrom = [&](size_t startPos, std::vector<PhraseMatch>& outMatches, bool includeUser) {
        outMatches.clear();
        const TrieNode* root = sysLex_.rootNode();
        if (!root) return;

        struct PathState {
            uint8_t pos;
            const TrieNode* node;
            std::vector<uint16_t> syls;
            float penalty;
            bool isExact;
        };
        std::vector<PathState> queue;
        queue.push_back({static_cast<uint8_t>(startPos), root, {}, 0.0f, true});

        while (!queue.empty()) {
            if (isCancelled(currentGeneration, myGeneration)) return;
            PathState cur = std::move(queue.back());
            queue.pop_back();

            // Skip separator '\'' if sitting on one
            uint8_t p = cur.pos;
            while (p < n && strokes[p].primaryKey == '\'') ++p;
            if (p >= n) continue;

            for (const SyllableEdge* edge : edgesByStart[p]) {
                const TrieNode* child = sysLex_.findChild(cur.node, edge->syllableId);
                if (!child) continue;

                std::vector<uint16_t> nextSyls = cur.syls;
                nextSyls.push_back(edge->syllableId);
                float nextPen = cur.penalty + edge->penalty;
                bool nextExact = cur.isExact && edge->isExact && !edge->isPartial;

                // Collect words at this TrieNode
                uint32_t take = std::min<uint32_t>(child->wordCount, 12);
                for (uint32_t k = 0; k < take; ++k) {
                    uint32_t wid = child->wordStart + k;
                    const WordEntry* we = sysLex_.wordAt(wid);
                    if (!we) continue;
                    std::string_view wtext = sysLex_.wordText(*we);
                    float baseScore = static_cast<float>(we->logFreq) * 0.001f + nextPen * 6.0f;
                    if (nextExact) baseScore += 18.0f;
                    if (we->charCount > 1) baseScore += static_cast<float>(we->charCount) * 4.5f;

                    // Context bigram bonus when starting at pos 0
                    if (startPos == 0 && !prevCommittedWord.empty()) {
                        baseScore += userLex_.queryBigramBonus(prevCommittedWord, wtext, nowSec);
                    }

                    PhraseMatch pm;
                    pm.endPos = edge->end;
                    pm.text = std::string(wtext);
                    pm.syllables = nextSyls;
                    pm.sysWordId = wid;
                    pm.score = baseScore;
                    pm.isUserWord = false;
                    pm.isExact = nextExact;
                    outMatches.push_back(std::move(pm));
                }

                // UserLexicon exact match at this syllable sequence
                if (includeUser && nextSyls.size() <= 8) {
                    std::vector<std::pair<std::string, float>> ures;
                    userLex_.queryExact(nextSyls, nowSec, ures);
                    for (const auto& ur : ures) {
                        PhraseMatch pm;
                        pm.endPos = edge->end;
                        pm.text = ur.first;
                        pm.syllables = nextSyls;
                        pm.sysWordId = 0;
                        pm.score = ur.second + 55.0f + nextPen * 5.0f + (nextExact ? 18.0f : 0.0f);
                        pm.isUserWord = true;
                        pm.isExact = nextExact;
                        outMatches.push_back(std::move(pm));
                    }
                }

                if (nextSyls.size() < 8 && edge->end < n) {
                    queue.push_back({edge->end, child, std::move(nextSyls), nextPen, nextExact});
                }
            }
        }
    };

    // Tier 1: Viterbi Beam Search (K = 24) for whole-sentence smart composition
    struct BeamHyp {
        float score = 0.0f;
        uint8_t pos = 0;
        std::vector<CandidateSegment> segs;
        uint32_t lastSysWordId = 0;
        std::string lastText;
    };

    static constexpr size_t kBeamWidth = 24;
    std::vector<std::vector<BeamHyp>> beams(n + 1);
    beams[0].push_back({0.0f, 0, {}, 0, prevCommittedWord});

    std::vector<PhraseMatch> stepMatches;
    for (size_t pos = 0; pos < n; ++pos) {
        if (isCancelled(currentGeneration, myGeneration)) {
            out.cancelled = true;
            return out;
        }
        if (beams[pos].empty()) continue;

        if (strokes[pos].primaryKey == '\'') {
            for (const auto& h : beams[pos]) {
                BeamHyp nh = h;
                nh.pos = static_cast<uint8_t>(pos + 1);
                beams[pos + 1].push_back(std::move(nh));
            }
            continue;
        }

        collectMatchesFrom(pos, stepMatches, true);
        if (stepMatches.empty()) continue;

        // Keep top 20 transitions from pos to avoid combinatorial blowup
        std::sort(stepMatches.begin(), stepMatches.end(),
                  [](const PhraseMatch& a, const PhraseMatch& b) { return a.score > b.score; });
        if (stepMatches.size() > 20) stepMatches.resize(20);

        for (const auto& h : beams[pos]) {
            for (const auto& m : stepMatches) {
                float bigramBonus = 0.0f;
                if (h.lastSysWordId != 0 && m.sysWordId != 0) {
                    uint32_t bs = sysLex_.findBigramScore(h.lastSysWordId, m.sysWordId);
                    if (bs > 0) bigramBonus += static_cast<float>(bs) * 0.0005f;
                }
                if (!h.lastText.empty()) {
                    bigramBonus += userLex_.queryBigramBonus(h.lastText, m.text, nowSec);
                }
                BeamHyp nh;
                nh.score = h.score + m.score + bigramBonus;
                nh.pos = m.endPos;
                nh.segs = h.segs;
                CandidateSegment cs;
                cs.text = m.text;
                cs.syllables = m.syllables;
                cs.sysWordId = m.sysWordId;
                cs.isUserWord = m.isUserWord;
                cs.consumedKeys = static_cast<uint8_t>(m.endPos - pos);
                nh.segs.push_back(std::move(cs));
                nh.lastSysWordId = m.sysWordId;
                nh.lastText = m.text;

                beams[m.endPos].push_back(std::move(nh));
            }
        }

        // Prune beam at future positions? We prune each position when we reach it, or keep top K now.
        for (size_t fp = pos + 1; fp <= n; ++fp) {
            if (beams[fp].size() > kBeamWidth) {
                std::sort(beams[fp].begin(), beams[fp].end(),
                          [](const BeamHyp& a, const BeamHyp& b) { return a.score > b.score; });
                beams[fp].resize(kBeamWidth);
            }
        }
    }

    if (isCancelled(currentGeneration, myGeneration)) {
        out.cancelled = true;
        return out;
    }

    // Emit whole-sentence Viterbi candidates from beams[n]
    std::sort(beams[n].begin(), beams[n].end(),
              [](const BeamHyp& a, const BeamHyp& b) { return a.score > b.score; });

    for (size_t bi = 0; bi < beams[n].size() && bi < 4; ++bi) {
        const auto& h = beams[n][bi];
        if (h.segs.size() >= 2) {
            CandidateItem item;
            for (const auto& s : h.segs) {
                item.text += s.text;
                item.syllables.insert(item.syllables.end(), s.syllables.begin(), s.syllables.end());
            }
            item.segments = h.segs;
            item.score = h.score;
            item.consumedKeys = static_cast<uint8_t>(n);
            item.tier = 1;
            item.isUserWord = (h.segs.size() == 1 && h.segs[0].isUserWord);
            addCandidate(std::move(item));
        }
    }

    // Tier 2 & 3 & 4: Direct matches starting from position 0
    std::vector<PhraseMatch> rootMatches;
    collectMatchesFrom(0, rootMatches, true);
    std::sort(rootMatches.begin(), rootMatches.end(),
              [](const PhraseMatch& a, const PhraseMatch& b) { return a.score > b.score; });

    for (const auto& m : rootMatches) {
        CandidateItem item;
        item.text = m.text;
        item.syllables = m.syllables;
        CandidateSegment cs;
        cs.text = m.text;
        cs.syllables = m.syllables;
        cs.sysWordId = m.sysWordId;
        cs.isUserWord = m.isUserWord;
        cs.consumedKeys = m.endPos;
        item.segments.push_back(std::move(cs));
        item.score = m.score;
        item.consumedKeys = m.endPos;
        item.isUserWord = m.isUserWord;
        if (m.endPos == n && m.syllables.size() >= 2) {
            item.tier = 2; // Full exact phrase
        } else if (m.syllables.size() >= 2) {
            item.tier = 3; // Prefix phrase
        } else {
            item.tier = 4; // Single char
        }
        addCandidate(std::move(item));
        if (pool.size() >= 72) break;
    }

    // Jianpin (Initial-letter) support for Full Pinyin (e.g. "nh" -> "你好", "zg" -> "中国")
    if (config.mode == InputMode::FullPinyin && rawInput.size() >= 2 && rawInput.size() <= 6) {
        bool allAlpha = true;
        for (char c : rawInput) {
            if (c < 'a' || c > 'z') { allAlpha = false; break; }
        }
        if (allAlpha) {
            std::vector<std::pair<std::string, float>> uInit;
            userLex_.queryInitials(rawInput, nowSec, uInit);
            for (const auto& ur : uInit) {
                CandidateItem item;
                item.text = ur.first;
                item.score = ur.second + 20.0f;
                item.consumedKeys = static_cast<uint8_t>(n);
                item.tier = 3;
                item.isUserWord = true;
                addCandidate(std::move(item));
            }

            std::vector<uint32_t> jianpinIds;
            sysLex_.lookupInitials(rawInput, jianpinIds);
            for (uint32_t wid : jianpinIds) {
                const WordEntry* we = sysLex_.wordAt(wid);
                if (!we) continue;
                CandidateItem item;
                item.text = std::string(sysLex_.wordText(*we));
                sysLex_.getWordSyllables(wid, item.syllables);
                CandidateSegment cs;
                cs.text = item.text;
                cs.syllables = item.syllables;
                cs.sysWordId = wid;
                cs.consumedKeys = static_cast<uint8_t>(n);
                item.segments.push_back(std::move(cs));
                item.score = static_cast<float>(we->logFreq) * 0.001f + 8.0f;
                item.consumedKeys = static_cast<uint8_t>(n);
                item.tier = 3;
                addCandidate(std::move(item));
            }
        }
    }

    // Strict tiered sorting:
    // Tier 0 (custom) -> Tier 1 (whole sentence) -> Tier 2 (full exact phrase)
    // -> Tier 3 (prefix / Jianpin) -> Tier 4 (single chars), ordered by score within tier.
    std::sort(pool.begin(), pool.end(), [](const CandidateItem& a, const CandidateItem& b) {
        if (a.tier != b.tier) return a.tier < b.tier;
        return a.score > b.score;
    });

    if (pool.size() > 64) pool.resize(64);
    out.candidates = std::move(pool);
    return out;
}

uint32_t Decoder::predictNextLetterMask(const std::vector<KeyStroke>& strokes,
                                        const DecoderConfig& config) const {
    const auto& st = SyllableTable::instance();
    if (config.mode == InputMode::XiaoheShuangpin) {
        if (strokes.empty() || (strokes.size() % 2 == 0)) {
            return st.validNextLetterMaskXiaohe(0);
        }
        return st.validNextLetterMaskXiaohe(strokes.back().primaryKey);
    }

    // Full Pinyin: find longest valid suffix starting from last separator or up to 5 chars
    std::string tail;
    size_t start = strokes.size() > 5 ? strokes.size() - 5 : 0;
    for (size_t i = start; i < strokes.size(); ++i) {
        if (strokes[i].primaryKey == '\'') tail.clear();
        else tail.push_back(strokes[i].primaryKey);
    }
    while (!tail.empty() && !st.isValidPrefix(tail)) {
        tail.erase(tail.begin());
    }
    return st.validNextLetterMaskFull(tail);
}

} // namespace jiagu
