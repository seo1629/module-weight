# 빠른 측정 도구 - role/Tag 지정과는 무관하게, 선택한 형상의 길이·면적·체적을
# 바로 재보거나, 알고 있는 총중량을 나눠서 단위중량(kg/m, kg/m², kg/m³, kg/EA)을
# 역산하는 계산기. entity.transformation만 사용하므로 최상위 조상의 배치(회전·이동)는
# 반영되지만, 더 위 조상의 스케일까지는 반영되지 않는 빠른 측정용이다.
module ModularWeightExporter
  module Measure
    module_function

    # entity가 SketchUp이 인정하는 닫힌 솔리드면 체적을, 아니면 하위 면 전체의 합을
    # 면적으로 계산한다. [ 'VOLUME'|'AREA'|nil, 값, 단위문자열 ] 을 반환한다.
    def volume_or_area(entity)
      transform = entity.transformation
      children = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
      faces = Geometry.collect_all_faces(children, transform, [])
      return [nil, nil, nil] if faces.empty?

      native = 0
      native = (entity.volume rescue 0) if entity.respond_to?(:volume)
      if native && native > 0
        volume_m3, = Geometry.compute_volume(faces)
        return ['VOLUME', volume_m3, 'm³'] if volume_m3 && volume_m3 > 1e-9
      end

      area_m2, = Geometry.compute_area(faces)
      return [nil, nil, nil] if area_m2.nil? || area_m2 <= 0
      ['AREA', area_m2, 'm²']
    end

    # 선택된 그룹(들)의 체적/면적을 재서 팝업으로 보여준다. (측정만, 저장 안 함)
    def measure_volume_area
      targets = Sketchup.active_model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      if targets.empty?
        UI.messagebox('체적 또는 면적을 잴 그룹/컴포넌트를 먼저 선택하세요.')
        return
      end
      lines = targets.first(10).map do |e|
        name = e.name.to_s.empty? ? '(이름없음)' : e.name
        mode, value, unit = volume_or_area(e)
        if mode.nil?
          "- #{name}: 형상을 인식하지 못했습니다 (닫힌 솔리드도 아니고 면도 없음)"
        else
          label = mode == 'VOLUME' ? '체적' : '면적'
          digits = mode == 'VOLUME' ? 6 : 4
          "- #{name}: #{label} 약 #{value.round(digits)} #{unit}"
        end
      end
      msg = "측정 결과:\n\n" + lines.join("\n")
      msg += "\n\n... 외 #{targets.length - 10}개 더 (최대 10개만 표시)" if targets.length > 10
      UI.messagebox(msg)
    rescue StandardError => e
      UI.messagebox("측정 중 오류가 발생했습니다: #{e.message}")
    end

    # 물량(quantity_value, 단위 unit_symbol)과 사용자가 입력하는 총중량(kg)으로
    # 단위중량을 계산해서 보여준다. 웹 자재 DB에 그대로 입력할 수 있는 값이다.
    def prompt_and_show_unit_weight(quantity_value, unit_symbol, label)
      title = "단위중량 계산 - #{label} #{quantity_value.round(6)} #{unit_symbol}"
      result = UI.inputbox(['총중량 (kg)'], [''], title)
      return if result == false
      total = result[0].to_f
      if !(total > 0)
        UI.messagebox('총중량은 0보다 큰 값이어야 합니다.')
        return
      end
      if !(quantity_value > 0)
        UI.messagebox('물량이 0보다 커야 계산할 수 있습니다.')
        return
      end
      unit_weight = total / quantity_value
      UI.messagebox(
        "단위중량 계산 결과\n\n" \
        "물량: #{quantity_value.round(6)} #{unit_symbol}\n" \
        "총중량: #{total} kg\n" \
        "→ 단위중량: #{unit_weight.round(4)} kg/#{unit_symbol}\n\n" \
        "이 값을 웹 자재 DB의 '단중' 항목에 그대로 입력하시면 됩니다."
      )
    end

    # 계산유형을 고르게 하고, 그에 맞는 방법으로 물량을 얻은 뒤 단위중량을 계산한다.
    def unit_weight_calculator
      options = [
        '체적(VOLUME) - 선택한 솔리드',
        '면적(AREA) - 선택한 형상',
        '길이(LENGTH) - 두 점 클릭',
        '개수(COUNT) - 직접 입력',
      ]
      result = UI.inputbox(['계산유형 선택'], [options.first], [options.join('|')], '단위중량 계산기')
      return if result == false
      choice = result[0]

      case choice
      when options[0], options[1]
        targets = Sketchup.active_model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        if targets.empty?
          UI.messagebox('먼저 형상(부재 그룹)을 선택하세요.')
          return
        end
        e = targets.first
        mode, value, unit = volume_or_area(e)
        if mode.nil?
          UI.messagebox('선택한 형상에서 체적/면적을 계산하지 못했습니다.')
          return
        end
        expected = choice == options[0] ? 'VOLUME' : 'AREA'
        if mode != expected
          got_label = mode == 'VOLUME' ? '체적(닫힌 솔리드)' : '면적'
          proceed = UI.messagebox("선택한 형상은 #{got_label} 기준으로 측정됩니다. 이대로 계산할까요?", MB_YESNO)
          return if proceed == IDNO
        end
        label = mode == 'VOLUME' ? '체적' : '면적'
        prompt_and_show_unit_weight(value, unit, label)
      when options[2]
        Sketchup.active_model.select_tool(LengthMeasureTool.new(:unit_weight))
      when options[3]
        count_result = UI.inputbox(['개수 (EA)'], ['1'], '개수 입력')
        return if count_result == false
        count = count_result[0].to_f
        if !(count > 0)
          UI.messagebox('개수는 0보다 커야 합니다.')
          return
        end
        prompt_and_show_unit_weight(count, 'EA', '개수')
      end
    rescue StandardError => e
      UI.messagebox("단위중량 계산 중 오류가 발생했습니다: #{e.message}")
    end
  end
end
