# 스틸 스터드 배치 도구 - SketchUp 확장 로더
# "모듈러 중량 Exporter"와 완전히 별개의 확장 프로그램이다. 서로 몰라도 되지만,
# 생성된 스터드에 같은 modular_weight 속성(AttributeDictionary) 계약으로 role/Tag/
# quantity_basis를 붙여두므로, 모듈러 중량 Exporter가 설치되어 있으면 바로 검증·내보내기
# 대상이 된다.
require 'sketchup.rb'
require 'extensions.rb'

module SteelStudPlacer
  unless defined?(EXTENSION)
    EXTENSION = SketchupExtension.new(
      '스틸 스터드 배치 도구',
      File.join(File.dirname(__FILE__), 'steel_stud_placer', 'main.rb')
    )
    EXTENSION.description = 'CAD로 만든 스터드 단면을 압출해서 지정한 간격으로 자동 배치합니다.'
    EXTENSION.version = '0.2.0'
    EXTENSION.creator = 'Modular Weight Project'
    EXTENSION.copyright = '2026'
    Sketchup.register_extension(EXTENSION, true)
  end
end
