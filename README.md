# pjfzf

fzf 기반 프로젝트 디렉토리 네비게이터. frecency(빈도+최근성) 정렬로 자주 사용하는 프로젝트에 빠르게 이동합니다.

## 설치

### Homebrew

```zsh
brew tap K021/pjfzf
brew install pjfzf
```

설치 후 `~/.zshrc`에 추가:

```zsh
source $(brew --prefix)/share/pjfzf/pj.zsh
```

### 수동 설치

```zsh
curl -o ~/.pj.zsh https://raw.githubusercontent.com/K021/pjfzf/main/pj.zsh
echo 'source ~/.pj.zsh' >> ~/.zshrc
source ~/.zshrc
```

### 의존성

- zsh
- [fzf](https://github.com/junegunn/fzf) (`brew install fzf`)

## 사용법

```zsh
pj                  # fzf로 프로젝트 선택 후 이동
pj <query>          # 검색어로 필터링하여 선택
pj add <path>       # 베이스 디렉토리 등록
pj remove <path>    # 베이스 디렉토리 제거
pj list             # 등록된 베이스 디렉토리 확인
pj help             # 도움말
```

### 프로젝트 생성

```zsh
pjmk                # 베이스 디렉토리 선택 → 이름 입력 → 생성 후 이동
pjmk my-project     # 이름을 미리 지정
```

### Tab 완성

`pj ` 입력 후 Tab을 누르면 fzf가 실행됩니다.

## 설정

| 파일 | 경로 |
|------|------|
| 설정 | `~/.config/pj/config` |
| 히스토리 | `~/.config/pj/history` |

설정 파일에는 베이스 디렉토리 경로가 한 줄씩 기록됩니다. 기본값은 `~/projects`입니다.

## 라이선스

MIT
