# Quotes

문장 단위로 읽고, 번역하고, 수집하는 iOS 리딩 플랫폼 (iPhone / iPad).

## 구조

```
Quotes/                  iOS 앱 (SwiftUI, iOS 17+)
├── App/                 앱 엔트리, 4탭 셸 (홈 · 둘러보기 · 서재 · 마이)
├── Core/
│   ├── Models/          도메인 모델 — 문장 트리(컬렉션→책→청크→문단→문장), 북마크 5종
│   ├── Contracts/       프로토콜 계약 (ContentRepository, BookmarkStore, …) + AppEnvironment
│   ├── Persistence/     SwiftData 스키마 (북마크, 읽기 위치)
│   ├── Services/        구현체 — 번들 JSON 콘텐츠, SwiftData 스토어, 내장 번역
│   └── DesignSystem/    공통 디자인 토큰/컴포넌트
├── Features/            Reader · Books · Home · Discover · My · Bookmarks
└── Resources/           샘플 콘텐츠 (문장 분리 + ko 번역 내장)

functions/               Firebase Cloud Functions (TS) — LLM 번역 + Firestore 캐시
scripts/                 Firestore 시드/스키마 검증
docs/                    Firestore 스키마 · 백엔드 설정 · iOS 연동 가이드
```

## 핵심 설계 원칙

**문장이 최소 단위다.** 모든 콘텐츠는 임포트 시점에 문장으로 분리되어 안정적인 ID(`b001-c001-p001-s001`)를 부여받는다. 북마크·하이라이트·읽기 위치는 전부 문장 ID에 앵커링되므로 기기·폰트·보기 모드가 바뀌어도 깨지지 않는다. 페이지 번호는 정본이 아니라 레이아웃 키별 파생 캐시다.

## 실행

```bash
brew install xcodegen   # 없다면
xcodegen generate
open Quotes.xcodeproj   # 시뮬레이터 선택 후 Run
```

Firebase 없이 번들 샘플 콘텐츠로 동작한다. 백엔드 배포는 `docs/backend-setup.md` 참조.

## 기능

- **리더**: 문장 / 문단 / 페이지 보기 모드, 원문 아래 한국어 번역 표시, 드래그 하이라이트
- **북마크 5종**: 하이라이트 · 캡처(온디맨드 이미지 렌더링+공유) · 페이지 · 책 · 컬렉션 — 각각 이름 지정 가능
- **마이**: 프로필 · 읽기 설정 · 북마크 관리(이름 변경 / 삭제 / 원문 위치로 이동)
