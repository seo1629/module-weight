# 메뉴에서 호출하는 명령들 - 선택 항목에 modular_weight 속성을 지정한다 (명세 1.4).
module ModularWeightExporter
  module Commands
    module_function

    def selected_containers
      Sketchup.active_model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
    end

    def alert_no_selection
      UI.messagebox('그룹 또는 컴포넌트를 먼저 선택하세요.')
    end

    def pick_category(allow_inherit: false)
      options = CATEGORIES.dup
      options.unshift('(상위에서 상속)') if allow_inherit
      result = UI.inputbox(['공종 선택'], [options.first], [options.join('|')], '공종 선택')
      return nil if result == false
      chosen = result[0]
      return :inherit if allow_inherit && chosen == '(상위에서 상속)'
      chosen
    end

    def pick_quantity_basis
      result = UI.inputbox(['계산 기준(quantity_basis)'], [QUANTITY_BASES.first], [QUANTITY_BASES.join('|')], '계산 기준 선택')
      return nil if result == false
      result[0]
    end

    def assign_module
      targets = selected_containers
      return alert_no_selection if targets.empty?
      targets.each do |e|
        ModularWeightExporter.set_attr(e, 'role', 'MODULE')
        if ModularWeightExporter.get_attr(e, 'module_id').nil?
          ModularWeightExporter.set_attr(e, 'module_id', ModularWeightExporter.generate_uuid)
        end
      end
      UI.messagebox("#{targets.length}개를 MODULE로 지정했습니다.")
    end

    def assign_container
      targets = selected_containers
      return alert_no_selection if targets.empty?
      cat = pick_category
      return if cat.nil?
      targets.each do |e|
        ModularWeightExporter.set_attr(e, 'role', 'CONTAINER')
        ModularWeightExporter.set_attr(e, 'category', cat)
      end
      UI.messagebox("#{targets.length}개를 CONTAINER(#{cat})로 지정했습니다.")
    end

    def assign_part
      targets = selected_containers
      return alert_no_selection if targets.empty?
      cat = pick_category(allow_inherit: true)
      return if cat.nil?
      basis = pick_quantity_basis
      return if basis.nil?
      targets.each do |e|
        ModularWeightExporter.set_attr(e, 'role', 'PART')
        ModularWeightExporter.set_attr(e, 'category', cat == :inherit ? nil : cat)
        ModularWeightExporter.set_attr(e, 'quantity_basis', basis)
      end
      UI.messagebox("#{targets.length}개를 PART(#{basis})로 지정했습니다.\nTag는 SketchUp의 Tag(레이어) 패널에서 별도로 지정하세요.")
    end

    def assign_ignore
      targets = selected_containers
      return alert_no_selection if targets.empty?
      result = UI.inputbox(['제외 사유 (필수)'], [''], 'IGNORE 지정')
      return if result == false || result[0].to_s.strip.empty?
      targets.each do |e|
        ModularWeightExporter.set_attr(e, 'role', 'IGNORE')
        ModularWeightExporter.set_attr(e, 'exclude_reason', result[0])
      end
      UI.messagebox("#{targets.length}개를 IGNORE로 지정했습니다.")
    end

    def toggle_excluded
      targets = selected_containers.select { |e| ModularWeightExporter.role_of(e) == 'PART' }
      if targets.empty?
        UI.messagebox('role=PART인 그룹/컴포넌트를 먼저 선택하세요.')
        return
      end
      targets.each do |e|
        if ModularWeightExporter.get_attr(e, 'excluded', false)
          ModularWeightExporter.set_attr(e, 'excluded', false)
          ModularWeightExporter.set_attr(e, 'exclude_reason', nil)
        else
          result = UI.inputbox(["'#{e.name}' 제외 사유 (필수)"], [''], '부재 제외')
          next if result == false || result[0].to_s.strip.empty?
          ModularWeightExporter.set_attr(e, 'excluded', true)
          ModularWeightExporter.set_attr(e, 'exclude_reason', result[0])
        end
      end
      UI.messagebox('완료했습니다.')
    end

    def assign_reference_faces
      model = Sketchup.active_model
      path = model.active_path
      if path.nil? || path.empty?
        UI.messagebox('먼저 대상 PART를 더블클릭해 편집 모드로 들어가고, 기준면을 선택한 뒤 이 명령을 실행하세요.')
        return
      end
      target = path.last
      faces = model.selection.to_a.select { |e| e.is_a?(Sketchup::Face) }
      if faces.empty?
        UI.messagebox('선택된 면이 없습니다. 편집 모드에서 기준면을 클릭해 선택하세요.')
        return
      end
      ModularWeightExporter.set_attr(target, 'quantity_basis', 'REFERENCE_FACES') if ModularWeightExporter.role_of(target).nil?
      ModularWeightExporter.set_attr(target, 'reference_face_ids', faces.map(&:persistent_id))
      UI.messagebox("#{faces.length}개 면을 기준면으로 지정했습니다: #{target.name}")
    end

    def start_axis_pick_tool
      Sketchup.active_model.select_tool(AxisPickTool.new)
    end

    def start_centroid_pick_tool
      Sketchup.active_model.select_tool(CentroidPickTool.new)
    end

    def show_attributes
      targets = selected_containers
      return alert_no_selection if targets.empty?
      e = targets.first
      dict = e.attribute_dictionary(ATTR_DICT)
      if dict.nil?
        UI.messagebox("[#{e.name}]\n지정된 modular_weight 속성이 없습니다.")
        return
      end
      lines = []
      dict.each_pair { |k, v| lines << "#{k}: #{v.inspect}" }
      lines.sort!
      lines << "tag(레이어): #{ModularWeightExporter.tag_of(e).inspect}"
      UI.messagebox("[#{e.name}]\n" + lines.join("\n"))
    end

    def reissue_model_id
      ModularWeightExporter.reissue_model_id!
      UI.messagebox('새 모델 ID를 발급했습니다. (기존 웹 프로젝트와 연결이 끊어집니다)')
    end
  end
end
