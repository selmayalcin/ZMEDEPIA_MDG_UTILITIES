CLASS zcl_mdg_mm_helper_active DEFINITION
  PUBLIC
  INHERITING FROM zcl_mdg_mm_helper
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    CLASS-METHODS destruct_instance
      IMPORTING
        !iv_material TYPE matnr .
    CLASS-METHODS destruct_instances .
    CLASS-METHODS get_instance
      IMPORTING
        !iv_material      TYPE matnr
      RETURNING
        VALUE(ro_mm_data) TYPE REF TO zcl_mdg_mm_helper
      EXCEPTIONS
        instance_creation_failed
        entity_data_all_read_error
        app_context_get_failed
        appcontext_attribute_get_error
        unexpected_error
        model_get_failed .
  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_s_instance,
        material TYPE matnr,
        instance TYPE REF TO zcl_mdg_mm_helper_active,
      END OF ty_s_instance .
    TYPES:
      ty_t_instance TYPE SORTED TABLE OF ty_s_instance WITH UNIQUE KEY material .

    CLASS-DATA gt_instances TYPE ty_t_instance .

    METHODS read_data_from_matnr
      IMPORTING
        !iv_matnr TYPE matnr .
    METHODS constructor
      IMPORTING
        !iv_matnr TYPE matnr
      EXCEPTIONS
        entity_data_all_read_error
        app_context_get_failed
        appcontext_attribute_get_error
        model_get_failed
        discard_instance
        unexpected_error .
    METHODS transfer_txtmi_instantiation .
    METHODS read_matchgmng_data
      IMPORTING
        !iv_matnr             TYPE matnr
        !iv_crequest          TYPE usmd_crequest OPTIONAL
        !it_data_entity_stage TYPE usmd_ts_data_entity OPTIONAL
      EXPORTING
        !et_matchgmng         TYPE usmd_ts_data_entity .
ENDCLASS.



CLASS ZCL_MDG_MM_HELPER_ACTIVE IMPLEMENTATION.


  METHOD constructor.

    super->constructor( ).

    IF iv_matnr IS NOT INITIAL.
      CALL METHOD read_data_from_matnr
        EXPORTING
          iv_matnr = iv_matnr.
    ENDIF.

  ENDMETHOD.


  METHOD destruct_instance.

    DELETE gt_instances WHERE material EQ iv_material.

  ENDMETHOD.


  METHOD destruct_instances.
    CLEAR gt_instances.
  ENDMETHOD.


  METHOD get_instance.

    DATA:
      ls_instance TYPE ty_s_instance.

    FIELD-SYMBOLS:
      <ls_instance> TYPE ty_s_instance.

    READ TABLE gt_instances ASSIGNING <ls_instance> WITH TABLE KEY material = iv_material.

    IF sy-subrc EQ 0 AND <ls_instance>-instance IS NOT INITIAL.
      ro_mm_data = <ls_instance>-instance.
    ELSE.
      ls_instance-material = iv_material.
      CREATE OBJECT ls_instance-instance TYPE zcl_mdg_mm_helper_active
        EXPORTING
          iv_matnr                       = iv_material
        EXCEPTIONS
          entity_data_all_read_error     = 1
          app_context_get_failed         = 2
          appcontext_attribute_get_error = 3
          model_get_failed               = 4
          discard_instance               = 5
          unexpected_error               = 6
          OTHERS                         = 7.

      IF sy-subrc <> 0.
        CASE sy-subrc.
          WHEN 1.
            MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_bp TYPE 'X' NUMBER 001 RAISING entity_data_all_read_error.
          WHEN 2.
            MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_br_bp TYPE 'X' NUMBER 004 RAISING app_context_get_failed.
          WHEN 3.
            MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_br_bp TYPE 'X' NUMBER 004 RAISING app_context_get_failed .
          WHEN 4.
            MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 001 RAISING  model_get_failed.
          WHEN 5.
            CALL METHOD destruct_instance
              EXPORTING
                iv_material = iv_material.
            RETURN.
          WHEN 6.
            MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 000 RAISING unexpected_error.
          WHEN OTHERS.
            MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 000 RAISING unexpected_error.
        ENDCASE.
      ENDIF.

      INSERT ls_instance INTO TABLE gt_instances.

      ro_mm_data = ls_instance-instance.

    ENDIF.

    IF ro_mm_data IS NOT BOUND.
      MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 002 RAISING instance_creation_failed.
    ENDIF.

  ENDMETHOD.


  METHOD read_data_from_matnr.

    CONSTANTS:
      c_prefix      TYPE string VALUE 'GT_',
      c_suffix_text TYPE string VALUE 'TXT'.

    DATA:
      lt_data_entity        TYPE usmd_ts_data_entity,
      lt_data_entity_temp   TYPE usmd_ts_data_entity,
      lt_message            TYPE usmd_t_message,
      lv_entity_tabname     TYPE seocpdname,
      lt_material_selection TYPE usmd_ts_sel,
      ls_material_selection TYPE usmd_s_sel,
      lr_entity             TYPE REF TO data,
      lv_fieldname          TYPE usmd_fieldname,
      lv_active             TYPE abap_bool,
      lt_matchgmng          TYPE usmd_ts_data_entity.

    FIELD-SYMBOLS:
      <ls_data_entity>     TYPE usmd_sx_data_entity,
      <lt_gt_entity>       TYPE SORTED TABLE,
      <ls_entity>          TYPE any,
      <lt_data>            TYPE ANY TABLE,
      <ls_entity_prop_ext> TYPE usmd_s_entity_prop_ext.

    IF iv_matnr IS INITIAL.
      MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 000. "#EC CI_USE_WANTED
    ENDIF.

    IF iv_matnr CA '$'.
      lv_active = abap_false.
    ELSE.
      lv_active = abap_true.
    ENDIF.

    IF sy-subrc = 0 AND iv_matnr IS NOT INITIAL.
      ls_material_selection-fieldname = if_mdg_bs_mat_gen_c=>gc_fieldname_material.
      ls_material_selection-sign   = 'I'.
      ls_material_selection-option = 'EQ'.
      ls_material_selection-low    = iv_matnr.
      INSERT ls_material_selection INTO TABLE lt_material_selection.
    ENDIF.

    IF lt_material_selection IS NOT INITIAL.

* Look for material entity in active data, if an existent material is changed (business activity = MAT2)
* This call triggers the derivations BAdI and will cause mt_mm_pp_material to be filled afterwards
      LOOP AT go_model->if_usmd_model_metadata_ext~dt_entity_prop ASSIGNING <ls_entity_prop_ext> WHERE usage_type = 1. "#EC CI_SORTSEQ - accessing SAP default content in MDG
        lv_fieldname = <ls_entity_prop_ext>-usmd_entity.
        CALL METHOD go_model->read_entity_data_all
          EXPORTING
            i_fieldname    = lv_fieldname
            it_sel         = lt_material_selection
            if_active      = lv_active
          IMPORTING
            et_message     = lt_message
            et_data_entity = lt_data_entity_temp.
        INSERT LINES OF lt_data_entity_temp INTO TABLE lt_data_entity.
        CLEAR: lv_fieldname.
        IF lt_message IS NOT INITIAL.
          RETURN.
        ENDIF.
      ENDLOOP.

      " add MATCHGMNG data
      CALL METHOD read_matchgmng_data
        EXPORTING
          iv_matnr             = iv_matnr
          it_data_entity_stage = lt_data_entity
        IMPORTING
          et_matchgmng         = lt_matchgmng.

      INSERT LINES OF lt_matchgmng INTO TABLE lt_data_entity.

    ENDIF.

* Transform untyped to typed data
    LOOP AT lt_data_entity ASSIGNING <ls_data_entity>.
      CLEAR: lv_entity_tabname, lr_entity.
      UNASSIGN: <ls_entity>, <lt_gt_entity>.

* Construct export table name and assign it to field symbol (it's used to fill the related mt)
      CASE <ls_data_entity>-struct.
        WHEN if_usmd_model_ext=>gc_struct_key_attr.
          IF <ls_data_entity>-usmd_entity_cont IS INITIAL.
            CONCATENATE c_prefix <ls_data_entity>-usmd_entity INTO lv_entity_tabname.
          ELSE.
            CONCATENATE c_prefix <ls_data_entity>-usmd_entity_cont INTO lv_entity_tabname.
          ENDIF.
        WHEN if_usmd_model_ext=>gc_struct_key_txt_langu.
          IF <ls_data_entity>-usmd_entity_cont IS INITIAL.
            IF <ls_data_entity>-usmd_entity = zcl_mdg_mm_helper=>if_mdg_bs_mat_gen_c~gc_entity_material.
              CONCATENATE c_prefix zcl_mdg_mm_helper=>cs_entities-material_txt INTO lv_entity_tabname.
            ELSE.
              CONCATENATE c_prefix <ls_data_entity>-usmd_entity c_suffix_text INTO lv_entity_tabname.
            ENDIF.
          ELSE.
            CONCATENATE c_prefix <ls_data_entity>-usmd_entity_cont c_suffix_text INTO lv_entity_tabname.
          ENDIF.
      ENDCASE.

* write data to gt
      ASSIGN (lv_entity_tabname) TO <lt_gt_entity>.
      IF <lt_gt_entity> IS NOT ASSIGNED.                  "#EC CI_SUBRC
        MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 000. "#EC CI_USE_WANTED
      ENDIF.

      CREATE DATA lr_entity LIKE LINE OF <lt_gt_entity>.
      ASSIGN lr_entity->* TO <ls_entity>.
      IF <ls_entity> IS NOT ASSIGNED.
        MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 000. "#EC CI_USE_WANTED
      ENDIF.

      CLEAR: <ls_entity>, <lt_gt_entity>.

      ASSIGN <ls_data_entity>-r_t_data->* TO <lt_data>.
      IF sy-subrc <> 0.
        MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 000. "#EC CI_USE_WANTED
      ENDIF.

      IF <lt_data> IS ASSIGNED.
        MOVE-CORRESPONDING <lt_data> TO <lt_gt_entity>.
      ENDIF.
    ENDLOOP.

    CALL METHOD transfer_txtmi_instantiation.

  ENDMETHOD.


  METHOD read_matchgmng_data.

    DATA:
      lr_data              TYPE REF TO data,
      ls_matchgmng         TYPE /mdgmm/_s_mm_pp_matchgmng,
      ls_type1_entity_data TYPE usmd_sx_data_entity,
      lt_aeoi_tmp          TYPE SORTED TABLE OF aeoi WITH UNIQUE KEY aennr aetyp objkt,
      lt_aeoi              TYPE TABLE OF aeoi.

    FIELD-SYMBOLS:
      <ls_data_entity> TYPE usmd_sx_data_entity,
      <ls_aeoi>        TYPE aeoi,
      <lt_data>        TYPE zif_mdg_mm_datatypes=>gty_t_matchgmng.

    CLEAR: et_matchgmng.

* material change management data
    CALL METHOD go_matchgmng_api->read_chgmng
      EXPORTING
        iv_matnr = iv_matnr
      IMPORTING
        et_aeoi  = lt_aeoi_tmp.
    LOOP AT lt_aeoi_tmp ASSIGNING <ls_aeoi>.
      INSERT <ls_aeoi> INTO TABLE lt_aeoi.
    ENDLOOP.
    SORT lt_aeoi DESCENDING BY revlv.

    IF lt_aeoi IS NOT INITIAL.

      " check if an entry for MATCHGMNG already is staging area
      READ TABLE it_data_entity_stage WITH KEY usmd_entity = 'MATCHGMNG' ASSIGNING <ls_data_entity>.
      IF sy-subrc = 0 AND <ls_data_entity> IS ASSIGNED.

        " entry exists -> modify data for this entry
        ASSIGN <ls_data_entity>-r_t_data->* TO <lt_data>.

        LOOP AT lt_aeoi ASSIGNING <ls_aeoi>.
          ls_matchgmng-material  = iv_matnr.
          ls_matchgmng-matchgmng = iv_crequest.
          ls_matchgmng-ecochgmng = <ls_aeoi>-aennr.
          ls_matchgmng-revchgmng = <ls_aeoi>-revlv.
          INSERT ls_matchgmng INTO TABLE <lt_data>.
        ENDLOOP.

        " no entry exists -> it has to be created from scratch
      ELSE.
        CALL METHOD go_model->create_data_reference
          EXPORTING
            i_fieldname = 'MATCHGMNG'
            i_struct    = if_usmd_model=>gc_struct_key_attr
            i_tabtype   = if_usmd_model=>gc_tabtype_sorted
          IMPORTING
            er_data     = lr_data.
        ASSIGN lr_data->* TO <lt_data>.

        LOOP AT lt_aeoi ASSIGNING <ls_aeoi>.
          CLEAR ls_matchgmng.
          ls_matchgmng-material  = iv_matnr.
          ls_matchgmng-matchgmng = iv_crequest.
          ls_matchgmng-ecochgmng = <ls_aeoi>-aennr.
          ls_matchgmng-revchgmng = <ls_aeoi>-revlv.
          INSERT ls_matchgmng INTO TABLE <lt_data>.
        ENDLOOP.

        ls_type1_entity_data-usmd_entity = 'MATCHGMNG'.
        ls_type1_entity_data-struct      = if_usmd_model=>gc_struct_key_attr.
        ls_type1_entity_data-r_t_data    = lr_data.
        INSERT ls_type1_entity_data INTO TABLE et_matchgmng.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD transfer_txtmi_instantiation.

    FIELD-SYMBOLS:
      <ls_material> TYPE /mdgmm/_s_mm_pp_material,
      <ls_mattxt>   TYPE /mdgmm/_st_mm_pp_material.


    LOOP AT gt_material ASSIGNING <ls_material>.
      IF <ls_material>-txtmi IS INITIAL.

        READ TABLE gt_mattxt
          ASSIGNING <ls_mattxt>
          WITH TABLE KEY material = <ls_material>-material langu = sy-langu.
        IF sy-subrc IS INITIAL.
          <ls_material>-txtmi = <ls_mattxt>-txtmi.
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
