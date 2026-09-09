# 모듈러 중량 산출 Exporter - SketchUp 확장 로더
# 개발명세 v0.1의 1장/6장 계약을 구현한다.
require 'sketchup.rb'
require 'extensions.rb'

module ModularWeightExporter
  unless defined?(EXTENSION)
    EXTENSION = SketchupExtension.new(
      '모듈러 중량 Exporter',
      File.join(File.dirname(__FILE__), 'modular_weight_exporter', 'main.rb')
    )
    EXTENSION.description = '모듈러 건축 부재의 물량(면적/체적/길이/개수)과 세계 좌표를 계산해 웹 Weight Calculator용 Export JSON으로 저장합니다.'
    EXTENSION.version = '0.7.0'
    EXTENSION.creator = 'Modular Weight Project'
    EXTENSION.copyright = '2026'
    Sketchup.register_extension(EXTENSION, true)
  end
end
