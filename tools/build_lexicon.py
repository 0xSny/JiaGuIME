#!/usr/bin/env python3
"""
JiaGuIME Offline Lexicon Compiler (tools/build_lexicon.py)
Downloads iDvel/rime-ice open-source dictionaries (8105, base, ext),
strictly cleans and validates every entry (no emojis, no garbled chars,
no broken pinyin, no single-letter junk), extracts bigrams + Jianpin trie,
and compiles a 8-byte aligned, CRC32-verified JGLEX01 binary for zero-copy mmap.
"""

import argparse
import math
import os
import re
import struct
import subprocess
import sys
import zlib
from collections import defaultdict

# 415 canonical Mandarin Pinyin syllables (without tone, u-umlaut as 'v' for n/l).
# Must match Engine/src/SyllableTable.cpp EXACTLY in order (1-indexed; 0 = invalid).
CANONICAL_SYLLABLES = [
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
    "za", "zai", "zan", "zang", "zao", "ze", "zei", "zen", "zeng", "zha", "zhai", "zhan", "zhang", "zhao", "zhe", "zhei", "zhen", "zheng", "zhi", "zhong", "zhou", "zhu", "zhua", "zhuai", "zhuan", "zhuang", "zhui", "zhun", "zhuo", "zi", "zong", "zou", "zu", "zuan", "zui", "zun", "zuo",
]

SYLLABLE_TO_ID = {s: idx + 1 for idx, s in enumerate(CANONICAL_SYLLABLES)}

SYLLABLE_ALIASES = {
    "nue": "nve",
    "lue": "lve",
    "ju": "ju", "jv": "ju",
    "jue": "jue", "jve": "jue",
    "juan": "juan", "jvan": "juan",
    "jun": "jun", "jvn": "jun",
    "qu": "qu", "qv": "qu",
    "que": "que", "qve": "que",
    "quan": "quan", "qvan": "quan",
    "qun": "qun", "qvn": "qun",
    "xu": "xu", "xv": "xu",
    "xue": "xue", "xve": "xue",
    "xuan": "xuan", "xvan": "xuan",
    "xun": "xun", "xvn": "xun",
    "yu": "yu", "yv": "yu",
    "yue": "yue", "yve": "yue",
    "yuan": "yuan", "yvan": "yuan",
    "yun": "yun", "yvn": "yun",
}

# Curated high-frequency everyday Chinese conversational bigrams to guarantee
# smooth contextual prediction even for short common phrases.
CURATED_BIGRAMS = [
    ("我", "们", 95000), ("你", "们", 94000), ("他", "们", 93000), ("她", "们", 91000),
    ("今", "天", 94000), ("明", "天", 93000), ("昨", "天", 92000), ("现", "在", 94000),
    ("什", "么", 96000), ("怎", "么", 95000), ("为", "什么", 93000), ("可", "以", 95000),
    ("没", "有", 96000), ("不", "是", 96000), ("就", "是", 95000), ("还", "是", 94000),
    ("这", "个", 95000), ("那", "个", 94000), ("这", "样", 93000), ("那", "样", 91000),
    ("一", "下", 94000), ("一", "个", 96000), ("一", "起", 93000), ("知", "道", 95000),
    ("觉", "得", 94000), ("喜", "欢", 93000), ("希", "望", 92000), ("因", "为", 94000),
    ("所", "以", 94000), ("但", "是", 94000), ("如", "果", 94000), ("虽", "然", 92000),
    ("已经", "开始", 88000), ("应该", "可以", 89000), ("今天", "天气", 91000),
    ("明天", "上午", 88000), ("明天", "下午", 88000), ("现在", "开始", 87000),
    ("真的", "吗", 90000), ("好的", "谢谢", 89000), ("谢谢", "你", 92000),
    ("对不起", "我", 86000), ("没关系", "的", 86000), ("加油", "吧", 85000),
    ("怎么", "了", 93000), ("怎么", "样", 93000), ("为什么", "会", 89000),
    ("可以", "吗", 92000), ("没有", "问题", 92000), ("不是", "吧", 90000),
    ("我们", "一起", 91000), ("大家", "好", 91000), ("工作", "顺利", 87000),
    ("输入", "法", 92000), ("手机", "号", 88000), ("微", "信", 94000),
    ("发", "送", 91000), ("收", "到", 92000), ("打", "开", 91000),
]

CJK_BMP_RE = re.compile(r"^[\u4e00-\u9fff]+$")


def is_clean_cjk_word(word: str) -> bool:
    if not word or len(word) > 8:
        return False
    return bool(CJK_BMP_RE.match(word))


def normalize_syllable(syl: str) -> str:
    s = syl.strip().lower()
    if s in SYLLABLE_ALIASES:
        s = SYLLABLE_ALIASES[s]
    return s


def clone_rime_ice(dest_dir: str) -> str:
    cn_dir = os.path.join(dest_dir, "cn_dicts")
    if os.path.isdir(cn_dir) and os.path.isfile(os.path.join(cn_dir, "8105.dict.yaml")):
        return cn_dir
    if os.path.isdir(dest_dir):
        import shutil
        shutil.rmtree(dest_dir, ignore_errors=True)
    print(f"[lexicon] Cloning iDvel/rime-ice (sparse cn_dicts) into {dest_dir}...")
    subprocess.run(
        ["git", "clone", "--depth", "1", "--filter=blob:none", "--sparse",
         "https://github.com/iDvel/rime-ice.git", dest_dir],
        check=True
    )
    subprocess.run(
        ["git", "-C", dest_dir, "sparse-checkout", "set", "cn_dicts"],
        check=True
    )
    return cn_dir


def parse_rime_dict(path: str, min_weight: int = 0):
    entries = []
    in_body = False
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.rstrip("\r\n")
            if not in_body:
                if line == "...":
                    in_body = True
                continue
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 2:
                continue
            word = parts[0].strip()
            if not is_clean_cjk_word(word):
                continue
            raw_syls = parts[1].strip().split()
            if len(raw_syls) != len(word):
                continue
            syl_ids = []
            valid = True
            for rs in raw_syls:
                ns = normalize_syllable(rs)
                sid = SYLLABLE_TO_ID.get(ns)
                if sid is None:
                    valid = False
                    break
                syl_ids.append(sid)
            if not valid:
                continue
            weight = 1
            if len(parts) >= 3 and parts[2].strip().isdigit():
                weight = int(parts[2].strip())
            if weight < min_weight:
                continue
            entries.append((word, tuple(syl_ids), weight))
    return entries


def freq_to_log_score(weight: int, is_single: bool, is_common_8105: bool, is_base: bool) -> int:
    # Convert raw corpus weight to monotonic 0..100000 fixed-point log score.
    w = max(weight, 1)
    score = int(math.log10(w + 1.0) * 10500.0)
    if is_common_8105:
        score += 6000
    if is_base:
        score += 3500
    if is_single and weight <= 10:
        score = max(100, score - 8000)
    return max(100, min(99999, score))


def main():
    parser = argparse.ArgumentParser(description="Build JiaGuIME binary mmap lexicon.")
    parser.add_argument("--rime-dir", default="rime-ice", help="Directory for rime-ice checkout")
    parser.add_argument("--output", default="Resources/jiagu_lexicon.bin", help="Output binary path")
    parser.add_argument("--max-phrases", type=int, default=180000, help="Max multi-char phrases")
    parser.add_argument("--max-bigrams", type=int, default=100000, help="Max bigram pairs")
    args = parser.parse_args()

    cn_dir = clone_rime_ice(args.rime_dir)
    p_8105 = os.path.join(cn_dir, "8105.dict.yaml")
    p_base = os.path.join(cn_dir, "base.dict.yaml")
    p_ext = os.path.join(cn_dir, "ext.dict.yaml")

    print("[lexicon] Parsing 8105.dict.yaml...")
    e_8105 = parse_rime_dict(p_8105, min_weight=0)
    print(f"  8105 clean entries: {len(e_8105)}")

    print("[lexicon] Parsing base.dict.yaml...")
    e_base = parse_rime_dict(p_base, min_weight=5)
    print(f"  base clean entries: {len(e_base)}")

    e_ext = []
    if os.path.isfile(p_ext):
        print("[lexicon] Parsing ext.dict.yaml (high-freq filter >= 200)...")
        e_ext = parse_rime_dict(p_ext, min_weight=200)
        print(f"  ext clean entries: {len(e_ext)}")

    # Deduplicate by (word, syl_tuple) keeping highest score
    merged = {}  # (word, syls) -> (log_freq, flags)
    common_single_chars = set()

    for word, syls, weight in e_8105:
        common_single_chars.add(word)
        key = (word, syls)
        sc = freq_to_log_score(weight, is_single=(len(word) == 1), is_common_8105=True, is_base=True)
        prev = merged.get(key)
        if prev is None or sc > prev[0]:
            merged[key] = (sc, 0x03)

    for word, syls, weight in e_base:
        key = (word, syls)
        is_single = (len(word) == 1)
        sc = freq_to_log_score(weight, is_single=is_single, is_common_8105=(word in common_single_chars), is_base=True)
        prev = merged.get(key)
        if prev is None or sc > prev[0]:
            flags = 0x02 | (0x01 if word in common_single_chars else 0x00)
            merged[key] = (sc, flags)

    # Separate single chars and phrases so we keep ALL 8105 single chars + top N phrases
    singles = []
    phrases = []
    seen_phrase_keys = set()

    for (word, syls), (sc, flags) in merged.items():
        if len(word) == 1:
            singles.append((word, syls, sc, flags))
        else:
            phrases.append((word, syls, sc, flags))
            seen_phrase_keys.add((word, syls))

    # Add ext phrases not already in base
    ext_phrases = []
    for word, syls, weight in e_ext:
        if len(word) <= 1:
            continue
        key = (word, syls)
        if key in seen_phrase_keys:
            continue
        sc = freq_to_log_score(weight, is_single=False, is_common_8105=False, is_base=False)
        ext_phrases.append((word, syls, sc, 0x00))

    phrases.sort(key=lambda x: x[2], reverse=True)
    ext_phrases.sort(key=lambda x: x[2], reverse=True)

    combined_phrases = phrases + ext_phrases
    if len(combined_phrases) > args.max_phrases:
        combined_phrases = combined_phrases[:args.max_phrases]

    all_entries = singles + combined_phrases
    print(f"[lexicon] Final vocabulary: {len(singles)} single-char readings + {len(combined_phrases)} phrases = {len(all_entries)} total")

    # Build Syllable Trie (BFS/array-flattened with sorted children for binary search)
    # Node structure: children dict during construction
    class TempNode:
        __slots__ = ("syl_id", "depth", "parent_idx", "children", "words", "max_freq", "final_idx")
        def __init__(self, syl_id: int, depth: int):
            self.syl_id = syl_id
            self.depth = depth
            self.parent_idx = 0
            self.children = {}  # syl_id -> TempNode
            self.words = []     # (word, log_freq, flags)
            self.max_freq = 0
            self.final_idx = 0

    root = TempNode(0, 0)
    for word, syls, sc, flags in all_entries:
        cur = root
        if sc > cur.max_freq:
            cur.max_freq = sc
        for sid in syls:
            nxt = cur.children.get(sid)
            if nxt is None:
                nxt = TempNode(sid, cur.depth + 1)
                cur.children[sid] = nxt
            cur = nxt
            if sc > cur.max_freq:
                cur.max_freq = sc
        cur.words.append((word, sc, flags))

    # Flatten trie in BFS order so each node's children are contiguous and sorted by syl_id
    flat_nodes = [root]
    head = 0
    while head < len(flat_nodes):
        node = flat_nodes[head]
        node.final_idx = head
        if node.children:
            for sid in sorted(node.children.keys()):
                child = node.children[sid]
                child.parent_idx = head
                flat_nodes.append(child)
        head += 1

    # Assign contiguous childStart/childCount and flatten WordEntry array
    word_entries = []  # (text, char_count, flags, log_freq, node_idx)
    word_text_to_best_id = {}  # word_text -> (best_freq, word_id)
    node_meta = []  # (syl_id, depth, parent_idx, child_start, child_count, word_start, word_count, max_freq)

    # First pass to know child_start for each node
    child_starts = {}
    cursor = 1
    for i, node in enumerate(flat_nodes):
        cnt = len(node.children)
        child_starts[i] = cursor if cnt > 0 else 0
        cursor += cnt

    for i, node in enumerate(flat_nodes):
        node.words.sort(key=lambda x: x[1], reverse=True)
        w_start = len(word_entries)
        w_cnt = len(node.words)
        for text, sc, flags in node.words:
            wid = len(word_entries)
            word_entries.append((text, len(text), flags, sc, i))
            prev = word_text_to_best_id.get(text)
            if prev is None or sc > prev[0]:
                word_text_to_best_id[text] = (sc, wid)
        node_meta.append((
            node.syl_id,
            node.depth,
            node.parent_idx,
            child_starts[i],
            len(node.children),
            w_start,
            w_cnt,
            node.max_freq,
        ))

    print(f"[lexicon] Syllable Trie nodes: {len(node_meta)}, Words: {len(word_entries)}")

    # Extract Bigrams from:
    # 1) Curated everyday conversational bigrams
    # 2) Splitting 3-char & 4-char high-freq phrases into (prefix_word, suffix_word) if both exist!
    bigram_scores = defaultdict(int)

    for w1, w2, sc in CURATED_BIGRAMS:
        id1 = word_text_to_best_id.get(w1)
        id2 = word_text_to_best_id.get(w2)
        if id1 is not None and id2 is not None:
            pair = (id1[1], id2[1])
            if sc > bigram_scores[pair]:
                bigram_scores[pair] = sc

    for text, clen, flags, sc, _ in word_entries:
        if clen == 2:
            id1 = word_text_to_best_id.get(text[0])
            id2 = word_text_to_best_id.get(text[1])
            if id1 is not None and id2 is not None:
                pair = (id1[1], id2[1])
                b_sc = max(1000, sc - 8000)
                if b_sc > bigram_scores[pair]:
                    bigram_scores[pair] = b_sc
        elif clen == 3 or clen == 4:
            for split_pos in (2, 1) if clen == 3 else (2,):
                p1 = text[:split_pos]
                p2 = text[split_pos:]
                id1 = word_text_to_best_id.get(p1)
                id2 = word_text_to_best_id.get(p2)
                if id1 is not None and id2 is not None:
                    pair = (id1[1], id2[1])
                    b_sc = max(2000, sc - 3000)
                    if b_sc > bigram_scores[pair]:
                        bigram_scores[pair] = b_sc

    bigram_items = sorted(bigram_scores.items(), key=lambda x: x[1], reverse=True)
    if len(bigram_items) > args.max_bigrams:
        bigram_items = bigram_items[:args.max_bigrams]
    # Sort by (prevWordId, currWordId) ascending for binary search
    bigram_items.sort(key=lambda x: x[0])
    print(f"[lexicon] Bigrams: {len(bigram_items)}")

    # Build Jianpin Initial Trie (lengths 2..6, top 16 words per node)
    class InitNode:
        __slots__ = ("letter", "depth", "children", "refs")
        def __init__(self, letter: int, depth: int):
            self.letter = letter
            self.depth = depth
            self.children = {}
            self.refs = []  # (log_freq, word_id)

    init_root = InitNode(0, 0)
    # Build mapping from node_idx -> initial string
    node_initials = [""] * len(flat_nodes)
    for i, node in enumerate(flat_nodes):
        if i == 0:
            continue
        syl_str = CANONICAL_SYLLABLES[node.syl_id - 1]
        node_initials[i] = node_initials[node.parent_idx] + syl_str[0]

    for wid, (text, clen, flags, sc, nidx) in enumerate(word_entries):
        if clen < 2 or clen > 6:
            continue
        init_str = node_initials[nidx]
        if len(init_str) != clen:
            continue
        cur = init_root
        for ch in init_str:
            code = ord(ch)
            nxt = cur.children.get(code)
            if nxt is None:
                nxt = InitNode(code, cur.depth + 1)
                cur.children[code] = nxt
            cur = nxt
        cur.refs.append((sc, wid))

    flat_init = [init_root]
    head = 0
    while head < len(flat_init):
        node = flat_init[head]
        if node.children:
            for code in sorted(node.children.keys()):
                flat_init.append(node.children[code])
        head += 1

    init_child_starts = {}
    cursor = 1
    for i, node in enumerate(flat_init):
        cnt = len(node.children)
        init_child_starts[i] = cursor if cnt > 0 else 0
        cursor += cnt

    init_node_meta = []
    init_refs = []
    for i, node in enumerate(flat_init):
        node.refs.sort(key=lambda x: x[0], reverse=True)
        top_refs = node.refs[:16]
        r_start = len(init_refs)
        r_cnt = len(top_refs)
        for _, wid in top_refs:
            init_refs.append(wid)
        init_node_meta.append((
            node.letter,
            node.depth,
            0,
            init_child_starts[i],
            len(node.children),
            r_start,
            r_cnt,
            0,
        ))
    print(f"[lexicon] Jianpin InitTrie nodes: {len(init_node_meta)}, refs: {len(init_refs)}")

    # Pack string pool (unique strings deduplicated)
    str_pool = bytearray()
    str_offset_map = {}
    packed_words = []
    for text, clen, flags, sc, nidx in word_entries:
        b = text.encode("utf-8")
        off = str_offset_map.get(text)
        if off is None:
            off = len(str_pool)
            str_offset_map[text] = off
            str_pool.extend(b)
            str_pool.append(0)
        packed_words.append((off, len(b), clen, flags, sc, nidx))

    # Pad helper to 8-byte boundary
    def pad8(buf: bytearray):
        rem = len(buf) % 8
        if rem != 0:
            buf.extend(b"\x00" * (8 - rem))

    body = bytearray()

    offset_nodes = 80 + len(body)
    for m in node_meta:
        body.extend(struct.pack("<HHIIIIII", *m))
    pad8(body)

    offset_words = 80 + len(body)
    for w in packed_words:
        body.extend(struct.pack("<IHBBII", *w))
    pad8(body)

    offset_bigrams = 80 + len(body)
    for (p_id, c_id), b_sc in bigram_items:
        body.extend(struct.pack("<IIII", p_id, c_id, b_sc, 0))
    pad8(body)

    offset_init_nodes = 80 + len(body)
    for m in init_node_meta:
        body.extend(struct.pack("<BBHIIIII", *m))
    pad8(body)

    offset_init_refs = 80 + len(body)
    for wid in init_refs:
        body.extend(struct.pack("<I", wid))
    pad8(body)

    offset_strings = 80 + len(body)
    body.extend(str_pool)
    pad8(body)

    total_size = 80 + len(body)
    crc = zlib.crc32(body) & 0xFFFFFFFF

    header = struct.pack(
        "<8sIIIIQIIIIIIIIIIII",
        b"JGLEX01\x00",
        1,
        80,
        0,
        crc,
        total_size,
        len(CANONICAL_SYLLABLES),
        len(node_meta),
        len(packed_words),
        len(bigram_items),
        len(init_node_meta),
        len(init_refs),
        offset_nodes,
        offset_words,
        offset_bigrams,
        offset_init_nodes,
        offset_init_refs,
        offset_strings,
    )
    assert len(header) == 80, f"Unexpected header size: {len(header)}"

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, "wb") as f:
        f.write(header)
        f.write(body)

    size_mb = total_size / (1024.0 * 1024.0)
    print(f"[lexicon] Wrote {args.output}: {total_size} bytes ({size_mb:.2f} MB), CRC32=0x{crc:08X}")
    assert 2.5 <= size_mb <= 32.0, f"Lexicon size out of expected bounds: {size_mb:.2f} MB"

    # Self-verify binary integrity
    with open(args.output, "rb") as f:
        raw = f.read()
        assert raw[:8] == b"JGLEX01\x00"
        assert (zlib.crc32(raw[80:]) & 0xFFFFFFFF) == crc
    print("[lexicon] Integrity self-check PASSED.")


if __name__ == "__main__":
    main()
