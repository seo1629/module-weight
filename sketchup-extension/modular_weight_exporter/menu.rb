# Extensions 메뉴에 명령을 등록한다.
module ModularWeightExporter
  module Menu
    module_function

    def register!
      return if @registered
      @registered = true

      menu = UI.menu('Extensions').add_submenu('모듈러 중량 Exporter')
      menu.add_item('① 모듈로 지정 (MODULE)') { Commands.assign_module }
      menu.add_item('② 컨테이너로 지정 (CONTAINER)') { Commands.assign_container }
      menu.add_item('③ 부재로 지정 (PART)') { Commands.assign_part }
      menu.add_item('④ 제외 그룹으로 지정 (IGNORE)') { Commands.assign_ignore }
      menu.add_separator
      menu.add_item('⑤ 기준면 지정 - AREA (편집모드 안에서)') { Commands.assign_reference_faces }
      menu.add_item('⑥ 기준축 지정 - LENGTH (편집모드 안에서)') { Commands.start_axis_pick_tool }
      menu.add_item('⑦ 무게중심 보정점 지정 (편집모드 안에서)') { Commands.start_centroid_pick_tool }
      menu.add_separator
      menu.add_item('⑧ 부재 제외/포함 전환') { Commands.toggle_excluded }
      menu.add_item('⑨ 선택 항목 속성 보기') { Commands.show_attributes }
      menu.add_separator
      menu.add_item('⑩ 중량 데이터 검증') { Exporter.validate_only }
      menu.add_item('⑪ JSON 내보내기') { Exporter.export_json }
      menu.add_item('⑫ 모델 ID 새로 발급') { Commands.reissue_model_id }
    end
  end
end
