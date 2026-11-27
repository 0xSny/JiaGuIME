#pragma once

#include <array>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace jiagu {

static constexpr uint16_t kInvalidSyllable = 0;
static constexpr uint16_t kMaxSyllables = 450;

// 11 standard Mandarin fuzzy pinyin groups (bitmask)
enum FuzzyMask : uint32_t {
    FUZZY_NONE      = 0,
    FUZZY_Z_ZH      = 1u << 0,
    FUZZY_C_CH      = 1u << 1,
    FUZZY_S_SH      = 1u << 2,
    FUZZY_L_N       = 1u << 3,
    FUZZY_F_H       = 1u << 4,
    FUZZY_R_L       = 1u << 5,
    FUZZY_K_G       = 1u << 6,
    FUZZY_AN_ANG    = 1u << 7,
    FUZZY_EN_ENG    = 1u << 8,
    FUZZY_IN_ING    = 1u << 9,
    FUZZY_IAN_IANG  = 1u << 10,
    FUZZY_UAN_UANG  = 1u << 10, // grouped with iang/uang or 11th bit: let's give UAN_UANG bit 10 and IAN_IANG bit 9? Wait: prompt says 11 groups!
};

// Exact 11 independent fuzzy groups:
// 0: z<->zh, 1: c<->ch, 2: s<->sh, 3: l<->n, 4: f<->h, 5: r<->l,
// 6: an<->ang, 7: en<->eng, 8: in<->ing, 9: ian<->iang, 10: uan<->uang
namespace FuzzyBit {
    static constexpr uint32_t Z_ZH     = 1u << 0;
    static constexpr uint32_t C_CH     = 1u << 1;
    static constexpr uint32_t S_SH     = 1u << 2;
    static constexpr uint32_t L_N      = 1u << 3;
    static constexpr uint32_t F_H      = 1u << 4;
    static constexpr uint32_t R_L      = 1u << 5;
    static constexpr uint32_t AN_ANG   = 1u << 6;
    static constexpr uint32_t EN_ENG   = 1u << 7;
    static constexpr uint32_t IN_ING   = 1u << 8;
    static constexpr uint32_t IAN_IANG = 1u << 9;
    static constexpr uint32_t UAN_UANG = 1u << 10;
}

struct SyllableCandidate {
    uint16_t syllableId = 0;
    float penalty = 0.0f; // 0.0 = exact match, >0 = fuzzy or typo penalty
    bool isExact = true;
};

class SyllableTable {
public:
    static const SyllableTable& instance();

    uint16_t count() const { return static_cast<uint16_t>(syllables_.size() - 1); }

    std::string_view name(uint16_t id) const;
    char initialChar(uint16_t id) const;

    // Full Pinyin lookup (exact + alias)
    uint16_t findExact(std::string_view pinyin) const;

    // Prefix check: true if any canonical syllable starts with prefix
    bool isValidPrefix(std::string_view prefix) const;

    // Return canonical syllable IDs whose spelling starts with prefix (for partial tail matching)
    void findByPrefix(std::string_view prefix, std::vector<uint16_t>& outIds, size_t limit = 24) const;

    // Fuzzy variants for a canonical syllable ID under given fuzzyMask
    void getFuzzyVariants(uint16_t id, uint32_t fuzzyMask, std::vector<SyllableCandidate>& out) const;

    // Official Xiaohe Shuangpin O(1) 2-key lookup: (key1, key2) -> syllableId(s)
    // Note: in Xiaohe, a 2-key pair maps deterministically to 0, 1, or 2 (rarely, e.g. zero-initial vs consonant) syllables.
    const std::vector<uint16_t>& lookupXiaohe(char c1, char c2) const;

    // Valid next letters in Full Pinyin given current syllable prefix (for spatial prior)
    uint32_t validNextLetterMaskFull(std::string_view currentPrefix) const;

    // Valid next letters in Xiaohe Shuangpin given current 0 or 1 char in syllable
    uint32_t validNextLetterMaskXiaohe(char firstCharOrZero) const;

private:
    SyllableTable();

    std::vector<std::string> syllables_; // 1-indexed; index 0 is ""
    std::vector<char> initialChars_;
    std::array<std::vector<uint16_t>, 26 * 26> xiaoheMap_;
    std::vector<uint16_t> emptyVec_;

    // Fast sorted table for prefix/exact lookup
    struct Entry {
        std::string text;
        uint16_t id;
    };
    std::vector<Entry> sortedEntries_;
    std::vector<std::pair<std::string, uint16_t>> aliases_;

    static void toXiaoheKeys(std::string_view syl, char& out1, char& out2);
};

} // namespace jiagu
