# 모듈러 중량 Exporter (SketchUp 확장 프로그램) v0.1

개발명세 `모듈러_중량산출_개발명세_v0.1.md`의 1장(SketchUp 작업 규칙)과 6장(Export JSON 계약)을
구현한 SketchUp Ruby 확장 프로그램입니다. `webapp/`이 읽는 것과 동일한 형식의 JSON을 만듭니다.

**실행 확인 안내**: 이 확장 프로그램은 SketchUp이 설치되지 않은 환경에서 문서상 SketchUp Ruby API
사양에 맞춰 작성했습니다. 실제 SketchUp에서 아직 실행해보지 않았으므로, 실무 모델에 쓰기 전에
반드시 아래 "먼저 테스트해보기"로 간단한 형상부터 확인해 보세요.

## 설치

1. `modular_weight_exporter.rb` 파일과 `modular_weight_exporter` 폴더(그 안의 모든 .rb 파일 포함)를
   함께 SketchUp Plugins 폴더에 복사합니다.
   - Windows: `C:\Users\<사용자>\AppData\Roaming\SketchUp\SketchUp 20XX\SketchUp\Plugins`
2. SketchUp을 재시작합니다.
3. 메뉴 `Extensions(확장 프로그램) → 모듈러 중량 Exporter`가 보이면 설치 완료입니다.
   (Extension Manager에서 "모듈러 중량 Exporter"가 활성화되어 있는지 확인하세요.)

`.rbz`로 배포하려면 `modular_weight_exporter.rb`와 `modular_weight_exporter/` 폴더를 압축해
확장자를 `.rbz`로 바꾼 뒤 Extension Manager의 "Install Extension"으로 설치합니다.

## 사용 순서

1. **모델 준비**: 명세 1.1~1.3에 맞춰 실제 크기로 모델링합니다. 부재는 각각 Group 또는 Component로 묶습니다.
2. **① 모듈로 지정**: 프로젝트 최상위 Group/Component를 선택하고 실행합니다. (module_id 자동 발급)
3. **② 컨테이너로 지정** (선택): 공종별로 묶은 그룹을 선택하고 실행 → 공종(STRUCTURE 등) 선택.
   PART가 CONTAINER 없이 MODULE 바로 아래 있어도 됩니다.
4. **③ 부재로 지정**: 실제 산출 대상 Group/Component(하나 이상 다중 선택 가능)를 선택하고 실행 →
   공종과 계산 기준(quantity_basis)을 선택합니다.
5. **자재 Tag 지정**: SketchUp 기본 **Tag(레이어)** 패널에서 PART에 Tag를 지정합니다
   (`ST_HSS_100X100X4.5`처럼 대문자+숫자+`_`+`.`만 사용). 별도 명령이 없습니다 - SketchUp 자체 기능입니다.
6. **AREA 부재**: PART를 더블클릭해 편집 모드로 들어가 기준면(들)을 클릭 선택한 뒤
   **⑤ 기준면 지정**을 실행합니다.
7. **LENGTH 부재**: PART를 더블클릭해 편집 모드로 들어간 뒤 **⑥ 기준축 지정**을 실행하고
   시작점 → 끝점을 클릭합니다. (로컬 X축이 길이 방향이라는 관례를 가정합니다 - 1.3절)
8. **COUNT 부재**: 제조사 CG가 있으면 편집 모드에서 **⑦ 무게중심 보정점 지정**으로 점을 찍고
   근거를 입력합니다. 없으면 자동으로 경계상자 중심을 ESTIMATED로 사용합니다.
9. **VOLUME 부재**: 추가 지정 없이 닫힌 솔리드면 됩니다.
10. **⑩ 중량 데이터 검증**으로 오류/경고를 확인하고 고칩니다.
11. **⑪ JSON 내보내기**로 저장한 뒤, 웹앱의 "업로드·검증" 탭에서 그 파일을 업로드합니다.

## 알려진 한계 (v0.1)

- **네이티브 UI만 사용**: 웹앱처럼 그래픽 속성 패널이 아니라 SketchUp 기본 메뉴/대화상자를 씁니다.
- **PART 내부 형상은 비교적 단순해야 함**: AREA/VOLUME 계산 시 PART 자신의 하위 그룹까지는
  재귀로 형상을 모으지만, 그 안에 role이 지정된 그룹(다른 PART 등)이 있으면 오류(NESTED_PART)로
  처리하고 그 부분은 계산에서 제외합니다.
- **LENGTH 방향은 로컬 X축 고정 관례**: 기준축을 임의 방향으로 찍을 수는 있지만, 단면 스케일
  검사(INVALID_SECTION_SCALE)는 "로컬 X가 길이 방향"이라는 가정 하에 Y/Z 스케일만 비교합니다.
- **두께 중심 보정 없음**: AREA 기준면 중심은 항상 기준면 자체이며, "판재 두께 중심으로 이동" 같은
  보정 기능은 아직 없습니다(명세 1.3의 알려진 근사 허용 범위에 해당).
- **VOLUME 교차검증**: SketchUp 자체 `volume` 값과 1% 이상 차이나면 NON_MANIFOLD 경고를 냅니다
  (완벽한 비단일다양체 판정은 아닙니다).
- 실제 SketchUp에서 테스트되지 않았습니다 (개발 환경에 SketchUp 없음). 특히 `mesh(0)` 파라미터,
  `AttributeDictionary`의 중첩 배열 저장(`axis_endpoints_local`), `active_path`/`edit_transform`
  동작은 실제 버전별로 미세한 차이가 있을 수 있습니다.

## 먼저 테스트해보기

`sample_export.json`과 같은 결과가 나오는지 다음 순서로 확인해보세요.

1. 새 SketchUp 파일에서 2m 길이 막대, 2×3m 사각형 면, 0.1m³ 블록, 인스턴스 하나를 만듭니다.
2. 전체를 감싸는 그룹을 만들어 **① 모듈로 지정**.
3. 각각을 **③ 부재로 지정** (LENGTH/AREA/VOLUME/COUNT로 하나씩).
4. **⑪ JSON 내보내기**로 저장한 뒤 `webapp/index.html`에 업로드해 물량이 예상대로 나오는지 확인합니다.
5. 문제가 있으면 `⑩ 중량 데이터 검증` 메시지와 함께 알려주세요 - 바로 고칠 수 있습니다.
