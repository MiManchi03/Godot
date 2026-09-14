#!/usr/bin/env python3
# tools/terminology_registry.py
# 术语注册中心 - 术语治理核心库

import yaml
import re
from dataclasses import dataclass, asdict, field
from typing import List, Dict, Set, Optional
from pathlib import Path

@dataclass
class Term:
    canonical: str
    aliases: List[str] = field(default_factory=list)
    forbidden: List[str] = field(default_factory=list)
    zh_label: str = ""
    description: str = ""
    domain: str = ""  # entity, action, system, action, ui

class TerminologyRegistry:
    FILE = Path(".opencode/terminology/TERMINOLOGY.yaml")
    MAPPING_FILE = Path(".opencode/routing/zh-en-map.yaml")

    def __init__(self):
        self.terms: Dict[str, 'Term'] = {}  # canonical -> Term
        self._alias_to_canonical: Dict[str, str] = {}
        self._forbidden_set: Set[str] = set()
        self._zh_to_canonical: Dict[str, str] = {}
        self.load()

    def load(self):
        if self.FILE.exists():
            data = yaml.safe_load(self.FILE.read_text(encoding="utf-8")) or {}
            for category in ["entities", "actions", "systems"]:
                for item in data.get(category, []):
                    term = Term(**item)
                    self._register_term(term)

    def _register_term(self, term: 'Term'):
        self.terms[term.canonical] = term
        for alias in term.aliases:
            self._alias_to_canonical[alias.lower()] = term.canonical
        for forbidden in term.forbidden:
            self._forbidden_set.add(forbidden.lower())
        if term.zh_label:
            self._zh_to_canonical[term.zh_label.lower()] = term.canonical

    def register(self, canonical: str, aliases: List[str], forbidden: List[str],
                 zh_label: str, description: str = "", domain: str = ""):
        """注册新术语（去重、合并）"""
        canonical = canonical.lower().strip()
        aliases = [a.lower().strip() for a in aliases if a.strip()]
        forbidden = [f.lower().strip() for f in forbidden if f.strip()]

        if canonical in self.terms:
            term = self.terms[canonical]
            term.aliases = list(set(term.aliases + aliases))
            term.forbidden = list(set(term.forbidden + forbidden))
            if zh_label and not term.zh_label:
                term.zh_label = zh_label
            if description and not term.description:
                term.description = description
            if domain and not term.domain:
                term.domain = domain
        else:
            term = Term(
                canonical=canonical,
                aliases=aliases,
                forbidden=forbidden,
                zh_label=zh_label,
                description=description,
                domain=domain
            )
            self._register_term(term)
        self.save()
        self.sync_mapping_table()

    def save(self):
        data = {"entities": [], "actions": [], "systems": []}
        for term in self.terms.values():
            item = {
                "canonical": term.canonical,
                "aliases": term.aliases,
                "forbidden": term.forbidden,
                "zh_label": term.zh_label,
                "description": term.description,
                "domain": term.domain
            }
            if term.domain == "entity":
                data["entities"].append(item)
            elif term.domain == "action":
                data["actions"].append(item)
            elif term.domain == "system":
                data["systems"].append(item)
            else:
                data["entities"].append(item)

        self.FILE.parent.mkdir(parents=True, exist_ok=True)
        self.FILE.write_text(yaml.dump(data, allow_unicode=True, sort_keys=False), encoding="utf-8")

    def sync_mapping_table(self):
        """自动生成 zh-en-map.yaml"""
        mapping = {}
        for term in self.terms.values():
            for alias in term.aliases:
                if alias != term.canonical:
                    mapping[alias] = term.canonical
            if term.zh_label and term.zh_label != term.canonical:
                mapping[term.zh_label] = term.canonical

        # 添加 forbidden 反向映射
        for term in self.terms.values():
            for forbidden in term.forbidden:
                mapping[forbidden] = term.canonical

        self.MAPPING_FILE.parent.mkdir(parents=True, exist_ok=True)
        self.MAPPING_FILE.write_text(
            yaml.dump(mapping, allow_unicode=True, sort_keys=True),
            encoding="utf-8"
        )

    def get_canonical(self, term: str) -> str:
        """获取标准词"""
        return self._alias_to_canonical.get(term.lower(), term)

    def get_canonical_from_zh(self, zh_term: str) -> Optional[str]:
        """从中文获取标准词"""
        return self._zh_to_canonical.get(zh_term.lower())

    def is_forbidden(self, term: str) -> bool:
        return term.lower() in self._forbidden_set

    def all_terms(self) -> List['Term']:
        return list(self.terms.values())

    def find_substring_conflicts(self) -> List[tuple]:
        """自检：禁用词若是同表某「允许词」（别名/标签/标准词）的子串，
        则子串匹配无法区分二者，会误伤合法写法。
        返回 [(canonical, forbidden, allowed), ...]
        追溯：PITFALLS「术语表的禁用词是白名单词的子串」
        """
        conflicts = []
        for term in self.terms.values():
            allowed = {a.lower() for a in term.aliases}
            if term.zh_label:
                allowed.add(term.zh_label.lower())
            allowed.add(term.canonical.lower())
            for forbidden in term.forbidden:
                fl = forbidden.lower()
                for a in allowed:
                    if a and fl != a and fl in a:
                        conflicts.append((term.canonical, forbidden, a))
        return conflicts

    @staticmethod
    def _word_in_line(word_lower: str, line_lower: str) -> bool:
        """禁止词匹配：纯 ASCII 词用词边界（避免 bot 命中 both/robot），含 CJK 用子串"""
        if word_lower.isascii() and word_lower.isalpha():
            return re.search(
                r'(?<![a-z0-9_])' + re.escape(word_lower) + r'(?![a-z0-9_])',
                line_lower
            ) is not None
        return word_lower in line_lower

    def check_content(self, content: str, filepath: str, suggest: bool = False) -> List[Dict]:
        """检查内容中的术语违规

        - 禁止词命中即为 ERROR（阻断）
        - suggest=True 时才运行"疑似未注册术语"启发式；默认关闭，因其噪声极大
        """
        violations = []
        lines = content.split('\n')
        lower_lines = [line.lower() for line in lines]

        # 检查 forbidden 词
        for term in self.terms.values():
            for forbidden in term.forbidden:
                fw = forbidden.lower()
                if not any(self._word_in_line(fw, ll) for ll in lower_lines):
                    continue
                for i, line_lower in enumerate(lower_lines, 1):
                    if self._word_in_line(fw, line_lower):
                        violations.append({
                            "file": filepath,
                            "line": i,
                            "forbidden_word": forbidden,
                            "canonical": term.canonical,
                            "message": f'禁止词 "{forbidden}"，请用 canonical: {term.canonical}',
                            "severity": "ERROR"
                        })
                        break

        # 启发式发现未注册术语（默认关闭）
        if suggest:
            potential_terms = self._extract_potential_terms(content)
            for pt in potential_terms:
                if not self.has_term(pt) and not self.is_forbidden(pt):
                    for i, line in enumerate(lines, 1):
                        if pt in line:
                            violations.append({
                                "file": filepath,
                                "line": i,
                                "word": pt,
                                "message": f'疑似新术语 "{pt}" 未在术语表注册，请先注册',
                                "severity": "WARNING"
                            })
                            break

        return violations

    def _extract_potential_terms(self, content: str) -> Set[str]:
        """启发式提取潜在新术语"""
        # 提取 PascalCase、snake_case、UPPER_SNAKE_CASE 词汇
        patterns = [
            r'\b[A-Z][a-z]+(?:[A-Z][a-z]+)+\b',  # PascalCase
            r'\b[a-z]+(?:_[a-z]+)+\b',  # snake_case
            r'\b[A-Z]+(?:_[A-Z]+)+\b',  # UPPER_SNAKE_CASE
        ]
        found = set()
        for pattern in patterns:
            found.update(re.findall(pattern, content))
        # 过滤掉已知术语
        known = set()
        for term in self.terms.values():
            known.update([a.lower() for a in term.aliases])
            known.update([f.lower() for f in term.forbidden])
        return {t for t in found if t.lower() not in known and len(t) > 2}

    def has_term(self, term: str) -> bool:
        return term.lower() in self._alias_to_canonical or term.lower() in self._forbidden_set
