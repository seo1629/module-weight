# Extensions 메뉴에 명령을 등록한다.
module ModularWeightExporter
  module Menu
    module_function

    def register!
      return if @registered
      @registered = true

      menu = UI.menu('Extensions').add_submenu('모듈러 중량 Exporter')
      menu.add_item('① 모듈로 지정 (MODULE)') { Commands.assign_module }
      menu.add_item('★ 빠른 부재 지정 (자동 판별, 추천)') { Commands.auto_assign_parts }
      menu.add_separator

      advanced = menu.add_submenu('수동/고급 지정')
      advanced.add_item('② 컨테이너로 지정 (CONTAINER)') { Commands.assign_container }
      advanced.add_item('③ 부재로 지정 (PART, 계산유형 직접 선택)') { Commands.assign_part }
      advanced.add_item('④ 제외 그룹으로 지정 (IGNORE)') { Commands.assign_ignore }
      advanced.add_separator
      advanced.add_item('⑤ 기준면 지정 - AREA (편집모드 안에서, 면 직접 선택)') { Commands.assign_reference_faces }
      advanced.add_item('⑥ 기준축 지정 - LENGTH (편집모드 안에서, 점 직접 클릭)') { Commands.start_axis_pick_tool }
      advanced.add_item('⑦ 무게중심 보정점 지정 (편집모드 안에서)') { Commands.start_centroid_pick_tool }
      advanced.add_separator
      advanced.add_item('⑧ 부재 제외/포함 전환') { Commands.toggle_excluded }
      advanced.add_item('⑨ 선택 항목 속성 보기') { Commands.show_attributes }
      advanced.add_item('⑫ 모델 ID 새로 발급') { Commands.reissue_model_id }

      menu.add_separator
      menu.add_item('⑩ 중량 데이터 검증') { Exporter.validate_only }
      menu.add_item('⑪ JSON 내보내기') { Exporter.export_json }
    end
  end
end
