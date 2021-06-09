CLASS zcl_mdg_mm_helper_staging DEFINITION
  PUBLIC
  INHERITING FROM zcl_mdg_mm_helper
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    CLASS-METHODS destruct_instance .
    CLASS-METHODS get_instance
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

*    TYPES:
*      BEGIN OF gty_s_instance,
*        crequest TYPE usmd_crequest,
*        material TYPE matnr,
*        instance TYPE REF TO zcl_mdg_mm_helper_staging,
*      END OF gty_s_instance .
*    TYPES:
*      gty_t_instance TYPE SORTED TABLE OF gty_s_instance WITH UNIQUE KEY crequest material .

    CLASS-DATA go_instance TYPE REF TO zcl_mdg_mm_helper_staging .
    DATA gv_crid TYPE usmd_crequest .
    DATA gv_wiid TYPE sww_wiid .
    CLASS-DATA gv_final_status_set TYPE abap_bool .

    METHODS constructor
      EXCEPTIONS
        entity_data_all_read_error
        app_context_get_failed
        appcontext_attribute_get_error
        model_get_failed
        discard_instance
        unexpected_error .
    METHODS read_entity_data_cr
      EXCEPTIONS
        model_get_failed
        app_context_get_failed
        appcontext_attribute_get_error
        entity_data_all_read_error
        discard_instance
        data_not_found
        dyn_assignment_failed .
    METHODS transfer_txtmi_instantiation .
    METHODS read_active_data_of_cr
      IMPORTING
        !iv_crequest        TYPE usmd_crequest
        !io_model           TYPE REF TO if_usmd_model_ext
      EXPORTING
        !et_entity_data_act TYPE usmd_ts_data_entity .
    METHODS read_matchgmng_data
      IMPORTING
        !it_materials   TYPE table_matnr
        !iv_crequest    TYPE usmd_crequest OPTIONAL
        !it_data_entity TYPE usmd_ts_data_entity OPTIONAL
      EXPORTING
        !et_matchgmng   TYPE usmd_ts_data_entity .
ENDCLASS.



CLASS ZCL_MDG_MM_HELPER_STAGING IMPLEMENTATION.


  METHOD constructor.

    CALL METHOD super->constructor.

    CALL METHOD read_entity_data_cr
      EXCEPTIONS
        entity_data_all_read_error     = 1
        app_context_get_failed         = 2
        appcontext_attribute_get_error = 3
        model_get_failed               = 4
        discard_instance               = 5
        OTHERS                         = 6.

    IF sy-subrc <> 0 .
      CASE sy-subrc.
        WHEN 1.
          RAISE entity_data_all_read_error.
        WHEN 2.
          RAISE app_context_get_failed.
        WHEN 3.
          RAISE appcontext_attribute_get_error.
        WHEN 4.
          RAISE model_get_failed.
        WHEN 5.
          RAISE discard_instance.
        WHEN OTHERS.
          RAISE unexpected_error.
      ENDCASE.
    ENDIF.

  ENDMETHOD.


  METHOD destruct_instance.

    FREE go_instance.

  ENDMETHOD.


  METHOD get_instance.
    DATA:
      lo_app_context   TYPE REF TO if_usmd_app_context,
      lv_force_reload  TYPE abap_bool,
      lo_crequest_util TYPE REF TO cl_usmd_crequest_util,
      lo_model         TYPE REF TO if_usmd_model,
      ls_crequest      TYPE usmd_s_crequest,
      lt_messages      TYPE usmd_t_message,
      lv_error         TYPE abap_bool,
      lv_material      TYPE matnr.

    FIELD-SYMBOLS:
      <ls_message> TYPE usmd_s_message.

    lv_force_reload = abap_false.

    CALL METHOD cl_usmd_app_context=>get_context
      RECEIVING
        eo_context = lo_app_context.

    IF lo_app_context IS BOUND.
      IF lo_app_context->mv_crequest_id IS INITIAL.
        lv_material = cl_mdg_bs_mat_assist_ui=>gv_current_material.

        CALL METHOD zcl_mdg_mm_helper_active=>get_instance
          EXPORTING
            iv_material                    = lv_material
          RECEIVING
            ro_mm_data                     = ro_mm_data
          EXCEPTIONS
            instance_creation_failed       = 1
            entity_data_all_read_error     = 2
            app_context_get_failed         = 3
            appcontext_attribute_get_error = 4
            unexpected_error               = 5
            model_get_failed               = 6
            OTHERS                         = 7.

        IF sy-subrc <> 0.
          CASE sy-subrc.
            WHEN 1.
              MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_bp TYPE 'X' NUMBER 001 RAISING entity_data_all_read_error ##MG_MISSING.
            WHEN 2.
              MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_br_bp TYPE 'X' NUMBER 004 RAISING app_context_get_failed ##MG_MISSING.
            WHEN 3.
              MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_br_bp TYPE 'X' NUMBER 004 RAISING app_context_get_failed ##MG_MISSING.
            WHEN 4.
              MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 001 RAISING  model_get_failed ##MG_MISSING.
            WHEN 5.
              MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 001 RAISING  instance_creation_failed ##MG_MISSING.
            WHEN 6.
              MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 000 RAISING unexpected_error ##MG_MISSING.
            WHEN OTHERS.
              MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 000 RAISING unexpected_error ##MG_MISSING.
          ENDCASE.
        ENDIF.

        RETURN.


      ELSEIF go_instance IS BOUND.
        IF lo_app_context->mv_wi_id <> go_instance->gv_wiid OR go_instance->gv_crid <> lo_app_context->mv_crequest_id.
          go_instance->gv_wiid = lo_app_context->mv_wi_id.
          go_instance->gv_crid = lo_app_context->mv_crequest_id.
          lv_force_reload = abap_true.
        ENDIF.

        IF gv_final_status_set = abap_false.
          CREATE OBJECT lo_crequest_util.

          CALL METHOD cl_usmd_model=>get_instance
            EXPORTING
              i_usmd_model = if_mdg_bs_mat_gen_c=>gc_model_mm
            IMPORTING
              eo_instance  = lo_model
              et_message   = lt_messages.

          LOOP AT lt_messages ASSIGNING <ls_message> WHERE msgty CA 'EAX'.
            lv_error = abap_true.
            EXIT.
          ENDLOOP.

          IF lv_error = abap_false.
            CALL METHOD lo_crequest_util->get_crequest
              EXPORTING
                id_crequest = lo_app_context->mv_crequest_id
                io_model    = lo_model
              IMPORTING
                es_crequest = ls_crequest.

            IF ls_crequest IS NOT INITIAL.
              IF ls_crequest-usmd_creq_status = usmd0_cs_crequest_status-finally_approved OR ls_crequest-usmd_creq_status = usmd0_cs_crequest_status-finally_rejected.
                gv_final_status_set = abap_true.
                lv_force_reload = abap_true.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

    IF go_instance IS INITIAL OR lv_force_reload = abap_true.

      CREATE OBJECT go_instance TYPE zcl_mdg_mm_helper_staging
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
            MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_bp TYPE 'X' NUMBER 001 RAISING entity_data_all_read_error ##MG_MISSING.
          WHEN 2.
            MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_br_bp TYPE 'X' NUMBER 004 RAISING app_context_get_failed.
          WHEN 3.
            MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_br_bp TYPE 'X' NUMBER 004 RAISING app_context_get_failed .
          WHEN 4.
            MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 001 RAISING  model_get_failed.
          WHEN 5.
            CALL METHOD destruct_instance.
            RETURN.
          WHEN 6.
            MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 000 RAISING unexpected_error.
          WHEN OTHERS.
            MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 000 RAISING unexpected_error.
        ENDCASE.
      ELSE.
        IF go_instance IS BOUND.
          go_instance->gv_wiid = lo_app_context->mv_wi_id.
          go_instance->gv_crid = lo_app_context->mv_crequest_id.
        ENDIF.

        ro_mm_data = go_instance.

        IF ro_mm_data IS NOT BOUND.
          MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 002 RAISING instance_creation_failed.
        ENDIF.
      ENDIF.
    ELSE.
      ro_mm_data = go_instance.
    ENDIF.



*    "Check if instance exists for CREQUEST (if app_context filled) or iv_matnr
*    "Only if iv_force_new_instance is false
*    IF iv_force_new_instance EQ abap_false.
*      IF iv_matnr IS NOT INITIAL.
*        READ TABLE mt_instances INTO ls_instance WITH KEY material = iv_matnr.
*      ELSE.
*        CALL METHOD cl_usmd_app_context=>get_context
*          RECEIVING
*            eo_context = lo_context.
*
*        IF lo_context IS BOUND.
*          CALL METHOD lo_context->get_attributes
*            IMPORTING
*              ev_crequest_id = lv_crequest.
*        ENDIF.
*        IF lv_crequest IS NOT INITIAL.
*          READ TABLE mt_instances INTO ls_instance WITH KEY crequest = lv_crequest.
*        ENDIF.
*      ENDIF.
*    ENDIF.
*
*
*    IF ls_instance-instance IS INITIAL       "A new Instance has to be created if no instance exists
*      OR iv_force_new_instance EQ abap_true. "a new instance is forced
*
*      CREATE OBJECT ro_mm_data_process TYPE zcl_mdg_mm_helper_staging
*        EXPORTING
*          iv_matnr                       = iv_matnr
*        EXCEPTIONS
*          entity_data_all_read_error     = 1
*          app_context_get_failed         = 2
*          appcontext_attribute_get_error = 3
*          model_get_failed               = 4
*          discard_instance               = 5
*          unexpected_error               = 6
*          OTHERS                         = 7.
*
*      IF sy-subrc <> 0.
*        CASE sy-subrc.
*          WHEN 1.
*            MESSAGE ID ZCL_MDG_general_functions=>gc_msg_class_dm_bp TYPE 'X' NUMBER 001 RAISING entity_data_all_read_error.
*          WHEN 2.
*            MESSAGE ID ZCL_MDG_general_functions=>gc_msg_class_br_bp TYPE 'X' NUMBER 004 RAISING app_context_get_failed.
*          WHEN 3.
*            MESSAGE ID ZCL_MDG_general_functions=>gc_msg_class_br_bp TYPE 'X' NUMBER 004 RAISING app_context_get_failed .
*          WHEN 4.
*            MESSAGE ID ZCL_MDG_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 001 RAISING  model_get_failed.
*          WHEN 5.
*            CALL METHOD destruct_instance
*              EXPORTING
*                iv_matnr = iv_matnr.
*            RETURN.
*          WHEN 6.
*            MESSAGE ID ZCL_MDG_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 000 RAISING unexpected_error.
*          WHEN OTHERS.
*            MESSAGE ID ZCL_MDG_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 000 RAISING unexpected_error.
*        ENDCASE.
*      ENDIF.
*
*      IF ro_mm_data_process IS NOT BOUND.
*        MESSAGE ID ZCL_MDG_general_functions=>gc_msg_class_dm_gen TYPE 'X' NUMBER 002 RAISING instance_creation_failed.
*      ENDIF.
*
*      "Store instance in Instance table
*      ls_instance-crequest = lv_crequest.
*      ls_instance-material = iv_matnr.
*      ls_instance-instance = ro_mm_data_process.
*      INSERT ls_instance INTO TABLE mt_instances.
*
*
*    ELSE. "Instance already exists for given key
*      ro_mm_data_process = ls_instance-instance.
*    ENDIF.

  ENDMETHOD.


  METHOD read_active_data_of_cr.
    DATA:
      lt_key_all            TYPE usmd_ts_entity_data,
      lt_data_entity_temp   TYPE usmd_ts_data_entity,
      lv_fieldname          TYPE usmd_fieldname,
      lt_message            TYPE usmd_t_message,
      lt_materials          TYPE table_matnr,
      ls_material_selection TYPE usmd_s_sel,
      lt_material_selection TYPE usmd_ts_sel,
      lt_matchgmng          TYPE usmd_ts_data_entity.

    FIELD-SYMBOLS:
      <lv_material>        TYPE matnr,
      <ls_key_all>         TYPE usmd_sx_entity_data,
      <lt_key>             TYPE ANY TABLE,
      <ls_entity_prop_ext> TYPE usmd_s_entity_prop_ext.

    CLEAR et_entity_data_act.

    "Get all materials in CR
    CALL METHOD io_model->get_cr_objectlist
      EXPORTING
        i_crequest = iv_crequest
      IMPORTING
        et_key_all = lt_key_all.

    READ TABLE lt_key_all ASSIGNING <ls_key_all> WITH TABLE KEY entity = if_mdg_bs_mat_gen_c=>gc_entity_material.
    IF sy-subrc IS INITIAL.
      ASSIGN <ls_key_all>-r_data->* TO <lt_key>.
      lt_materials = <lt_key>.
    ELSE.
      RETURN.
    ENDIF.

    "Build selection tab for all materials in CR
    LOOP AT lt_materials ASSIGNING <lv_material>.
      ls_material_selection-fieldname = if_mdg_bs_mat_gen_c=>gc_fieldname_material.
      ls_material_selection-sign = usmd0_cs_ra-sign_i.
      ls_material_selection-option = usmd0_cs_ra-option_eq.
      ls_material_selection-low = <lv_material>.
      APPEND ls_material_selection TO lt_material_selection. "#EC CI_APPEND_OK
    ENDLOOP.

    "Read active data
    IF lt_material_selection IS NOT INITIAL.

      " Look for material entity in active data, if an existent material is changed (business activity = MAT2)
      " This call triggers the derivations BAdI and will cause mt_mm_pp_material to be filled afterwards
      LOOP AT io_model->if_usmd_model_metadata_ext~dt_entity_prop ASSIGNING <ls_entity_prop_ext> WHERE usage_type = 1. "#EC CI_SORTSEQ - accessing SAP default content in MDG
        lv_fieldname = <ls_entity_prop_ext>-usmd_entity.
        CALL METHOD go_model->read_entity_data_all
          EXPORTING
            i_fieldname    = lv_fieldname
            it_sel         = lt_material_selection
            if_active      = abap_true
          IMPORTING
            et_message     = lt_message
            et_data_entity = lt_data_entity_temp.
        INSERT LINES OF lt_data_entity_temp INTO TABLE et_entity_data_act.
        CLEAR: lv_fieldname.
        IF lt_message IS NOT INITIAL.
          RETURN.
        ENDIF.
      ENDLOOP.

      " add MATCHGMNG data
      CALL METHOD read_matchgmng_data
        EXPORTING
          it_materials   = lt_materials
          it_data_entity = et_entity_data_act
        IMPORTING
          et_matchgmng   = lt_matchgmng.

      INSERT LINES OF lt_matchgmng INTO TABLE et_entity_data_act.



    ENDIF.

  ENDMETHOD.


  METHOD read_entity_data_cr.

    TYPES: BEGIN OF ty_s_usmd1222,
             entity_type       TYPE usmd_entity,
             entity_key        TYPE usmd_entity_key_hash,
             entity_key_string TYPE usmd_entity_key_string,
           END OF ty_s_usmd1222,
           ty_t_usmd1222 TYPE SORTED TABLE OF ty_s_usmd1222 WITH UNIQUE KEY entity_type entity_key.

    CONSTANTS:
      c_prefix      TYPE string VALUE 'GT_',
      c_suffix_text TYPE string VALUE '_TXT'.

    DATA:
      lo_context               TYPE REF TO if_usmd_app_context,
      lo_model                 TYPE REF TO if_usmd_model_ext,
      lt_entity_data           TYPE usmd_ts_data_entity,
      lt_entity_data_act       TYPE usmd_ts_data_entity,
      ls_entity_data_act       TYPE usmd_sx_data_entity,
      lt_message               TYPE usmd_t_message,
      lv_entity                TYPE usmd_entity,
      lv_fieldname             TYPE usmd_fieldname,
      lr_entity_key_struc      TYPE REF TO data,
      lr_entity_key_struc_1222 TYPE REF TO data,
      lo_key_conv              TYPE REF TO if_usmd_key_conversion,
      lt_usmd1222              TYPE ty_t_usmd1222,
      lv_is_parallel           TYPE boolean,
      lv_found                 TYPE boolean,
      lv_updated               TYPE boolean,
      lr_entity                TYPE REF TO data,
      lv_entity_tabname        TYPE seocpdname,
      lt_data_entity_temp      TYPE usmd_ts_data_entity,
      ls_entity_data           TYPE usmd_sx_data_entity,
      lo_conv_api              TYPE REF TO if_usmd_conv_som_gov_api,
      lt_object_list           TYPE usmd_gov_api_t_ent_struc.

    FIELD-SYMBOLS:
      <ls_usmd1222>              TYPE ty_s_usmd1222,
      <ls_entity_data>           TYPE usmd_sx_data_entity,
      <ls_entity_data_act>       TYPE usmd_sx_data_entity,
      <lt_entity>                TYPE ANY TABLE,
      <lt_entity_act>            TYPE ANY TABLE,
      <ls_entity>                TYPE any,
      <ls_entity_act>            TYPE any,
      <ls_entity_key_struc>      TYPE any,
      <ls_entity_key_struc_1222> TYPE any,
      <lt_data>                  TYPE ANY TABLE,
      <lt_mt_entity>             TYPE SORTED TABLE,
      <lt_entity_data>           TYPE ANY TABLE,
      <ls_entity_prop_ext>       TYPE usmd_s_entity_prop_ext.

* Get CR Context
    CALL METHOD cl_usmd_app_context=>get_context
      RECEIVING
        eo_context = lo_context.

    IF lo_context IS NOT BOUND.
      RAISE app_context_get_failed.
    ENDIF.

*Get Model Instance and CR ID from the aplication context
    CALL METHOD lo_context->get_attributes
      IMPORTING
        eo_model = lo_model.
    IF lo_model IS NOT BOUND.
      RAISE appcontext_attribute_get_error.
    ENDIF.

    "Set key fields: CR ID, WI ID, Final status
    me->gv_crid = lo_context->mv_crequest_id.
    me->gv_wiid = lo_context->mv_wi_id.

    IF cl_usmd_crequest_util=>is_crequest_closed( i_crequest_status = cl_usmd_crequest_util=>get_cr_status_by_cr( i_crequest = lo_context->mv_crequest_id ) ).
      me->gv_final_status_set = abap_true.
    ENDIF.

    IF me->gv_final_status_set EQ abap_false.

* Read all data from Staging Area
      LOOP AT lo_model->if_usmd_model_metadata_ext~dt_entity_prop ASSIGNING <ls_entity_prop_ext> WHERE usage_type = 1. "#EC CI_SORTSEQ - accessing SAP default content in MDG
        lv_fieldname = <ls_entity_prop_ext>-usmd_entity.
        CALL METHOD go_model->read_entity_data_all
          EXPORTING
            i_fieldname    = lv_fieldname
            i_crequest     = lo_context->mv_crequest_id
            if_active      = abap_false
          IMPORTING
            et_message     = lt_message
            et_data_entity = lt_data_entity_temp.
        INSERT LINES OF lt_data_entity_temp INTO TABLE lt_entity_data.
        CLEAR: lv_fieldname.
        IF lt_message IS NOT INITIAL.
          RETURN.
        ENDIF.
      ENDLOOP.

* read the active area of the CR
      CALL METHOD read_active_data_of_cr
        EXPORTING
          iv_crequest        = lo_context->mv_crequest_id
          io_model           = lo_model
        IMPORTING
          et_entity_data_act = lt_entity_data_act.

*get the object list by using conv api
      IF cl_usmd_conv_som_gov_api=>check_instance_exists(
          iv_model_name = if_mdg_bs_mat_gen_c=>gc_model_mm ) EQ abap_true.
        TRY.

            lo_conv_api = cl_usmd_conv_som_gov_api=>get_instance(
                        iv_model_name = if_mdg_bs_mat_gen_c=>gc_model_mm ).

            lo_conv_api->set_environment(
              EXPORTING
                iv_crequest_id = lo_context->mv_crequest_id ).

            CHECK  lo_context->mv_crequest_id IS NOT INITIAL.

            lo_conv_api->get_object_list(
              IMPORTING
                et_object_list = lt_object_list ).

          CATCH cx_usmd_conv_som_gov_api ##NO_HANDLER.
          CATCH cx_usmd_app_context_cons_error ##NO_HANDLER.
          CATCH cx_usmd_conv_som_gov_api_env ##NO_HANDLER.
          CATCH cx_usmd_gov_api_core_error ##NO_HANDLER.
          CATCH cx_usmd_gov_api ##NO_HANDLER.

        ENDTRY.
      ENDIF.

* merge active data into entity data (staging data), in case it is not yet there and in case it is not part of the object list
      LOOP AT lt_entity_data_act ASSIGNING <ls_entity_data_act>.

        ASSIGN <ls_entity_data_act>-r_t_data->* TO <lt_entity>.
        CHECK <lt_entity> IS ASSIGNED.

        IF <ls_entity_data_act>-usmd_entity_cont IS INITIAL.
          lv_entity = <ls_entity_data_act>-usmd_entity.
        ELSE.
          lv_entity = <ls_entity_data_act>-usmd_entity_cont.
        ENDIF.

        READ TABLE lt_object_list WITH KEY entity = lv_entity TRANSPORTING NO FIELDS. "not part of the object list
        IF sy-subrc NE 0.

          READ TABLE lt_entity_data  WITH KEY usmd_entity = lv_entity TRANSPORTING NO FIELDS.
          IF sy-subrc NE 0.

            ls_entity_data-struct = <ls_entity_data_act>-struct.
            ls_entity_data-usmd_entity = <ls_entity_data_act>-usmd_entity.
            ls_entity_data-usmd_entity_cont = <ls_entity_data_act>-usmd_entity_cont.
            CREATE DATA ls_entity_data-r_t_data LIKE <lt_entity>.
            ASSIGN ls_entity_data-r_t_data->* TO <lt_entity_data>.
            MOVE-CORRESPONDING <lt_entity> TO <lt_entity_data>.

            INSERT ls_entity_data INTO TABLE lt_entity_data.

          ENDIF.
        ENDIF.

        CLEAR: lv_entity,ls_entity_data.
        UNASSIGN: <lt_entity>.
      ENDLOOP.


    ELSE.
      CALL METHOD read_active_data_of_cr
        EXPORTING
          iv_crequest        = lo_context->mv_crequest_id
          io_model           = lo_model
        IMPORTING
          et_entity_data_act = lt_entity_data.
    ENDIF.


    "If we have a CR type that has parallel processing enabled we have to remove changes from other CRs
    CALL METHOD cl_usmd2_cust_access_service=>is_parallel_cr_type
      EXPORTING
        iv_creq_type   = lo_context->mv_crequest_type
      RECEIVING
        rv_is_parallel = lv_is_parallel.

    IF lv_is_parallel EQ abap_true.
      SELECT entity_type entity_key entity_key_string FROM usmd1222 "#EC CI_SUBRC
        INTO TABLE lt_usmd1222
        WHERE crequest_id EQ lo_context->mv_crequest_id.

      "Get active data
      CALL METHOD read_active_data_of_cr
        EXPORTING
          iv_crequest        = lo_context->mv_crequest_id
          io_model           = lo_model
        IMPORTING
          et_entity_data_act = lt_entity_data_act.

      CALL METHOD cl_usmd_key_conversion=>get_instance
        RECEIVING
          ro_key_conversion = lo_key_conv.

      LOOP AT lt_usmd1222 ASSIGNING <ls_usmd1222>.
        lv_entity = <ls_usmd1222>-entity_type.
        lv_fieldname = lv_entity.

        CALL METHOD lo_model->create_data_reference
          EXPORTING
            i_fieldname = lv_fieldname
            i_struct    = lo_model->gc_struct_key
            if_table    = abap_false
          IMPORTING
            er_data     = lr_entity_key_struc_1222.
        ASSIGN lr_entity_key_struc_1222->* TO <ls_entity_key_struc_1222>.

        CALL METHOD lo_model->create_data_reference
          EXPORTING
            i_fieldname = lv_fieldname
            i_struct    = lo_model->gc_struct_key
            if_table    = abap_false
          IMPORTING
            er_data     = lr_entity_key_struc.
        ASSIGN lr_entity_key_struc->* TO <ls_entity_key_struc>.

        "Get key of change
        CALL METHOD lo_key_conv->string_tech_2_entity_key
          EXPORTING
            iv_key_string  = <ls_usmd1222>-entity_key_string
          IMPORTING
            ev_entity_type = lv_entity
            es_entity_key  = <ls_entity_key_struc_1222>.

        "Get the corresponding inactive data
        UNASSIGN <ls_entity_data>.
        READ TABLE lt_entity_data ASSIGNING <ls_entity_data>
          WITH KEY usmd_entity = if_mdg_bs_mat_gen_c=>gc_entity_material
                   usmd_entity_cont = lv_entity.
        IF sy-subrc IS NOT INITIAL.
          READ TABLE lt_entity_data ASSIGNING <ls_entity_data>
            WITH KEY usmd_entity = lv_entity
                     usmd_entity_cont = space.
        ENDIF.

        IF <ls_entity_data> IS ASSIGNED.
          ASSIGN <ls_entity_data>-r_t_data->* TO <lt_entity>.
          lv_found = abap_false.
          LOOP AT <lt_entity> ASSIGNING <ls_entity>.     "#EC CI_NESTED
            MOVE-CORRESPONDING <ls_entity> TO <ls_entity_key_struc>.
            IF <ls_entity_key_struc> EQ <ls_entity_key_struc_1222>.
              lv_found = abap_true.
              EXIT.
            ENDIF.
          ENDLOOP.

          "If found replace the act data with inact data
          "If NOT found we have a deletion -> remove from active data
          IF lv_found EQ abap_true.
            "Update or Insert
            UNASSIGN  <ls_entity_data_act>.
            READ TABLE lt_entity_data_act ASSIGNING <ls_entity_data_act>
              WITH KEY usmd_entity = if_mdg_bs_mat_gen_c=>gc_entity_material
                       usmd_entity_cont = lv_entity.
            IF sy-subrc IS NOT INITIAL.
              READ TABLE lt_entity_data_act ASSIGNING <ls_entity_data_act>
                WITH KEY usmd_entity = lv_entity
                         usmd_entity_cont = space.
            ENDIF.

            IF <ls_entity_data_act> IS ASSIGNED. "Update
              lv_updated = abap_false.
              ASSIGN <ls_entity_data_act>-r_t_data->* TO <lt_entity_act>.
              LOOP AT <lt_entity_act> ASSIGNING <ls_entity_act>. "#EC CI_NESTED
                MOVE-CORRESPONDING <ls_entity_act> TO <ls_entity_key_struc>.
                IF <ls_entity_key_struc> EQ <ls_entity_key_struc_1222>.
                  DELETE TABLE <lt_entity_act> FROM <ls_entity_act>. "#EC CI_ANYSEQ
                  INSERT <ls_entity> INTO TABLE <lt_entity_act>.
                  lv_updated = abap_true.
                  EXIT.
                ENDIF.
              ENDLOOP.
              IF lv_updated EQ abap_false. "Insert new entry
                INSERT <ls_entity> INTO TABLE <lt_entity_act>.
              ENDIF.
            ELSE. "Insert
              CLEAR ls_entity_data_act.
              ls_entity_data_act-struct = <ls_entity_data>-struct.
              ls_entity_data_act-usmd_entity = <ls_entity_data>-usmd_entity.
              ls_entity_data_act-usmd_entity_cont = <ls_entity_data>-usmd_entity_cont.
              CREATE DATA ls_entity_data_act-r_t_data LIKE <lt_entity>.
              ASSIGN ls_entity_data_act-r_t_data->* TO <lt_entity_act>.
              INSERT <ls_entity> INTO TABLE <lt_entity_act>.
              INSERT ls_entity_data_act INTO TABLE lt_entity_data_act.
            ENDIF.


          ELSE. "delete
            UNASSIGN  <ls_entity_data_act>.
            READ TABLE lt_entity_data_act ASSIGNING <ls_entity_data_act>
              WITH KEY usmd_entity = if_mdg_bs_mat_gen_c=>gc_entity_material
                       usmd_entity_cont = lv_entity.
            IF sy-subrc IS NOT INITIAL.
              READ TABLE lt_entity_data_act ASSIGNING <ls_entity_data_act>
                WITH KEY usmd_entity = lv_entity
                         usmd_entity_cont = space.
            ENDIF.
            IF <ls_entity_data_act> IS ASSIGNED.
              ASSIGN <ls_entity_data_act>-r_t_data->* TO <lt_entity_act>.
              LOOP AT <lt_entity_act> ASSIGNING <ls_entity_act>. "#EC CI_NESTED
                MOVE-CORRESPONDING <ls_entity_act> TO <ls_entity_key_struc>.
                IF <ls_entity_key_struc> EQ <ls_entity_key_struc_1222>.
                  DELETE TABLE <lt_entity_act> FROM <ls_entity_act>. "#EC CI_ANYSEQ
                ENDIF.
              ENDLOOP.
            ENDIF."IF <ls_entity_data_act> IS ASSIGNED.
          ENDIF.
        ELSE. "Delete
          UNASSIGN  <ls_entity_data_act>.
          READ TABLE lt_entity_data_act ASSIGNING <ls_entity_data_act>
            WITH KEY usmd_entity = if_mdg_bs_mat_gen_c=>gc_entity_material
                     usmd_entity_cont = lv_entity.
          IF sy-subrc IS NOT INITIAL.
            READ TABLE lt_entity_data_act ASSIGNING <ls_entity_data_act>
              WITH KEY usmd_entity = lv_entity
                       usmd_entity_cont = space.
          ENDIF.
          IF <ls_entity_data_act> IS ASSIGNED.
            ASSIGN <ls_entity_data_act>-r_t_data->* TO <lt_entity_act>.
            LOOP AT <lt_entity_act> ASSIGNING <ls_entity_act>. "#EC CI_NESTED
              MOVE-CORRESPONDING <ls_entity_act> TO <ls_entity_key_struc>.
              IF <ls_entity_key_struc> EQ <ls_entity_key_struc_1222>.
                DELETE TABLE <lt_entity_act> FROM <ls_entity_act>. "#EC CI_ANYSEQ
              ENDIF.
            ENDLOOP.
          ENDIF."IF <ls_entity_data_act> IS ASSIGNED.
        ENDIF.
      ENDLOOP.

      lt_entity_data = lt_entity_data_act.
    ENDIF. "IF lv_is_parallel EQ abap_true.



    "Now we have gathered the correct data
    "It has to be stored in the GTs
* Transform untyped to typed data
    LOOP AT lt_entity_data ASSIGNING <ls_entity_data>.
      CLEAR: lv_entity_tabname, lr_entity.
      UNASSIGN: <ls_entity>, <lt_data>, <lt_mt_entity>.
* Construct export table name and assign it to field symbol (it's used to fill the related mt)

      CASE <ls_entity_data>-struct.
        WHEN if_usmd_model_ext=>gc_struct_key_attr.
          IF <ls_entity_data>-usmd_entity_cont IS INITIAL.
            CONCATENATE c_prefix <ls_entity_data>-usmd_entity INTO lv_entity_tabname.
          ELSE.
            CONCATENATE c_prefix <ls_entity_data>-usmd_entity_cont INTO lv_entity_tabname.
          ENDIF.
        WHEN if_usmd_model_ext=>gc_struct_key_txt_langu.
          IF <ls_entity_data>-usmd_entity_cont IS INITIAL.
            IF <ls_entity_data>-usmd_entity = if_mdg_bs_mat_gen_c~gc_entity_material.
              CONCATENATE c_prefix zcl_mdg_mm_helper=>cs_entities-material_txt INTO lv_entity_tabname.
            ELSE.
              CONCATENATE c_prefix <ls_entity_data>-usmd_entity c_suffix_text INTO lv_entity_tabname.
            ENDIF.
          ELSE.
            CONCATENATE c_prefix <ls_entity_data>-usmd_entity_cont c_suffix_text INTO lv_entity_tabname.
          ENDIF.
      ENDCASE.

* write data to gt_* tables
      ASSIGN (lv_entity_tabname) TO <lt_mt_entity>.       "#EC CI_SUBRC
      IF <lt_mt_entity> IS NOT ASSIGNED.
        MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_mm TYPE 'X' NUMBER 002 WITH lv_entity_tabname INTO zcl_mdg_general_functions=>gv_error_message ##MG_MISSING.
        RAISE dyn_assignment_failed.
      ENDIF.

      CREATE DATA lr_entity LIKE LINE OF <lt_mt_entity>.
      ASSIGN lr_entity->* TO <ls_entity>.
      IF <ls_entity> IS NOT ASSIGNED.
        MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_mm TYPE 'X' NUMBER 002 WITH lv_entity_tabname INTO zcl_mdg_general_functions=>gv_error_message ##MG_MISSING.
        RAISE dyn_assignment_failed.
      ENDIF.

      CLEAR: <ls_entity>, <lt_mt_entity>.

      ASSIGN <ls_entity_data>-r_t_data->* TO <lt_data>.
      IF sy-subrc <> 0.
        MESSAGE ID zcl_mdg_general_functions=>gc_msg_class_dm_mm TYPE 'X' NUMBER 002 WITH lv_entity_tabname INTO zcl_mdg_general_functions=>gv_error_message ##MG_MISSING.
        RAISE dyn_assignment_failed.
      ENDIF.

      IF <lt_data> IS ASSIGNED.
        MOVE-CORRESPONDING <lt_data> TO <lt_mt_entity>.
      ENDIF.

    ENDLOOP.

    CALL METHOD transfer_txtmi_instantiation.



*
*      CALL METHOD cl_usmd_app_context=>get_context
*        RECEIVING
*          eo_context = lo_context.
*
*      IF lo_context IS NOT BOUND.
*        RAISE app_context_get_failed.
*      ENDIF.
*
**Get Model Instance and CR ID from the aplication context
*      CALL METHOD lo_context->get_attributes
*        IMPORTING
*          eo_model = lo_model.
*      IF lo_model IS NOT BOUND.
*        RAISE appcontext_attribute_get_error.
*      ENDIF.
*
*      "Set key fields
*      "CR ID
*      "WI ID
*      "Final status
*      me->gv_crid = lo_context->mv_crequest_id.
*      me->gv_wiid = lo_context->mv_wi_id.
*
*      IF cl_usmd_crequest_util=>is_crequest_closed( i_crequest_status = cl_usmd_crequest_util=>get_cr_status_by_cr( i_crequest = lo_context->mv_crequest_id ) ).
*        me->gv_final_status_set = abap_true.
*      ENDIF.
*
*      IF me->gv_final_status_set EQ abap_false.
**read all material entity DATA from staging area
*        CALL METHOD lo_model->read_entity_data_all
*          EXPORTING
*            i_fieldname    = if_mdg_bs_mat_gen_c=>gc_fieldname_material
*            i_crequest     = lo_context->mv_crequest_id
*            if_active      = abap_false
*          IMPORTING
*            et_message     = lt_message
*            et_data_entity = lt_entity_data.
*
**Read all dradbasic(document) entity data from staging area
*        CALL METHOD lo_model->read_entity_data_all
*          EXPORTING
*            i_fieldname    = ZCL_MDG_MM_helper=>scs_fields-dradbasic
*            i_crequest     = lo_context->mv_crequest_id
*            if_active      = abap_false
*          IMPORTING
*            et_message     = lt_message
*            et_data_entity = lt_entity_data_dradbasic.
*
*        INSERT LINES OF lt_entity_data_dradbasic INTO TABLE lt_entity_data.
*
*      ELSE.
*        CALL METHOD read_active_data_of_cr
*          EXPORTING
*            iv_crequest        = lo_context->mv_crequest_id
*            io_model           = lo_model
*          IMPORTING
*            et_entity_data_act = lt_entity_data.
*      ENDIF.
*
*
*      "If we have a CR type that has parallel processing enabled we have to remove changes from other CRs
*      CALL METHOD cl_usmd2_cust_access_service=>is_parallel_cr_type
*        EXPORTING
*          iv_creq_type   = lo_context->mv_crequest_type
*        RECEIVING
*          rv_is_parallel = lv_is_parallel.
*
*      IF lv_is_parallel EQ abap_true.
*        SELECT entity_type entity_key entity_key_string FROM usmd1222
*          INTO TABLE lt_usmd1222
*          WHERE crequest_id EQ lo_context->mv_crequest_id.
*
*        "Get active data
*        CALL METHOD read_active_data_of_cr
*          EXPORTING
*            iv_crequest        = lo_context->mv_crequest_id
*            io_model           = lo_model
*          IMPORTING
*            et_entity_data_act = lt_entity_data_act.
*
*        CALL METHOD cl_usmd_key_conversion=>get_instance
*          RECEIVING
*            ro_key_conversion = lo_key_conv.
*
*        LOOP AT lt_usmd1222 ASSIGNING <ls_usmd1222>.
*          lv_entity = <ls_usmd1222>-entity_type.
*          lv_fieldname = lv_entity.
*
*          CALL METHOD lo_model->create_data_reference
*            EXPORTING
*              i_fieldname = lv_fieldname
*              i_struct    = lo_model->gc_struct_key
*              if_table    = abap_false
*            IMPORTING
*              er_data     = lr_entity_key_struc_1222.
*          ASSIGN lr_entity_key_struc_1222->* TO <ls_entity_key_struc_1222>.
*
*          CALL METHOD lo_model->create_data_reference
*            EXPORTING
*              i_fieldname = lv_fieldname
*              i_struct    = lo_model->gc_struct_key
*              if_table    = abap_false
*            IMPORTING
*              er_data     = lr_entity_key_struc.
*          ASSIGN lr_entity_key_struc->* TO <ls_entity_key_struc>.
*
*          "Get key of change
*          CALL METHOD lo_key_conv->string_tech_2_entity_key
*            EXPORTING
*              iv_key_string  = <ls_usmd1222>-entity_key_string
*            IMPORTING
*              ev_entity_type = lv_entity
*              es_entity_key  = <ls_entity_key_struc_1222>.
*
*          "Get the corresponding inactive data
*          UNASSIGN <ls_entity_data>.
*          READ TABLE lt_entity_data ASSIGNING <ls_entity_data>
*            WITH KEY usmd_entity = if_mdg_bs_mat_gen_c=>gc_entity_material
*                     usmd_entity_cont = lv_entity.
*          IF sy-subrc IS NOT INITIAL.
*            READ TABLE lt_entity_data ASSIGNING <ls_entity_data>
*              WITH KEY usmd_entity = lv_entity
*                       usmd_entity_cont = space.
*          ENDIF.
*
*          IF <ls_entity_data> IS ASSIGNED.
*            ASSIGN <ls_entity_data>-r_t_data->* TO <lt_entity>.
*            lv_found = abap_false.
*            LOOP AT <lt_entity> ASSIGNING <ls_entity>.
*              MOVE-CORRESPONDING <ls_entity> TO <ls_entity_key_struc>.
*              IF <ls_entity_key_struc> EQ <ls_entity_key_struc_1222>.
*                lv_found = abap_true.
*                EXIT.
*              ENDIF.
*            ENDLOOP.
*
*            "If found replace the act data with inact data
*            "If NOT found we have a deletion -> remove from active data
*            IF lv_found EQ abap_true.
*              "Update or Insert
*              UNASSIGN  <ls_entity_data_act>.
*              READ TABLE lt_entity_data_act ASSIGNING <ls_entity_data_act>
*                WITH KEY usmd_entity = if_mdg_bs_mat_gen_c=>gc_entity_material
*                         usmd_entity_cont = lv_entity.
*              IF sy-subrc IS NOT INITIAL.
*                READ TABLE lt_entity_data_act ASSIGNING <ls_entity_data_act>
*                  WITH KEY usmd_entity = lv_entity
*                           usmd_entity_cont = space.
*              ENDIF.
*
*              IF <ls_entity_data_act> IS ASSIGNED. "Update
*                lv_updated = abap_false.
*                ASSIGN <ls_entity_data_act>-r_t_data->* TO <lt_entity_act>.
*                LOOP AT <lt_entity_act> ASSIGNING <ls_entity_act>.
*                  MOVE-CORRESPONDING <ls_entity_act> TO <ls_entity_key_struc>.
*                  IF <ls_entity_key_struc> EQ <ls_entity_key_struc_1222>.
*                    DELETE TABLE <lt_entity_act> FROM <ls_entity_act>.
*                    INSERT <ls_entity> INTO TABLE <lt_entity_act>.
*                    lv_updated = abap_true.
*                    EXIT.
*                  ENDIF.
*                ENDLOOP.
*                IF lv_updated EQ abap_false. "Insert new entry
*                  INSERT <ls_entity> INTO TABLE <lt_entity_act>.
*                ENDIF.
*              ELSE. "Insert
*                CLEAR ls_entity_data_act.
*                ls_entity_data_act-struct = <ls_entity_data>-struct.
*                ls_entity_data_act-usmd_entity = <ls_entity_data>-usmd_entity.
*                ls_entity_data_act-usmd_entity_cont = <ls_entity_data>-usmd_entity_cont.
*                CREATE DATA ls_entity_data_act-r_t_data LIKE <lt_entity>.
*                ASSIGN ls_entity_data_act-r_t_data->* TO <lt_entity_act>.
*                INSERT <ls_entity> INTO TABLE <lt_entity_act>.
*                INSERT ls_entity_data_act INTO TABLE lt_entity_data_act.
*              ENDIF.
*
*
*            ELSE. "delete
*              UNASSIGN  <ls_entity_data_act>.
*              READ TABLE lt_entity_data_act ASSIGNING <ls_entity_data_act>
*                WITH KEY usmd_entity = if_mdg_bs_mat_gen_c=>gc_entity_material
*                         usmd_entity_cont = lv_entity.
*              IF sy-subrc IS NOT INITIAL.
*                READ TABLE lt_entity_data_act ASSIGNING <ls_entity_data_act>
*                  WITH KEY usmd_entity = lv_entity
*                           usmd_entity_cont = space.
*              ENDIF.
*              IF <ls_entity_data_act> IS ASSIGNED.
*                ASSIGN <ls_entity_data_act>-r_t_data->* TO <lt_entity_act>.
*                LOOP AT <lt_entity_act> ASSIGNING <ls_entity_act>.
*                  MOVE-CORRESPONDING <ls_entity_act> TO <ls_entity_key_struc>.
*                  IF <ls_entity_key_struc> EQ <ls_entity_key_struc_1222>.
*                    DELETE TABLE <lt_entity_act> FROM <ls_entity_act>.
*                  ENDIF.
*                ENDLOOP.
*              ENDIF."IF <ls_entity_data_act> IS ASSIGNED.
*            ENDIF.
*          ELSE. "Delete
*            UNASSIGN  <ls_entity_data_act>.
*            READ TABLE lt_entity_data_act ASSIGNING <ls_entity_data_act>
*              WITH KEY usmd_entity = if_mdg_bs_mat_gen_c=>gc_entity_material
*                       usmd_entity_cont = lv_entity.
*            IF sy-subrc IS NOT INITIAL.
*              READ TABLE lt_entity_data_act ASSIGNING <ls_entity_data_act>
*                WITH KEY usmd_entity = lv_entity
*                         usmd_entity_cont = space.
*            ENDIF.
*            IF <ls_entity_data_act> IS ASSIGNED.
*              ASSIGN <ls_entity_data_act>-r_t_data->* TO <lt_entity_act>.
*              LOOP AT <lt_entity_act> ASSIGNING <ls_entity_act>.
*                MOVE-CORRESPONDING <ls_entity_act> TO <ls_entity_key_struc>.
*                IF <ls_entity_key_struc> EQ <ls_entity_key_struc_1222>.
*                  DELETE TABLE <lt_entity_act> FROM <ls_entity_act>.
*                ENDIF.
*              ENDLOOP.
*            ENDIF."IF <ls_entity_data_act> IS ASSIGNED.
*          ENDIF.
*        ENDLOOP.
*
*        lt_entity_data = lt_entity_data_act.
*      ENDIF. "IF lv_is_parallel EQ abap_true.
*
*
*
*      "Now we have gathered the correct data
*      "It has to be stored in the GTs
** Transform untyped to typed data
*      LOOP AT lt_entity_data ASSIGNING <ls_entity_data>.
*        CLEAR: lv_entity_tabname, lr_entity.
*        UNASSIGN: <ls_entity>, <lt_data>, <lt_mt_entity>.
** Construct export table name and assign it to field symbol (it's used to fill the related mt)
*
*        CASE <ls_entity_data>-struct.
*          WHEN if_usmd_model_ext=>gc_struct_key_attr.
*            IF <ls_entity_data>-usmd_entity_cont IS INITIAL.
*              CONCATENATE lc_prefix <ls_entity_data>-usmd_entity INTO lv_entity_tabname.
*            ELSE.
*              CONCATENATE lc_prefix <ls_entity_data>-usmd_entity_cont INTO lv_entity_tabname.
*            ENDIF.
*          WHEN if_usmd_model_ext=>gc_struct_key_txt_langu.
*            IF <ls_entity_data>-usmd_entity_cont IS INITIAL.
*              IF <ls_entity_data>-usmd_entity = if_mdg_bs_mat_gen_c~gc_entity_material.
*                CONCATENATE lc_prefix ZCL_MDG_MM_helper=>cs_entities-material_txt INTO lv_entity_tabname.
*              ELSE.
*                CONCATENATE lc_prefix <ls_entity_data>-usmd_entity lc_suffix_text INTO lv_entity_tabname.
*              ENDIF.
*            ELSE.
*              CONCATENATE lc_prefix <ls_entity_data>-usmd_entity_cont lc_suffix_text INTO lv_entity_tabname.
*            ENDIF.
*        ENDCASE.
*
** write data to gt_* tables
*        ASSIGN (lv_entity_tabname) TO <lt_mt_entity>.     "#EC CI_SUBRC
*        IF <lt_mt_entity> IS NOT ASSIGNED.
*          MESSAGE ID ZCL_MDG_general_functions=>gc_msg_class_dm_mm TYPE 'X' NUMBER 002 WITH lv_entity_tabname INTO ZCL_MDG_general_functions=>gv_error_message.
*          RAISE dyn_assignment_failed.
*        ENDIF.
*
*        CREATE DATA lr_entity LIKE LINE OF <lt_mt_entity>.
*        ASSIGN lr_entity->* TO <ls_entity>.
*        IF <ls_entity> IS NOT ASSIGNED.
*          MESSAGE ID ZCL_MDG_general_functions=>gc_msg_class_dm_mm TYPE 'X' NUMBER 002 WITH lv_entity_tabname INTO ZCL_MDG_general_functions=>gv_error_message.
*          RAISE dyn_assignment_failed.
*        ENDIF.
*
*        CLEAR: <ls_entity>, <lt_mt_entity>.
*
*        ASSIGN <ls_entity_data>-r_t_data->* TO <lt_data>.
*        IF sy-subrc <> 0.
*          MESSAGE ID ZCL_MDG_general_functions=>gc_msg_class_dm_mm TYPE 'X' NUMBER 002 WITH lv_entity_tabname INTO ZCL_MDG_general_functions=>gv_error_message.
*          RAISE dyn_assignment_failed.
*        ENDIF.
*
*        IF <lt_data> IS ASSIGNED.
*          MOVE-CORRESPONDING <lt_data> TO <lt_mt_entity>.
*        ENDIF.
*
*      ENDLOOP.
*
*    CALL METHOD transfer_txtmi_instantiation.


  ENDMETHOD.


  METHOD read_matchgmng_data.

    DATA:
      lr_data              TYPE REF TO data,
      ls_matchgmng         TYPE /mdgmm/_s_mm_pp_matchgmng,
      ls_type1_entity_data TYPE usmd_sx_data_entity,
      lt_aeoi_tmp          TYPE SORTED TABLE OF aeoi WITH UNIQUE KEY aennr aetyp objkt,
      lt_aeoi              TYPE TABLE OF aeoi.

    FIELD-SYMBOLS:
      <lv_material>    TYPE matnr,
      <ls_data_entity> TYPE usmd_sx_data_entity,
      <ls_aeoi>        TYPE aeoi,
      <lt_data>        TYPE zif_mdg_mm_datatypes=>gty_t_matchgmng.

    CLEAR: et_matchgmng.

    LOOP AT it_materials ASSIGNING <lv_material>.

      CLEAR: lt_aeoi_tmp, lt_aeoi.

* material change management data
      CALL METHOD go_matchgmng_api->read_chgmng
        EXPORTING
          iv_matnr = <lv_material>
        IMPORTING
          et_aeoi  = lt_aeoi_tmp.

      LOOP AT lt_aeoi_tmp ASSIGNING <ls_aeoi>. "#EC CI_NESTED
        INSERT <ls_aeoi> INTO TABLE lt_aeoi.
      ENDLOOP.
      SORT lt_aeoi DESCENDING BY revlv. "#EC CI_SORTLOOP

      IF lt_aeoi IS NOT INITIAL.

        " check if an entry for MATCHGMNG already is staging area
        READ TABLE it_data_entity WITH KEY usmd_entity = 'MATCHGMNG' ASSIGNING <ls_data_entity>.
        IF sy-subrc = 0 AND <ls_data_entity> IS ASSIGNED.

          " entry exists -> modify data for this entry
          ASSIGN <ls_data_entity>-r_t_data->* TO <lt_data>.

          LOOP AT lt_aeoi ASSIGNING <ls_aeoi>. "#EC CI_NESTED
            CLEAR ls_matchgmng.
            ls_matchgmng-material  = <lv_material>.
            ls_matchgmng-matchgmng = iv_crequest.
            ls_matchgmng-ecochgmng = <ls_aeoi>-aennr.
            ls_matchgmng-revchgmng = <ls_aeoi>-revlv.
            INSERT ls_matchgmng INTO TABLE <lt_data>.
          ENDLOOP.

          " no entry exists -> it has to be created from scratch
        ELSE.
          CLEAR: lr_data.
          CALL METHOD go_model->create_data_reference
            EXPORTING
              i_fieldname = 'MATCHGMNG'
              i_struct    = if_usmd_model=>gc_struct_key_attr
              i_tabtype   = if_usmd_model=>gc_tabtype_sorted
            IMPORTING
              er_data     = lr_data.
          ASSIGN lr_data->* TO <lt_data>.

          LOOP AT lt_aeoi ASSIGNING <ls_aeoi>. "#EC CI_NESTED
            CLEAR ls_matchgmng.
            ls_matchgmng-material  = <lv_material>.
            ls_matchgmng-matchgmng = iv_crequest.
            ls_matchgmng-ecochgmng = <ls_aeoi>-aennr.
            ls_matchgmng-revchgmng = <ls_aeoi>-revlv.
            INSERT ls_matchgmng INTO TABLE <lt_data>.
          ENDLOOP.
          CLEAR: ls_type1_entity_data.
          ls_type1_entity_data-usmd_entity = 'MATCHGMNG'.
          ls_type1_entity_data-struct      = if_usmd_model=>gc_struct_key_attr.
          ls_type1_entity_data-r_t_data    = lr_data.
          INSERT ls_type1_entity_data INTO TABLE et_matchgmng.
        ENDIF.
      ENDIF.

    ENDLOOP.

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
