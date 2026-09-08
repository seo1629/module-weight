# 모델 트리를 순회하며 modules[]/elements[]/diagnostics[]를 만든다 (명세 1.2, 6.2).
#
# 알려진 단순화(v0.1):
# - MODULE은 model.entities 최상위에 직접 있는 Group/ComponentInstance여야 한다.
# - PART 내부 형상은 PART 자신의 entities(중첩 그룹 포함)에서 재귀로 모으지만,
#   PART 안에 role이 지정된 그룹(다른 PART/CONTAINER/MODULE)이 있으면 NESTED_PART로 처리하고
#   그 안쪽은 물량 계산에 포함하지 않는다.
# - LENGTH는 로컬 X축이 길이 방향이라는 관례를 가정한다 (명세 1.3).
module ModularWeightExporter
  module Builder
    module_function

    def build_export_data
      diagnostics = []
      modules_json = []
      elements_json = []

      module_entities = scan_top_level(Sketchup.active_model.entities, diagnostics)

      module_entities.each do |mod_entity|
        mod_json = module_json_for(mod_entity, diagnostics)
        modules_json << mod_json
        children_entities(mod_entity).each do |child|
          walk(child, mod_json['id'], mod_entity.transformation, [mod_entity], nil, false, diagnostics, elements_json)
        end
      end

      ids = modules_json.map { |m| m['id'] }
      ids.uniq.each do |id|
        next unless ids.count(id) > 1
        diagnostics << diag('DUPLICATE_ID', nil, id, "모듈 id 중복: #{id}")
      end

      { modules: modules_json, elements: elements_json, diagnostics: diagnostics }
    end

    def children_entities(entity)
      entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
    end

    def container_like?(e)
      e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    end

    def diag(code, element_id, module_id, message)
      { 'code' => code, 'severity' => WARNING_CODES.include?(code) ? 'WARNING' : 'ERROR',
        'element_id' => element_id, 'module_id' => module_id, 'message' => message }
    end

    # 최상위에서 MODULE들을 찾는다. 모듈 밖에 PART/CONTAINER가 있으면 OUTSIDE_MODULE 오류.
    def scan_top_level(entities, diagnostics)
      mods = []
      entities.each do |e|
        next unless container_like?(e)
        role = ModularWeightExporter.role_of(e)
        case role
        when 'MODULE'
          mods << e
        when 'PART', 'CONTAINER'
          diagnostics << diag('OUTSIDE_MODULE', nil, nil, "모듈 밖에 role=#{role} 그룹이 있습니다: #{e.name}")
        end
      end
      mods
    end

    def module_json_for(entity, diagnostics)
      t = entity.transformation
      origin = Geometry.point_to_arr_m(t.origin)
      m = t.to_a
      xaxis = Geometry.normalize([m[0], m[1], m[2]])
      yaxis = Geometry.normalize([m[4], m[5], m[6]])
      zaxis = Geometry.normalize([m[8], m[9], m[10]])

      mod_id = ModularWeightExporter.get_attr(entity, 'module_id')
      if mod_id.nil? || mod_id.to_s.empty?
        mod_id = ModularWeightExporter.generate_uuid
        ModularWeightExporter.set_attr(entity, 'module_id', mod_id)
      end

      unless Geometry.rigid_transform?(t)
        diagnostics << diag('INVALID_SECTION_SCALE', nil, mod_id,
                             "모듈(#{entity.name})은 이동/회전만 허용됩니다. 스케일 또는 전단이 감지되었습니다.")
      end

      bb = entity.bounds
      min = [Geometry.to_m(bb.min.x), Geometry.to_m(bb.min.y), Geometry.to_m(bb.min.z)]
      max = [Geometry.to_m(bb.max.x), Geometry.to_m(bb.max.y), Geometry.to_m(bb.max.z)]

      name = entity.name.to_s
      name = 'MODULE' if name.empty?

      {
        'id' => mod_id,
        'name' => name,
        'origin_world_m' => origin,
        'axes_world' => { 'x' => xaxis, 'y' => yaxis, 'z' => zaxis },
        'bounds_world_m' => { 'min' => min, 'max' => max },
      }
    end

    # role 트리를 재귀로 내려가며 CONTAINER는 통과, PART는 element로 만든다.
    def walk(entity, module_id, parent_transform, ancestor_path, inherited_category, inside_part, diagnostics, elements_json)
      return unless container_like?(entity)

      role = ModularWeightExporter.role_of(entity)
      total_transform = parent_transform * entity.transformation
      path = ancestor_path + [entity]

      case role
      when 'MODULE'
        diagnostics << diag('INVALID_MODULE_REF', nil, module_id, "모듈 내부에 중첩된 MODULE이 있습니다: #{entity.name}")
      when 'IGNORE'
        # 하위는 계산 대상에서 완전히 제외한다.
      when 'CONTAINER'
        if inside_part
          diagnostics << diag('NESTED_PART', nil, module_id, "PART 내부에 CONTAINER가 중첩되어 있습니다: #{entity.name}")
          return
        end
        cat = ModularWeightExporter.category_of(entity)
        if cat.nil? || cat.to_s.empty?
          diagnostics << diag('UNCLASSIFIED', nil, module_id, "공종 미분류 컨테이너: #{entity.name}")
        else
          inherited_category = cat
        end
        children_entities(entity).each do |child|
          walk(child, module_id, total_transform, path, inherited_category, inside_part, diagnostics, elements_json)
        end
      when 'PART'
        if inside_part
          diagnostics << diag('NESTED_PART', nil, module_id, "PART 내부에 다른 PART가 중첩되어 있습니다: #{entity.name}")
          return
        end
        build_element(entity, module_id, parent_transform, total_transform, path, inherited_category, diagnostics, elements_json)
      else
        # role 미지정 그룹: 단순 정리용 그룹으로 보고 계속 하위를 탐색한다.
        children_entities(entity).each do |child|
          walk(child, module_id, total_transform, path, inherited_category, inside_part, diagnostics, elements_json)
        end
      end
    end

    # PART 내부에 role이 지정된 그룹(다른 PART 등)이 숨어있는지 점검한다.
    def scan_nested_roles(entities, module_id, element_id, diagnostics)
      entities.each do |e|
        next unless container_like?(e)
        r = ModularWeightExporter.role_of(e)
        if r && r != 'IGNORE'
          diagnostics << diag('NESTED_PART', element_id, module_id, "PART 내부에 role=#{r} 그룹이 중첩되어 있습니다: #{e.name}")
        end
        scan_nested_roles(children_entities(e), module_id, element_id, diagnostics)
      end
    end

    def native_volume_m3(entity)
      return nil unless entity.respond_to?(:volume)
      v = entity.volume
      return nil if v.nil? || v <= 0
      Geometry.to_m3(v)
    rescue StandardError
      nil
    end

    def build_element(entity, module_id, parent_transform, total_transform, path, inherited_category, diagnostics, elements_json)
      own_category = ModularWeightExporter.category_of(entity)
      category = own_category
      if category.nil? || category.to_s.empty?
        category = inherited_category
        if category.nil? || category.to_s.empty?
          diagnostics << diag('UNCLASSIFIED', nil, module_id, "공종 미분류 부재: #{entity.name} (OTHER로 집계)")
          category = 'OTHER'
        end
      end

      instance_path = path.map { |e| e.persistent_id.to_s }.join('.')
      element_id = "#{ModularWeightExporter.model_id}:#{instance_path}"

      scan_nested_roles(children_entities(entity), module_id, element_id, diagnostics)

      tag = ModularWeightExporter.tag_of(entity)
      # 진단 메시지에 사람이 알아볼 수 있는 이름/Tag를 붙인다 (element_id만으론 SketchUp에서 못 찾음).
      display_name = entity.name.to_s.empty? ? '(이름없음)' : entity.name
      label = tag ? "#{display_name} [Tag:#{tag}]" : display_name

      if tag.nil?
        diagnostics << diag('MISSING_TAG', element_id, module_id, "#{label}: 자재 Tag가 지정되지 않았습니다.")
      elsif tag !~ TAG_RE
        diagnostics << diag('UNCLASSIFIED', element_id, module_id, "#{label}: Tag 형식이 규칙(^[A-Z][A-Z0-9_.]*$)과 다릅니다.")
      end

      excluded = ModularWeightExporter.get_attr(entity, 'excluded', false) ? true : false
      exclude_reason = ModularWeightExporter.get_attr(entity, 'exclude_reason')
      if excluded && (exclude_reason.nil? || exclude_reason.to_s.empty?)
        diagnostics << diag('UNCLASSIFIED', element_id, module_id, "#{label}: 제외 부재에 사유가 없습니다.")
      end

      basis = ModularWeightExporter.quantity_basis_of(entity)
      metrics = { 'area_m2' => nil, 'volume_m3' => nil, 'length_m' => nil, 'count' => nil }

      if basis.nil? || basis.to_s.empty?
        diagnostics << diag('BASIS_MISMATCH', element_id, module_id, "#{label}: quantity_basis가 지정되지 않았습니다. \"부재로 지정\" 명령으로 다시 지정하세요.")
      elsif !QUANTITY_BASES.include?(basis)
        diagnostics << diag('BASIS_MISMATCH', element_id, module_id, "#{label}: 알 수 없는 quantity_basis: #{basis}")
      else
        fill_metric!(metrics, basis, entity, element_id, module_id, parent_transform, total_transform, diagnostics, label)
      end

      min, max = Geometry.world_bounds_m(entity, parent_transform)
      name = entity.name.to_s
      name = 'PART' if name.empty?

      elements_json << {
        'id' => element_id,
        'instance_path' => instance_path,
        'name' => name,
        'module_id' => module_id,
        'category' => category,
        'tag' => tag,
        'quantity_basis' => basis,
        'included' => !excluded,
        'exclude_reason' => excluded ? exclude_reason : nil,
        'visibility' => {
          'tag_visible' => entity.layer.nil? ? true : entity.layer.visible?,
          'hidden' => entity.hidden?,
        },
        'metrics' => metrics,
        'bounds_world_m' => { 'min' => min, 'max' => max },
      }
    end

    def fill_metric!(metrics, basis, entity, element_id, module_id, parent_transform, total_transform, diagnostics, label = nil)
      label ||= entity.name.to_s.empty? ? '(이름없음)' : entity.name
      case basis
      when 'REFERENCE_FACES'
        ids = ModularWeightExporter.get_attr(entity, 'reference_face_ids', [])
        ids = [] if ids.nil?
        if ids.empty?
          diagnostics << diag('INVALID_REFERENCE', element_id, module_id, "#{label}: 기준면이 지정되지 않았습니다. \"기준면 지정\" 명령을 먼저 실행하세요.")
          return
        end
        found = Geometry.find_faces_by_ids(children_entities(entity), ids, total_transform, [])
        if found.empty?
          diagnostics << diag('INVALID_REFERENCE', element_id, module_id, "#{label}: 지정된 기준면을 찾을 수 없습니다(편집 후 삭제되었을 수 있음). 다시 지정하세요.")
          return
        end
        if found.length < ids.length
          diagnostics << diag('INVALID_REFERENCE', element_id, module_id, "#{label}: 지정된 기준면 #{ids.length}개 중 #{found.length}개만 찾았습니다.")
        end
        area_m2, centroid = Geometry.compute_area(found)
        if area_m2.nil? || area_m2 <= 0
          diagnostics << diag('DEGENERATE_GEOMETRY', element_id, module_id, "#{label}: 기준면 면적이 0에 가깝습니다.")
          return
        end
        metrics['area_m2'] = {
          'value' => area_m2, 'centroid_world_m' => centroid,
          'quantity_method' => 'TRANSFORMED_REFERENCE_FACES', 'centroid_method' => 'AREA_WEIGHTED',
          'quality' => 'CALCULATED',
          'assumptions' => ['균일 면밀도 가정', '기준면을 질량 중심면으로 근사(두께 중심 보정 없음)'],
        }
      when 'SOLID'
        faces = Geometry.collect_all_faces(children_entities(entity), total_transform, [])
        if faces.empty?
          diagnostics << diag('MISSING_METRIC', element_id, module_id, "#{label}: 체적을 계산할 형상이 없습니다.")
          return
        end
        volume_m3, centroid = Geometry.compute_volume(faces)
        if volume_m3.nil? || volume_m3 <= 0
          diagnostics << diag('NON_MANIFOLD', element_id, module_id, "#{label}: 닫힌 솔리드가 아니거나 면 방향이 일관되지 않습니다.")
          return
        end
        native = native_volume_m3(entity)
        if native && (native - volume_m3).abs > ([native, volume_m3].max * 0.01 + 1e-9)
          diagnostics << diag('NON_MANIFOLD', element_id, module_id,
                               "#{label}: 체적 적분(#{volume_m3.round(6)}m³)이 SketchUp 자체 체적(#{native.round(6)}m³)과 1% 이상 차이납니다. 닫힘 여부를 확인하세요.")
        end
        metrics['volume_m3'] = {
          'value' => volume_m3, 'centroid_world_m' => centroid,
          'quantity_method' => 'CLOSED_MESH_INTEGRAL', 'centroid_method' => 'VOLUME_INTEGRAL',
          'quality' => 'CALCULATED', 'assumptions' => ['균일 밀도 가정'],
        }
      when 'AXIS_ENDPOINTS'
        pts = ModularWeightExporter.get_attr(entity, 'axis_endpoints_local')
        if pts.nil? || pts.length != 2
          diagnostics << diag('MISSING_METRIC', element_id, module_id, "#{label}: 기준축 두 점이 지정되지 않았습니다. \"기준축 지정\" 명령을 먼저 실행하세요.")
          return
        end
        p1 = Geom::Point3d.new(pts[0][0], pts[0][1], pts[0][2])
        p2 = Geom::Point3d.new(pts[1][0], pts[1][1], pts[1][2])
        length_m, mid = Geometry.compute_length(p1, p2, total_transform)
        if length_m.nil? || length_m <= 1e-9
          diagnostics << diag('DEGENERATE_GEOMETRY', element_id, module_id, "#{label}: 기준축 길이가 0에 가깝습니다.")
          return
        end
        length_axis_index = ModularWeightExporter.get_attr(entity, 'length_axis_index', 0)
        if Geometry.section_scale_invalid?(total_transform, length_axis_index)
          diagnostics << diag('INVALID_SECTION_SCALE', element_id, module_id, "#{label}: 단면 방향 스케일이 균일하지 않습니다. 규격/단중 불일치 위험이 있어 자동 계산하지 않습니다.")
          return
        end
        metrics['length_m'] = {
          'value' => length_m, 'centroid_world_m' => mid,
          'quantity_method' => 'TRANSFORMED_AXIS_ENDPOINTS', 'centroid_method' => 'AXIS_MIDPOINT',
          'quality' => 'CALCULATED', 'assumptions' => ['균일 선밀도 가정', '로컬 X축이 길이 방향이라는 관례를 사용'],
        }
      when 'INSTANCE'
        override = ModularWeightExporter.get_attr(entity, 'centroid_override_local')
        if override && override.length == 3
          pt = Geom::Point3d.new(override[0], override[1], override[2]).transform(total_transform)
          note = ModularWeightExporter.get_attr(entity, 'centroid_note')
          metrics['count'] = {
            'value' => 1, 'centroid_world_m' => Geometry.point_to_arr_m(pt),
            'quantity_method' => 'INSTANCE_ONE', 'centroid_method' => 'USER_POINT',
            'quality' => 'USER_SPECIFIED',
            'assumptions' => [note.to_s.empty? ? '사용자 지정 중심점 (근거 미입력)' : note],
          }
        else
          min, max = Geometry.world_bounds_m(entity, parent_transform)
          mid = [(min[0] + max[0]) / 2.0, (min[1] + max[1]) / 2.0, (min[2] + max[2]) / 2.0]
          metrics['count'] = {
            'value' => 1, 'centroid_world_m' => mid,
            'quantity_method' => 'INSTANCE_ONE', 'centroid_method' => 'BBOX_CENTER',
            'quality' => 'ESTIMATED',
            'assumptions' => ['제조사/사용자 지정 중심점 없음 - 경계상자 중심으로 추정'],
          }
        end
      end
    end
  end
end
