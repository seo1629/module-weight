# 순수 형상 계산 함수 모음 (개발명세 2.2절).
# 어떤 함수도 UI/선택 상태에 의존하지 않는다 - 이미 계산된 world transform과
# Face/좌표만 받아서 SI 단위(m, m2, m3)로 물량과 중심을 반환한다.
module ModularWeightExporter
  module Geometry
    module_function

    def to_m(v) v * IN_TO_M end
    def to_m2(v) v * IN_TO_M**2 end
    def to_m3(v) v * IN_TO_M**3 end

    def point_to_arr_m(pt)
      [to_m(pt.x), to_m(pt.y), to_m(pt.z)]
    end

    def vec_length(v)
      Math.sqrt(v.inject(0.0) { |s, x| s + x * x })
    end

    def normalize(v)
      len = vec_length(v)
      return [0.0, 0.0, 0.0] if len <= 1e-12
      v.map { |x| x / len }
    end

    # entity 하위(중첩 그룹/컴포넌트 포함)의 모든 Face를 world transform과 함께 수집한다.
    # PART의 SOLID 기준 물량 계산에 쓰인다.
    def collect_all_faces(entities, transform, results)
      entities.each do |e|
        case e
        when Sketchup::Face
          results << [e, transform]
        when Sketchup::Group
          collect_all_faces(e.entities, transform * e.transformation, results)
        when Sketchup::ComponentInstance
          collect_all_faces(e.definition.entities, transform * e.transformation, results)
        end
      end
      results
    end

    # persistent_id 목록에 해당하는 Face만 world transform과 함께 수집한다.
    # PART의 REFERENCE_FACES 기준 물량 계산에 쓰인다.
    def find_faces_by_ids(entities, ids, transform, results)
      id_set = ids.to_a
      entities.each do |e|
        case e
        when Sketchup::Face
          results << [e, transform] if id_set.include?(e.persistent_id)
        when Sketchup::Group
          find_faces_by_ids(e.entities, ids, transform * e.transformation, results)
        when Sketchup::ComponentInstance
          find_faces_by_ids(e.definition.entities, ids, transform * e.transformation, results)
        end
      end
      results
    end

    # AREA: 기준면들의 변환 후 면적 합과 면적가중 중심 (명세 2.2).
    # face_transform_pairs: [[face, world_transform], ...] - 면마다 다른 transform 허용.
    def compute_area(face_transform_pairs)
      total_area = 0.0
      wx = wy = wz = 0.0
      face_transform_pairs.each do |face, transform|
        mesh = face.mesh(0)
        (1..mesh.count_polygons).each do |i|
          tri = mesh.polygon_points_at(i)
          next if tri.length < 3
          a = tri[0].transform(transform)
          b = tri[1].transform(transform)
          c = tri[2].transform(transform)
          ux, uy, uz = b.x - a.x, b.y - a.y, b.z - a.z
          vx, vy, vz = c.x - a.x, c.y - a.y, c.z - a.z
          cx = uy * vz - uz * vy
          cy = uz * vx - ux * vz
          cz = ux * vy - uy * vx
          tri_area = Math.sqrt(cx * cx + cy * cy + cz * cz) / 2.0
          next if tri_area <= 1e-12
          ccx = (a.x + b.x + c.x) / 3.0
          ccy = (a.y + b.y + c.y) / 3.0
          ccz = (a.z + b.z + c.z) / 3.0
          total_area += tri_area
          wx += tri_area * ccx
          wy += tri_area * ccy
          wz += tri_area * ccz
        end
      end
      return [0.0, nil] if total_area <= 1e-9
      [to_m2(total_area), [to_m(wx / total_area), to_m(wy / total_area), to_m(wz / total_area)]]
    end

    # VOLUME: signed tetrahedra 적분으로 체적과 체적중심을 동시에 계산 (명세 2.2).
    # 기준점 r은 첫 삼각형의 첫 정점으로 잡아 수치 오차를 줄인다.
    # signed 합으로 중심을 구하므로 전체 방향이 반전되어 있어도(면이 전부 안쪽을 향해도)
    # 중심 좌표 자체는 올바르게 나온다 - 부호가 분자/분모에서 상쇄되기 때문이다.
    def compute_volume(face_transform_pairs)
      return [0.0, nil] if face_transform_pairs.empty?
      rx = ry = rz = nil
      vol_signed = 0.0
      cxs = cys = czs = 0.0
      face_transform_pairs.each do |face, transform|
        mesh = face.mesh(0)
        (1..mesh.count_polygons).each do |i|
          tri = mesh.polygon_points_at(i)
          next if tri.length < 3
          a = tri[0].transform(transform)
          b = tri[1].transform(transform)
          c = tri[2].transform(transform)
          if rx.nil?
            rx, ry, rz = a.x, a.y, a.z
          end
          ax, ay, az = a.x - rx, a.y - ry, a.z - rz
          bx, by, bz = b.x - rx, b.y - ry, b.z - rz
          cx, cy, cz = c.x - rx, c.y - ry, c.z - rz
          crx = by * cz - bz * cy
          cry = bz * cx - bx * cz
          crz = bx * cy - by * cx
          v = (ax * crx + ay * cry + az * crz) / 6.0
          tcx = (rx + a.x + b.x + c.x) / 4.0
          tcy = (ry + a.y + b.y + c.y) / 4.0
          tcz = (rz + a.z + b.z + c.z) / 4.0
          vol_signed += v
          cxs += v * tcx
          cys += v * tcy
          czs += v * tcz
        end
      end
      return [0.0, nil] if vol_signed.abs <= 1e-9
      volume_m3 = to_m3(vol_signed.abs)
      centroid = [to_m(cxs / vol_signed), to_m(cys / vol_signed), to_m(czs / vol_signed)]
      [volume_m3, centroid]
    end

    # LENGTH: 로컬 두 끝점을 world로 변환한 거리와 중점 (명세 2.2).
    def compute_length(p1_local, p2_local, transform)
      a = p1_local.transform(transform)
      b = p2_local.transform(transform)
      length = a.distance(b)
      mid = [to_m((a.x + b.x) / 2.0), to_m((a.y + b.y) / 2.0), to_m((a.z + b.z) / 2.0)]
      [to_m(length), mid]
    end

    # transform의 4x4 행렬에서 각 축의 스케일(길이)을 직접 구한다.
    # xaxis/yaxis/zaxis 접근자에 의존하지 않아 스케일 해석이 더 안정적이다.
    def axis_scales(transform)
      m = transform.to_a
      x = Math.sqrt(m[0] * m[0] + m[1] * m[1] + m[2] * m[2])
      y = Math.sqrt(m[4] * m[4] + m[5] * m[5] + m[6] * m[6])
      z = Math.sqrt(m[8] * m[8] + m[9] * m[9] + m[10] * m[10])
      [x, y, z]
    end

    # LENGTH 부재: length_axis_index(기본 0=로컬 X, 명세 1.3의 관례)를 길이 방향으로 보고,
    # 나머지 두 축(단면 방향) 스케일이 서로 다르면 규격이 왜곡된 것으로 본다 (INVALID_SECTION_SCALE).
    # 자동 인식(AutoDetect)은 실제로 긴 축이 X가 아닐 수도 있어 length_axis_index를 넘겨준다.
    def section_scale_invalid?(transform, length_axis_index = 0)
      scales = axis_scales(transform)
      other = (0..2).reject { |i| i == length_axis_index }
      a, b = scales[other[0]], scales[other[1]]
      (a - b).abs > [a, b, 1.0].max * 1e-4
    end

    # MODULE 변환이 이동/회전만으로 이루어진 강체 변환인지 검사한다 (명세 1.3).
    def rigid_transform?(transform)
      x, y, z = axis_scales(transform)
      (x - 1.0).abs < 1e-6 && (y - 1.0).abs < 1e-6 && (z - 1.0).abs < 1e-6
    end

    # entity의 world 경계상자. parent_transform은 entity 자신의 transformation은
    # 제외한, entity의 "부모"까지의 누적 transform이어야 한다.
    # (entity.bounds 자체가 이미 entity 자신의 transformation을 반영한 값이기 때문)
    def world_bounds_m(entity, parent_transform)
      bb = entity.bounds
      corners = (0..7).map { |i| bb.corner(i).transform(parent_transform) }
      xs = corners.map(&:x)
      ys = corners.map(&:y)
      zs = corners.map(&:z)
      min = [to_m(xs.min), to_m(ys.min), to_m(zs.min)]
      max = [to_m(xs.max), to_m(ys.max), to_m(zs.max)]
      [min, max]
    end
  end
end
