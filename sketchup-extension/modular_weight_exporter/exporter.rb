# JSON 봉투 조립, 파일 저장, 검증 요약 (명세 6.1, 1.5).
module ModularWeightExporter
  module Exporter
    module_function

    def build_envelope
      data = Builder.build_export_data
      model = Sketchup.active_model
      model_name = model.title.to_s
      model_name = '이름 없는 모델' if model_name.empty?

      {
        'schema_version' => SCHEMA_VERSION,
        'export_id' => ModularWeightExporter.generate_uuid,
        'exported_at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'exporter' => {
          'name' => 'ModularWeightExporter',
          'version' => '0.1.0',
          'sketchup_version' => Sketchup.version,
        },
        'model' => { 'id' => ModularWeightExporter.model_id, 'name' => model_name },
        'units' => { 'area' => 'm2', 'length' => 'm', 'volume' => 'm3', 'count' => 'EA' },
        'coordinate_system' => { 'up_axis' => 'Z', 'handedness' => 'RIGHT', 'frame' => 'SKETCHUP_WORLD' },
        'scope' => { 'mode' => 'ALL_REGISTERED_MODULES', 'includes_hidden' => true },
        'modules' => data[:modules],
        'elements' => data[:elements],
        'diagnostics' => data[:diagnostics],
      }
    end

    def summarize(diagnostics)
      errors = diagnostics.select { |d| d['severity'] == 'ERROR' }
      warnings = diagnostics.select { |d| d['severity'] == 'WARNING' }
      [errors, warnings]
    end

    def validate_only
      envelope = build_envelope
      errors, warnings = summarize(envelope['diagnostics'])
      msg = "모듈 #{envelope['modules'].length}개, 부재 #{envelope['elements'].length}개\n" \
            "오류 #{errors.length}건, 경고 #{warnings.length}건\n\n"
      (errors + warnings).first(25).each do |d|
        loc = d['element_id'] || d['module_id'] || '-'
        msg += "[#{d['severity']}] #{d['code']} (#{loc})\n  #{d['message']}\n"
      end
      total = errors.length + warnings.length
      msg += "\n... 외 #{total - 25}건 (최대 25건만 표시)" if total > 25
      UI.messagebox(msg)
    rescue StandardError => e
      UI.messagebox("검증 중 오류가 발생했습니다: #{e.message}\n#{e.backtrace.first(3).join("\n")}")
    end

    def export_json
      envelope = build_envelope
      errors, warnings = summarize(envelope['diagnostics'])

      if !errors.empty?
        result = UI.messagebox(
          "오류 #{errors.length}건, 경고 #{warnings.length}건이 있습니다.\n" \
          "오류가 있는 상태로 JSON을 내보내면 웹에서 '검토 필요'로 표시됩니다.\n계속 내보내시겠습니까?",
          MB_YESNO
        )
        return if result == IDNO
      end

      safe_name = envelope['model']['name'].gsub(/[\\\/:*?"<>|]/, '_')
      default_name = "#{safe_name}_#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}.weight.json"
      path = UI.savepanel('모듈러 중량 산출 JSON 내보내기', '', default_name)
      return if path.nil?
      path += '.json' unless path.downcase.end_with?('.json')

      File.open(path, 'w:UTF-8') { |f| f.write(JSON.pretty_generate(envelope)) }

      UI.messagebox(
        "내보내기 완료.\n" \
        "모듈 #{envelope['modules'].length}개, 부재 #{envelope['elements'].length}개\n" \
        "오류 #{errors.length}건, 경고 #{warnings.length}건\n\n#{path}"
      )
    rescue StandardError => e
      UI.messagebox("내보내기 중 오류가 발생했습니다: #{e.message}\n#{e.backtrace.first(3).join("\n")}")
    end
  end
end
