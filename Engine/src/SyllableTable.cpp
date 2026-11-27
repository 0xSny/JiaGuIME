#include "SyllableTable.hpp"

#include <algorithm>
#include <cstring>

namespace jiagu {

static const char* const kCanonicalSyllables[] = {
    "a", "ai", "an", "ang", "ao",
    "ba", "bai", "ban", "bang", "bao", "bei", "ben", "beng", "bi", "bian", "biao", "bie", "bin", "bing", "bo", "bu",
    "ca", "cai", "can", "cang", "cao", "ce", "cei", "cen", "ceng", "cha", "chai", "chan", "chang", "chao", "che", "chen", "cheng", "chi", "chong", "chou", "chu", "chua", "chuai", "chuan", "chuang", "chui", "chun", "chuo", "ci", "cong", "cou", "cu", "cuan", "cui", "cun", "cuo",
    "da", "dai", "dan", "dang", "dao", "de", "dei", "den", "deng", "di", "dia", "dian", "diao", "die", "ding", "diu", "dong", "dou", "du", "duan", "dui", "dun", "duo",
    "e", "ei", "en", "eng", "er",
    "fa", "fan", "fang", "fei", "fen", "feng", "fiao", "fo", "fou", "fu",
    "ga", "gai", "gan", "gang", "gao", "ge", "gei", "gen", "geng", "gong", "gou", "gu", "gua", "guai", "guan", "guang", "gui", "gun", "guo",
    "ha", "hai", "han", "hang", "hao", "he", "hei", "hen", "heng", "hong", "hou", "hu", "hua", "huai", "huan", "huang", "hui", "hun", "huo",
    "ji", "jia", "jian", "jiang", "jiao", "jie", "jin", "jing", "jiong", "jiu", "ju", "juan", "jue", "jun",
    "ka", "kai", "kan", "kang", "kao", "ke", "kei", "ken", "keng", "kong", "kou", "ku", "kua", "kuai", "kuan", "kuang", "kui", "kun", "kuo",
    "la", "lai", "lan", "lang", "lao", "le", "lei", "leng", "li", "lia", "lian", "liang", "liao", "lie", "lin", "ling", "liu", "lo", "long", "lou", "lu", "luan", "lun", "luo", "lv", "lve",
    "ma", "mai", "man", "mang", "mao", "me", "mei", "men", "meng", "mi", "mian", "miao", "mie", "min", "ming", "miu", "mo", "mou", "mu",
    "na", "nai", "nan", "nang", "nao", "ne", "nei", "nen", "neng", "ni", "nian", "niang", "niao", "nie", "nin", "ning", "niu", "nong", "nou", "nu", "nuan", "nun", "nuo", "nv", "nve",
    "o", "ou",
    "pa", "pai", "pan", "pang", "pao", "pei", "pen", "peng", "pi", "pian", "piao", "pie", "pin", "ping", "po", "pou", "pu",
    "qi", "qia", "qian", "qiang", "qiao", "qie", "qin", "qing", "qiong", "qiu", "qu", "quan", "que", "qun",
    "ran", "rang", "rao", "re", "ren", "reng", "ri", "rong", "rou", "ru", "rua", "ruan", "rui", "run", "ruo",
    "sa", "sai", "san", "sang", "sao", "se", "sei", "sen", "seng", "sha", "shai", "shan", "shang", "shao", "she", "shei", "shen", "sheng", "shi", "shou", "shu", "shua", "shuai", "shuan", "shuang", "shui", "shun", "shuo", "si", "song", "sou", "su", "suan", "sui", "sun", "suo",
    "ta", "tai", "tan", "tang", "tao", "te", "tei", "teng", "ti", "tian", "tiao", "tie", "ting", "tong", "tou", "tu", "tuan", "tui", "tun", "tuo",
    "wa", "wai", "wan", "wang", "wei", "wen", "weng", "wo", "wu",
    "xi", "xia", "xian", "xiang", "xiao", "xie", "xin", "xing", "xiong", "xiu", "xu", "xuan", "xue", "xun",
    "ya", "yan", "yang", "yao", "ye", "yi", "yin", "ying", "yo", "yong", "you", "yu", "yuan", "yue", "yun",
    "za", "zai", "zan", "zang", "zao", "ze", "zei", "zen", "zeng", "zha", "zhai", "zhan", "zhang", "zhao", "zhe", "zhei", "zhen", "zheng", "zhi", "zhong", "zhou", "zhu", "zhua", "zhuai", "zhuan", "zhuang", "zhui", "zhun", "zhuo", "zi", "zong", "zou", "zu", "zuan", "zui", "zun", "zuo"
};

const SyllableTable& SyllableTable::instance() {
    static const SyllableTable inst;
    return inst;
}

void SyllableTable::toXiaoheKeys(std::string_view syl, char& out1, char& out2) {
    // Official Xiaohe Shuangpin zero-initial rules:
    // 1-letter: a->aa, e->ee, o->oo
    // 2-letter: ai->ai, ei->ei, ao->ao, ou->ou, er->er, an->an, en->en
    // 3-letter: ang->ah, eng->eg
    if (syl == "a")   { out1 = 'a'; out2 = 'a'; return; }
    if (syl == "e")   { out1 = 'e'; out2 = 'e'; return; }
    if (syl == "o")   { out1 = 'o'; out2 = 'o'; return; }
    if (syl == "ai")  { out1 = 'a'; out2 = 'i'; return; }
    if (syl == "ei")  { out1 = 'e'; out2 = 'i'; return; }
    if (syl == "ao")  { out1 = 'a'; out2 = 'o'; return; }
    if (syl == "ou")  { out1 = 'o'; out2 = 'u'; return; }
    if (syl == "er")  { out1 = 'e'; out2 = 'r'; return; }
    if (syl == "an")  { out1 = 'a'; out2 = 'n'; return; }
    if (syl == "en")  { out1 = 'e'; out2 = 'n'; return; }
    if (syl == "ang") { out1 = 'a'; out2 = 'h'; return; }
    if (syl == "eng") { out1 = 'e'; out2 = 'g'; return; }

    // Initial mapping: zh->v, ch->i, sh->u
    std::string_view fin = syl;
    if (syl.size() >= 2 && syl[0] == 'z' && syl[1] == 'h') {
        out1 = 'v';
        fin = syl.substr(2);
    } else if (syl.size() >= 2 && syl[0] == 'c' && syl[1] == 'h') {
        out1 = 'i';
        fin = syl.substr(2);
    } else if (syl.size() >= 2 && syl[0] == 's' && syl[1] == 'h') {
        out1 = 'u';
        fin = syl.substr(2);
    } else {
        out1 = syl[0];
        fin = syl.substr(1);
    }

    // Final mapping
    if (fin == "iu") out2 = 'q';
    else if (fin == "ei") out2 = 'w';
    else if (fin == "e") out2 = 'e';
    else if (fin == "uan") out2 = 'r';
    else if (fin == "ue" || fin == "ve") out2 = 't';
    else if (fin == "un") out2 = 'y';
    else if (fin == "u") out2 = 'u';
    else if (fin == "i") out2 = 'i';
    else if (fin == "o" || fin == "uo") out2 = 'o';
    else if (fin == "ie") out2 = 'p';
    else if (fin == "a") out2 = 'a';
    else if (fin == "ong" || fin == "iong") out2 = 's';
    else if (fin == "ai") out2 = 'd';
    else if (fin == "en") out2 = 'f';
    else if (fin == "eng") out2 = 'g';
    else if (fin == "ang") out2 = 'h';
    else if (fin == "an") out2 = 'j';
    else if (fin == "ing" || fin == "uai") out2 = 'k';
    else if (fin == "iang" || fin == "uang") out2 = 'l';
    else if (fin == "ou") out2 = 'z';
    else if (fin == "ia" || fin == "ua") out2 = 'x';
    else if (fin == "ao") out2 = 'c';
    else if (fin == "ui" || fin == "v") out2 = 'v';
    else if (fin == "in") out2 = 'b';
    else if (fin == "iao") out2 = 'n';
    else if (fin == "ian") out2 = 'm';
    else out2 = 0;
}

SyllableTable::SyllableTable() {
    const size_t n = sizeof(kCanonicalSyllables) / sizeof(kCanonicalSyllables[0]);
    syllables_.reserve(n + 1);
    initialChars_.reserve(n + 1);
    syllables_.push_back("");
    initialChars_.push_back('\0');

    sortedEntries_.reserve(n);
    for (size_t i = 0; i < n; ++i) {
        std::string s = kCanonicalSyllables[i];
        uint16_t id = static_cast<uint16_t>(i + 1);
        syllables_.push_back(s);
        initialChars_.push_back(s[0]);
        sortedEntries_.push_back({s, id});

        char k1 = 0, k2 = 0;
        toXiaoheKeys(s, k1, k2);
        if (k1 >= 'a' && k1 <= 'z' && k2 >= 'a' && k2 <= 'z') {
            xiaoheMap_[(k1 - 'a') * 26 + (k2 - 'a')].push_back(id);
        }
    }

    std::sort(sortedEntries_.begin(), sortedEntries_.end(),
              [](const Entry& a, const Entry& b) { return a.text < b.text; });

    auto addAlias = [&](const char* alias, const char* canonical) {
        uint16_t cid = findExact(canonical);
        if (cid != kInvalidSyllable) {
            aliases_.emplace_back(alias, cid);
        }
    };
    addAlias("nue", "nve");
    addAlias("lue", "lve");
    addAlias("jv", "ju");
    addAlias("jve", "jue");
    addAlias("jvan", "juan");
    addAlias("jvn", "jun");
    addAlias("qv", "qu");
    addAlias("qve", "que");
    addAlias("qvan", "quan");
    addAlias("qvn", "qun");
    addAlias("xv", "xu");
    addAlias("xve", "xue");
    addAlias("xvan", "xuan");
    addAlias("xvn", "xun");
    addAlias("yv", "yu");
    addAlias("yve", "yue");
    addAlias("yvan", "yuan");
    addAlias("yvn", "yun");
}

std::string_view SyllableTable::name(uint16_t id) const {
    if (id == 0 || id >= syllables_.size()) return {};
    return syllables_[id];
}

char SyllableTable::initialChar(uint16_t id) const {
    if (id == 0 || id >= initialChars_.size()) return '\0';
    return initialChars_[id];
}

uint16_t SyllableTable::findExact(std::string_view pinyin) const {
    if (pinyin.empty() || pinyin.size() > 6) return kInvalidSyllable;
    auto it = std::lower_bound(sortedEntries_.begin(), sortedEntries_.end(), pinyin,
                               [](const Entry& e, std::string_view key) { return e.text < key; });
    if (it != sortedEntries_.end() && it->text == pinyin) {
        return it->id;
    }
    for (const auto& kv : aliases_) {
        if (kv.first == pinyin) return kv.second;
    }
    return kInvalidSyllable;
}

bool SyllableTable::isValidPrefix(std::string_view prefix) const {
    if (prefix.empty() || prefix.size() > 6) return false;
    auto it = std::lower_bound(sortedEntries_.begin(), sortedEntries_.end(), prefix,
                               [](const Entry& e, std::string_view key) { return e.text < key; });
    if (it != sortedEntries_.end() && it->text.size() >= prefix.size() &&
        std::memcmp(it->text.data(), prefix.data(), prefix.size()) == 0) {
        return true;
    }
    return false;
}

void SyllableTable::findByPrefix(std::string_view prefix, std::vector<uint16_t>& outIds, size_t limit) const {
    outIds.clear();
    if (prefix.empty() || prefix.size() > 6) return;
    auto it = std::lower_bound(sortedEntries_.begin(), sortedEntries_.end(), prefix,
                               [](const Entry& e, std::string_view key) { return e.text < key; });
    while (it != sortedEntries_.end() && outIds.size() < limit) {
        if (it->text.size() >= prefix.size() &&
            std::memcmp(it->text.data(), prefix.data(), prefix.size()) == 0) {
            outIds.push_back(it->id);
            ++it;
        } else {
            break;
        }
    }
}

void SyllableTable::getFuzzyVariants(uint16_t id, uint32_t fuzzyMask, std::vector<SyllableCandidate>& out) const {
    out.clear();
    if (id == kInvalidSyllable || id >= syllables_.size()) return;
    out.push_back({id, 0.0f, true});
    if (fuzzyMask == 0) return;

    const std::string& base = syllables_[id];
    std::vector<std::string> variants;
    variants.reserve(4);
    variants.push_back(base);

    auto expandInitial = [&](const char* a, const char* b) {
        size_t curSize = variants.size();
        size_t alen = std::strlen(a), blen = std::strlen(b);
        for (size_t i = 0; i < curSize; ++i) {
            const std::string& v = variants[i];
            if (v.size() >= alen && v.compare(0, alen, a) == 0) {
                // Avoid turning zh into zzh if a="z", b="zh"
                if (alen == 1 && blen == 2 && v.size() >= 2 && v[1] == b[1]) continue;
                variants.push_back(std::string(b) + v.substr(alen));
            } else if (v.size() >= blen && v.compare(0, blen, b) == 0) {
                variants.push_back(std::string(a) + v.substr(blen));
            }
        }
    };

    auto expandFinal = [&](const char* a, const char* b) {
        size_t curSize = variants.size();
        size_t alen = std::strlen(a), blen = std::strlen(b);
        for (size_t i = 0; i < curSize; ++i) {
            const std::string& v = variants[i];
            if (v.size() > alen && v.compare(v.size() - alen, alen, a) == 0) {
                // Prevent 'iang' matching 'an' etc.
                if (alen == 2 && v.size() > 3 && v.compare(v.size() - 3, 3, "ian") == 0 && std::strcmp(a, "an") == 0) {
                    continue;
                }
                if (alen == 2 && v.size() > 3 && v.compare(v.size() - 3, 3, "uan") == 0 && std::strcmp(a, "an") == 0) {
                    continue;
                }
                variants.push_back(v.substr(0, v.size() - alen) + b);
            } else if (v.size() > blen && v.compare(v.size() - blen, blen, b) == 0) {
                if (blen == 3 && v.size() > 4 && (v.compare(v.size() - 4, 4, "iang") == 0 || v.compare(v.size() - 4, 4, "uang") == 0) && std::strcmp(b, "ang") == 0) {
                    continue;
                }
                variants.push_back(v.substr(0, v.size() - blen) + a);
            }
        }
    };

    if (fuzzyMask & FuzzyBit::Z_ZH) expandInitial("z", "zh");
    if (fuzzyMask & FuzzyBit::C_CH) expandInitial("c", "ch");
    if (fuzzyMask & FuzzyBit::S_SH) expandInitial("s", "sh");
    if (fuzzyMask & FuzzyBit::L_N)  expandInitial("l", "n");
    if (fuzzyMask & FuzzyBit::F_H)  expandInitial("f", "h");
    if (fuzzyMask & FuzzyBit::R_L)  expandInitial("r", "l");

    if (fuzzyMask & FuzzyBit::AN_ANG)   expandFinal("an", "ang");
    if (fuzzyMask & FuzzyBit::EN_ENG)   expandFinal("en", "eng");
    if (fuzzyMask & FuzzyBit::IN_ING)   expandFinal("in", "ing");
    if (fuzzyMask & FuzzyBit::IAN_IANG) expandFinal("ian", "iang");
    if (fuzzyMask & FuzzyBit::UAN_UANG) expandFinal("uan", "uang");

    for (size_t i = 1; i < variants.size(); ++i) {
        uint16_t vid = findExact(variants[i]);
        if (vid != kInvalidSyllable && vid != id) {
            bool dup = false;
            for (const auto& c : out) {
                if (c.syllableId == vid) { dup = true; break; }
            }
            if (!dup) {
                out.push_back({vid, 2.2f, false});
            }
        }
    }
}

const std::vector<uint16_t>& SyllableTable::lookupXiaohe(char c1, char c2) const {
    if (c1 < 'a' || c1 > 'z' || c2 < 'a' || c2 > 'z') return emptyVec_;
    return xiaoheMap_[(c1 - 'a') * 26 + (c2 - 'a')];
}

uint32_t SyllableTable::validNextLetterMaskFull(std::string_view currentPrefix) const {
    uint32_t mask = 0;
    if (currentPrefix.empty()) {
        for (const auto& e : sortedEntries_) {
            mask |= (1u << (e.text[0] - 'a'));
        }
        return mask;
    }
    auto it = std::lower_bound(sortedEntries_.begin(), sortedEntries_.end(), currentPrefix,
                               [](const Entry& e, std::string_view key) { return e.text < key; });
    while (it != sortedEntries_.end()) {
        if (it->text.size() >= currentPrefix.size() &&
            std::memcmp(it->text.data(), currentPrefix.data(), currentPrefix.size()) == 0) {
            if (it->text.size() > currentPrefix.size()) {
                char nextCh = it->text[currentPrefix.size()];
                if (nextCh >= 'a' && nextCh <= 'z') {
                    mask |= (1u << (nextCh - 'a'));
                }
            }
            ++it;
        } else {
            break;
        }
    }
    return mask;
}

uint32_t SyllableTable::validNextLetterMaskXiaohe(char firstCharOrZero) const {
    if (firstCharOrZero < 'a' || firstCharOrZero > 'z') {
        // Every letter a..z can start a syllable in Xiaohe
        return (1u << 26) - 1u;
    }
    uint32_t mask = 0;
    int idxBase = (firstCharOrZero - 'a') * 26;
    for (int j = 0; j < 26; ++j) {
        if (!xiaoheMap_[idxBase + j].empty()) {
            mask |= (1u << j);
        }
    }
    return mask;
}

} // namespace jiagu
