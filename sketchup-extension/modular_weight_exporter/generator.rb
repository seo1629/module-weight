# 스틸 스터드 생성·배치 도구.
#
# 사용 순서:
# 1. CAD(dwg/dxf 등)에서 만든 스터드 단면을 SketchUp File > Import로 가져와
#    바닥(XY 평면, Z=0 부근)에 눕혀서 배치한다. 위쪽(+Z)으로 압출된다고 가정한다.
# 2. 그 단면 그룹/컴포넌트를 선택하고 "스틸 스터드 배치" 실행.
# 3. 높이 -> 간격 -> 공종 -> Tag를 순서대로 입력.
# 4. 3D 화면에서 배치선의 시작점 -> 끝점을 클릭.
#
# 알려진 한계(v1):
# - 벽 방향에 맞춰 단면을 자동으로 회전하지 않는다 (무게 계산에는 영향 없음, 방향만 관련).
# - 배치선이 완전히 수평(같은 높이)이라고 가정하고, 시작점의 Z를 기준 바닥으로 쓴다.
module ModularWeightExporter
  module Generator
    module_function

    def start_stud_tool
      targets = Sketchup.active_model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      if targets.empty?
        UI.messagebox(
          "먼저 스터드 단면(2D 형상)을 선택하세요.\n\n" \
          "CAD에서 만든 단면을 File > Import로 가져와 바닥(XY 평면, Z=0 부근)에 눕혀 배치한 뒤 " \
          "선택하면 됩니다. 그 형상을 위쪽(+Z)으로 압출해서 스터드를 만듭니다."
        )
        return
      end
      template = targets.first
      template_def = template.respond_to?(:definition) ? template.definition : nil
      if template_def.nil?
        UI.messagebox('선택한 항목에서 형상 정의를 찾을 수 없습니다. 그룹 또는 컴포넌트를 선택하세요.')
        return
      end

      height_result = UI.inputbox(['층고 / 스터드 높이 (mm)'], ['2400'], '스틸 스터드 배치 - ① 높이')
      return if height_result == false
      height_mm = height_result[0].to_f
      if !(height_mm > 0)
        UI.messagebox('높이는 0보다 커야 합니다.')
        return
      end

      spacing_result = UI.inputbox(['스터드 간격 (mm)'], ['450'], '스틸 스터드 배치 - ② 간격')
      return if spacing_result == false
      spacing_mm = spacing_result[0].to_f
      if !(spacing_mm > 0)
        UI.messagebox('간격은 0보다 커야 합니다.')
        return
      end

      cat_result = UI.inputbox(['공종 선택'], [CATEGORIES.first], [CATEGORIES.join('|')], '스틸 스터드 배치 - ③ 공종')
      return if cat_result == false
      category = cat_result[0]

      tag_result = UI.inputbox(['Tag (선택 - 비우면 나중에 SketchUp Tag 패널에서 지정)'], [''], '스틸 스터드 배치 - ④ Tag')
      return if tag_result == false
      tag = tag_result[0].to_s.strip
      tag = nil if tag.empty?

      UI.messagebox('이제 3D 화면에서 배치할 선의 시작점을 클릭한 뒤, 끝점을 클릭하세요.')
      Sketchup.active_model.select_tool(
        StudPlacementTool.new(template_def, height_mm, spacing_mm, category, tag)
      )
    end

    # 2D 단면 정의(template_def)를 한 번만 실제로 압출해서, 여러 번 배치(인스턴스)할
    # 재사용 가능한 "3D 스터드 솔리드" 정의를 만든다. height_mm은 밀리미터 단위.
    def build_solid_definition(template_def, height_mm)
      model = Sketchup.active_model
      height_in = height_mm / 25.4
      solid_def = model.definitions.add("STUD_SOLID_#{Time.now.to_i}_#{rand(1000)}")
      inst = solid_def.entities.add_instance(template_def, Geom::Transformation.new)
      inst.explode
      faces = solid_def.entities.grep(Sketchup::Face)
      raise '선택한 형상에서 닫힌 2D 면을 찾지 못했습니다 (단면이 닫힌 폴리곤이어야 합니다).' if faces.empty?
      faces.each do |f|
        begin
          f.pushpull(height_in)
        rescue StandardError
          # 다른 면 압출로 이미 병합·삭제된 경우는 건너뛴다.
        end
      end
      [solid_def, height_in]
    end

    # p1 -> p2 (world 좌표, 두 점 클릭으로 얻음) 선을 따라 spacing_mm 간격으로
    # 스터드를 배치한다. 양 끝점에는 반드시 스터드가 오도록 마지막 위치를 보정한다.
    def place_studs(p1, p2, template_def, height_mm, spacing_mm, category, tag)
      model = Sketchup.active_model
      model.start_operation('스틸 스터드 배치', true)

      solid_def, height_in = build_solid_definition(template_def, height_mm)

      dx = p2.x - p1.x
      dy = p2.y - p1.y
      length_in = Math.sqrt(dx * dx + dy * dy)
      if length_in <= 1e-6
        model.abort_operation
        UI.messagebox('두 점의 위치가 같습니다. 처음부터 다시 실행하세요.')
        return
      end

      spacing_in = spacing_mm / 25.4
      positions_in = []
      d = 0.0
      while d < length_in
        positions_in << d
        d += spacing_in
      end
      positions_in << length_in if positions_in.empty? || (positions_in.last - length_in).abs > 1e-6

      base_z = p1.z
      axis_endpoints_local = [[0.0, 0.0, 0.0], [0.0, 0.0, height_in]]
      entities = model.active_entities
      count = 0

      positions_in.each do |d|
        t = d / length_in
        x = p1.x + dx * t
        y = p1.y + dy * t
        transform = Geom::Transformation.new([x, y, base_z])
        inst = entities.add_instance(solid_def, transform)
        ModularWeightExporter.set_attr(inst, 'role', 'PART')
        ModularWeightExporter.set_attr(inst, 'category', category)
        ModularWeightExporter.set_attr(inst, 'quantity_basis', 'AXIS_ENDPOINTS')
        ModularWeightExporter.set_attr(inst, 'axis_endpoints_local', axis_endpoints_local)
        ModularWeightExporter.set_attr(inst, 'length_axis_index', 2) # 로컬 Z축이 길이 방향
        if tag
          layers = model.layers
          layer = layers[tag] || layers.add(tag)
          inst.layer = layer
        end
        count += 1
      end

      model.commit_operation
      length_m = Geometry.to_m(length_in)
      height_m = Geometry.to_m(height_in)
      UI.messagebox(
        "스터드 #{count}개를 배치했습니다.\n\n" \
        "배치선 길이: #{length_m.round(3)} m\n" \
        "간격: #{spacing_mm.round(1)} mm\n" \
        "높이: #{height_m.round(3)} m\n" \
        "공종: #{category}\n" \
        "#{tag ? "Tag: #{tag}" : 'Tag는 아직 없음 - SketchUp Tag 패널에서 직접 지정하세요'}\n\n" \
        "role=PART, 계산유형=LENGTH로 이미 지정되어 있어 바로 ⑩ 검증 대상이 됩니다."
      )
    rescue StandardError => e
      model.abort_operation
      UI.messagebox("스터드 배치 중 오류가 발생했습니다: #{e.message}")
    end
  end

  # 두 점을 클릭해 스터드 배치선을 지정하는 도구. 두 번째 클릭 즉시 Generator.place_studs를 호출한다.
  class StudPlacementTool
    def initialize(template_def, height_mm, spacing_mm, category, tag)
      @template_def = template_def
      @height_mm = height_mm
      @spacing_mm = spacing_mm
      @category = category
      @tag = tag
      @points = []
    end

    def activate
      @ip = Sketchup::InputPoint.new
    end

    def onMouseMove(_flags, x, y, view)
      @ip.pick(view, x, y)
      view.invalidate
    end

    def draw(view)
      @ip.draw(view) if @ip && @ip.valid?
      return if @points.empty?
      view.draw_points([@points[0]], 12, 1, 'red')
      if @ip && @ip.valid?
        view.set_color_from_line(@points[0], @ip.position)
        view.draw_line(@points[0], @ip.position)
      end
    end

    def onLButtonDown(_flags, x, y, view)
      @ip.pick(view, x, y)
      @points << @ip.position
      finish if @points.length == 2
    end

    def onCancel(_reason, _view)
      Sketchup.active_model.select_tool(nil)
    end

    def finish
      Sketchup.active_model.select_tool(nil)
      Generator.place_studs(@points[0], @points[1], @template_def, @height_mm, @spacing_mm, @category, @tag)
    end
  end
end
