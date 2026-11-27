#pragma once

#include "SyllableTable.hpp"
#include "SystemLexicon.hpp"
#include "UserLexicon.hpp"

#include <atomic>
#include <cstdint>
#include <string>
#include <vector>

namespace jiagu {

enum class InputMode : uint8_t {
    FullPinyin = 0,
    XiaoheShuangpin = 1,
};

struct TouchKeyProb {
    char key = 0;       // lowercase 'a'..'z' or '\''
    float logProb = 0;  // <= 0.0f (0.0 for primary key)
};

struct KeyStroke {
    char primaryKey = 0;
    std::vector<TouchKeyProb> alternatives; // Top-3 2D Gaussian alternatives (including primaryKey)
};

struct DecoderConfig {
    InputMode mode = InputMode::FullPinyin;
    uint32_t fuzzyMask = 0;
    float spatialWeight = 1.0f;         // 0.0 .. 2.0
    bool enableTransposition = true;    // ign<->ing, ui<->iu etc. in Full Pinyin
    bool xiaoheShowExpandedPreedit = true;
};

struct CandidateSegment {
    std::string text;
    std::vector<uint16_t> syllables;
    uint32_t sysWordId = 0;
    bool isUserWord = false;
    bool isCustomPhrase = false;
    uint8_t consumedKeys = 0;
};

struct CandidateItem {
    std::string text;
    std::vector<uint16_t> syllables;
    std::vector<CandidateSegment> segments;
    float score = 0.0f;
    uint8_t consumedKeys = 0; // How many input keystrokes this candidate covers
    uint8_t tier = 4;         // 0=custom, 1=sentence, 2=exact phrase, 3=prefix, 4=single char
    bool isUserWord = false;
    bool isCustomPhrase = false;
};

struct DecodeOutput {
    uint64_t generation = 0;
    bool cancelled = false;
    std::string preeditDisplay;     // Segmented display string for inline marked text
    std::vector<CandidateItem> candidates;
};

struct CustomPhrase {
    std::string abbr;
    std::string text;
};

class Decoder {
public:
    Decoder(const SystemLexicon& sysLex, const UserLexicon& userLex);

    DecodeOutput decode(const std::vector<KeyStroke>& strokes,
                        const DecoderConfig& config,
                        const std::string& prevCommittedWord,
                        const std::vector<CustomPhrase>& customPhrases,
                        const std::atomic<uint64_t>& currentGeneration,
                        uint64_t myGeneration,
                        uint64_t nowSec) const;

    // Predict next-letter probability mask for Voronoi / spatial prior
    uint32_t predictNextLetterMask(const std::vector<KeyStroke>& strokes,
                                   const DecoderConfig& config) const;

private:
    const SystemLexicon& sysLex_;
    const UserLexicon& userLex_;

    struct SyllableEdge {
        uint8_t start = 0;
        uint8_t end = 0;
        uint16_t syllableId = 0;
        float penalty = 0.0f;   // 0 for exact primary, negative/positive cost
        bool isExact = true;
        bool isPartial = false;
    };

    void buildFullPinyinEdges(const std::vector<KeyStroke>& strokes,
                              const DecoderConfig& config,
                              std::vector<SyllableEdge>& outEdges,
                              std::vector<std::string>& outBestSegments) const;

    void buildXiaoheEdges(const std::vector<KeyStroke>& strokes,
                          const DecoderConfig& config,
                          std::vector<SyllableEdge>& outEdges,
                          std::vector<std::string>& outBestSegments) const;
};

} // namespace jiagu
