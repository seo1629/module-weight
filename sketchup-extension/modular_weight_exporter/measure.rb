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

    # Tag로 여러 부재를 한꺼번에 선택했을 때(Tags 패널 Select Entities), 그 전체의
    # 물량 합계를 계산유형별로 내서 보여준다. 각 부재는 이미 저장된 기준면/기준축/
    # quantity_basis를 그대로 쓰므로, 내보내기 시 웹앱 "자재 집계" 표에 나오는 물량과
    # 같은 값이 나와야 한다 (검산용).
    def sum_selected_quantities
      targets = Sketchup.active_model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      if targets.empty?
        UI.messagebox("합계를 낼 부재들을 먼저 선택하세요.\n(Tags 패널에서 Tag 우클릭 → Select Entities 추천)")
        return
      end

      sums = { 'AREA' => 0.0, 'VOLUME' => 0.0, 'LENGTH' => 0.0, 'COUNT' => 0.0 }
      counts = { 'AREA' => 0, 'VOLUME' => 0, 'LENGTH' => 0, 'COUNT' => 0 }
      failed = []
      skipped_non_part = 0

      targets.each do |e|
        if ModularWeightExporter.role_of(e) != 'PART'
          skipped_non_part += 1
          next
        end
        name = e.name.to_s.empty? ? '(이름없음)' : e.name
        tag = ModularWeightExporter.tag_of(e) || '(Tag없음)'
        basis = ModularWeightExporter.quantity_basis_of(e)
        transform = e.transformation
        children = Builder.children_entities(e)

        begin
          case basis
          when 'REFERENCE_FACES'
            ids = ModularWeightExporter.get_attr(e, 'reference_face_ids', [])
            ids = [] if ids.nil?
            found = ids.empty? ? [] : Geometry.find_faces_by_ids(children, ids, transform, [])
            if found.empty?
              failed << "#{name} [Tag:#{tag}]: 기준면 없음/못 찾음"
            else
              area_m2, = Geometry.compute_area(found)
              if area_m2 && area_m2 > 0
                sums['AREA'] += area_m2
                counts['AREA'] += 1
              else
                failed << "#{name} [Tag:#{tag}]: 면적 0"
              end
            end
          when 'SOLID'
            faces = Geometry.collect_all_faces(children, transform, [])
            if faces.empty?
              failed << "#{name} [Tag:#{tag}]: 형상 없음"
            else
              volume_m3, = Geometry.compute_volume(faces)
              if volume_m3 && volume_m3 > 0
                sums['VOLUME'] += volume_m3
                counts['VOLUME'] += 1
              else
                failed << "#{name} [Tag:#{tag}]: 닫힌 솔리드 아님"
              end
            end
          when 'AXIS_ENDPOINTS'
            pts = ModularWeightExporter.get_attr(e, 'axis_endpoints_local')
            if pts.nil? || pts.length != 2
              failed << "#{name} [Tag:#{tag}]: 기준축 없음"
            else
              p1 = Geom::Point3d.new(pts[0][0], pts[0][1], pts[0][2])
              p2 = Geom::Point3d.new(pts[1][0], pts[1][1], pts[1][2])
              length_m, = Geometry.compute_length(p1, p2, transform)
              if length_m && length_m > 0
                sums['LENGTH'] += length_m
                counts['LENGTH'] += 1
              else
                failed << "#{name} [Tag:#{tag}]: 길이 0"
              end
            end
          when 'INSTANCE'
            sums['COUNT'] += 1
            counts['COUNT'] += 1
          else
            failed << "#{name} [Tag:#{tag}]: 계산유형 미지정"
          end
        rescue StandardError => err
          failed << "#{name} [Tag:#{tag}]: 오류(#{err.message})"
        end
      end

      lines = ["선택 #{targets.length}개 (PART 아님/미지정 #{skipped_non_part}개 제외)", '']
      lines << "LENGTH 합계: #{sums['LENGTH'].round(4)} m  (#{counts['LENGTH']}개)" if counts['LENGTH'] > 0
      lines << "AREA 합계: #{sums['AREA'].round(4)} m²  (#{counts['AREA']}개)" if counts['AREA'] > 0
      lines << "VOLUME 합계: #{sums['VOLUME'].round(6)} m³  (#{counts['VOLUME']}개)" if counts['VOLUME'] > 0
      lines << "COUNT 합계: #{sums['COUNT'].round(0)} EA  (#{counts['COUNT']}개)" if counts['COUNT'] > 0
      lines << '계산된 물량이 없습니다.' if counts.values.all?(&:zero?)

      unless failed.empty?
        lines << ''
        lines << "계산 실패 #{failed.length}건:"
        lines.concat(failed.first(10).map { |f| "- #{f}" })
        lines << "... 외 #{failed.length - 10}건 더" if failed.length > 10
      end

      UI.messagebox("물량 합계 (웹앱 자재 집계표와 비교용)\n\n" + lines.join("\n"))
    rescue StandardError => e
      UI.messagebox("합계 계산 중 오류가 발생했습니다: #{e.message}")
    end

    # 총중량을 모를 때(카탈로그 정미중량 없음) 쓰는 이론 계산.
    # 선택한 형상(주로 강재 등 LENGTH형 부재)의 체적을 실제로 재고, 길이로 나눠
    # 단면적을 구한 뒤 비중을 곱한다 - 손으로 단면적을 근사하지 않고 모델링된
    # 형상(중공 단면 등 포함)을 그대로 반영하는 게 핵심이다.
    # 단위중량(kg/m) = (체적 ÷ 길이) × 비중 × 1000 = 단면적 × 밀도
    def theoretical_unit_weight_by_cross_section
      targets = Sketchup.active_model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      if targets.empty?
        UI.messagebox(
          "단면적을 계산할 형상을 먼저 선택하세요.\n" \
          "실제 부재 전체를 선택해도 되고, 계산이 편하도록 1m 등 임의 길이로 잘라 " \
          "모델링한 샘플(같은 단면)을 선택해도 됩니다. 중공관이면 속이 빈 부분까지 " \
          "형상에 반영되어 있어야 정확합니다."
        )
        return
      end
      e = targets.first
      mode, volume_m3, = volume_or_area(e)
      if mode != 'VOLUME'
        UI.messagebox(
          '선택한 형상이 닫힌 솔리드가 아니라 체적을 계산할 수 없습니다.\n' \
          '(중공 단면이라면 바깥쪽뿐 아니라 속 빈 부분까지 실제 형상으로 모델링되어 있어야 합니다)'
        )
        return
      end

      len_result = UI.inputbox(
        ['이 형상의 길이 (m)  - 모르면 취소 후 📏 길이 재기로 먼저 측정하세요'],
        [''],
        "체적 약 #{volume_m3.round(6)} m³ - 길이 입력"
      )
      return if len_result == false
      length_m = len_result[0].to_f
      if !(length_m > 0)
        UI.messagebox('길이는 0보다 커야 합니다.')
        return
      end

      cross_section_m2 = volume_m3 / length_m

      sg_result = UI.inputbox(
        ['비중 (SG, 물=1 기준) - 예: 철=7.85'],
        [''],
        "단면적 약 #{cross_section_m2.round(6)} m² - 비중 입력"
      )
      return if sg_result == false
      sg = sg_result[0].to_f
      if !(sg > 0)
        UI.messagebox('비중은 0보다 커야 합니다.')
        return
      end

      density = sg * 1000
      unit_weight = cross_section_m2 * density

      UI.messagebox(
        "형상 기반 이론 단위중량 계산 결과\n\n" \
        "체적: #{volume_m3.round(6)} m³\n" \
        "길이: #{length_m.round(4)} m\n" \
        "→ 단면적: #{cross_section_m2.round(6)} m²  (체적 ÷ 길이)\n\n" \
        "비중: #{sg}  (밀도 #{density.round(1)} kg/m³)\n\n" \
        "→ 단위중량: #{unit_weight.round(4)} kg/m\n\n" \
        "이 값을 웹 자재 DB의 '단중' 항목(LENGTH, kg/m)에 입력하시면 됩니다.\n" \
        "이론값이니 출처는 'KS 규격표 대조 필요' 등으로 남겨두세요."
      )
    rescue StandardError => e
      UI.messagebox("계산 중 오류가 발생했습니다: #{e.message}")
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
