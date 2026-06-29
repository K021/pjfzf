---
작성일시: 2026-06-29
작성맥락: 다른 맥에서 brew 설치 실패 → tap 수정 후, homebrew-core 공식 등재 준비
검토: 1회(자체) · 접지=실제 brew audit/style/install 실행 결과 · 발견 0
---

# homebrew-core 제출 준비

## 요약
- **현재 상태**: personal tap(`K021/homebrew-pjfzf`) 설치는 **수정 완료·검증됨**. core 등재용 formula도 **기술적으로 준비 완료**(`brew audit --strict --online --new`·`brew style` 통과).
- **남은 게이트(제출해도 지금은 거부됨)**: ① 인지도(notability) 미달 — 본인 제출 기준 별 ≥225 / fork ≥90 / watcher ≥90 중 하나 필요, 현재 **0/0/0**. ② "`.zshrc`에 `source`하는 zsh 스크립트"라는 형태가 core의 "CLI tool/library 기본" 방침과 충돌할 **설계 리스크(가설, 메인테이너 판단)**.
- **결론**: 지금은 제출 불가. **tap으로 배포·홍보해 별을 모으는 것이 1단계**, 임계치 도달 시 아래 formula로 PR 1건이면 끝.

## 목차
1. 등재 기준 (공식 문서 접지)
2. 준비된 core formula
3. 제출 절차 (임계치 도달 시)
4. 설계 리스크와 대안

---

## 1. 등재 기준 (docs.brew.sh/Acceptable-Formulae, 2026-06 확인)

| 항목 | 기준 | pjfzf 현황 |
|---|---|---|
| 인지도 (본인이 만든 SW 직접 제출) | fork ≥90 **또는** watcher ≥90 **또는** star ≥225 | ⚠ 0 / 0 / 0 |
| 인지도 (제3자 제출) | fork ≥30 / watcher ≥30 / star ≥75 | ⚠ 0 / 0 / 0 |
| 안정 버전 태그 | tagged stable tarball 필수 | ✅ v0.1.0 |
| 라이선스 | DFSG 호환 오픈소스 | ✅ MIT |
| 자가 업그레이드 X / GUI 아님 / CLI·library | CLI tool or library 기본 | ◐ shell 함수 라이브러리(리스크 §4) |
| 테스트 | `test do` 블록 필수 | ✅ 아래 formula에 포함 |

> 인지도 수치는 **PR 심사 단계에서** 검사된다. 로컬 `brew audit`는 통과해도 인지도 미달이면 봇/메인테이너가 PR을 닫는다.

## 2. 준비된 core formula

`brew style`(tap 컨텍스트, offense 0) + `brew audit --strict --online --new`(exit 0, 발견 0) 통과 확인됨. tap formula와의 차이는 **`test do` 블록 추가**(core 필수) 및 caveats의 `opt_pkgshare` 사용.

```ruby
class Pjfzf < Formula
  desc "Project directory navigator with fuzzy finding"
  homepage "https://github.com/K021/pjfzf"
  url "https://github.com/K021/pjfzf/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "7204dc6fdb506bee29e97025b1704a5fd789547f54bb5c851ad6d4bf21dde1bd"
  license "MIT"

  depends_on "fzf"

  def install
    pkgshare.install "pj.zsh"
  end

  def caveats
    <<~EOS
      To enable pjfzf, add the following to your ~/.zshrc:
        source #{opt_pkgshare}/pj.zsh
    EOS
  end

  test do
    assert_match "Project directory navigator",
                 shell_output("zsh -fc 'source #{pkgshare}/pj.zsh && pj help'")
  end
end
```

## 3. 제출 절차 (별 ≥225 등 임계치 도달 시)

```zsh
# 1. homebrew-core fork & clone
gh repo fork Homebrew/homebrew-core --clone
# 2. 위 formula를 Formula/p/pjfzf.rb 로 추가 (core는 첫 글자 하위 디렉토리)
# 3. 로컬 검증
brew install --build-from-source ./Formula/p/pjfzf.rb
brew test pjfzf
brew audit --strict --online --new pjfzf
# 4. PR 생성 (제목: "pjfzf 0.1.0 (new formula)")
git checkout -b pjfzf
git add Formula/p/pjfzf.rb && git commit -m "pjfzf 0.1.0 (new formula)"
gh pr create --repo Homebrew/homebrew-core
```

등재되면 사용자는 `brew install pjfzf` 한 줄(tap·trust 불필요).

## 4. 설계 리스크와 대안

- **리스크**: core는 "기본적으로 CLI tool이나 library를 설치"하길 요구. pjfzf는 바이너리가 없고 `.zshrc`에 `source`해야 동작하는 zsh 함수 모음 → 메인테이너가 "shell plugin/dotfile류는 tap에서 배포하라"며 반려할 가능성(공식 문서에 명문 규정은 **없음** → 확정 아닌 가설).
- **대안 A**: tap 유지 + 인지도 확보에 집중(가장 현실적). zsh 생태계는 plugin manager(oh-my-zsh/zinit) 배포가 관행이라, core 미등재여도 사용자 도달에는 충분.
- **대안 B**: `pj`를 **실행 가능한 CLI 바이너리**로도 제공(예: 핵심 로직을 별도 실행파일로, shell 함수는 thin wrapper)하면 core 적합성이 올라감 — 단 frecency·`cd` 특성상 shell 통합이 본질이라 과도할 수 있음.

## 관련
- 홍보 계획: [260315-1-홍보-계획.md](./260315-1-홍보-계획.md)
- tap 설치 버그 수정: 본 작업에서 sha256(`9d9d90`→`7204dc`) 교정 + README `brew trust` 단계 추가 + repo 중복 Formula 제거.
