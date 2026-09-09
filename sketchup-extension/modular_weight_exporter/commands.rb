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

    # role=MODULE인 그룹은 ②/③/④/★ 대상에서 항상 보호한다 - 여러 번 실수로
    # 모듈 껍데기 자체의 role이 PART/CONTAINER/IGNORE로 덮어써지는 사고가 반복돼서 추가함.
    # 반환값: [보호되어 제외된 목록, 실제로 처리할 목록]
    def split_protected(targets)
      targets.partition { |e| ModularWeightExporter.role_of(e) == 'MODULE' }
    end

    def entity_names(list)
      list.map { |e| e.name.to_s.empty? ? '(이름없음)' : e.name }.join(', ')
    end

    def protected_warning(protected_targets)
      return '' if protected_targets.empty?
      "\n\n⚠ MODULE로 지정된 그룹 #{protected_targets.length}개는 보호되어 건너뛰었습니다 (모듈 껍데기에는 실행 안 함): #{entity_names(protected_targets)}"
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
      labels = QUANTITY_BASES.map { |b| QUANTITY_BASIS_LABELS[b] }
      result = UI.inputbox(['계산 기준 (AREA/VOLUME/LENGTH/COUNT)'], [labels.first], [labels.join('|')], '계산 기준 선택')
      return nil if result == false
      idx = labels.index(result[0])
      idx ? QUANTITY_BASES[idx] : nil
    end

    def pick_category_and_tag(allow_inherit: false)
      options = CATEGORIES.dup
      options.unshift('(상위에서 상속)') if allow_inherit
      prompts = ['공종 선택', 'Tag (선택 - 비우면 나중에 Tag 패널에서 지정)']
      defaults = [options.first, '']
      list = [options.join('|'), '']
      result = UI.inputbox(prompts, defaults, list, '부재 자동 지정')
      return nil if result == false
      cat = result[0]
      cat = :inherit if allow_inherit && cat == '(상위에서 상속)'
      tag = result[1].to_s.strip
      [cat, tag.empty? ? nil : tag]
    end

    def apply_tag(targets, tag)
      if tag !~ TAG_RE
        UI.messagebox("Tag 형식이 올바르지 않습니다: #{tag}\n(대문자로 시작하고 대문자·숫자·_·. 만 사용) Tag 지정은 건너뜁니다.")
        return
      end
      layers = Sketchup.active_model.layers
      layer = layers[tag]
      layer ||= layers.add(tag)
      targets.each { |e| e.layer = layer }
    rescue StandardError => e
      UI.messagebox("Tag 자동 적용 중 오류가 발생했습니다: #{e.message}\n대신 SketchUp Tag 패널에서 직접 지정해주세요.")
    end

    # 형상을 보고 AREA/VOLUME/LENGTH를 자동 판별해 기준면/기준축까지 한 번에 지정한다.
    # 애매한 형상만 사용자가 ③/⑤/⑥으로 수동 지정하면 된다.
    def auto_assign_parts
      all_targets = selected_containers
      return alert_no_selection if all_targets.empty?
      protected_targets, targets = split_protected(all_targets)
      if targets.empty?
        UI.messagebox("선택한 항목이 전부 이미 MODULE로 지정된 그룹입니다 (보호됨).\n모듈 껍데기가 아니라 그 안의 개별 부재를 선택해주세요.")
        return
      end
      cat, tag = pick_category_and_tag(allow_inherit: true) || return

      lines = []
      targets.each do |e|
        begin
          ModularWeightExporter.set_attr(e, 'role', 'PART')
          ModularWeightExporter.set_attr(e, 'category', cat == :inherit ? nil : cat)

          basis = AutoDetect.detect_basis(e)
          if basis.nil?
            lines << "- #{e.name}: 형상만으로 계산유형을 판별하지 못했습니다 → ③으로 직접 지정하세요."
            next
          end
          ModularWeightExporter.set_attr(e, 'quantity_basis', basis)

          case basis
          when 'REFERENCE_FACES'
            faces = AutoDetect.all_faces(e)
            if faces.empty?
              lines << "- #{e.name}: AREA로 추정했지만 면을 찾지 못했습니다 → 편집모드에서 ⑤로 지정하세요."
            else
              ModularWeightExporter.set_attr(e, 'reference_face_ids', faces.map(&:persistent_id))
              lines << "- #{e.name}: AREA (면 #{faces.length}개 자동 선택)"
            end
          when 'AXIS_ENDPOINTS'
            axis_index, p1, p2 = AutoDetect.axis_endpoints_for(e)
            ModularWeightExporter.set_attr(e, 'axis_endpoints_local', [p1, p2])
            ModularWeightExporter.set_attr(e, 'length_axis_index', axis_index)
            lines << "- #{e.name}: LENGTH (경계상자 긴 방향 자동 지정)"
          when 'SOLID'
            lines << "- #{e.name}: VOLUME (닫힌 솔리드 - 추가 지정 불필요)"
          end
        rescue StandardError => err
          lines << "- #{e.name}: 자동 지정 중 오류(#{err.message}) → ③/⑤/⑥으로 직접 지정하세요."
        end
      end

      apply_tag(targets, tag) if tag

      UI.messagebox(
        "자동 지정 결과 (#{targets.length}개):\n\n#{lines.join("\n")}\n\n" \
        "결과가 이상하면 그 부재만 ③(계산유형 다시 지정) 또는 ⑤/⑥(수동 지정)으로 고치세요.\n" \
        "Tag를 비워뒀다면 SketchUp Tag 패널에서 직접 지정하세요." \
        "#{protected_warning(protected_targets)}"
      )
    end

    # ③으로 계산유형만 바꾼 뒤 기준면/기준축이 비어있는 경우를 위한 명령.
    # ★와 달리 형상을 보고 유형을 다시 판별하지 않고, 지금 지정된 quantity_basis를
    # 그대로 둔 채 경계상자 기반으로 기준면(전체 면)/기준축(긴 방향)만 채운다.
    def fill_basis_geometry
      targets = selected_containers.select { |e| ModularWeightExporter.role_of(e) == 'PART' }
      if targets.empty?
        UI.messagebox('role=PART로 지정된 그룹/컴포넌트를 먼저 선택하세요.')
        return
      end

      lines = []
      targets.each do |e|
        begin
          basis = ModularWeightExporter.quantity_basis_of(e)
          case basis
          when 'REFERENCE_FACES'
            faces = AutoDetect.all_faces(e)
            if faces.empty?
              lines << "- #{e.name}: 면을 찾지 못했습니다 → ⑤로 직접 지정하세요."
            else
              ModularWeightExporter.set_attr(e, 'reference_face_ids', faces.map(&:persistent_id))
              lines << "- #{e.name}: 기준면 #{faces.length}개 자동 채움"
            end
          when 'AXIS_ENDPOINTS'
            axis_index, p1, p2 = AutoDetect.axis_endpoints_for(e)
            ModularWeightExporter.set_attr(e, 'axis_endpoints_local', [p1, p2])
            ModularWeightExporter.set_attr(e, 'length_axis_index', axis_index)
            lines << "- #{e.name}: 기준축 자동 채움 (경계상자 긴 방향)"
          when 'SOLID', 'INSTANCE'
            lines << "- #{e.name}: 이 계산유형은 추가로 채울 게 없습니다."
          else
            lines << "- #{e.name}: quantity_basis가 없습니다 → ③을 먼저 실행하세요."
          end
        rescue StandardError => err
          lines << "- #{e.name}: 오류(#{err.message})"
        end
      end

      UI.messagebox("기준면/기준축 자동 채우기 결과 (#{targets.length}개):\n\n#{lines.join("\n")}")
    end

    # 선택 상태와 무관하게 모델 전체를 뒤져서 AREA/LENGTH 부재의 기준면/기준축을
    # 전부 현재 형상 기준으로 다시 채운다. Tag로 하나하나 선택해서 채우다가 빠뜨리는
    # 부재가 계속 생겨서, 놓치는 게 없도록 만든 전체 일괄 버전이다.
    def refresh_all_basis_geometry
      targets = []
      Builder.each_part_entity(Sketchup.active_model.entities) { |e| targets << e }
      targets.select! { |e| %w[REFERENCE_FACES AXIS_ENDPOINTS].include?(ModularWeightExporter.quantity_basis_of(e)) }
      if targets.empty?
        UI.messagebox('AREA(면적) 또는 LENGTH(길이)로 지정된 부재를 모델에서 찾지 못했습니다.')
        return
      end
      result = UI.messagebox(
        "모델 전체에서 AREA/LENGTH로 지정된 부재 #{targets.length}개의 기준면/기준축을 " \
        "전부 현재 형상 기준으로 다시 채웁니다 (선택 상태와 무관하게 모델 전체를 검사합니다).\n계속하시겠습니까?",
        MB_YESNO
      )
      return if result == IDNO

      fixed = 0
      skipped = []
      targets.each do |e|
        begin
          basis = ModularWeightExporter.quantity_basis_of(e)
          label = e.name.to_s.empty? ? '(이름없음)' : e.name
          if basis == 'REFERENCE_FACES'
            faces = AutoDetect.all_faces(e)
            if faces.empty?
              skipped << label
            else
              ModularWeightExporter.set_attr(e, 'reference_face_ids', faces.map(&:persistent_id))
              fixed += 1
            end
          elsif basis == 'AXIS_ENDPOINTS'
            axis_index, p1, p2 = AutoDetect.axis_endpoints_for(e)
            ModularWeightExporter.set_attr(e, 'axis_endpoints_local', [p1, p2])
            ModularWeightExporter.set_attr(e, 'length_axis_index', axis_index)
            fixed += 1
          end
        rescue StandardError
          skipped << label
        end
      end

      msg = "#{fixed}개 부재의 기준면/기준축을 새로고침했습니다."
      msg += "\n\n면/형상을 찾지 못해 건너뛴 부재 #{skipped.length}개: #{skipped.join(', ')}" unless skipped.empty?
      UI.messagebox(msg)
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
      all_targets = selected_containers
      return alert_no_selection if all_targets.empty?
      protected_targets, targets = split_protected(all_targets)
      if targets.empty?
        UI.messagebox("선택한 항목이 전부 이미 MODULE로 지정된 그룹입니다 (보호됨).\n모듈 껍데기가 아니라 그 안의 그룹을 선택해주세요.")
        return
      end
      cat = pick_category
      return if cat.nil?
      targets.each do |e|
        ModularWeightExporter.set_attr(e, 'role', 'CONTAINER')
        ModularWeightExporter.set_attr(e, 'category', cat)
      end
      UI.messagebox("#{targets.length}개를 CONTAINER(#{cat})로 지정했습니다.#{protected_warning(protected_targets)}")
    end

    def assign_part
      all_targets = selected_containers
      return alert_no_selection if all_targets.empty?
      protected_targets, targets = split_protected(all_targets)
      if targets.empty?
        UI.messagebox("선택한 항목이 전부 이미 MODULE로 지정된 그룹입니다 (보호됨).\n모듈 껍데기가 아니라 그 안의 개별 부재를 선택해주세요.")
        return
      end
      cat = pick_category(allow_inherit: true)
      return if cat.nil?
      basis = pick_quantity_basis
      return if basis.nil?
      targets.each do |e|
        ModularWeightExporter.set_attr(e, 'role', 'PART')
        ModularWeightExporter.set_attr(e, 'category', cat == :inherit ? nil : cat)
        ModularWeightExporter.set_attr(e, 'quantity_basis', basis)
      end
      UI.messagebox("#{targets.length}개를 PART(#{basis})로 지정했습니다.\nTag는 SketchUp의 Tag(레이어) 패널에서 별도로 지정하세요.#{protected_warning(protected_targets)}")
    end

    # IGNORE는 "실수로 덮어씀"이 아니라 "의도적으로 계산에서 뺌"이라는 뜻이므로,
    # 다른 명령과 달리 MODULE 그룹에도 적용할 수 있게 허용한다 (모듈 전체를 통째로
    # 제외하고 싶을 때 - 예: 참고용/구버전 프레임이 같은 파일에 남아있는 경우).
    def assign_ignore
      targets = selected_containers
      return alert_no_selection if targets.empty?
      was_module = targets.select { |e| ModularWeightExporter.role_of(e) == 'MODULE' }
      result = UI.inputbox(['제외 사유 (필수)'], [''], 'IGNORE 지정')
      return if result == false || result[0].to_s.strip.empty?
      targets.each do |e|
        ModularWeightExporter.set_attr(e, 'role', 'IGNORE')
        ModularWeightExporter.set_attr(e, 'exclude_reason', result[0])
      end
      msg = "#{targets.length}개를 IGNORE로 지정했습니다."
      msg += "\n\n(이전에 MODULE로 지정되어 있던 #{was_module.length}개 포함: #{entity_names(was_module)})" unless was_module.empty?
      UI.messagebox(msg)
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

    # 선택된 그룹(들)이 지금 어떤 Tag(자재)로 연결되고, 무게를 어떤 기준(AREA/VOLUME/
    # LENGTH/COUNT)으로 계산하는지, 그 기준으로 지금 형상에서 실제로 얼마가 나오는지까지
    # 한 번에 보여준다. entity.transformation만 사용한 미리보기라 모듈/컨테이너의 배치
    # 회전·이동은 반영되지만, 정확한 최종 값은 JSON 내보내기 시 전체 경로로 다시 계산된다.
    def describe_selection
      targets = selected_containers
      return alert_no_selection if targets.empty?

      blocks = targets.first(12).map { |e| describe_one_entity(e) }
      msg = blocks.join("\n\n" + ('-' * 40) + "\n\n")
      msg += "\n\n... 외 #{targets.length - 12}개 더 (한 번에 최대 12개만 표시)" if targets.length > 12
      UI.messagebox(msg)
    end

    def describe_one_entity(e)
      role = ModularWeightExporter.role_of(e)
      name = e.name.to_s.empty? ? '(이름없음)' : e.name
      tag = ModularWeightExporter.tag_of(e)
      header = "[#{name}]  Tag(자재): #{tag || '(없음)'}"

      case role
      when nil
        "#{header}\n역할: 미지정 (①/★/③으로 지정 필요)"
      when 'MODULE'
        "#{header}\n역할: MODULE (모듈 껍데기 - 자체 무게 없음, 안의 부재들을 집계)"
      when 'CONTAINER'
        cat = ModularWeightExporter.category_of(e)
        "#{header}\n역할: CONTAINER (집계용 - 자체 무게 없음) · 공종: #{cat || '(미지정)'}"
      when 'IGNORE'
        reason = ModularWeightExporter.get_attr(e, 'exclude_reason')
        "#{header}\n역할: IGNORE (계산에서 완전히 제외됨)\n사유: #{reason || '(없음)'}"
      when 'PART'
        cat = ModularWeightExporter.category_of(e)
        excluded = ModularWeightExporter.get_attr(e, 'excluded', false)
        lines = [header, "역할: PART · 공종: #{cat || '(상위에서 상속 또는 미지정)'}"]
        lines << "⚠ 이 부재는 현재 '제외' 상태입니다 (계산에 포함 안 됨)" if excluded
        lines << describe_basis(e)
        lines.join("\n")
      else
        "#{header}\n역할: 알 수 없음(#{role})"
      end
    rescue StandardError => err
      "[#{e.name}]\n미리보기 중 오류: #{err.message}"
    end

    # PART의 quantity_basis에 맞춰 "무게를 구하는 기준"을 사람이 읽을 말로 설명하고,
    # 현재 형상으로 실제 계산해본 예상 물량까지 같이 보여준다.
    def describe_basis(e)
      basis = ModularWeightExporter.quantity_basis_of(e)
      transform = e.transformation
      children = Builder.children_entities(e)

      case basis
      when 'REFERENCE_FACES'
        ids = ModularWeightExporter.get_attr(e, 'reference_face_ids', [])
        ids = [] if ids.nil?
        return "계산 기준: AREA(면적) - 기준면이 아직 지정되지 않았습니다 (⑤ 또는 ★로 지정 필요)" if ids.empty?
        found = Geometry.find_faces_by_ids(children, ids, transform, [])
        return "계산 기준: AREA(면적) - 지정된 기준면 #{ids.length}개를 찾을 수 없습니다 (형상이 바뀌었을 수 있음)" if found.empty?
        area_m2, = Geometry.compute_area(found)
        "계산 기준: AREA(면적)\n" \
        "  → 기준면 #{found.length}개(지정 #{ids.length}개)의 면적을 더해서 계산\n" \
        "  → 지금 형상 기준 예상 면적: 약 #{area_m2.round(4)} m²\n" \
        "  → 무게 = 이 면적 × 웹 자재 DB에서 이 Tag에 매핑한 kg/m² 단중"
      when 'SOLID'
        faces = Geometry.collect_all_faces(children, transform, [])
        return "계산 기준: VOLUME(체적) - 계산할 형상이 없습니다" if faces.empty?
        volume_m3, = Geometry.compute_volume(faces)
        "계산 기준: VOLUME(체적)\n" \
        "  → 닫힌 솔리드 전체의 체적을 적분해서 계산\n" \
        "  → 지금 형상 기준 예상 체적: 약 #{volume_m3.round(6)} m³\n" \
        "  → 무게 = 이 체적 × 웹 자재 DB에서 이 Tag에 매핑한 kg/m³ 밀도(비중)"
      when 'AXIS_ENDPOINTS'
        pts = ModularWeightExporter.get_attr(e, 'axis_endpoints_local')
        return "계산 기준: LENGTH(길이) - 기준축이 아직 지정되지 않았습니다 (⑥ 또는 ★로 지정 필요)" if pts.nil? || pts.length != 2
        p1 = Geom::Point3d.new(pts[0][0], pts[0][1], pts[0][2])
        p2 = Geom::Point3d.new(pts[1][0], pts[1][1], pts[1][2])
        length_m, = Geometry.compute_length(p1, p2, transform)
        "계산 기준: LENGTH(길이)\n" \
        "  → 지정된 기준축 두 점 사이의 거리로 계산\n" \
        "  → 지금 형상 기준 예상 길이: 약 #{length_m.round(4)} m\n" \
        "  → 무게 = 이 길이 × 웹 자재 DB에서 이 Tag에 매핑한 kg/m 단중"
      when 'INSTANCE'
        override = ModularWeightExporter.get_attr(e, 'centroid_override_local')
        cg_note = override && override.length == 3 ? '사용자 지정 중심점 있음' : '중심점 미지정 (경계상자 중심으로 추정됨)'
        "계산 기준: COUNT(개수)\n" \
        "  → 이 부재 1개당 1EA로 계산 (물량은 항상 1)\n" \
        "  → 무게중심: #{cg_note}\n" \
        "  → 무게 = 1 × 웹 자재 DB에서 이 Tag에 매핑한 kg/EA 단중"
      when nil, ''
        "계산 기준: 지정되지 않음 (③ 또는 ★로 지정 필요)"
      else
        "계산 기준: 알 수 없는 값(#{basis})"
      end
    end

    def reissue_model_id
      ModularWeightExporter.reissue_model_id!
      UI.messagebox('새 모델 ID를 발급했습니다. (기존 웹 프로젝트와 연결이 끊어집니다)')
    end
  end
end
