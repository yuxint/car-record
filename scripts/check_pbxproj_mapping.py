#!/usr/bin/env python3
"""
检查并修复 Xcode project.pbxproj 与实际 Swift 文件的映射关系。

默认只检查：
  scripts/check_pbxproj_mapping.py

自动修复：
  scripts/check_pbxproj_mapping.py --fix
"""

from __future__ import annotations

import argparse
import re
import sys
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple


PBX_ID_RE = re.compile(r"^[0-9A-F]{24}$")
HEADER_RE = re.compile(r"^\s*([0-9A-F]{24}) /\* (.*?) \*/ = \{$")
FILE_REF_RE = re.compile(
    r"^\s*([0-9A-F]{24}) /\* (.*?) \*/ = \{isa = PBXFileReference;.*?path = (.*?); sourceTree = (.*?); \};\s*$"
)
BUILD_FILE_RE = re.compile(
    r"^\s*([0-9A-F]{24}) /\* (.*?) \*/ = \{isa = PBXBuildFile; fileRef = ([0-9A-F]{24}) /\* .*? \*/; \};\s*$"
)
CHILD_RE = re.compile(r"^\s*([0-9A-F]{24}) /\* (.*?) \*/,\s*$")
ASSIGN_RE = re.compile(r"^\s*(name|path|sourceTree) = (.*?);\s*$")


@dataclass
class Group:
    gid: str
    comment: str
    name_raw: Optional[str] = None
    path_raw: Optional[str] = None
    source_tree_raw: str = '"<group>"'
    children: List[str] = field(default_factory=list)


@dataclass
class FileRef:
    fid: str
    comment: str
    path_raw: str
    source_tree_raw: str

    @property
    def path_value(self) -> str:
        return strip_quotes(self.path_raw)


@dataclass
class BuildFile:
    bid: str
    comment: str
    file_ref_id: str


def strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        return value[1:-1]
    return value


def quote_if_needed(value: str) -> str:
    if re.fullmatch(r"[A-Za-z0-9_./-]+", value):
        return value
    return f'"{value}"'


def find_section(lines: List[str], name: str) -> Tuple[int, int]:
    begin = f"/* Begin {name} section */\n"
    end = f"/* End {name} section */\n"
    try:
        start = lines.index(begin)
        finish = lines.index(end)
    except ValueError:
        raise RuntimeError(f"找不到 section: {name}")
    return start, finish


def parse_id_comments(lines: List[str]) -> Dict[str, str]:
    result: Dict[str, str] = {}
    for line in lines:
        m = HEADER_RE.match(line)
        if m:
            result[m.group(1)] = m.group(2)
    return result


def parse_file_refs(section_lines: List[str]) -> Dict[str, FileRef]:
    refs: Dict[str, FileRef] = {}
    for line in section_lines:
        m = FILE_REF_RE.match(line)
        if not m:
            continue
        fid, comment, path_raw, source_tree_raw = m.groups()
        refs[fid] = FileRef(fid=fid, comment=comment, path_raw=path_raw, source_tree_raw=source_tree_raw)
    return refs


def parse_build_files(section_lines: List[str]) -> Dict[str, BuildFile]:
    result: Dict[str, BuildFile] = {}
    for line in section_lines:
        m = BUILD_FILE_RE.match(line)
        if not m:
            continue
        bid, comment, file_ref_id = m.groups()
        result[bid] = BuildFile(bid=bid, comment=comment, file_ref_id=file_ref_id)
    return result


def parse_groups(section_lines: List[str]) -> List[Group]:
    groups: List[Group] = []
    i = 0
    while i < len(section_lines):
        line = section_lines[i]
        h = HEADER_RE.match(line)
        if not h:
            i += 1
            continue
        gid, comment = h.groups()
        i += 1

        isa = None
        children: List[str] = []
        name_raw = None
        path_raw = None
        source_tree_raw = '"<group>"'

        while i < len(section_lines):
            cur = section_lines[i]
            if cur.strip() == "};":
                i += 1
                break
            if "isa = " in cur:
                isa = cur
            if cur.strip() == "children = (":
                i += 1
                while i < len(section_lines):
                    ch_line = section_lines[i]
                    if ch_line.strip() == ");":
                        i += 1
                        break
                    cm = CHILD_RE.match(ch_line)
                    if cm:
                        children.append(cm.group(1))
                    i += 1
                continue
            am = ASSIGN_RE.match(cur)
            if am:
                key, val = am.groups()
                if key == "name":
                    name_raw = val
                elif key == "path":
                    path_raw = val
                elif key == "sourceTree":
                    source_tree_raw = val
            i += 1

        if isa and "PBXGroup" in isa:
            groups.append(
                Group(
                    gid=gid,
                    comment=comment,
                    name_raw=name_raw,
                    path_raw=path_raw,
                    source_tree_raw=source_tree_raw,
                    children=children,
                )
            )
    return groups


def parse_sources_files(lines: List[str], sources_section_range: Tuple[int, int]) -> Tuple[str, List[str]]:
    start, end = sources_section_range
    section = lines[start + 1 : end]

    block_id = ""
    files: List[str] = []

    i = 0
    while i < len(section):
        h = HEADER_RE.match(section[i])
        if not h:
            i += 1
            continue
        candidate_id = h.group(1)
        i += 1
        saw_sources = False
        while i < len(section):
            cur = section[i]
            if "isa = PBXSourcesBuildPhase;" in cur:
                saw_sources = True
            if cur.strip() == "files = (":
                i += 1
                while i < len(section):
                    cl = section[i]
                    if cl.strip() == ");":
                        break
                    m = CHILD_RE.match(cl)
                    if m:
                        files.append(m.group(1))
                    i += 1
                if saw_sources:
                    block_id = candidate_id
                    return block_id, files
            if cur.strip() == "};":
                i += 1
                break
            i += 1

    raise RuntimeError("未找到 PBXSourcesBuildPhase files 列表")


def locate_carrecord_group(groups: List[Group]) -> Group:
    for g in groups:
        if g.name_raw and strip_quotes(g.name_raw) == "CarRecord":
            return g
    for g in groups:
        if g.comment == "CarRecord":
            return g
    raise RuntimeError("未找到 CarRecord 根组")


def build_parents(groups: List[Group]) -> Dict[str, str]:
    parent: Dict[str, str] = {}
    for g in groups:
        for c in g.children:
            parent[c] = g.gid
    return parent


def resolve_group_path(group: Group, group_map: Dict[str, Group], parent_map: Dict[str, str], cache: Dict[str, Optional[Path]]) -> Optional[Path]:
    if group.gid in cache:
        return cache[group.gid]

    source_tree = strip_quotes(group.source_tree_raw)
    path_val = strip_quotes(group.path_raw) if group.path_raw else ""

    if source_tree == "SOURCE_ROOT":
        base = Path(path_val) if path_val else Path(".")
        cache[group.gid] = base
        return base

    parent_id = parent_map.get(group.gid)
    if not parent_id:
        cache[group.gid] = None
        return None

    parent_group = group_map.get(parent_id)
    if not parent_group:
        cache[group.gid] = None
        return None

    parent_path = resolve_group_path(parent_group, group_map, parent_map, cache)
    if parent_path is None:
        cache[group.gid] = None
        return None

    if path_val:
        cache[group.gid] = parent_path / path_val
    else:
        cache[group.gid] = parent_path
    return cache[group.gid]


def generate_id(existing: Set[str]) -> str:
    while True:
        candidate = uuid.uuid4().hex.upper()[:24]
        if candidate not in existing and PBX_ID_RE.match(candidate):
            existing.add(candidate)
            return candidate


def format_group_block(group: Group, id_comments: Dict[str, str]) -> List[str]:
    out = [f"\t\t{group.gid} /* {group.comment} */ = {{\n"]
    out.append("\t\t\tisa = PBXGroup;\n")
    out.append("\t\t\tchildren = (\n")
    for cid in group.children:
        cmt = id_comments.get(cid, cid)
        out.append(f"\t\t\t\t{cid} /* {cmt} */,\n")
    out.append("\t\t\t);\n")
    if group.name_raw is not None:
        out.append(f"\t\t\tname = {group.name_raw};\n")
    if group.path_raw is not None:
        out.append(f"\t\t\tpath = {group.path_raw};\n")
    out.append(f"\t\t\tsourceTree = {group.source_tree_raw};\n")
    out.append("\t\t};\n")
    return out


def format_file_ref_line(file_ref: FileRef) -> str:
    return (
        f"\t\t{file_ref.fid} /* {file_ref.comment} */ = "
        f"{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_ref.path_raw}; sourceTree = {file_ref.source_tree_raw}; }};\n"
    )


def format_build_file_line(build: BuildFile, file_ref_comment: str) -> str:
    return (
        f"\t\t{build.bid} /* {build.comment} */ = "
        f"{{isa = PBXBuildFile; fileRef = {build.file_ref_id} /* {file_ref_comment} */; }};\n"
    )


def rewrite_sources_files(lines: List[str], sources_section_range: Tuple[int, int], file_ids: List[str], id_comments: Dict[str, str]) -> None:
    start, end = sources_section_range
    section = lines[start + 1 : end]

    i = 0
    while i < len(section):
        if section[i].strip() != "files = (":
            i += 1
            continue
        list_start = i + 1
        j = list_start
        while j < len(section) and section[j].strip() != ");":
            j += 1
        if j >= len(section):
            raise RuntimeError("Sources files 列表格式异常")

        new_block = [f"\t\t\t\t{fid} /* {id_comments.get(fid, fid)} */,\n" for fid in file_ids]
        section = section[:list_start] + new_block + section[j:]
        lines[start + 1 : end] = section
        return

    raise RuntimeError("未找到 Sources files 列表")


def main() -> int:
    parser = argparse.ArgumentParser(description="检查/修复 project.pbxproj 与 Swift 文件映射")
    parser.add_argument("--fix", action="store_true", help="自动修复")
    parser.add_argument(
        "--project",
        default="CarRecord/CarRecord.xcodeproj/project.pbxproj",
        help="project.pbxproj 路径",
    )
    parser.add_argument(
        "--source-root",
        default="ios/CarRecord",
        help="Swift 源码根目录（相对仓库）",
    )
    args = parser.parse_args()

    repo_root = Path.cwd()
    pbxproj_path = (repo_root / args.project).resolve()
    source_root = (repo_root / args.source_root).resolve()
    xcode_source_root = pbxproj_path.parent.parent

    if not pbxproj_path.exists():
        print(f"错误: 不存在 {pbxproj_path}", file=sys.stderr)
        return 2
    if not source_root.exists():
        print(f"错误: 不存在 {source_root}", file=sys.stderr)
        return 2

    raw_text = pbxproj_path.read_text(encoding="utf-8")
    lines = raw_text.splitlines(keepends=True)

    build_range = find_section(lines, "PBXBuildFile")
    file_ref_range = find_section(lines, "PBXFileReference")
    group_range = find_section(lines, "PBXGroup")
    sources_range = find_section(lines, "PBXSourcesBuildPhase")

    id_comments = parse_id_comments(lines)

    build_entries = parse_build_files(lines[build_range[0] + 1 : build_range[1]])
    file_refs = parse_file_refs(lines[file_ref_range[0] + 1 : file_ref_range[1]])
    groups = parse_groups(lines[group_range[0] + 1 : group_range[1]])
    _, source_build_ids = parse_sources_files(lines, sources_range)

    group_map = {g.gid: g for g in groups}
    parent_map = build_parents(groups)

    carrecord_group = locate_carrecord_group(groups)

    # 解析 group 逻辑路径（相对 SOURCE_ROOT）
    group_path_cache: Dict[str, Optional[Path]] = {}
    for g in groups:
        resolve_group_path(g, group_map, parent_map, group_path_cache)

    # fileRef -> 物理路径
    file_ref_group: Dict[str, str] = {}
    for g in groups:
        for child in g.children:
            if child in file_refs:
                file_ref_group[child] = g.gid

    pbx_swift_abs_to_ref: Dict[Path, str] = {}
    stale_file_ref_ids: Set[str] = set()

    for fid, fr in file_refs.items():
        if strip_quotes(fr.source_tree_raw) != "<group>":
            continue
        if not fr.path_value.endswith(".swift"):
            continue

        gid = file_ref_group.get(fid)
        if not gid:
            stale_file_ref_ids.add(fid)
            continue

        group_rel = group_path_cache.get(gid)
        if group_rel is None:
            stale_file_ref_ids.add(fid)
            continue

        abs_path = (xcode_source_root / group_rel / fr.path_value).resolve()
        if str(abs_path).startswith(str(source_root)):
            if abs_path.exists():
                pbx_swift_abs_to_ref[abs_path] = fid
            else:
                stale_file_ref_ids.add(fid)

    fs_swift_files = {
        p.resolve()
        for p in source_root.rglob("*.swift")
        if p.is_file()
    }

    missing_files = sorted(fs_swift_files - set(pbx_swift_abs_to_ref.keys()))
    mapped_basenames = {p.name for p in pbx_swift_abs_to_ref.keys()}
    duplicate_name_missing = sorted([p for p in missing_files if p.name in mapped_basenames])
    missing_files = sorted([p for p in missing_files if p.name not in mapped_basenames])
    stale_ref_paths = sorted(set(pbx_swift_abs_to_ref.keys()) - fs_swift_files)
    for stale_path in stale_ref_paths:
        fid = pbx_swift_abs_to_ref.get(stale_path)
        if fid:
            stale_file_ref_ids.add(fid)

    # build file 与 source phase 关联
    build_ids_by_ref: Dict[str, List[str]] = {}
    for bid, be in build_entries.items():
        build_ids_by_ref.setdefault(be.file_ref_id, []).append(bid)

    source_build_set = set(source_build_ids)

    # 需要清理的 build id：指向 stale fileRef，或者 buildFile 指向不存在 fileRef
    stale_build_ids: Set[str] = set()
    for bid, be in build_entries.items():
        if be.file_ref_id in stale_file_ref_ids or be.file_ref_id not in file_refs:
            stale_build_ids.add(bid)

    # 现有有效 swift 文件但不在 sources 的 build file
    for path, fid in pbx_swift_abs_to_ref.items():
        if path not in fs_swift_files:
            continue
        bids = build_ids_by_ref.get(fid, [])
        if not any(b in source_build_set for b in bids):
            # 算缺失，后面补一个 build file 并加入 sources
            missing_files.append(path)
            stale_file_ref_ids.add(fid)
            for b in bids:
                stale_build_ids.add(b)

    # 去重
    missing_files = sorted(set(missing_files))

    print("检查结果:")
    print(f"- 源码中存在且可自动补齐的 Swift 文件缺失映射: {len(missing_files)}")
    print(f"- 与已映射文件同名（疑似历史遗留）的未映射 Swift 文件: {len(duplicate_name_missing)}")
    print(f"- pbxproj 中无效/失效的 Swift 文件映射: {len(stale_file_ref_ids)}")
    print(f"- pbxproj 中无效/失效的 BuildFile: {len(stale_build_ids)}")

    if missing_files:
        print("\n缺失映射文件:")
        for p in missing_files:
            print(f"  + {p.relative_to(repo_root)}")

    if duplicate_name_missing:
        print("\n同名未映射文件（仅提示，不自动修复）:")
        for p in duplicate_name_missing:
            print(f"  ! {p.relative_to(repo_root)}")

    if stale_file_ref_ids:
        print("\n失效 FileReference:")
        for fid in sorted(stale_file_ref_ids):
            fr = file_refs.get(fid)
            if fr:
                print(f"  - {fid} ({fr.comment})")
            else:
                print(f"  - {fid}")

    if stale_build_ids:
        print("\n失效 BuildFile:")
        for bid in sorted(stale_build_ids):
            be = build_entries.get(bid)
            if be:
                print(f"  - {bid} ({be.comment})")
            else:
                print(f"  - {bid}")

    if not args.fix:
        has_issue = bool(missing_files or stale_file_ref_ids or stale_build_ids)
        print("\n未执行修复（如需自动修复请加 --fix）")
        return 1 if has_issue else 0

    if not (missing_files or stale_file_ref_ids or stale_build_ids):
        print("\n未发现可修复项，project.pbxproj 无需修改")
        return 0

    # ===== 开始修复 =====
    existing_ids: Set[str] = set(id_comments.keys())

    # 1) 清理 stale fileRef + stale buildFile + sources 列表
    for g in groups:
        g.children = [c for c in g.children if c not in stale_file_ref_ids]

    build_entries = {bid: be for bid, be in build_entries.items() if bid not in stale_build_ids}
    source_build_ids = [bid for bid in source_build_ids if bid not in stale_build_ids]

    for fid in stale_file_ref_ids:
        file_refs.pop(fid, None)
        id_comments.pop(fid, None)

    for bid in stale_build_ids:
        id_comments.pop(bid, None)

    # 2) 按目录补 group/fileRef/buildFile/sources
    group_map = {g.gid: g for g in groups}
    parent_map = build_parents(groups)
    group_path_cache = {}
    for g in groups:
        resolve_group_path(g, group_map, parent_map, group_path_cache)

    def ensure_group_for_dir(abs_dir: Path) -> Group:
        rel_parts = abs_dir.relative_to(source_root).parts
        current = carrecord_group

        for part in rel_parts:
            found = None
            for cid in current.children:
                cg = group_map.get(cid)
                if not cg:
                    continue
                candidate = strip_quotes(cg.path_raw) if cg.path_raw else (strip_quotes(cg.name_raw) if cg.name_raw else "")
                if candidate == part:
                    found = cg
                    break

            if found:
                current = found
                continue

            new_gid = generate_id(existing_ids)
            new_group = Group(
                gid=new_gid,
                comment=part,
                name_raw=None,
                path_raw=quote_if_needed(part),
                source_tree_raw='"<group>"',
                children=[],
            )
            groups.append(new_group)
            group_map[new_gid] = new_group
            current.children.append(new_gid)
            id_comments[new_gid] = part
            current = new_group

        return current

    for abs_file in missing_files:
        parent_dir = abs_file.parent
        group = ensure_group_for_dir(parent_dir)

        basename = abs_file.name
        new_fid = generate_id(existing_ids)
        file_ref = FileRef(
            fid=new_fid,
            comment=basename,
            path_raw=quote_if_needed(basename),
            source_tree_raw='"<group>"',
        )
        file_refs[new_fid] = file_ref
        id_comments[new_fid] = basename
        group.children.append(new_fid)

        new_bid = generate_id(existing_ids)
        build_comment = f"{basename} in Sources"
        build_entry = BuildFile(
            bid=new_bid,
            comment=build_comment,
            file_ref_id=new_fid,
        )
        build_entries[new_bid] = build_entry
        id_comments[new_bid] = build_comment
        source_build_ids.append(new_bid)

    # 3) 重写 section
    # BuildFile
    new_build_lines = [
        format_build_file_line(be, file_refs[be.file_ref_id].comment)
        for be in sorted(build_entries.values(), key=lambda x: (x.comment.lower(), x.bid))
    ]
    lines[build_range[0] + 1 : build_range[1]] = new_build_lines

    # FileReference
    non_swift_lines: List[str] = []
    old_file_ref_lines = lines[file_ref_range[0] + 1 : file_ref_range[1]]
    for line in old_file_ref_lines:
        if FILE_REF_RE.match(line):
            continue
        if line.strip():
            non_swift_lines.append(line)

    swift_lines = [
        format_file_ref_line(fr)
        for fr in sorted(file_refs.values(), key=lambda x: (x.comment.lower(), x.fid))
    ]
    lines[file_ref_range[0] + 1 : file_ref_range[1]] = non_swift_lines + swift_lines

    # Group
    group_blocks: List[str] = []
    for g in groups:
        group_blocks.extend(format_group_block(g, id_comments))
    lines[group_range[0] + 1 : group_range[1]] = group_blocks

    # Sources files
    source_build_ids_unique = []
    seen_source_ids = set()
    for bid in source_build_ids:
        if bid not in build_entries:
            continue
        if bid in seen_source_ids:
            continue
        seen_source_ids.add(bid)
        source_build_ids_unique.append(bid)

    source_build_ids_unique.sort(key=lambda bid: (build_entries[bid].comment.lower(), bid))
    rewrite_sources_files(lines, sources_range, source_build_ids_unique, id_comments)

    new_text = "".join(lines)
    pbxproj_path.write_text(new_text, encoding="utf-8")

    print("\n已执行修复并写回 project.pbxproj")
    return 0


if __name__ == "__main__":
    sys.exit(main())
