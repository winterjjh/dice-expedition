# 주사위 원정대

직업마다 고유한 주사위를 가진 영웅 네 명으로 파티를 꾸려 세 개의 막을 돌파하는 턴제 로그라이크.
주사위의 여섯 면은 숫자가 아닌 직업 고유 스킬이며, 굴림과 다시 굴림, 면 강화, 전직으로 파티를 성장시키는 구조.

## 설치 없이 해보는 방법

- **웹에서 바로 실행**: 저장소가 공개 상태이고 Settings → Pages → Source가 "GitHub Actions"로 설정된 경우, `https://winterjjh.github.io/dice-expedition/` 주소에서 실행
- **Windows 실행 파일**: 저장소의 Actions 탭 → 가장 최근의 초록색 build 실행 → 아래쪽 Artifacts의 `dice-expedition-windows` 내려받기 → 압축 해제 후 `dice-expedition.exe` 실행
- main 브랜치에 변경이 올라갈 때마다 자동 점검과 빌드가 다시 진행

## 게임 구성

- 직업 8종(방패병, 검투사, 궁수, 도적, 화염술사, 서리술사, 치유사, 음유시인), 단순한 견습 주사위(빈 면 2개)로 시작해 막을 깰 때마다 전직, 마지막 전직은 두 갈래 중 선택
- 주사위 여섯 면 모두가 그 직업만의 스킬(총 47종): 방패병의 대신 맞기·가시 버티기, 궁수의 조준·표식 화살, 도적의 훔치기·급소 찌르기, 서리술사의 얼리기·산산조각, 음유시인의 앙코르·조율 등
- 매 턴 네 영웅에게 나온 스킬 조합으로 싸우는 구조: 얼린 적에게 산산조각 세 배, 독 걸린 적에게 급소 찌르기 두 배, 표식 찍은 적에게 집중 공격
- 마나를 모아 쓰는 직업별 주문 10종, 장비 12종
- 갈림길 지도: 전투, 정예, 대장간, 상점, 사건, 우두머리
- 막마다 우두머리 1체, 체력 절반 이하에서 2단계 행동 전환
- 자동 저장과 이어하기

## 프로젝트 구조

| 경로 | 내용 |
| --- | --- |
| `data/faces.json` | 주사위 면 정의(이름, 분류, 대상, 설명) |
| `data/classes.json` | 직업별 체력, 주사위 6면, 전직 경로, 주문 |
| `data/spells.json` | 주문 비용과 효과 설명 |
| `data/items.json` | 장비 효과 |
| `data/enemies.json` | 적 능력치, 적 주사위, 막별 조우 구성 |
| `scripts/combat.gd` | 전투 규칙 전체 |
| `scripts/game.gd` | 원정 진행, 지도 생성, 저장 |
| `scripts/data.gd` | 데이터 불러오기와 영웅 면 계산 |
| `scripts/ui/` | 화면 구성(모든 화면을 코드로 생성) |
| `tests/sim.gd` | 데이터 검증과 자동 플레이 120회 승률 측정 |
| `tests/ui_smoke.gd` | 모든 화면을 한 번씩 여는 점검 |

밸런스 조정은 `data/` 폴더의 JSON 수정만으로 가능하며, 수정 후 올리면 자동 점검 로그(Actions → build → Balance and data check)에서 봇 승률 확인 가능.

## Godot에서 직접 열기

1. Godot 4.3 표준판 설치(설치 없는 단일 실행 파일 형태로도 사용 가능)
2. 이 저장소를 내려받아 Godot 프로젝트 관리자에서 `project.godot` 가져오기
3. F5로 실행

명령줄 점검:

```
godot --headless --path . res://tests/sim.tscn
godot --headless --path . res://tests/ui_smoke.tscn
```

## 스토어 출시 준비 사항

- **Steam**: Windows 빌드 그대로 사용 가능, Steamworks 연동(업적, 클라우드 저장)은 GodotSteam 추가 필요
- **Android**: Godot의 Android 내보내기 사용, 서명 키와 Android SDK 필요(CI에서 처리 가능)
- **iOS**: Xcode가 있는 macOS 환경 필요(GitHub Actions의 macOS 실행기로 처리 가능)
- 화면은 1280×800 기준, 비율에 맞춰 늘어나는 설정으로 세로 화면 대응은 추가 작업 필요

## 사용 자원

- 글꼴: Galmuri, SIL Open Font License 1.1 (`fonts/Galmuri-OFL.md`)
- 그 밖의 그래픽은 모두 코드로 그린 도형과 글자

## 그림 넣는 방법

- `art/hero/<직업 키>.png`, `art/enemy/<적 키>.png`, `art/skill/<스킬 키>.png`, `art/ui/<이름>.png`, `art/bg/<이름>.jpg`에 파일이 있으면 자동으로 사용, 없으면 코드로 그린 그림으로 대체
- 여러 개가 모인 원본 그림은 `python3 tools/slice_art.py <원본 폴더> .`로 낱개 분할
