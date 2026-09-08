# 공통 상수와 modular_weight AttributeDictionary 접근 헬퍼.
# 개발명세 1.4절의 속성 계약을 그대로 따른다.
module ModularWeightExporter
  ATTR_DICT = 'modular_weight'.freeze

  CATEGORIES = %w[STRUCTURE FLOOR WALL CEILING OPENING MEP OTHER].freeze
  ROLES = %w[MODULE CONTAINER PART IGNORE].freeze
  QUANTITY_BASES = %w[REFERENCE_FACES SOLID AXIS_ENDPOINTS INSTANCE].freeze
  QUANTITY_BASIS_LABELS = {
    'REFERENCE_FACES' => 'REFERENCE_FACES (면적·AREA)',
    'SOLID' => 'SOLID (체적·VOLUME)',
    'AXIS_ENDPOINTS' => 'AXIS_ENDPOINTS (길이·LENGTH)',
    'INSTANCE' => 'INSTANCE (개수·COUNT)',
  }.freeze
  TAG_RE = /\A[A-Z][A-Z0-9_.]*\z/.freeze
  IN_TO_M = 0.0254
  SCHEMA_VERSION = '1.0.0'.freeze
  WARNING_CODES = %w[ESTIMATED_CENTROID ESTIMATED_UNIT_WEIGHT UNCLASSIFIED].freeze

  module_function

  def get_attr(entity, key, default = nil)
    dict = entity.attribute_dictionary(ATTR_DICT)
    return default if dict.nil?
    value = entity.get_attribute(ATTR_DICT, key)
    value.nil? ? default : value
  end

  def set_attr(entity, key, value)
    if value.nil?
      dict = entity.attribute_dictionary(ATTR_DICT)
      dict.delete_key(key) if dict
    else
      entity.set_attribute(ATTR_DICT, key, value)
    end
  end

  def role_of(entity)
    get_attr(entity, 'role')
  end

  def category_of(entity)
    get_attr(entity, 'category')
  end

  def quantity_basis_of(entity)
    get_attr(entity, 'quantity_basis')
  end

  # 자재 Tag는 SketchUp 고유 Tag(Layer) 기능을 그대로 사용한다 (명세 1.2).
  def tag_of(entity)
    layer = entity.layer
    return nil if layer.nil?
    return nil if layer.name == 'Layer0' # 기본(미지정) Tag
    layer.name
  end

  def generate_uuid
    chars = Array.new(32) { rand(16).to_s(16) }
    chars[12] = '4'
    chars[16] = %w[8 9 a b][rand(4)]
    "#{chars[0, 8].join}-#{chars[8, 4].join}-#{chars[12, 4].join}-#{chars[16, 4].join}-#{chars[20, 12].join}"
  end

  def model_id
    model = Sketchup.active_model
    id = model.get_attribute(ATTR_DICT, 'model_id')
    if id.nil? || id.to_s.empty?
      id = generate_uuid
      model.set_attribute(ATTR_DICT, 'model_id', id)
    end
    id
  end

  def reissue_model_id!
    Sketchup.active_model.set_attribute(ATTR_DICT, 'model_id', generate_uuid)
  end
end
