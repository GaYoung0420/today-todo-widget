# FocusTodo

FocusTodo는 오늘 할 일, 뽀모도로 집중 세션, 메모, 집중 음악, 방해 사이트 차단, Notion 데이터베이스 동기화를 한곳에서 관리하는 macOS 메뉴바 앱입니다.

큰 프로젝트 관리 도구가 아니라, 작업 중에도 곁에 작게 띄워두고 바로 다음 할 일에 집중하기 위한 개인용 데스크톱 유틸리티입니다.

## 다운로드

최신 배포 파일:

[FocusTodo-macOS.zip](https://github.com/GaYoung0420/today-todo-widget/raw/main/releases/FocusTodo-macOS.zip)

압축을 풀고 `FocusTodo.app`을 실행하면 메뉴바에 타이머 아이콘이 나타납니다.

현재 배포 파일은 개발자 서명 및 Apple 공증을 거치지 않은 빌드입니다. macOS에서 실행을 막으면 Finder에서 앱을 우클릭한 뒤 `열기`를 선택해 실행하세요.

## 주요 기능

- 오늘, 이전 날짜, 다음 날짜를 오가며 관리하는 데일리 투두
- 메뉴바에서 바로 여는 투두 패널
- 선택한 할 일에 연결되는 뽀모도로 타이머
- 할 일별 목표/완료 뽀모도로 카운트
- 할 일 메모 패널
- 집중 세션 중 방해 사이트 차단
- 내장 집중 음악
- 타이머 길이, 차단 사이트, 동기화 옵션 설정
- Notion 데이터베이스 양방향 동기화
- 위젯에서 바로 실행하는 수동 새로고침과 자동 동기화
- Notion 토큰은 macOS Keychain에 저장

## 실행 요구사항

- macOS 14 이상

소스에서 직접 빌드하려면 아래 도구가 필요합니다.

- Xcode Command Line Tools
- Swift 5.9 이상

```bash
xcode-select --install
```

## 소스에서 실행하기

프로젝트 루트에서 실행합니다.

```bash
bash script/build_and_run.sh
```

이 스크립트는 Swift 패키지를 빌드하고 `dist/FocusTodo.app`을 만든 뒤, 기존 FocusTodo 프로세스를 종료하고 앱을 다시 엽니다.

실행 후 macOS 메뉴바의 타이머 아이콘을 클릭하면 투두 패널이 열립니다. 우클릭하면 앱 메뉴를 열 수 있습니다.

## 배포 파일 만들기

배포용 앱 zip을 다시 만들려면 아래 명령을 실행합니다.

```bash
bash script/package_release.sh
```

생성 결과:

```text
dist/FocusTodo.app
releases/FocusTodo-macOS.zip
```

## 개발 명령어

빌드만 실행:

```bash
swift build
```

빌드, 실행, 프로세스 확인:

```bash
bash script/build_and_run.sh --verify
```

앱 로그와 함께 실행:

```bash
bash script/build_and_run.sh --logs
```

텔레메트리 로그와 함께 실행:

```bash
bash script/build_and_run.sh --telemetry
```

LLDB로 디버깅:

```bash
bash script/build_and_run.sh --debug
```

## Notion 연동

FocusTodo는 Notion 데이터베이스의 행을 투두로 가져오고, 앱에서 수정한 내용을 다시 해당 Notion 페이지에 반영할 수 있습니다.

### 설정 방법

1. Notion integration을 생성합니다.
2. integration token을 복사합니다.
3. integration에 읽기, 삽입, 업데이트 권한이 있는지 확인합니다.
4. 연동할 Notion 데이터베이스를 전체 페이지로 엽니다.
5. 데이터베이스의 연결 메뉴에서 integration을 공유합니다.
6. FocusTodo에서 설정을 열고 `노션` 탭으로 이동합니다.
7. `노션 연동`을 켭니다.
8. integration token을 붙여넣습니다.
9. 데이터베이스 URL 또는 데이터베이스 ID를 붙여넣습니다.
10. `가져오기`를 클릭합니다.
11. 계속 자동으로 동기화하려면 `자동 동기화`를 켜둡니다.

예를 들어 데이터베이스 링크가 아래와 같다면:

```text
https://www.notion.so/workspace/0123456789abcdef0123456789abcdef?v=...
```

데이터베이스 ID는 아래 값입니다.

```text
0123456789abcdef0123456789abcdef
```

FocusTodo에는 전체 링크 또는 데이터베이스 ID만 입력해도 됩니다.

### 속성 매핑

FocusTodo는 Notion 데이터베이스의 일반적인 속성 이름과 타입을 자동으로 감지합니다.

- 제목: 첫 번째 Notion `title` 속성
- 메모: `notes`, `note`, `memo`, `description`, `설명`, `메모` 같은 rich text 속성
- 완료 여부: `done`, `complete`, `completed`, `완료`, `완료 여부` 같은 checkbox 또는 status 속성
- 날짜: `date`, `due`, `deadline`, `schedule`, `날짜`, `일자`, `일정`, `기한`, `마감` 같은 date 속성
- 목표 뽀모도로: `pomodoro`, `target`, `estimate`, `뽀모도로`, `예상` 같은 number 속성

지원하지 않는 속성은 그대로 둡니다. FocusTodo는 안전하게 감지할 수 있는 `title`, `rich_text`, `checkbox`, `status`, `date`, `number` 타입에만 값을 씁니다.

### 동기화 방식

- `가져오기`는 연결된 Notion 데이터베이스의 행을 가져옵니다.
- 자동 동기화는 백그라운드에서 Notion을 주기적으로 확인합니다. 기본 간격은 60초입니다.
- 위젯을 열거나 날짜를 바꾸면 오래된 데이터를 새로고침합니다.
- Notion에서 가져온 투두는 Notion page ID로 매칭해 중복 생성을 막습니다.
- Notion에서 삭제된 행은 다음 가져오기 때 로컬의 Notion 연동 투두 목록에서도 제거됩니다.
- Notion 연동이 켜진 상태에서 새 로컬 투두를 만들면 Notion 페이지가 생성됩니다.
- 제목, 메모, 완료 여부, 날짜, 목표 뽀모도로 수를 수정하면 지원되는 Notion 속성에 반영됩니다.
- Notion과 연결된 투두를 삭제하면 해당 Notion 페이지를 영구 삭제하지 않고 보관 처리합니다.

## 로컬 데이터

앱 상태는 아래 위치에 저장됩니다.

```text
~/Library/Application Support/FocusTodo/state.json
```

Notion integration token은 `state.json`에 저장하지 않고 macOS Keychain에 저장합니다.

## 사이트 차단 안내

사이트 차단은 뽀모도로 집중 세션 중에 동작합니다. 앱은 설정에 등록된 차단 사이트 목록과 현재 브라우저 URL을 비교합니다. 사용하는 브라우저와 macOS 설정에 따라 자동화 또는 접근성 관련 권한 요청이 나타날 수 있습니다.

## 문제 해결

Notion에서 `Could not find database with ID` 같은 404 오류가 나오면 데이터베이스 ID 파싱은 되었지만 integration이 해당 데이터베이스에 접근할 수 없는 상태입니다.

아래 항목을 확인하세요.

- 원본 Notion 데이터베이스가 integration과 공유되어 있는지 확인
- linked database view가 아니라 원본 데이터베이스 URL을 사용했는지 확인
- integration이 같은 Notion 워크스페이스에 속해 있는지 확인
- integration에 읽기, 삽입, 업데이트 권한이 있는지 확인
- relation 속성을 사용한다면 연결된 데이터베이스도 integration과 공유되어 있는지 확인

앱을 실행했는데 창이 보이지 않으면 macOS 메뉴바의 타이머 아이콘을 확인하거나 아래 명령으로 프로세스를 확인하세요.

```bash
pgrep -x FocusTodo
```

## 프로젝트 구조

```text
Package.swift
Sources/FocusTodo/
  App/
  Models/
  Services/
  Stores/
  Support/
  Views/
  Resources/
script/build_and_run.sh
script/package_release.sh
releases/FocusTodo-macOS.zip
```

## 라이선스

아직 별도 라이선스를 지정하지 않았습니다.
