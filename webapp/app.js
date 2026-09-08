'use strict';

/* =========================================================================
 * 모듈러 중량 산출 - 로컬 웹앱 (MVP)
 * 개발명세 v0.1 기준: 계산 엔진(2장)과 화면(4장) 계약을 구현한다.
 * 단일 파일로 file:// 에서도 동작하도록 IndexedDB 대신 localStorage를 사용한다.
 * ========================================================================= */

// ---------------------------------------------------------------------------
// 데모 데이터 (첨부 sample_export.json / sample_calculation_fixture.json 임베드)
// ---------------------------------------------------------------------------
const SAMPLE_EXPORT = {"schema_version":"1.0.0","export_id":"20000000-0000-4000-8000-000000000001","exported_at":"2026-09-08T04:00:00Z","exporter":{"name":"ModularWeightExporter fixture","version":"0.1.0","sketchup_version":"fixture-not-executed"},"model":{"id":"10000000-0000-4000-8000-000000000001","name":"개발 검수용 가상 모델"},"units":{"area":"m2","length":"m","volume":"m3","count":"EA"},"coordinate_system":{"up_axis":"Z","handedness":"RIGHT","frame":"SKETCHUP_WORLD"},"scope":{"mode":"ALL_REGISTERED_MODULES","includes_hidden":true},"modules":[{"name":"MODULE_A01","bounds_world_m":{"max":[2.5,2.5,1.25],"min":[-1,-0.5,-0.5]},"axes_world":{"y":[0,1,0],"x":[1,0,0],"z":[0,0,1]},"id":"module-a01","origin_world_m":[0,0,0]}],"elements":[{"id":"10000000-0000-4000-8000-000000000001:101.201","instance_path":"101.201","name":"시험 보","module_id":"module-a01","category":"OTHER","tag":"TEST_BEAM","quantity_basis":"AXIS_ENDPOINTS","included":true,"exclude_reason":null,"visibility":{"tag_visible":true,"hidden":false},"metrics":{"area_m2":null,"volume_m3":null,"length_m":{"value":2,"centroid_world_m":[1,0,0],"quantity_method":"TRANSFORMED_AXIS_ENDPOINTS","centroid_method":"AXIS_MIDPOINT","quality":"CALCULATED","assumptions":["개발 검수용 가상 형상과 균일 밀도. USER_POINT는 테스트 설계에서 지정한 점이며 실제 제조사 자료가 아님."]},"count":null},"bounds_world_m":{"max":[2,0.05,0.05],"min":[0,-0.05,-0.05]}},{"id":"10000000-0000-4000-8000-000000000001:101.202","instance_path":"101.202","name":"시험 보드","module_id":"module-a01","category":"OTHER","tag":"TEST_BOARD","quantity_basis":"REFERENCE_FACES","included":true,"exclude_reason":null,"visibility":{"tag_visible":true,"hidden":false},"metrics":{"area_m2":{"value":6,"centroid_world_m":[0,1,0],"quantity_method":"TRANSFORMED_REFERENCE_FACES","centroid_method":"AREA_WEIGHTED","quality":"CALCULATED","assumptions":["개발 검수용 가상 형상과 균일 밀도. USER_POINT는 테스트 설계에서 지정한 점이며 실제 제조사 자료가 아님."]},"volume_m3":null,"length_m":null,"count":null},"bounds_world_m":{"max":[1,2.5,0],"min":[-1,-0.5,0]}},{"id":"10000000-0000-4000-8000-000000000001:101.203","instance_path":"101.203","name":"시험 블록","module_id":"module-a01","category":"OTHER","tag":"TEST_BLOCK","quantity_basis":"SOLID","included":true,"exclude_reason":null,"visibility":{"tag_visible":true,"hidden":false},"metrics":{"area_m2":null,"volume_m3":{"value":0.1,"centroid_world_m":[0,0,1],"quantity_method":"CLOSED_MESH_INTEGRAL","centroid_method":"VOLUME_INTEGRAL","quality":"CALCULATED","assumptions":["개발 검수용 가상 형상과 균일 밀도. USER_POINT는 테스트 설계에서 지정한 점이며 실제 제조사 자료가 아님."]},"length_m":null,"count":null},"bounds_world_m":{"max":[0.25,0.2,1.25],"min":[-0.25,-0.2,0.75]}},{"id":"10000000-0000-4000-8000-000000000001:101.204","instance_path":"101.204","name":"시험 장비","module_id":"module-a01","category":"OTHER","tag":"TEST_EQUIPMENT","quantity_basis":"INSTANCE","included":true,"exclude_reason":null,"visibility":{"tag_visible":true,"hidden":false},"metrics":{"area_m2":null,"volume_m3":null,"length_m":null,"count":{"value":1,"centroid_world_m":[2,0,0],"quantity_method":"INSTANCE_ONE","centroid_method":"USER_POINT","quality":"USER_SPECIFIED","assumptions":["개발 검수용 가상 형상과 균일 밀도. USER_POINT는 테스트 설계에서 지정한 점이며 실제 제조사 자료가 아님."]}},"bounds_world_m":{"max":[2.5,0.5,0.5],"min":[1.5,-0.5,-0.5]}}],"diagnostics":[]};

const SAMPLE_FIXTURE = {"mappings":[{"material_version_id":"test-0-v1","tag":"TEST_BEAM"},{"material_version_id":"test-1-v1","tag":"TEST_BOARD"},{"material_version_id":"test-2-v1","tag":"TEST_BLOCK"},{"material_version_id":"test-3-v1","tag":"TEST_EQUIPMENT"}],"materials":[{"quality":"ESTIMATED","calc_type":"LENGTH","source_date":"2026-09-08","unit_weight":10,"specification":"검수용 가상 값","unit":"kg/m","source":"개발 명세 AT-01~05. 실무 사용 금지","version_id":"test-0-v1","material_id":"test-0","name":"시험 보"},{"quality":"ESTIMATED","calc_type":"AREA","source_date":"2026-09-08","unit_weight":5,"specification":"검수용 가상 값","unit":"kg/m2","source":"개발 명세 AT-01~05. 실무 사용 금지","version_id":"test-1-v1","material_id":"test-1","name":"시험 보드"},{"quality":"ESTIMATED","calc_type":"VOLUME","source_date":"2026-09-08","unit_weight":1000,"specification":"검수용 가상 값","unit":"kg/m3","source":"개발 명세 AT-01~05. 실무 사용 금지","version_id":"test-2-v1","material_id":"test-2","name":"시험 블록"},{"quality":"ESTIMATED","calc_type":"COUNT","source_date":"2026-09-08","unit_weight":50,"specification":"검수용 가상 값","unit":"kg/EA","source":"개발 명세 AT-01~05. 실무 사용 금지","version_id":"test-3-v1","material_id":"test-3","name":"시험 장비"}],"fixture_version":"1.0.0","expected":{"centroid_world_m":[0.6,0.15,0.5],"total_mass_kg":200,"element_mass_kg":[20,30,100,50],"status":"ESTIMATED"}};

// ---------------------------------------------------------------------------
// 상수
// ---------------------------------------------------------------------------
const CATEGORIES = ['STRUCTURE', 'FLOOR', 'WALL', 'CEILING', 'OPENING', 'MEP', 'OTHER'];
const CALC_TYPES = ['AREA', 'VOLUME', 'LENGTH', 'COUNT'];
const UNIT_BY_TYPE = { AREA: 'kg/m2', VOLUME: 'kg/m3', LENGTH: 'kg/m', COUNT: 'kg/EA' };
const METRIC_KEY_BY_BASIS = {
  REFERENCE_FACES: 'area_m2',
  SOLID: 'volume_m3',
  AXIS_ENDPOINTS: 'length_m',
  INSTANCE: 'count',
};
const CALC_TYPE_BY_BASIS = {
  REFERENCE_FACES: 'AREA',
  SOLID: 'VOLUME',
  AXIS_ENDPOINTS: 'LENGTH',
  INSTANCE: 'COUNT',
};
// 명세 6.2 quantity_method 허용값: quantity_basis마다 정확히 하나만 허용된다.
const QUANTITY_METHOD_BY_BASIS = {
  REFERENCE_FACES: 'TRANSFORMED_REFERENCE_FACES',
  SOLID: 'CLOSED_MESH_INTEGRAL',
  AXIS_ENDPOINTS: 'TRANSFORMED_AXIS_ENDPOINTS',
  INSTANCE: 'INSTANCE_ONE',
};
const CENTROID_METHODS = ['AREA_WEIGHTED', 'VOLUME_INTEGRAL', 'AXIS_MIDPOINT', 'USER_POINT', 'BBOX_CENTER', 'UNAVAILABLE'];
const TAG_RE = /^[A-Z][A-Z0-9_.]*$/;
const STATUS_ORDER = ['BLOCKED', 'EMPTY', 'INCOMPLETE', 'CG_INCOMPLETE', 'ESTIMATED', 'VALID'];
const STATUS_LABEL = {
  EMPTY: 'EMPTY · 포함 부재 없음',
  BLOCKED: 'BLOCKED · 업로드 반영 안 됨',
  INCOMPLETE: 'INCOMPLETE · 일부 미산출',
  CG_INCOMPLETE: 'CG_INCOMPLETE · 무게중심 계산 불가',
  ESTIMATED: 'ESTIMATED · 추정 근거 포함',
  VALID: 'VALID · 확정 가능',
};

const STORAGE_KEY = 'modular_weight_project_v1';

// ---------------------------------------------------------------------------
// 상태
// ---------------------------------------------------------------------------
function defaultState() {
  return {
    projectName: '새 프로젝트',
    createdAt: nowIso(),
    revisionStatus: 'DRAFT', // DRAFT | FIXED
    engineVersion: '0.1.0',
    importMeta: null, // {fileName, modelId, exportId, exportedAt, importedAt, elementCount, moduleCount}
    modules: [], // Module[]
    elements: [], // Element[]
    fileDiagnostics: [], // Diagnostic[] from validation
    materials: [], // MaterialVersion[]
    mappings: {}, // tag -> version_id
    overrides: {}, // element_id -> {excluded, reason}
    manualMasses: [], // {id, name, module_id, category, mass_kg, x,y,z(or null), source, reason}
    selectedModuleId: 'ALL',
    unitDisplay: 'ton',
    fixedSnapshot: null, // {fixedAt, totals, cg, status, elementCount}
    warningAcks: {}, // tag/element key -> true
  };
}

let state = loadState() || defaultState();

function nowIso() { return new Date().toISOString(); }

function saveState() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    setSaveStatus('저장됨 · ' + new Date().toLocaleTimeString('ko-KR'));
  } catch (e) {
    setSaveStatus('저장 실패 (브라우저 저장소 사용 불가)');
  }
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch (e) {
    return null;
  }
}

function setSaveStatus(text) {
  const el = document.getElementById('saveStatus');
  if (el) el.textContent = text;
}

// ---------------------------------------------------------------------------
// 유틸
// ---------------------------------------------------------------------------
function isFiniteVec3(v) {
  return Array.isArray(v) && v.length === 3 && v.every((n) => typeof n === 'number' && Number.isFinite(n));
}
function fmtKg(v, digits = 2) {
  if (v === null || v === undefined || Number.isNaN(v)) return '—';
  return v.toLocaleString('ko-KR', { minimumFractionDigits: digits, maximumFractionDigits: digits });
}
function fmtMass(kg) {
  if (kg === null || kg === undefined) return '—';
  if (state.unitDisplay === 'ton') return fmtKg(kg / 1000, 3) + ' ton';
  return fmtKg(kg, 2) + ' kg';
}
function fmtQty(v, digits = 3) {
  if (v === null || v === undefined) return '—';
  return v.toLocaleString('ko-KR', { minimumFractionDigits: 0, maximumFractionDigits: digits });
}
function fmtMm(v) {
  if (v === null || v === undefined) return '—';
  return (v * 1000).toLocaleString('ko-KR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + ' mm';
}
function uid(prefix) {
  return prefix + '-' + Math.random().toString(36).slice(2, 9);
}
function categoryLabel(c) { return c || 'OTHER'; }
function escapeHtml(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function download(filename, content, mime) {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

// ---------------------------------------------------------------------------
// 1. 검증 (MW-02/03, 6장 계약)
// ---------------------------------------------------------------------------
function validateExportJson(json) {
  const blocking = []; // Diagnostic[]
  const warnings = [];

  function block(code, message, element_id = null, module_id = null) {
    blocking.push({ code, severity: 'ERROR', element_id, module_id, message });
  }
  function warn(code, message, element_id = null, module_id = null) {
    warnings.push({ code, severity: 'WARNING', element_id, module_id, message });
  }

  if (!json || typeof json !== 'object') {
    block('INVALID_SCHEMA', '파일이 JSON 객체가 아닙니다.');
    return { ok: false, blocking, warnings };
  }
  if (typeof json.schema_version !== 'string' || !json.schema_version.startsWith('1.')) {
    block('INVALID_SCHEMA', `지원하지 않는 schema_version입니다: ${json.schema_version}`);
  }
  for (const key of ['export_id', 'exported_at', 'exporter', 'model', 'units', 'coordinate_system', 'scope', 'modules', 'elements']) {
    if (json[key] === undefined) block('INVALID_SCHEMA', `필수 필드 누락: ${key}`);
  }
  if (json.units) {
    const u = json.units;
    if (u.area !== 'm2' || u.length !== 'm' || u.volume !== 'm3' || u.count !== 'EA') {
      block('INVALID_SCHEMA', '단위 계약이 SI 고정값(m2/m/m3/EA)과 다릅니다.');
    }
  }
  if (json.coordinate_system) {
    const c = json.coordinate_system;
    if (c.frame !== 'SKETCHUP_WORLD' || c.handedness !== 'RIGHT' || c.up_axis !== 'Z') {
      block('INVALID_FRAME', '좌표계 계약이 SKETCHUP_WORLD/RIGHT/Z와 다릅니다.');
    }
  }
  if (blocking.length) return { ok: false, blocking, warnings };

  const modules = Array.isArray(json.modules) ? json.modules : [];
  const moduleIds = new Set();
  for (const m of modules) {
    if (!m.id) { block('INVALID_MODULE_REF', '모듈 id가 없습니다.'); continue; }
    if (moduleIds.has(m.id)) block('DUPLICATE_ID', `모듈 id 중복: ${m.id}`, null, m.id);
    moduleIds.add(m.id);
    if (!isFiniteVec3(m.origin_world_m)) block('INVALID_SCHEMA', `모듈 origin_world_m 오류: ${m.id}`, null, m.id);
    if (!m.axes_world || !isFiniteVec3(m.axes_world.x) || !isFiniteVec3(m.axes_world.y) || !isFiniteVec3(m.axes_world.z)) {
      block('INVALID_SCHEMA', `모듈 축 정의 오류: ${m.id}`, null, m.id);
    }
    if (!m.bounds_world_m || !isFiniteVec3(m.bounds_world_m.min) || !isFiniteVec3(m.bounds_world_m.max)) {
      block('INVALID_SCHEMA', `모듈 경계상자 오류: ${m.id}`, null, m.id);
    }
  }

  const elements = Array.isArray(json.elements) ? json.elements : [];
  const elementIds = new Set();
  for (const el of elements) {
    if (!el.id) { block('INVALID_SCHEMA', '부재 id가 없습니다.'); continue; }
    if (elementIds.has(el.id)) block('DUPLICATE_ID', `부재 id 중복: ${el.id}`, el.id);
    elementIds.add(el.id);
    if (!el.module_id || !moduleIds.has(el.module_id)) {
      block('INVALID_MODULE_REF', `존재하지 않는 module_id 참조: ${el.module_id}`, el.id);
    }
    if (!isFiniteVec3(el.bounds_world_m && el.bounds_world_m.min) || !isFiniteVec3(el.bounds_world_m && el.bounds_world_m.max)) {
      block('INVALID_SCHEMA', `부재 경계상자 오류`, el.id);
    }
  }
  if (blocking.length) return { ok: false, blocking, warnings };

  // 부재 단위 오류/경고 (파일 반영은 허용, 검토 필요로 기록)
  for (const el of elements) {
    if (el.tag === null || el.tag === undefined) {
      warn('MISSING_TAG', '자재 Tag가 지정되지 않았습니다.', el.id, el.module_id);
    } else if (!TAG_RE.test(el.tag)) {
      warn('UNCLASSIFIED', `Tag 형식이 규칙(^[A-Z][A-Z0-9_.]*$)과 다릅니다: ${el.tag}`, el.id, el.module_id);
    }
    if (!CATEGORIES.includes(el.category)) {
      warn('UNCLASSIFIED', `공종 미분류 또는 알 수 없는 값: ${el.category}`, el.id, el.module_id);
    }
    const metricKey = METRIC_KEY_BY_BASIS[el.quantity_basis];
    if (!metricKey) {
      warn('BASIS_MISMATCH', `알 수 없는 quantity_basis: ${el.quantity_basis}`, el.id, el.module_id);
    } else {
      const metric = el.metrics ? el.metrics[metricKey] : undefined;
      if (el.included && (metric === null || metric === undefined)) {
        warn('MISSING_METRIC', `quantity_basis(${el.quantity_basis})에 해당하는 metric이 없습니다.`, el.id, el.module_id);
      } else if (metric) {
        if (!(typeof metric.value === 'number' && Number.isFinite(metric.value) && metric.value > 0)) {
          warn('DEGENERATE_GEOMETRY', '물량 value가 유한 양수가 아닙니다. (형상 재확인 필요)', el.id, el.module_id);
        }
        if (metricKey === 'count' && !Number.isInteger(metric.value)) {
          warn('DEGENERATE_GEOMETRY', 'COUNT 물량이 정수가 아닙니다. (형상 재확인 필요)', el.id, el.module_id);
        }
        if (metric.quantity_method !== QUANTITY_METHOD_BY_BASIS[el.quantity_basis]) {
          warn('BASIS_MISMATCH', `quantity_method(${metric.quantity_method})가 quantity_basis(${el.quantity_basis})의 허용값(${QUANTITY_METHOD_BY_BASIS[el.quantity_basis]})과 다릅니다.`, el.id, el.module_id);
        }
        if (!CENTROID_METHODS.includes(metric.centroid_method)) {
          warn('UNCLASSIFIED', `알 수 없는 centroid_method: ${metric.centroid_method}`, el.id, el.module_id);
        }
        if (metric.centroid_method === 'BBOX_CENTER' && metric.quality !== 'ESTIMATED') {
          warn('ESTIMATED_CENTROID', 'centroid_method=BBOX_CENTER이면 quality=ESTIMATED이어야 합니다 (명세 6.2).', el.id, el.module_id);
        }
        if (metric.centroid_method === 'UNAVAILABLE' && metric.centroid_world_m !== null) {
          warn('UNCLASSIFIED', 'centroid_method=UNAVAILABLE인데 centroid 값이 존재합니다.', el.id, el.module_id);
        }
        if (metric.centroid_method !== 'UNAVAILABLE' && metric.centroid_world_m === null) {
          warn('MISSING_CENTROID', 'centroid_world_m이 없습니다.', el.id, el.module_id);
        }
      }
    }
    if (el.included === false && !el.exclude_reason) {
      warn('UNCLASSIFIED', '제외(included=false) 부재에 exclude_reason이 없습니다.', el.id, el.module_id);
    }
  }

  return { ok: true, blocking, warnings };
}

// ---------------------------------------------------------------------------
// 2. 자재 DB 헬퍼
// ---------------------------------------------------------------------------
function activeMaterialsByVersionId() {
  const map = new Map();
  for (const m of state.materials) map.set(m.version_id, m);
  return map;
}

function seedMaterialsFromFixture(fixture) {
  const materials = fixture.materials.map((m) => ({ ...m, active: true }));
  const mappings = {};
  for (const map of fixture.mappings) mappings[map.tag] = map.material_version_id;
  return { materials, mappings };
}

// ---------------------------------------------------------------------------
// 2.1 표준 Tag 카탈로그 (참고용) — SketchUp에서 자주 쓰는 Tag 명명 예시와 참고 단중.
// 모두 이론값(단면적×밀도, 밀도×두께) 또는 카탈로그 예시이며 실제 프로젝트에는
// 검증된 제조사 자료·구조계산서로 교체해야 한다. 1.2절 Tag 규칙(^[A-Z][A-Z0-9_.]*$)을 따른다.
// ---------------------------------------------------------------------------
const DEFAULT_MATERIAL_CATALOG = [
  // --- STRUCTURE (강재, 밀도 7,850 kg/m³ 기준 이론값) ---
  { tag: 'ST_HSS_75X75X3.2', category: 'STRUCTURE', name: '각형강관 75x75x3.2T', calc_type: 'LENGTH',
    unit_weight: 7.2, specification: 'KS D 3568 상당, t=3.2mm',
    source: '이론값 = 단면적(4t(a-t))×7,850kg/m³. KS 규격표 대조 필요', quality: 'ESTIMATED' },
  { tag: 'ST_HSS_100X100X4.5', category: 'STRUCTURE', name: '각형강관 100x100x4.5T', calc_type: 'LENGTH',
    unit_weight: 13.5, specification: 'KS D 3568 상당, t=4.5mm',
    source: '이론값 = 단면적(4t(a-t))×7,850kg/m³. KS 규격표 대조 필요', quality: 'ESTIMATED' },
  { tag: 'ST_HSS_150X100X4.5', category: 'STRUCTURE', name: '각형강관 150x100x4.5T', calc_type: 'LENGTH',
    unit_weight: 17.0, specification: 'KS D 3568 상당, t=4.5mm',
    source: '이론값 = 단면적(2t((a-t)+(b-t)))×7,850kg/m³. KS 규격표 대조 필요', quality: 'ESTIMATED' },
  { tag: 'ST_PLATE_6', category: 'STRUCTURE', name: '강판 6T', calc_type: 'AREA',
    unit_weight: 47.1, specification: 't=6mm', density_kg_m3: 7850, thickness_m: 0.006,
    source: '밀도×두께 = 7,850×0.006 (명세 2.3 예시값)', quality: 'ESTIMATED' },
  { tag: 'ST_PLATE_9', category: 'STRUCTURE', name: '강판 9T', calc_type: 'AREA',
    unit_weight: 70.7, specification: 't=9mm', density_kg_m3: 7850, thickness_m: 0.009,
    source: '밀도×두께 = 7,850×0.009', quality: 'ESTIMATED' },

  // --- FLOOR ---
  { tag: 'BD_CEMENT_18', category: 'FLOOR', name: '시멘트보드 18T', calc_type: 'AREA',
    unit_weight: 21.6, specification: 't=18mm, 밀도 1,200kg/m³ 가정(제품별 1,000~1,800 편차)',
    density_kg_m3: 1200, thickness_m: 0.018,
    source: '밀도×두께 참고값 — 제품 스펙시트로 밀도 확인 필수', quality: 'ESTIMATED' },
  { tag: 'FL_DECK_1.2T', category: 'FLOOR', name: '데크플레이트 1.2T (예시)', calc_type: 'AREA',
    unit_weight: 13.0, specification: 't=1.2mm, 리브 형상 포함 카탈로그 예시',
    source: '제조사 카탈로그 예시값(미확인) — 실제 제품 규격표로 교체 필수', quality: 'ESTIMATED' },

  // --- WALL ---
  { tag: 'BD_GYPSUM_9.5', category: 'WALL', name: '석고보드 9.5T', calc_type: 'AREA',
    unit_weight: 7.1, specification: 't=9.5mm, 밀도 750kg/m³ 가정', density_kg_m3: 750, thickness_m: 0.0095,
    source: '밀도×두께 참고값 (KS F 3504 일반석고보드 밀도 추정)', quality: 'ESTIMATED' },
  { tag: 'BD_GYPSUM_12.5', category: 'WALL', name: '석고보드 12.5T', calc_type: 'AREA',
    unit_weight: 9.4, specification: 't=12.5mm, 밀도 750kg/m³ 가정', density_kg_m3: 750, thickness_m: 0.0125,
    source: '밀도×두께 참고값 (KS F 3504 일반석고보드 밀도 추정)', quality: 'ESTIMATED' },
  { tag: 'INS_GW_100', category: 'WALL', name: '글라스울 단열재 100T (24K)', calc_type: 'AREA',
    unit_weight: 2.4, specification: 't=100mm, 밀도 24kg/m³(24K)', density_kg_m3: 24, thickness_m: 0.1,
    source: '밀도×두께 참고값 — 제품 등급(K값)별 밀도 확인 필수', quality: 'ESTIMATED' },
  { tag: 'INS_XPS_50', category: 'WALL', name: '압출법 보온판(XPS) 50T', calc_type: 'AREA',
    unit_weight: 1.5, specification: 't=50mm, 밀도 30kg/m³ 가정', density_kg_m3: 30, thickness_m: 0.05,
    source: '밀도×두께 참고값 — 제품 등급별 밀도 확인 필수', quality: 'ESTIMATED' },

  // --- CEILING ---
  { tag: 'BD_MTILE_15', category: 'CEILING', name: '미네랄 텍스 천장재 15T', calc_type: 'AREA',
    unit_weight: 5.3, specification: 't=15mm, 밀도 350kg/m³ 가정', density_kg_m3: 350, thickness_m: 0.015,
    source: '밀도×두께 참고값 — 제품 스펙시트로 밀도 확인 필수', quality: 'ESTIMATED' },

  // --- OPENING (제품별 편차가 매우 크므로 반드시 실 제품 스펙으로 교체) ---
  { tag: 'OP_WINDOW_STD', category: 'OPENING', name: '시스템창호 세트 (예시)', calc_type: 'COUNT',
    unit_weight: 35, specification: '규격/유리 사양에 따라 편차 큼',
    source: '제품 카탈로그 미확인 임시값 — 실제 사용 전 반드시 교체', quality: 'ESTIMATED' },
  { tag: 'OP_DOOR_STD', category: 'OPENING', name: '도어 세트 (예시)', calc_type: 'COUNT',
    unit_weight: 28, specification: '방화/방음 사양에 따라 편차 큼',
    source: '제품 카탈로그 미확인 임시값 — 실제 사용 전 반드시 교체', quality: 'ESTIMATED' },

  // --- MEP (제품별 편차가 매우 크므로 반드시 실 제품 스펙으로 교체) ---
  { tag: 'MEP_FCU_STD', category: 'MEP', name: 'FCU(팬코일유닛) 표준형 (예시)', calc_type: 'COUNT',
    unit_weight: 32, specification: '용량/모델별 편차 큼',
    source: '제조사 카탈로그 미확인 임시값 — 실제 사용 전 반드시 교체', quality: 'ESTIMATED' },
  { tag: 'MEP_PANEL_STD', category: 'MEP', name: '분전반 (예시)', calc_type: 'COUNT',
    unit_weight: 18, specification: '회로 수/용량별 편차 큼',
    source: '제조사 카탈로그 미확인 임시값 — 실제 사용 전 반드시 교체', quality: 'ESTIMATED' },
];

function buildCatalogMaterials() {
  const today = new Date().toISOString().slice(0, 10);
  return DEFAULT_MATERIAL_CATALOG.map((c) => {
    const material_id = 'catalog-' + c.tag.toLowerCase().replace(/[^a-z0-9]+/g, '-');
    return {
      material_id,
      version_id: material_id + '-v' + Date.now().toString(36),
      name: c.name,
      specification: c.specification,
      calc_type: c.calc_type,
      unit_weight: c.unit_weight,
      unit: UNIT_BY_TYPE[c.calc_type],
      source: c.source,
      source_date: today,
      quality: c.quality,
      estimate_reason: c.quality === 'ESTIMATED' ? '표준 Tag 카탈로그 참고값 — 실제 제품/구조계산 자료로 교체 필요' : null,
      thickness_m: c.thickness_m || null,
      density_kg_m3: c.density_kg_m3 || null,
      active: true,
      catalog_tag: c.tag,
    };
  });
}

// ---------------------------------------------------------------------------
// 3. 계산 엔진 (순수 함수, 명세 2장)
// ---------------------------------------------------------------------------
// 개별 부재 산출 결과를 계산한다. UI 상태와 분리된 순수 함수다.
function resolveElement(el, materialsByVersion, mappings, overrides) {
  const override = overrides[el.id];
  const result = {
    element: el,
    excluded: !!(override && override.excluded) || el.included === false,
    excludeReason: (override && override.reason) || el.exclude_reason || null,
    basisKey: METRIC_KEY_BY_BASIS[el.quantity_basis] || null,
    metric: null,
    material: null,
    mass: null,
    centroid: null,
    centroidMethod: null,
    quality: null, // effective quality for display
    issues: [], // diagnostic codes
    resolved: false, // mass computed?
  };

  if (result.excluded) return result;

  const basisKey = result.basisKey;
  if (!basisKey) {
    result.issues.push('BASIS_MISMATCH');
    return result;
  }
  const metric = el.metrics ? el.metrics[basisKey] : null;
  result.metric = metric || null;
  if (!metric) {
    result.issues.push('MISSING_METRIC');
    return result;
  }

  const tag = el.tag;
  if (!tag) {
    result.issues.push('MISSING_TAG');
    return result;
  }
  const versionId = mappings[tag];
  if (!versionId) {
    result.issues.push('UNMAPPED_TAG');
    return result;
  }
  const material = materialsByVersion.get(versionId);
  if (!material || material.active === false) {
    result.issues.push('UNMAPPED_TAG');
    return result;
  }
  result.material = material;

  const expectedCalcType = CALC_TYPE_BY_BASIS[el.quantity_basis];
  if (material.calc_type !== expectedCalcType) {
    result.issues.push('BASIS_MISMATCH');
    return result;
  }

  // 물량(metric.value) 자체가 유효하지 않은 것은 형상 문제이므로 DEGENERATE_GEOMETRY로 구분한다.
  // INVALID_UNIT_WEIGHT는 명세 6.4 표대로 자재 DB의 단중 문제에만 사용한다.
  if (!(typeof metric.value === 'number' && Number.isFinite(metric.value) && metric.value > 0)) {
    result.issues.push('DEGENERATE_GEOMETRY');
    return result;
  }
  if (basisKey === 'count' && !Number.isInteger(metric.value)) {
    result.issues.push('DEGENERATE_GEOMETRY');
    return result;
  }
  if (!(typeof material.unit_weight === 'number' && Number.isFinite(material.unit_weight) && material.unit_weight > 0)) {
    result.issues.push('INVALID_UNIT_WEIGHT');
    return result;
  }

  // --- 계산 (명세 2.3) ---
  result.mass = metric.value * material.unit_weight;
  result.resolved = true;
  result.centroidMethod = metric.centroid_method;
  result.centroid = metric.centroid_world_m || null;

  const estimated =
    metric.quality === 'ESTIMATED' ||
    metric.quality === 'USER_SPECIFIED' ||
    metric.centroid_method === 'BBOX_CENTER' ||
    material.quality === 'ESTIMATED';
  result.quality = estimated ? 'ESTIMATED' : 'CALCULATED';

  if (!result.centroid && metric.centroid_method !== 'UNAVAILABLE') {
    // 계약상 있어야 하는데 없는 경우도 누락으로 처리
    result.centroid = null;
  }

  return result;
}

// 전체 집계: 모듈 필터가 적용된 elements/manualMasses를 받는다.
function aggregate(elements, manualMasses, materials, mappings, overrides) {
  const materialsByVersion = activeMaterialsByVersionId2(materials);
  const resolved = elements.map((el) => resolveElement(el, materialsByVersion, mappings, overrides));

  const included = resolved.filter((r) => !r.excluded);
  const unresolved = included.filter((r) => !r.resolved);
  const ok = included.filter((r) => r.resolved);
  const missingCentroid = ok.filter((r) => !r.centroid);
  const estimatedElems = ok.filter((r) => r.quality === 'ESTIMATED');

  const manualValid = manualMasses.filter((m) => typeof m.mass_kg === 'number' && m.mass_kg > 0);
  const manualWithLoc = manualValid.filter((m) => m.x !== null && m.x !== undefined && m.y !== null && m.z !== null);
  const manualMissingLoc = manualValid.filter((m) => !(m.x !== null && m.x !== undefined && m.y !== null && m.z !== null));

  const totalResolvedMass = ok.reduce((s, r) => s + r.mass, 0) + manualValid.reduce((s, m) => s + m.mass_kg, 0);

  let status;
  if (ok.length === 0 && manualValid.length === 0) {
    status = 'EMPTY';
  } else if (unresolved.length > 0) {
    status = 'INCOMPLETE';
  } else if (missingCentroid.length > 0 || manualMissingLoc.length > 0) {
    status = 'CG_INCOMPLETE';
  } else if (estimatedElems.length > 0) {
    status = 'ESTIMATED';
  } else {
    status = 'VALID';
  }

  // CG: VALID/ESTIMATED만 확정 CG. INCOMPLETE/CG_INCOMPLETE는 참고용으로만 계산한다.
  const cgItems = ok.filter((r) => r.centroid).map((r) => ({ mass: r.mass, c: r.centroid }));
  for (const m of manualWithLoc) cgItems.push({ mass: m.mass_kg, c: [m.x, m.y, m.z] });
  const cgMass = cgItems.reduce((s, i) => s + i.mass, 0);
  let cgWorld = null;
  if (cgMass > 0) {
    cgWorld = [0, 1, 2].map((i) => cgItems.reduce((s, it) => s + it.mass * it.c[i], 0) / cgMass);
  }
  const cgConfirmed = status === 'VALID' || status === 'ESTIMATED';

  // 그룹 집계
  function groupSum(keyFn) {
    const map = new Map();
    for (const r of ok) {
      const k = keyFn(r.element, null);
      map.set(k, (map.get(k) || 0) + r.mass);
    }
    for (const m of manualValid) {
      const k = keyFn(null, m);
      map.set(k, (map.get(k) || 0) + m.mass_kg);
    }
    return map;
  }
  const byModule = groupSum((el, m) => (el ? el.module_id : m.module_id) || '미지정');
  const byCategory = groupSum((el, m) => (el ? el.category : m.category) || 'OTHER');

  const materialAgg = new Map(); // material name+calc_type -> {qty, unit, mass, calcType}
  for (const r of ok) {
    const key = r.material.name + '@' + r.material.version_id;
    const cur = materialAgg.get(key) || { name: r.material.name, calcType: r.material.calc_type, unit: METRIC_UNIT(r.material.calc_type), qty: 0, mass: 0 };
    cur.qty += r.metric.value;
    cur.mass += r.mass;
    materialAgg.set(key, cur);
  }

  return {
    resolved, included, unresolved, ok, missingCentroid, estimatedElems,
    manualValid, manualWithLoc, manualMissingLoc,
    totalResolvedMass, status, cgWorld, cgMass, cgConfirmed,
    byModule, byCategory, materialAgg,
  };
}
function METRIC_UNIT(calcType) {
  return { AREA: 'm2', VOLUME: 'm3', LENGTH: 'm', COUNT: 'EA' }[calcType] || '';
}
function activeMaterialsByVersionId2(materials) {
  const map = new Map();
  for (const m of materials) map.set(m.version_id, m);
  return map;
}

function elementsForModule(moduleId) {
  if (moduleId === 'ALL') return state.elements;
  return state.elements.filter((e) => e.module_id === moduleId);
}
function manualForModule(moduleId) {
  if (moduleId === 'ALL') return state.manualMasses;
  return state.manualMasses.filter((m) => m.module_id === moduleId);
}
function currentAggregate() {
  return aggregate(elementsForModule(state.selectedModuleId), manualForModule(state.selectedModuleId), state.materials, state.mappings, state.overrides);
}
function fullAggregate() {
  return aggregate(state.elements, state.manualMasses, state.materials, state.mappings, state.overrides);
}

// ---------------------------------------------------------------------------
// 4. 렌더링
// ---------------------------------------------------------------------------
function renderAll() {
  renderTopbar();
  renderImportTab();
  renderDashboard();
  renderElements();
  renderCg();
  renderManual();
  renderMaterials();
  renderReports();
}

function renderTopbar() {
  document.getElementById('projectNameLabel').textContent = state.projectName;
  const badge = document.getElementById('revisionBadge');
  badge.textContent = state.revisionStatus === 'FIXED' ? '확정' : 'DRAFT';
  badge.className = 'badge ' + (state.revisionStatus === 'FIXED' ? 'badge-fixed' : 'badge-draft');

  const sel = document.getElementById('moduleFilterSelect');
  const prev = state.selectedModuleId;
  sel.innerHTML = '<option value="ALL">전체 모듈</option>' +
    state.modules.map((m) => `<option value="${escapeHtml(m.id)}">${escapeHtml(m.name)}</option>`).join('');
  sel.value = state.modules.some((m) => m.id === prev) ? prev : 'ALL';
  state.selectedModuleId = sel.value;

  document.getElementById('unitDisplaySelect').value = state.unitDisplay;

  const agg = fullAggregate();
  const unresolvedCount = agg.unresolved.length;
  const link = document.getElementById('unresolvedLink');
  if (unresolvedCount > 0) {
    link.hidden = false;
    link.textContent = `미해결 ${unresolvedCount}건`;
  } else {
    link.hidden = true;
  }
}

function renderImportTab() {
  const summaryEl = document.getElementById('importSummary');
  if (!state.importMeta) {
    summaryEl.hidden = true;
    document.getElementById('validationCard').hidden = true;
    return;
  }
  summaryEl.hidden = false;
  const meta = state.importMeta;
  summaryEl.innerHTML = `
    <div class="row"><span>파일명</span><strong>${escapeHtml(meta.fileName)}</strong></div>
    <div class="row"><span>모델 ID</span><span class="tag-mono">${escapeHtml(meta.modelId)}</span></div>
    <div class="row"><span>Export ID</span><span class="tag-mono">${escapeHtml(meta.exportId)}</span></div>
    <div class="row"><span>내보낸 시각</span><span>${escapeHtml(meta.exportedAt)}</span></div>
    <div class="row"><span>가져온 시각</span><span>${escapeHtml(meta.importedAt)}</span></div>
    <div class="row"><span>모듈 / 부재 수</span><span>${meta.moduleCount} / ${meta.elementCount}</span></div>
  `;

  document.getElementById('validationCard').hidden = false;
  const errs = state.fileDiagnostics.filter((d) => d.severity === 'ERROR');
  const warns = state.fileDiagnostics.filter((d) => d.severity === 'WARNING');
  document.getElementById('errCount').textContent = errs.length;
  document.getElementById('warnCount').textContent = warns.length;

  document.getElementById('vtab-errors').innerHTML = errs.length
    ? diagnosticsTable(errs)
    : '<p class="hint">오류가 없습니다.</p>';
  document.getElementById('vtab-warnings').innerHTML = warns.length
    ? diagnosticsTable(warns)
    : '<p class="hint">경고가 없습니다.</p>';

  document.getElementById('vtab-mapping').innerHTML = renderMappingPanel();
}

function diagnosticsTable(list) {
  return `<div class="table-wrap"><table class="data-table"><thead><tr>
    <th>코드</th><th>부재 ID</th><th>메시지</th></tr></thead><tbody>
    ${list.map((d) => `<tr><td class="tag-mono">${escapeHtml(d.code)}</td><td class="tag-mono">${escapeHtml(d.element_id || d.module_id || '-')}</td><td>${escapeHtml(d.message)}</td></tr>`).join('')}
  </tbody></table></div>`;
}

function renderMappingPanel() {
  const tags = Array.from(new Set(state.elements.map((e) => e.tag).filter(Boolean))).sort();
  if (!tags.length) return '<p class="hint">Tag가 있는 부재가 없습니다.</p>';
  const rows = tags.map((tag) => {
    const affected = state.elements.filter((e) => e.tag === tag && e.included !== false).length;
    const current = state.mappings[tag] || '';
    const options = state.materials
      .filter((m) => m.active !== false)
      .map((m) => `<option value="${escapeHtml(m.version_id)}" ${m.version_id === current ? 'selected' : ''}>${escapeHtml(m.name)} (${escapeHtml(m.calc_type)}, ${m.unit_weight} ${escapeHtml(m.unit)})</option>`)
      .join('');
    const tagValid = TAG_RE.test(tag);
    return `<tr>
      <td class="tag-mono">${escapeHtml(tag)}${tagValid ? '' : ' <span class="hint">(형식 경고)</span>'}</td>
      <td>${affected}</td>
      <td><select data-tag="${escapeHtml(tag)}" class="mapSelect"><option value="">-- 미매핑 --</option>${options}</select></td>
    </tr>`;
  }).join('');
  return `<div class="table-wrap"><table class="data-table"><thead><tr>
    <th>Tag</th><th>영향 부재 수</th><th>매핑 자재 버전</th></tr></thead><tbody>${rows}</tbody></table></div>
    <p class="hint">매핑을 변경하면 해당 Tag의 포함 부재 전체에 동일한 자재 버전이 적용됩니다.</p>`;
}

function renderDashboard() {
  const hasData = state.elements.length > 0 || state.manualMasses.length > 0;
  document.getElementById('dashboardEmpty').hidden = hasData;
  document.getElementById('dashboardBody').hidden = !hasData;
  if (!hasData) return;

  const agg = currentAggregate();
  const pill = document.getElementById('statusPill');
  pill.textContent = agg.status;
  pill.className = 'status-pill ' + agg.status;
  document.getElementById('statusNote').textContent = STATUS_LABEL[agg.status] || '';

  const totalLabel = agg.status === 'INCOMPLETE' ? '유효 항목 소계' : '총중량';
  document.getElementById('totalMassValue').textContent = agg.status === 'EMPTY' ? '—' : fmtMass(agg.totalResolvedMass);
  document.getElementById('totalMassSub').textContent =
    agg.status === 'INCOMPLETE' ? `${totalLabel} (미해결 ${agg.unresolved.length}건 제외)` : `산출 버전: ${state.revisionStatus}`;

  document.getElementById('countsValue').textContent = `${agg.ok.length} / ${agg.resolved.length - agg.included.length} / ${agg.unresolved.length}`;

  if (agg.status === 'EMPTY' || agg.status === 'CG_INCOMPLETE' || !agg.cgWorld) {
    document.getElementById('cgValue').textContent = agg.status === 'CG_INCOMPLETE' ? '계산 불가' : '—';
    document.getElementById('cgSub').textContent = agg.status === 'CG_INCOMPLETE' ? `중심 누락 ${agg.missingCentroid.length + agg.manualMissingLoc.length}건` : '';
  } else {
    document.getElementById('cgValue').textContent = `(${agg.cgWorld.map((v) => fmtKg(v, 3)).join(', ')}) m`;
    document.getElementById('cgSub').textContent = agg.cgConfirmed ? '확정 가능' : '참고용';
  }

  renderBarChart('chartByModule', agg.byModule, (id) => (state.modules.find((m) => m.id === id) || {}).name || id, agg.totalResolvedMass);
  renderBarChart('chartByCategory', agg.byCategory, (id) => id, agg.totalResolvedMass);

  const tbody = document.querySelector('#materialAggTable tbody');
  const rows = Array.from(agg.materialAgg.values()).sort((a, b) => b.mass - a.mass);
  tbody.innerHTML = rows.map((r) => `<tr>
    <td>${escapeHtml(r.name)}</td><td>${r.calcType}</td><td>${fmtQty(r.qty)}</td><td>${r.unit}</td>
    <td>${fmtKg(r.mass)}</td><td>${agg.totalResolvedMass > 0 ? fmtKg((r.mass / agg.totalResolvedMass) * 100, 1) + '%' : '—'}</td>
  </tr>`).join('') || '<tr><td colspan="6" class="hint">데이터 없음</td></tr>';

  const fixBtn = document.getElementById('fixResultBtn');
  const canFix = (agg.status === 'VALID' || agg.status === 'ESTIMATED') && state.revisionStatus !== 'FIXED';
  fixBtn.disabled = !canFix;
  document.getElementById('fixResultMsg').textContent = state.revisionStatus === 'FIXED'
    ? '이미 확정된 버전입니다. 수정하려면 새 Draft가 필요합니다.'
    : (canFix ? '' : 'VALID 또는 확인된 ESTIMATED 상태에서만 확정할 수 있습니다.');
}

function renderBarChart(containerId, map, labelFn, total) {
  const el = document.getElementById(containerId);
  const entries = Array.from(map.entries()).sort((a, b) => b[1] - a[1]);
  if (!entries.length) { el.innerHTML = '<p class="hint">데이터 없음</p>'; return; }
  const max = Math.max(...entries.map((e) => e[1]), 1);
  el.innerHTML = entries.map(([key, val]) => `
    <div class="bar-row">
      <span>${escapeHtml(labelFn(key))}</span>
      <span class="bar-track"><span class="bar-fill" style="width:${(val / max) * 100}%"></span></span>
      <span>${fmtMass(val)}</span>
    </div>`).join('');
}

let selectedElementId = null;

function renderElements() {
  const search = (document.getElementById('elementSearch').value || '').toLowerCase();
  const catFilter = document.getElementById('elementCategoryFilter').value;
  const statusFilter = document.getElementById('elementStatusFilter').value;

  const catSelect = document.getElementById('elementCategoryFilter');
  if (catSelect.options.length <= 1) {
    catSelect.innerHTML = '<option value="">공종 전체</option>' + CATEGORIES.map((c) => `<option value="${c}">${c}</option>`).join('');
  }

  const scoped = elementsForModule(state.selectedModuleId);
  const materialsByVersion = activeMaterialsByVersionId2(state.materials);
  const rows = scoped.map((el) => ({ el, r: resolveElement(el, materialsByVersion, state.mappings, state.overrides) }));

  function rowStatus(r) {
    if (r.excluded) return 'EXCLUDED';
    if (!r.resolved) return 'UNRESOLVED';
    if (r.quality === 'ESTIMATED') return 'ESTIMATED';
    return 'OK';
  }

  const filtered = rows.filter(({ el, r }) => {
    if (search && !(`${el.name} ${el.tag || ''} ${el.instance_path}`.toLowerCase().includes(search))) return false;
    if (catFilter && el.category !== catFilter) return false;
    if (statusFilter && rowStatus(r) !== statusFilter) return false;
    return true;
  });

  const tbody = document.querySelector('#elementsTable tbody');
  tbody.innerHTML = filtered.map(({ el, r }) => {
    const st = rowStatus(r);
    const badgeClass = { OK: 'badge-ok', UNRESOLVED: 'badge-unresolved', EXCLUDED: 'badge-excluded', ESTIMATED: 'badge-estimated' }[st];
    const moduleName = (state.modules.find((m) => m.id === el.module_id) || {}).name || el.module_id;
    const qty = r.metric ? fmtQty(r.metric.value) + ' ' + METRIC_UNIT(CALC_TYPE_BY_BASIS[el.quantity_basis]) : '—';
    const unitW = r.material ? `${r.material.unit_weight} ${r.material.unit}` : '—';
    return `<tr data-id="${escapeHtml(el.id)}">
      <td>${escapeHtml(el.name)}</td>
      <td>${escapeHtml(moduleName)}</td>
      <td>${escapeHtml(el.category)}</td>
      <td class="tag-mono">${escapeHtml(el.tag || '-')}</td>
      <td>${CALC_TYPE_BY_BASIS[el.quantity_basis] || '-'}</td>
      <td>${qty}</td>
      <td>${unitW}</td>
      <td>${r.resolved ? fmtKg(r.mass) : '미산출'}</td>
      <td>${r.centroid ? (r.quality === 'ESTIMATED' ? '추정' : '계산됨') : (r.resolved ? '누락' : '-')}</td>
      <td><span class="badge-status ${badgeClass}">${st}</span></td>
    </tr>`;
  }).join('') || '<tr><td colspan="10" class="hint">표시할 부재가 없습니다.</td></tr>';

  const subtotal = filtered.filter(({ r }) => r.resolved).reduce((s, { r }) => s + r.mass, 0);
  document.getElementById('elementsSubtotal').textContent = `현재 표시 행 소계: ${fmtMass(subtotal)} (${filtered.length}건)`;

  tbody.querySelectorAll('tr[data-id]').forEach((tr) => {
    tr.addEventListener('click', () => {
      selectedElementId = tr.getAttribute('data-id');
      renderElementDetail();
    });
  });

  renderElementDetail();
}

function renderElementDetail() {
  const panel = document.getElementById('elementDetailPanel');
  if (!selectedElementId) { panel.hidden = true; return; }
  const el = state.elements.find((e) => e.id === selectedElementId);
  if (!el) { panel.hidden = true; return; }
  const r = resolveElement(el, activeMaterialsByVersionId2(state.materials), state.mappings, state.overrides);
  panel.hidden = false;

  const formula = r.resolved
    ? `m = ${fmtQty(r.metric.value)} ${METRIC_UNIT(CALC_TYPE_BY_BASIS[el.quantity_basis])} × ${r.material.unit_weight} ${r.material.unit} = ${fmtKg(r.mass)} kg`
    : `계산 불가: ${r.issues.join(', ') || (r.excluded ? '제외됨' : '알 수 없음')}`;

  const overrideRow = state.overrides[el.id];
  panel.innerHTML = `
    <div class="card-head">
      <h2>${escapeHtml(el.name)}</h2>
      <button class="btn btn-ghost" id="closeDetailBtn">닫기</button>
    </div>
    <dl>
      <dt>element_id</dt><dd class="tag-mono">${escapeHtml(el.id)}</dd>
      <dt>instance_path</dt><dd class="tag-mono">${escapeHtml(el.instance_path)}</dd>
      <dt>모듈</dt><dd>${escapeHtml((state.modules.find((m) => m.id === el.module_id) || {}).name || el.module_id)}</dd>
      <dt>공종 / Tag</dt><dd>${escapeHtml(el.category)} / <span class="tag-mono">${escapeHtml(el.tag || '-')}</span></dd>
      <dt>계산유형 / 기준</dt><dd>${CALC_TYPE_BY_BASIS[el.quantity_basis] || '-'} / ${escapeHtml(el.quantity_basis)}</dd>
      <dt>물량 산출 방식</dt><dd>${r.metric ? escapeHtml(r.metric.quantity_method) : '-'}</dd>
      <dt>중심 산출 방식</dt><dd>${r.metric ? escapeHtml(r.metric.centroid_method) : '-'}</dd>
      <dt>중심 좌표 (world, m)</dt><dd>${r.centroid ? `(${r.centroid.map((v) => fmtKg(v, 3)).join(', ')})` : '—'}</dd>
      <dt>가정</dt><dd>${r.metric && r.metric.assumptions ? escapeHtml(r.metric.assumptions.join(' / ')) : '-'}</dd>
      <dt>포함 여부</dt><dd>${el.included === false ? '파일에서 제외' : (overrideRow && overrideRow.excluded ? `수동 제외 (${escapeHtml(overrideRow.reason || '')})` : '포함')}</dd>
      <dt>diagnostic</dt><dd>${r.issues.length ? r.issues.join(', ') : '없음'}</dd>
    </dl>
    <div class="formula">${escapeHtml(formula)}</div>
    <div class="btn-row">
      ${el.included !== false ? `<button class="btn" id="toggleExcludeBtn">${overrideRow && overrideRow.excluded ? '포함으로 복원' : '이 부재 제외'}</button>` : ''}
    </div>
  `;
  document.getElementById('closeDetailBtn').addEventListener('click', () => { selectedElementId = null; renderElementDetail(); });
  const toggleBtn = document.getElementById('toggleExcludeBtn');
  if (toggleBtn) {
    toggleBtn.addEventListener('click', () => {
      if (overrideRow && overrideRow.excluded) {
        delete state.overrides[el.id];
      } else {
        const reason = prompt('제외 사유를 입력하세요.');
        if (!reason) return;
        state.overrides[el.id] = { excluded: true, reason };
      }
      saveState();
      renderAll();
    });
  }
}

function renderCg() {
  const hasData = state.elements.length > 0 || state.manualMasses.length > 0;
  document.getElementById('cgEmpty').hidden = hasData;
  document.getElementById('cgBody').hidden = !hasData;
  if (!hasData) return;

  const agg = currentAggregate();
  document.getElementById('cgMass').textContent = agg.status === 'EMPTY' ? '—' : fmtMass(agg.totalResolvedMass);

  const showCg = agg.cgWorld && agg.status !== 'CG_INCOMPLETE' && agg.status !== 'EMPTY';
  document.getElementById('cgX').textContent = showCg ? fmtKg(agg.cgWorld[0], 3) + ' m' : '—';
  document.getElementById('cgY').textContent = showCg ? fmtKg(agg.cgWorld[1], 3) + ' m' : '—';
  document.getElementById('cgZ').textContent = showCg ? fmtKg(agg.cgWorld[2], 3) + ' m' : '—';
  document.getElementById('cgQuality').textContent = agg.status === 'ESTIMATED' ? '추정 포함' : (agg.status === 'VALID' ? '확정 가능' : (agg.status === 'INCOMPLETE' ? '참고용 (일부 미산출)' : '계산 불가'));

  drawProjection('svgPlanXY', agg, 0, 1, 'X', 'Y');
  drawProjection('svgFrontXZ', agg, 0, 2, 'X', 'Z');
  drawProjection('svgSideYZ', agg, 1, 2, 'Y', 'Z');

  const tbody = document.querySelector('#cgIssueTable tbody');
  const rows = [];
  for (const r of agg.estimatedElems) rows.push([r.element.name, '추정 근거 포함', r.centroidMethod || '-']);
  for (const r of agg.missingCentroid) rows.push([r.element.name, '중심 좌표 누락', 'UNAVAILABLE']);
  for (const m of agg.manualMissingLoc) rows.push([m.name, '수동 항목 위치 미입력', '-']);
  tbody.innerHTML = rows.map(([n, reason, method]) => `<tr><td>${escapeHtml(n)}</td><td>${escapeHtml(reason)}</td><td>${escapeHtml(method)}</td></tr>`).join('')
    || '<tr><td colspan="3" class="hint">없음</td></tr>';
}

function drawProjection(svgId, agg, ai, bi, labelA, labelB) {
  const svg = document.getElementById(svgId);
  const modules = state.selectedModuleId === 'ALL' ? state.modules : state.modules.filter((m) => m.id === state.selectedModuleId);
  if (!modules.length) { svg.innerHTML = ''; return; }

  let minA = Infinity, maxA = -Infinity, minB = Infinity, maxB = -Infinity;
  for (const m of modules) {
    minA = Math.min(minA, m.bounds_world_m.min[ai], m.bounds_world_m.max[ai]);
    maxA = Math.max(maxA, m.bounds_world_m.min[ai], m.bounds_world_m.max[ai]);
    minB = Math.min(minB, m.bounds_world_m.min[bi], m.bounds_world_m.max[bi]);
    maxB = Math.max(maxB, m.bounds_world_m.min[bi], m.bounds_world_m.max[bi]);
  }
  const pad = Math.max(0.3, (maxA - minA) * 0.15, (maxB - minB) * 0.15);
  minA -= pad; maxA += pad; minB -= pad; maxB += pad;
  const W = 300, H = 300;
  function toX(a) { return ((a - minA) / (maxA - minA || 1)) * W; }
  function toY(b) { return H - ((b - minB) / (maxB - minB || 1)) * H; }

  let svgContent = '';
  for (const m of modules) {
    const x0 = toX(m.bounds_world_m.min[ai]), x1 = toX(m.bounds_world_m.max[ai]);
    const y0 = toY(m.bounds_world_m.min[bi]), y1 = toY(m.bounds_world_m.max[bi]);
    svgContent += `<rect x="${Math.min(x0, x1)}" y="${Math.min(y0, y1)}" width="${Math.abs(x1 - x0)}" height="${Math.abs(y1 - y0)}" fill="none" stroke="#8891a3" stroke-dasharray="4 3" />`;
    svgContent += `<text x="${Math.min(x0, x1) + 4}" y="${Math.min(y0, y1) + 12}" font-size="9" fill="#6b7280">${escapeHtml(m.name)}</text>`;
  }
  if (agg.cgWorld) {
    const cx = toX(agg.cgWorld[ai]), cy = toY(agg.cgWorld[bi]);
    const dashed = agg.status !== 'VALID' && agg.status !== 'ESTIMATED';
    const stroke = dashed ? '#b8770b' : '#2f5fd6';
    svgContent += `<g stroke="${stroke}" stroke-width="2" ${dashed ? 'stroke-dasharray="3 3"' : ''}>
      <line x1="${cx - 8}" y1="${cy}" x2="${cx + 8}" y2="${cy}" />
      <line x1="${cx}" y1="${cy - 8}" x2="${cx}" y2="${cy + 8}" />
    </g>`;
  }
  svgContent += `<text x="6" y="14" font-size="10" fill="#6b7280">${labelA} / ${labelB}</text>`;
  svg.innerHTML = svgContent;
}

function renderManual() {
  const modSel = document.getElementById('mModule');
  modSel.innerHTML = state.modules.map((m) => `<option value="${escapeHtml(m.id)}">${escapeHtml(m.name)}</option>`).join('') || '<option value="">모듈 없음</option>';
  const catSel = document.getElementById('mCategory');
  if (catSel.options.length === 0) catSel.innerHTML = CATEGORIES.map((c) => `<option value="${c}">${c}</option>`).join('');

  const tbody = document.querySelector('#manualTable tbody');
  tbody.innerHTML = state.manualMasses.map((m) => {
    const loc = (m.x !== null && m.x !== undefined) ? `(${m.x}, ${m.y}, ${m.z})` : '<span class="hint">미입력</span>';
    const moduleName = (state.modules.find((mm) => mm.id === m.module_id) || {}).name || m.module_id;
    return `<tr>
      <td>${escapeHtml(m.name)}</td><td>${escapeHtml(moduleName)}</td><td>${escapeHtml(m.category)}</td>
      <td>${fmtKg(m.mass_kg)}</td><td>${loc}</td>
      <td>${escapeHtml(m.source)} / ${escapeHtml(m.reason)}</td>
      <td><button class="btn btn-ghost" data-del="${m.id}">삭제</button></td>
    </tr>`;
  }).join('') || '<tr><td colspan="7" class="hint">항목 없음</td></tr>';

  tbody.querySelectorAll('[data-del]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.manualMasses = state.manualMasses.filter((m) => m.id !== btn.getAttribute('data-del'));
      saveState(); renderAll();
    });
  });

  const totalManual = state.manualMasses.reduce((s, m) => s + (m.mass_kg || 0), 0);
  const missingLoc = state.manualMasses.filter((m) => m.x === null || m.x === undefined).length;
  document.getElementById('manualSummary').textContent = `합계 ${fmtMass(totalManual)} · 위치 누락 ${missingLoc}건`;
}

function renderCatalogTable() {
  const loadedTags = new Set(state.materials.filter((m) => m.catalog_tag).map((m) => m.catalog_tag));
  const tbody = document.querySelector('#catalogTable tbody');
  tbody.innerHTML = DEFAULT_MATERIAL_CATALOG.map((c) => `<tr>
    <td>${escapeHtml(c.category)}</td>
    <td class="tag-mono">${escapeHtml(c.tag)}</td>
    <td>${escapeHtml(c.name)}</td>
    <td>${c.calc_type}</td>
    <td>${c.unit_weight} ${escapeHtml(UNIT_BY_TYPE[c.calc_type])}</td>
    <td class="hint">${escapeHtml(c.source)}</td>
    <td>${loadedTags.has(c.tag) ? '<span class="badge-status badge-ok">추가됨</span>' : '<span class="hint">미추가</span>'}</td>
  </tr>`).join('');
}

function renderMaterials() {
  updateMaterialFormUnit();
  renderCatalogTable();
  const tbody = document.querySelector('#materialsTable tbody');
  tbody.innerHTML = state.materials.map((m) => `<tr>
    <td>${escapeHtml(m.name)}</td><td>${escapeHtml(m.specification || '-')}</td><td>${m.calc_type}</td>
    <td>${m.unit_weight}</td><td>${escapeHtml(m.unit)}</td><td>${m.quality}</td>
    <td>${escapeHtml(m.source)}</td><td class="tag-mono">${escapeHtml(m.version_id)}</td>
    <td>${m.active === false ? '비활성' : '활성'}</td>
    <td><button class="btn btn-ghost" data-toggle="${m.version_id}">${m.active === false ? '활성화' : '비활성화'}</button></td>
  </tr>`).join('') || '<tr><td colspan="10" class="hint">등록된 자재 없음</td></tr>';

  tbody.querySelectorAll('[data-toggle]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const m = state.materials.find((mm) => mm.version_id === btn.getAttribute('data-toggle'));
      if (m) m.active = m.active === false ? true : false;
      saveState(); renderAll();
    });
  });
}

function renderReports() {
  document.getElementById('reportMeta').textContent =
    `프로젝트: ${state.projectName} · 산출 버전: ${state.revisionStatus} · 엔진 v${state.engineVersion} · ${state.importMeta ? '원본: ' + state.importMeta.fileName : '업로드 데이터 없음'}`;

  const agg = fullAggregate();
  const body = document.getElementById('reportBody');
  if (!state.elements.length && !state.manualMasses.length) {
    body.innerHTML = '<p class="hint">표시할 산출 결과가 없습니다.</p>';
    return;
  }
  const draftWatermark = state.revisionStatus !== 'FIXED' ? '<p class="watermark-draft">DRAFT · 검토용</p>' : '';
  body.innerHTML = `
    ${draftWatermark}
    <p><strong>상태:</strong> ${agg.status} — ${STATUS_LABEL[agg.status]}</p>
    <p><strong>총중량:</strong> ${agg.status === 'EMPTY' ? '—' : fmtMass(agg.totalResolvedMass)}</p>
    <p><strong>CG (world, m):</strong> ${agg.cgWorld && agg.cgConfirmed ? `(${agg.cgWorld.map((v) => fmtKg(v, 3)).join(', ')})` : '계산 불가 또는 참고용'}</p>
    <p><strong>포함/미산출/제외:</strong> ${agg.ok.length} / ${agg.unresolved.length} / ${agg.resolved.length - agg.included.length}</p>
    <p><strong>수동 추가 중량 합계:</strong> ${fmtMass(agg.manualValid.reduce((s, m) => s + m.mass_kg, 0))} (${agg.manualValid.length}건, 위치 누락 ${agg.manualMissingLoc.length}건)</p>
    <p class="hint">반올림한 행 합과 총계가 다를 수 있습니다. 표시 자릿수: kg 2자리, ton 3자리, CG mm 1자리.</p>
  `;
}

const MAT_MODE_OPTIONS = {
  AREA: [
    ['DIRECT', '직접 단중'],
    ['DENSITY_THICKNESS', '밀도(비중) × 두께'],
  ],
  VOLUME: [
    ['DIRECT', '직접 단중'],
    ['SG', '비중으로 입력'],
  ],
  LENGTH: [['DIRECT', '직접 단중']],
  COUNT: [['DIRECT', '직접 단중']],
};

function rebuildMaterialModeOptions() {
  const calcType = document.getElementById('matCalcType').value;
  const sel = document.getElementById('matMode');
  const prev = sel.value;
  const opts = MAT_MODE_OPTIONS[calcType] || MAT_MODE_OPTIONS.LENGTH;
  sel.innerHTML = opts.map(([v, label]) => `<option value="${v}">${label}</option>`).join('');
  if (opts.some(([v]) => v === prev)) sel.value = prev;
}

function updateMaterialFormUnit() {
  rebuildMaterialModeOptions();
  const calcType = document.getElementById('matCalcType').value;
  document.getElementById('matUnit').value = UNIT_BY_TYPE[calcType];
  const mode = document.getElementById('matMode').value;

  document.getElementById('matModeLabel').hidden = calcType === 'LENGTH' || calcType === 'COUNT';

  const isAreaDensity = calcType === 'AREA' && mode === 'DENSITY_THICKNESS';
  const isVolumeSg = calcType === 'VOLUME' && mode === 'SG';

  document.getElementById('matDensityField').hidden = !isAreaDensity;
  document.getElementById('matDensityUnitField').hidden = !isAreaDensity;
  document.getElementById('matThicknessField').hidden = !isAreaDensity;
  document.getElementById('matSgField').hidden = !isVolumeSg;
  document.getElementById('matWeightField').hidden = isAreaDensity || isVolumeSg;
  document.getElementById('matWeightUnitField').hidden = !(calcType === 'AREA' && mode === 'DIRECT');
}

// ---------------------------------------------------------------------------
// 5. 이벤트 바인딩
// ---------------------------------------------------------------------------
function bindNav() {
  document.querySelectorAll('.nav-item').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.nav-item').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      document.querySelectorAll('.tab-panel').forEach((p) => (p.hidden = true));
      document.getElementById('tab-' + btn.dataset.tab).hidden = false;
    });
  });

  document.getElementById('unresolvedLink').addEventListener('click', (e) => {
    e.preventDefault();
    document.querySelector('.nav-item[data-tab="import"]').click();
    document.querySelector('.tabbar-btn[data-vtab="mapping"]').click();
  });
}

function bindImport() {
  const dropzone = document.getElementById('dropzone');
  const fileInput = document.getElementById('fileInput');
  document.getElementById('pickFileBtn').addEventListener('click', () => fileInput.click());
  fileInput.addEventListener('change', () => { if (fileInput.files[0]) handleFile(fileInput.files[0]); });
  dropzone.addEventListener('dragover', (e) => { e.preventDefault(); dropzone.classList.add('dragover'); });
  dropzone.addEventListener('dragleave', () => dropzone.classList.remove('dragover'));
  dropzone.addEventListener('drop', (e) => {
    e.preventDefault(); dropzone.classList.remove('dragover');
    if (e.dataTransfer.files[0]) handleFile(e.dataTransfer.files[0]);
  });

  document.getElementById('loadDemoBtn').addEventListener('click', () => {
    applyImport(SAMPLE_EXPORT, 'sample_export.json (데모)');
    const seeded = seedMaterialsFromFixture(SAMPLE_FIXTURE);
    state.materials = seeded.materials;
    state.mappings = seeded.mappings;
    saveState();
    renderAll();
  });

  document.querySelectorAll('.tabbar-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tabbar-btn').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      document.querySelectorAll('.vtab-panel').forEach((p) => (p.hidden = true));
      document.getElementById('vtab-' + btn.dataset.vtab).hidden = false;
    });
  });

  document.getElementById('content').addEventListener('change', (e) => {
    if (e.target.classList.contains('mapSelect')) {
      const tag = e.target.getAttribute('data-tag');
      if (e.target.value) state.mappings[tag] = e.target.value;
      else delete state.mappings[tag];
      saveState(); renderAll();
    }
  });
}

function handleFile(file) {
  if (file.size > 20 * 1024 * 1024) {
    alert('20MB를 초과하는 파일입니다. MVP 지원 한도를 벗어납니다.');
    return;
  }
  const reader = new FileReader();
  reader.onload = () => {
    let json;
    try {
      json = JSON.parse(reader.result);
    } catch (e) {
      alert('JSON 파싱에 실패했습니다: ' + e.message);
      return;
    }
    applyImport(json, file.name);
  };
  reader.readAsText(file, 'utf-8');
}

function applyImport(json, fileName) {
  const { ok, blocking, warnings } = validateExportJson(json);
  if (!ok) {
    state.fileDiagnostics = blocking;
    state.importMeta = null;
    document.getElementById('importSummary').hidden = true;
    document.getElementById('validationCard').hidden = false;
    document.getElementById('errCount').textContent = blocking.length;
    document.getElementById('warnCount').textContent = 0;
    document.getElementById('vtab-errors').innerHTML = diagnosticsTable(blocking);
    document.getElementById('vtab-warnings').innerHTML = '<p class="hint">-</p>';
    document.getElementById('vtab-mapping').innerHTML = '<p class="hint">-</p>';
    alert('BLOCKED: 파일 계약 오류로 반영하지 않았습니다. 기존 데이터는 유지됩니다.');
    return;
  }

  // 재업로드: 같은 model_id의 같은 element_id에는 override/mapping을 승계
  const sameModel = state.importMeta && state.importMeta.modelId === json.model.id;
  const prevOverrides = sameModel ? state.overrides : {};
  const existingIds = new Set(json.elements.map((e) => e.id));
  const carriedOverrides = {};
  for (const [id, ov] of Object.entries(prevOverrides)) {
    if (existingIds.has(id)) carriedOverrides[id] = ov;
  }

  state.modules = json.modules;
  state.elements = json.elements;
  state.fileDiagnostics = warnings;
  state.overrides = carriedOverrides;
  state.selectedModuleId = 'ALL';
  state.revisionStatus = 'DRAFT';
  state.importMeta = {
    fileName,
    modelId: json.model.id,
    modelName: json.model.name,
    exportId: json.export_id,
    exportedAt: json.exported_at,
    importedAt: nowIso(),
    moduleCount: json.modules.length,
    elementCount: json.elements.length,
  };
  saveState();
  renderAll();
}

function bindDashboard() {
  document.getElementById('moduleFilterSelect').addEventListener('change', (e) => {
    state.selectedModuleId = e.target.value;
    saveState(); renderAll();
  });
  document.getElementById('unitDisplaySelect').addEventListener('change', (e) => {
    state.unitDisplay = e.target.value;
    saveState(); renderAll();
  });
  document.getElementById('fixResultBtn').addEventListener('click', () => {
    const agg = fullAggregate();
    if (!(agg.status === 'VALID' || agg.status === 'ESTIMATED')) return;
    if (agg.status === 'ESTIMATED' && !confirm('추정 근거가 포함된 결과입니다. 확인 후 확정하시겠습니까?')) return;
    state.revisionStatus = 'FIXED';
    state.fixedSnapshot = {
      fixedAt: nowIso(),
      status: agg.status,
      totalMass: agg.totalResolvedMass,
      cg: agg.cgWorld,
      elementCount: agg.ok.length,
    };
    saveState(); renderAll();
  });
}

function bindElements() {
  ['elementSearch', 'elementCategoryFilter', 'elementStatusFilter'].forEach((id) => {
    document.getElementById(id).addEventListener('input', renderElements);
    document.getElementById(id).addEventListener('change', renderElements);
  });
  document.getElementById('exportElementsCsvBtn').addEventListener('click', () => {
    exportElementsCsv();
  });
}

function exportElementsCsv() {
  const scoped = elementsForModule(state.selectedModuleId);
  const materialsByVersion = activeMaterialsByVersionId2(state.materials);
  const header = ['부재명', '모듈', '공종', 'Tag', '계산유형', '물량', '단중', '중량_kg', '중심품질', '상태'];
  const lines = [header.join(',')];
  for (const el of scoped) {
    const r = resolveElement(el, materialsByVersion, state.mappings, state.overrides);
    const status = r.excluded ? 'EXCLUDED' : (!r.resolved ? 'UNRESOLVED' : (r.quality === 'ESTIMATED' ? 'ESTIMATED' : 'OK'));
    const moduleName = (state.modules.find((m) => m.id === el.module_id) || {}).name || el.module_id;
    const row = [
      el.name, moduleName, el.category, el.tag || '', CALC_TYPE_BY_BASIS[el.quantity_basis] || '',
      r.metric ? r.metric.value : '', r.material ? r.material.unit_weight : '', r.resolved ? r.mass : '',
      r.centroid ? (r.quality === 'ESTIMATED' ? 'ESTIMATED' : 'CALCULATED') : '', status,
    ].map((v) => `"${String(v).replace(/"/g, '""')}"`);
    lines.push(row.join(','));
  }
  download(`elements_${Date.now()}.csv`, '﻿' + lines.join('\r\n'), 'text/csv;charset=utf-8');
}

function bindManual() {
  document.getElementById('manualForm').addEventListener('submit', (e) => {
    e.preventDefault();
    const x = document.getElementById('mX').value;
    const y = document.getElementById('mY').value;
    const z = document.getElementById('mZ').value;
    const anyLoc = x !== '' || y !== '' || z !== '';
    const allLoc = x !== '' && y !== '' && z !== '';
    if (anyLoc && !allLoc) { alert('위치는 세 값 모두 입력하거나 모두 비워두세요.'); return; }
    const mass = parseFloat(document.getElementById('mMass').value);
    if (!(mass > 0)) { alert('중량은 0보다 큰 값이어야 합니다.'); return; }
    state.manualMasses.push({
      id: uid('manual'),
      name: document.getElementById('mName').value,
      module_id: document.getElementById('mModule').value,
      category: document.getElementById('mCategory').value,
      mass_kg: mass,
      x: allLoc ? parseFloat(x) : null,
      y: allLoc ? parseFloat(y) : null,
      z: allLoc ? parseFloat(z) : null,
      source: document.getElementById('mSource').value,
      reason: document.getElementById('mReason').value,
    });
    e.target.reset();
    saveState(); renderAll();
  });
}

function bindMaterials() {
  document.getElementById('loadCatalogBtn').addEventListener('click', () => {
    const already = new Set(state.materials.filter((m) => m.catalog_tag).map((m) => m.catalog_tag));
    const toAdd = DEFAULT_MATERIAL_CATALOG.filter((c) => !already.has(c.tag));
    if (!toAdd.length) { alert('이미 모든 카탈로그 자재가 추가되어 있습니다.'); return; }
    if (!confirm(`카탈로그 자재 ${toAdd.length}개를 추가하고 해당 Tag에 자동 매핑합니다.\n모두 참고용 추정치이며 실제 프로젝트에는 검증된 자료로 교체해야 합니다. 계속하시겠습니까?`)) return;
    const materials = buildCatalogMaterials().filter((m) => toAdd.some((c) => c.tag === m.catalog_tag));
    state.materials.push(...materials);
    for (const m of materials) state.mappings[m.catalog_tag] = m.version_id;
    saveState();
    renderAll();
    alert(`${materials.length}개 자재를 추가하고 매핑했습니다.`);
  });

  document.getElementById('matCalcType').addEventListener('change', updateMaterialFormUnit);
  document.getElementById('matMode').addEventListener('change', updateMaterialFormUnit);
  document.getElementById('matQuality').addEventListener('change', (e) => {
    document.getElementById('matEstimateReasonField').hidden = e.target.value !== 'ESTIMATED';
  });

  document.getElementById('materialForm').addEventListener('submit', (e) => {
    e.preventDefault();
    const calcType = document.getElementById('matCalcType').value;
    const mode = document.getElementById('matMode').value;
    let unitWeight;
    let thickness = null, density = null;
    if (calcType === 'AREA' && mode === 'DENSITY_THICKNESS') {
      const rawDensity = parseFloat(document.getElementById('matDensity').value);
      const densityUnit = document.getElementById('matDensityUnit').value; // kg/m3 | SG
      thickness = parseFloat(document.getElementById('matThickness').value);
      if (!(rawDensity > 0) || !(thickness > 0)) { alert('밀도(비중)와 두께는 0보다 커야 합니다.'); return; }
      density = densityUnit === 'SG' ? rawDensity * 1000 : rawDensity; // 비중(SG) × 1000 = kg/m3
      unitWeight = density * thickness;
    } else if (calcType === 'VOLUME' && mode === 'SG') {
      const sg = parseFloat(document.getElementById('matSg').value);
      if (!(sg > 0)) { alert('비중은 0보다 커야 합니다.'); return; }
      unitWeight = sg * 1000; // 비중(SG) × 1000 = kg/m3
    } else {
      const rawWeight = parseFloat(document.getElementById('matWeight').value);
      if (!(rawWeight > 0)) { alert('단중은 0보다 커야 합니다.'); return; }
      if (calcType === 'AREA') {
        const weightUnit = document.getElementById('matWeightUnit').value; // kg/m2 | g/cm2
        unitWeight = weightUnit === 'g/cm2' ? rawWeight * 10 : rawWeight; // 1 g/cm2 = 10 kg/m2
      } else {
        unitWeight = rawWeight;
      }
    }
    const name = document.getElementById('matName').value.trim();
    const source = document.getElementById('matSource').value.trim();
    if (!name || !source) { alert('이름과 출처는 필수입니다.'); return; }
    const quality = document.getElementById('matQuality').value;
    if (quality === 'ESTIMATED' && !document.getElementById('matEstimateReason').value.trim()) {
      alert('ESTIMATED 품질은 추정 사유가 필요합니다.'); return;
    }

    const editingId = document.getElementById('matEditingId').value;
    const baseMaterialId = editingId ? state.materials.find((m) => m.version_id === editingId).material_id : uid('mat');
    const versionId = uid('v');
    state.materials.push({
      material_id: baseMaterialId,
      version_id: versionId,
      name,
      specification: document.getElementById('matSpec').value,
      calc_type: calcType,
      unit_weight: unitWeight,
      unit: UNIT_BY_TYPE[calcType],
      source,
      source_date: document.getElementById('matSourceDate').value,
      quality,
      estimate_reason: quality === 'ESTIMATED' ? document.getElementById('matEstimateReason').value : null,
      thickness_m: thickness, density_kg_m3: density,
      active: true,
    });
    e.target.reset();
    document.getElementById('matEditingId').value = '';
    document.getElementById('matCancelEditBtn').hidden = true;
    updateMaterialFormUnit();
    saveState(); renderAll();
  });

  document.getElementById('matCancelEditBtn').addEventListener('click', () => {
    document.getElementById('materialForm').reset();
    document.getElementById('matEditingId').value = '';
    document.getElementById('matCancelEditBtn').hidden = true;
  });
}

function bindReports() {
  document.getElementById('downloadCsvBtn').addEventListener('click', () => {
    state.selectedModuleId = 'ALL';
    exportElementsCsv();
  });
  document.getElementById('downloadJsonBtn').addEventListener('click', () => {
    const agg = fullAggregate();
    const basis = {
      generated_at: nowIso(),
      project: state.projectName,
      revision_status: state.revisionStatus,
      engine_version: state.engineVersion,
      import_meta: state.importMeta,
      status: agg.status,
      total_mass_kg: agg.status === 'EMPTY' ? null : agg.totalResolvedMass,
      cg_world_m: agg.cgConfirmed ? agg.cgWorld : null,
      materials_snapshot: state.materials,
      mappings_snapshot: state.mappings,
      overrides_snapshot: state.overrides,
      manual_masses: state.manualMasses,
      elements: agg.resolved.map((r) => ({
        id: r.element.id, name: r.element.name, module_id: r.element.module_id,
        excluded: r.excluded, resolved: r.resolved, mass_kg: r.mass,
        centroid_world_m: r.centroid, quality: r.quality, issues: r.issues,
      })),
    };
    download(`calculation_basis_${Date.now()}.json`, JSON.stringify(basis, null, 2), 'application/json');
  });
  document.getElementById('printReportBtn').addEventListener('click', () => window.print());

  document.getElementById('backupExportBtn').addEventListener('click', () => {
    download(`project_backup_${Date.now()}.json`, JSON.stringify(state, null, 2), 'application/json');
  });
  document.getElementById('backupImportInput').addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const restored = JSON.parse(reader.result);
        if (!restored || typeof restored !== 'object' || !Array.isArray(restored.elements)) {
          throw new Error('스키마 불일치');
        }
        state = Object.assign(defaultState(), restored);
        saveState(); renderAll();
        alert('백업을 복원했습니다.');
      } catch (err) {
        alert('백업 복원 실패: ' + err.message);
      }
    };
    reader.readAsText(file, 'utf-8');
  });

  document.getElementById('reportTitleInput').addEventListener('input', (e) => {
    document.getElementById('reportTitle').textContent = e.target.value || '모듈러 중량 산출 보고서';
  });
}

// ---------------------------------------------------------------------------
// 초기화
// ---------------------------------------------------------------------------
function init() {
  bindNav();
  bindImport();
  bindDashboard();
  bindElements();
  bindManual();
  bindMaterials();
  bindReports();
  renderAll();
  setSaveStatus(localStorage.getItem(STORAGE_KEY) ? '이전 세션 불러옴' : '저장된 데이터 없음');
}

document.addEventListener('DOMContentLoaded', init);
