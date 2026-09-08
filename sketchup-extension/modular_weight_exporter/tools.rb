# 점 클릭으로 기준축(LENGTH)/무게중심 보정점을 지정하는 도구.
# 반드시 대상 PART를 더블클릭해 편집 모드(active_path)로 들어간 뒤 실행해야 한다 -
# 그래야 InputPoint#position이 PART 로컬 좌표로 직접 나온다 (명세의 axis_endpoints_local 계약).
module ModularWeightExporter
  class AxisPickTool
    def activate
      @ip = Sketchup::InputPoint.new
      @points = []
      model = Sketchup.active_model
      if model.active_path.nil? || model.active_path.empty?
        UI.messagebox('먼저 대상 PART를 더블클릭해 편집 모드로 들어간 뒤 이 명령을 실행하세요.')
        # activate 콜백 안에서 바로 select_tool(nil)을 부르면 SketchUp 툴 상태머신과
        # 재진입 충돌이 날 수 있어 타이머로 한 틱 늦춘다.
        UI.start_timer(0, false) { model.select_tool(nil) }
      end
    end

    def onMouseMove(_flags, x, y, view)
      @ip.pick(view, x, y)
      view.invalidate
    end

    def draw(view)
      @ip.draw(view) if @ip && @ip.valid?
      return if @points.empty?
      view.draw_points([@points[0]], 12, 1, 'red')
    end

    def onLButtonDown(_flags, x, y, view)
      @ip.pick(view, x, y)
      @points << @ip.position
      finish(view) if @points.length == 2
    end

    def onCancel(_reason, _view)
      Sketchup.active_model.select_tool(nil)
    end

    def finish(_view)
      model = Sketchup.active_model
      path = model.active_path
      if path.nil? || path.empty?
        UI.messagebox('PART 편집 모드가 아닙니다. 처음부터 다시 실행하세요.')
        model.select_tool(nil)
        return
      end
      target = path.last
      p1, p2 = @points
      ModularWeightExporter.set_attr(target, 'quantity_basis', 'AXIS_ENDPOINTS') if ModularWeightExporter.role_of(target).nil?
      ModularWeightExporter.set_attr(target, 'axis_endpoints_local', [[p1.x, p1.y, p1.z], [p2.x, p2.y, p2.z]])
      UI.messagebox("기준축을 지정했습니다: #{target.name}")
      model.select_tool(nil)
    end
  end

  class CentroidPickTool
    def activate
      @ip = Sketchup::InputPoint.new
      model = Sketchup.active_model
      if model.active_path.nil? || model.active_path.empty?
        UI.messagebox('먼저 대상 PART를 더블클릭해 편집 모드로 들어간 뒤 이 명령을 실행하세요.')
        UI.start_timer(0, false) { model.select_tool(nil) }
      end
    end

    def onMouseMove(_flags, x, y, view)
      @ip.pick(view, x, y)
      view.invalidate
    end

    def draw(view)
      @ip.draw(view) if @ip && @ip.valid?
    end

    def onLButtonDown(_flags, x, y, view)
      @ip.pick(view, x, y)
      pt = @ip.position
      model = Sketchup.active_model
      path = model.active_path
      if path.nil? || path.empty?
        UI.messagebox('PART 편집 모드가 아닙니다.')
        model.select_tool(nil)
        return
      end
      target = path.last
      result = UI.inputbox(['근거/출처 (필수 - 예: 제조사 카탈로그 CG값)'], [''], '무게중심 보정 근거')
      if result == false || result[0].to_s.strip.empty?
        UI.messagebox('근거를 입력해야 저장됩니다. 취소되었습니다.')
        model.select_tool(nil)
        return
      end
      ModularWeightExporter.set_attr(target, 'centroid_override_local', [pt.x, pt.y, pt.z])
      ModularWeightExporter.set_attr(target, 'centroid_note', result[0])
      UI.messagebox("무게중심 보정점을 지정했습니다: #{target.name}")
      model.select_tool(nil)
    end

    def onCancel(_reason, _view)
      Sketchup.active_model.select_tool(nil)
    end
  end
end
