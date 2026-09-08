# 형상만 보고 계산유형(quantity_basis)과 기준면/기준축을 추정한다.
# "빠른 부재 지정" 명령이 사용한다 - 사람이 매번 REFERENCE_FACES/AXIS_ENDPOINTS를
# 고르고 편집모드에 들어가 면/점을 찍는 수고를 단순한 형상(판재, 직선 부재, 닫힌 솔리드)에서는
# 없애 준다. 애매한 형상은 nil을 반환해 사용자가 직접(③/⑤/⑥) 지정하게 한다.
#
# 판단 기준(모두 부재 "자기 자신"의 로컬 좌표계 기준 - 배치 회전과 무관):
# - 네이티브 volume이 있으면(닫힌 솔리드) → SOLID
# - 세 변 중 가장 짧은 변이 중간 변의 15% 미만이면 → 얇은 판(REFERENCE_FACES)
# - 가장 긴 변이 중간 변의 4배를 넘으면 → 가늘고 긴 부재(AXIS_ENDPOINTS)
# - 그 외(정육면체에 가깝거나 판단이 애매함) → nil, 수동 지정 필요
module ModularWeightExporter
  module AutoDetect
    module_function

    def local_bounds(entity)
      entity.definition.bounds
    end

    def local_extents(entity)
      bb = local_bounds(entity)
      [
        (bb.max.x - bb.min.x).abs,
        (bb.max.y - bb.min.y).abs,
        (bb.max.z - bb.min.z).abs,
      ]
    end

    def native_volume_positive?(entity)
      return false unless entity.respond_to?(:volume)
      v = entity.volume
      !v.nil? && v > 0
    rescue StandardError
      false
    end

    def detect_basis(entity)
      return 'SOLID' if native_volume_positive?(entity)

      dims = local_extents(entity)
      sorted = dims.sort
      d1, d2, d3 = sorted
      return nil if d2 <= 1e-6 # 퇴화 형상(선/점) - 판단 불가

      return 'REFERENCE_FACES' if d1 < 0.15 * d2
      return 'AXIS_ENDPOINTS' if d3 > 4.0 * d2

      nil
    end

    # 가장 긴 로컬 축을 길이 방향으로 보고, 그 축의 양 끝 - 단면 중심을 지나는
    # 두 점을 로컬 좌표로 반환한다. [axis_index, [x,y,z], [x,y,z]]
    def axis_endpoints_for(entity)
      bb = local_bounds(entity)
      dims = local_extents(entity)
      axis_index = dims.each_index.max_by { |i| dims[i] }
      min = bb.min
      max = bb.max
      mx = (min.x + max.x) / 2.0
      my = (min.y + max.y) / 2.0
      mz = (min.z + max.z) / 2.0
      case axis_index
      when 0
        p1 = [min.x, my, mz]
        p2 = [max.x, my, mz]
      when 1
        p1 = [mx, min.y, mz]
        p2 = [mx, max.y, mz]
      else
        p1 = [mx, my, min.z]
        p2 = [mx, my, max.z]
      end
      [axis_index, p1, p2]
    end

    # entity 자신의 하위(중첩 그룹 포함)에서 모든 Face를 찾는다 (transform 없이 객체만).
    def all_faces(entity)
      pairs = Geometry.collect_all_faces(Builder.children_entities(entity), Geom::Transformation.new, [])
      pairs.map { |face, _t| face }
    end
  end
end
