CLASS zcl_mdg_mm_helper_utilities DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_s_plant_data ,
        werks TYPE werks_d,
        beskz TYPE beskz,
      END OF ty_s_plant_data .
    TYPES:
      ty_t_plant_data TYPE STANDARD TABLE OF ty_s_plant_data .

    CLASS-METHODS get_mat_details_from_crequest
      IMPORTING
        !iv_crequest TYPE usmd_crequest
      EXPORTING
        !ev_werks    TYPE werks_d
        !ev_mtart    TYPE mtart
        !ev_beskz    TYPE beskz
        !ev_matnr    TYPE matnr
        !ev_matkl    TYPE matkl
        !et_werks    TYPE ty_t_plant_data .
    CLASS-METHODS read_crequest
      IMPORTING
        !iv_crequest   TYPE usmd_crequest
        !iv_usmd_model TYPE usmd_model
      EXPORTING
        !es_crequest   TYPE usmd_s_crequest .
    CLASS-METHODS get_matnr_from_crequest
      IMPORTING
        !iv_cr_number   TYPE usmd_crequest
      RETURNING
        VALUE(rv_matnr) TYPE matnr .
  PROTECTED SECTION.
  PRIVATE SECTION.
*    TYPES:
*      BEGIN OF ty_s_key_value,
*        key   TYPE usmd_value,
*        value TYPE smt_fixed_value,
*      END OF ty_s_key_value .
*    TYPES:
*      ty_t_key_value TYPE STANDARD TABLE OF ty_s_key_value WITH KEY key .
*    TYPES:
*      BEGIN OF ty_s_changed_field,
*        entity    TYPE usmd_entity,
*        attribute TYPE usmd_attribute,
*        key_value TYPE ty_t_key_value,
*        old_value TYPE usmd_value,
*        new_value TYPE usmd_value,
*      END OF ty_s_changed_field .
*    TYPES:
*      ty_t_changed_field TYPE STANDARD TABLE OF ty_s_changed_field WITH KEY entity attribute .
*    TYPES:
*      BEGIN OF ty_s_change_doc,
*        user     TYPE xubname,
*        doc_num  TYPE cdchangenr,
*        chng_fld TYPE ty_t_changed_field,
*      END OF ty_s_change_doc .
ENDCLASS.



CLASS ZCL_MDG_MM_HELPER_UTILITIES IMPLEMENTATION.


  METHOD get_matnr_from_crequest.
    "Get Model Instance
    cl_usmd_model_ext=>get_instance( EXPORTING i_usmd_model = 'MM'
                                     IMPORTING eo_instance  = DATA(lo_model) ).

    IF lo_model IS BOUND.
      "Get Model Object List
      lo_model->if_usmd_model_cr_ext~get_cr_objectlist( EXPORTING i_crequest = iv_cr_number
                                                        IMPORTING et_key_all = DATA(lt_key_all) ).
      "Get MATERIAL Entity Keys
      READ TABLE lt_key_all ASSIGNING FIELD-SYMBOL(<ls_key_all>) WITH KEY entity = 'MATERIAL'.
      IF <ls_key_all> IS ASSIGNED.
        FIELD-SYMBOLS <lt_data> TYPE ANY TABLE.
        ASSIGN <ls_key_all>-r_data->* TO <lt_data>.
        IF <lt_data> IS ASSIGNED.
          LOOP AT <lt_data> ASSIGNING FIELD-SYMBOL(<ls_data>).
            rv_matnr = <ls_data>.
            EXIT.
          ENDLOOP.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD get_mat_details_from_crequest.

    DATA:
         lo_model         TYPE REF TO if_usmd_model_ext,
##NEEDED  lt_message       TYPE usmd_t_message,
         lt_entities      TYPE usmd_t_entity,
          ls_plant_data TYPE ty_s_plant_data,
          lt_plant_data TYPE ty_t_plant_data.

    FIELD-SYMBOLS:
      <lt_data_ent> TYPE ANY TABLE,
      <ls_data_ent> TYPE any,
      <lv_werks>       TYPE any,
      <lv_beskz>       TYPE any.

    FIELD-SYMBOLS:
      <lt_mm_data_ent> TYPE ANY TABLE,
      <ls_mm_data_ent> TYPE any,
      <lv_matnr>       TYPE any,
      <lv_matkl>       TYPE any,
      <lv_mtart>       TYPE any.

*   Return Instance of IF_USMD_MODEL_EXT
    cl_usmd_model_ext=>get_instance(
        EXPORTING
          i_usmd_model = 'MM'
        IMPORTING
          eo_instance  = lo_model
          et_message   = lt_message
    ).

    CHECK lo_model IS NOT INITIAL.

*  Gets Staging Data
    lo_model->read_entity_data_all(
   EXPORTING
     i_fieldname      = if_mdg_bs_mat_gen_c=>gc_fieldname_material
     if_active        = abap_false
     i_crequest       = iv_crequest
     it_entity_filter = lt_entities
   IMPORTING
     et_message       = lt_message
     et_data_entity   = DATA(lt_data_entity)
     ).
*   Read Material Related Data
    READ TABLE lt_data_entity WITH TABLE KEY struct = 'KATTR' usmd_entity = 'MATERIAL' usmd_entity_cont = '' INTO DATA(ls_data_entity).

    IF sy-subrc EQ 0.
      ASSIGN ls_data_entity-r_t_data->*  TO <lt_mm_data_ent>.
      CHECK <lt_mm_data_ent> IS ASSIGNED.

      LOOP AT  <lt_mm_data_ent> ASSIGNING <ls_mm_data_ent>.
        ASSIGN COMPONENT 'MTART' OF STRUCTURE <ls_mm_data_ent> TO <lv_mtart>.
        IF sy-subrc EQ 0.
          ev_mtart = <lv_mtart>.
        ENDIF.
        ASSIGN COMPONENT 'MATKL' OF STRUCTURE <ls_mm_data_ent> TO <lv_matkl>.
        IF sy-subrc EQ 0.
          ev_matkl = <lv_matkl>.
        ENDIF.
        ASSIGN COMPONENT 'MATERIAL' OF STRUCTURE <ls_mm_data_ent> TO <lv_matnr>.
        IF sy-subrc EQ 0.
          ev_matnr = <lv_matnr>.
        ENDIF.
      ENDLOOP.

    ENDIF.

*   Read Plant Related Data
    READ TABLE lt_data_entity WITH TABLE KEY struct = 'KATTR' usmd_entity = 'MATERIAL' usmd_entity_cont = 'MARCBASIC' INTO DATA(ls_data_entity_marc).

    IF sy-subrc = 0.
      ASSIGN ls_data_entity_marc-r_t_data->*  TO <lt_data_ent>.
      CHECK <lt_data_ent> IS ASSIGNED.

      LOOP AT  <lt_data_ent> ASSIGNING <ls_data_ent>.
*       Reads Plant
        ASSIGN COMPONENT 'WERKS' OF STRUCTURE <ls_data_ent> TO <lv_werks>.
        IF <lv_werks> IS ASSIGNED.
          ev_werks = <lv_werks>.
          ls_plant_data-werks = <lv_werks>.
        ENDIF.
*       Reads Procurement Type
        ASSIGN COMPONENT 'BESKZ' OF STRUCTURE <ls_data_ent> TO <lv_beskz>.
        IF <lv_beskz> IS ASSIGNED.
          ev_beskz = <lv_beskz>.
          ls_plant_data-beskz = <lv_beskz>.
        ENDIF.
        INSERT ls_plant_data INTO TABLE lt_plant_data.
      ENDLOOP.
    ENDIF.
*
*   Returns all plants that assigned to the material
    et_werks = lt_plant_data.

  ENDMETHOD.


  METHOD read_crequest.

*&---------------------------------------------------------------------*

    DATA lr_model       TYPE REF TO if_usmd_model_ext.
    DATA lt_sel         TYPE usmd_ts_sel.
    DATA ls_sel         TYPE usmd_s_sel.
    DATA lt_crequest    TYPE usmd_ts_crequest.

    CLEAR: es_crequest.
*   Get read-only access to USMD model data
    CALL METHOD cl_usmd_model_ext=>get_instance
      EXPORTING
        i_usmd_model = iv_usmd_model
      IMPORTING
        eo_instance  = lr_model.
*   Read the CR itself (to get the CR type)
    ls_sel-sign      = 'I'.
    ls_sel-option    = 'EQ'.
    ls_sel-fieldname = usmd0_cs_fld-crequest.
    ls_sel-low       = iv_crequest.
    INSERT ls_sel INTO TABLE lt_sel.
    CALL METHOD lr_model->read_char_value
      EXPORTING
        i_fieldname       = usmd0_cs_fld-crequest
        it_sel            = lt_sel
        if_use_edtn_slice = abap_false
      IMPORTING
        et_data           = lt_crequest.
    READ TABLE lt_crequest INTO es_crequest INDEX 1.
    ASSERT sy-subrc = 0. " CR not found



  ENDMETHOD.
ENDCLASS.
