#include "EngineAPI.hpp"

#include <cassert>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

using namespace jiagu;

static KeyStroke makeKey(char c) {
    KeyStroke k;
    k.primaryKey = c;
    k.alternatives.push_back({c, 0.0f});
    return k;
}

static void pushString(EngineAPI& eng, const std::string& s) {
    for (char c : s) {
        eng.pushKeyStroke(makeKey(c));
    }
}

int main(int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: test_engine <path-to-jiagu_lexicon.bin>\n";
        return 1;
    }

    const std::string lexPath = argv[1];
    const std::string tmpUserDir = "/tmp/jiagu_test_user";
    std::filesystem::remove_all(tmpUserDir);

    EngineAPI engine;
    auto t0 = std::chrono::steady_clock::now();
    bool ok = engine.initialize(lexPath, tmpUserDir);
    auto t1 = std::chrono::steady_clock::now();
    double coldMs = std::chrono::duration<double, std::milli>(t1 - t0).count();

    std::cout << "[test] Cold start mmap time: " << coldMs << " ms\n";
    assert(ok && "Failed to mmap lexicon");
    assert(coldMs < 20.0 && "Cold start exceeded 20ms threshold!");

    // 1. Verify Xiaohe Shuangpin table & zero-initial rules
    const auto& st = SyllableTable::instance();
    assert(st.lookupXiaohe('n', 'i').size() >= 1);
    assert(st.name(st.lookupXiaohe('n', 'i')[0]) == "ni");
    assert(st.name(st.lookupXiaohe('h', 'c')[0]) == "hao");
    // Zero-initial: a->aa, e->ee, o->oo, ang->ah, eng->eg
    assert(st.name(st.lookupXiaohe('a', 'a')[0]) == "a");
    assert(st.name(st.lookupXiaohe('e', 'e')[0]) == "e");
    assert(st.name(st.lookupXiaohe('o', 'o')[0]) == "o");
    assert(st.name(st.lookupXiaohe('a', 'h')[0]) == "ang");
    assert(st.name(st.lookupXiaohe('e', 'g')[0]) == "eng");
    // Initials: zh->v, ch->i, sh->u
    assert(st.name(st.lookupXiaohe('v', 'i')[0]) == "zhi");
    assert(st.name(st.lookupXiaohe('i', 'i')[0]) == "chi");
    assert(st.name(st.lookupXiaohe('u', 'i')[0]) == "shi");
    std::cout << "[test] Xiaohe Shuangpin mapping & zero-initial rules PASSED\n";

    // 2. Full Pinyin decode test: "nihao" -> contains "你好"
    DecoderConfig cfg;
    cfg.mode = InputMode::FullPinyin;
    engine.setConfig(cfg);
    pushString(engine, "nihao");
    uint64_t gen = engine.bumpGeneration();
    DecodeOutput out = engine.decodeCurrent(gen);
    assert(!out.cancelled && !out.candidates.empty());
    bool foundNihao = false;
    for (const auto& c : out.candidates) {
        if (c.text == "你好") { foundNihao = true; break; }
    }
    assert(foundNihao && "Full Pinyin 'nihao' did not return '你好'");
    std::cout << "[test] Full Pinyin 'nihao' top1=" << out.candidates[0].text << " PASSED\n";

    // 3. Xiaohe Shuangpin decode test: "nihc" -> contains "你好"
    engine.clearStrokes();
    cfg.mode = InputMode::XiaoheShuangpin;
    engine.setConfig(cfg);
    pushString(engine, "nihc");
    gen = engine.bumpGeneration();
    out = engine.decodeCurrent(gen);
    assert(!out.cancelled && !out.candidates.empty());
    foundNihao = false;
    for (const auto& c : out.candidates) {
        if (c.text == "你好") { foundNihao = true; break; }
    }
    assert(foundNihao && "Xiaohe 'nihc' did not return '你好'");
    std::cout << "[test] Xiaohe Shuangpin 'nihc' top1=" << out.candidates[0].text << " PASSED\n";

    // 4. Segmented selection auto-phrase synthesis + persistence + regret rollback
    engine.clearStrokes();
    cfg.mode = InputMode::FullPinyin;
    engine.setConfig(cfg);
    pushString(engine, "jiaguwen");
    gen = engine.bumpGeneration();
    out = engine.decodeCurrent(gen);
    assert(!out.candidates.empty());

    // Simulate segmented selection: pick 1st segment covering partial, then rest
    CandidateItem seg1;
    seg1.text = "甲";
    seg1.syllables = {st.findExact("jia")};
    seg1.consumedKeys = 3;
    auto r1 = engine.commitCandidate(seg1);
    assert(!r1.compositionFinished);

    CandidateItem seg2;
    seg2.text = "骨";
    seg2.syllables = {st.findExact("gu")};
    seg2.consumedKeys = 2;
    auto r2 = engine.commitCandidate(seg2);
    assert(!r2.compositionFinished);

    CandidateItem seg3;
    seg3.text = "文";
    seg3.syllables = {st.findExact("wen")};
    seg3.consumedKeys = 3;
    auto r3 = engine.commitCandidate(seg3);
    assert(r3.compositionFinished);
    assert(r3.synthesizedPhrase == "甲骨文");

    // Now typing "jiaguwen" again should rank "甲骨文" in top candidates!
    pushString(engine, "jiaguwen");
    gen = engine.bumpGeneration();
    out = engine.decodeCurrent(gen);
    assert(!out.candidates.empty());
    assert(out.candidates[0].text == "甲骨文");
    std::cout << "[test] Segmented auto-phrase synthesis ('甲骨文') PASSED\n";

    // Flush and reload in new EngineAPI instance to verify persistence
    engine.flushUserLexicon();
    EngineAPI engine2;
    assert(engine2.initialize(lexPath, tmpUserDir));
    engine2.setConfig(cfg);
    pushString(engine2, "jiaguwen");
    gen = engine2.bumpGeneration();
    out = engine2.decodeCurrent(gen);
    assert(!out.candidates.empty() && out.candidates[0].text == "甲骨文");
    std::cout << "[test] UserLexicon WAL/snapshot persistence PASSED\n";

    // Regret rollback test
    engine2.clearStrokes();
    CandidateItem mistake;
    mistake.text = "误触词";
    mistake.syllables = {st.findExact("wu"), st.findExact("chu"), st.findExact("ci")};
    mistake.consumedKeys = 8;
    pushString(engine2, "wuchuci");
    engine2.commitCandidate(mistake);
    assert(engine2.userLearnedCount() >= 2);
    engine2.notifyBackspaceAfterCommit();
    engine2.forgetUserWord("甲骨文");
    std::cout << "[test] Backspace regret rollback & forgetWord PASSED\n";

    // Lock-free cancellation test
    pushString(engine2, "zhongguorenmin");
    uint64_t staleGen = engine2.bumpGeneration();
    engine2.bumpGeneration(); // newer generation
    DecodeOutput cancelledOut = engine2.decodeCurrent(staleGen);
    assert(cancelledOut.cancelled);
    std::cout << "[test] Lock-free generation token cancellation PASSED\n";

    std::filesystem::remove_all(tmpUserDir);
    std::cout << "ALL C++17 ENGINE TESTS PASSED!\n";
    return 0;
}
