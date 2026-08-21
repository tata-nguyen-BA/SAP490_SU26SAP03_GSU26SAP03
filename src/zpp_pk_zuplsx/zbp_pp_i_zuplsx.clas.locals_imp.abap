CLASS lhc_UploadLog DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR UploadLog RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ UploadLog RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK UploadLog.

    METHODS uploadFromExcel FOR MODIFY
      IMPORTING keys FOR ACTION UploadLog~uploadFromExcel RESULT result.

ENDCLASS.

CLASS lhc_UploadLog IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD uploadFromExcel.

*"ThaoNTT add authority
*    AUTHORITY-CHECK OBJECT 'Z_UPLOAD'
*      ID 'ZUPLMOD' FIELD 'PP'
*      ID 'ACTVT'   FIELD '01'
*      ID 'WERKS'   DUMMY.
*    IF sy-subrc <> 0.
*      LOOP AT keys INTO DATA(ls_auth_key).
*        APPEND VALUE #( %cid   = ls_auth_key-%cid
*                        %param = VALUE #( Type    = 'Error'
*                                          Message = 'Bạn không có quyền upload lệnh sản xuất' ) ) TO result.
*      ENDLOOP.
*      RETURN.
*    ENDIF.
*"End add

    LOOP AT keys INTO DATA(ls_key).

      " --- 1. Parse JSON ---
      DATA ls_request TYPE zpp_if_zuplsx_types=>ts_post_request.

      CLEAR ls_request.
      TRY.
          xco_cp_json=>data->from_string( ls_key-%param-PayloadJson )->apply(
              VALUE #( ( xco_cp_json=>transformation->camel_case_to_underscore ) )
          )->write_to( REF #( ls_request ) ).
        CATCH cx_root INTO DATA(lx_parse).
          APPEND VALUE #( %cid   = ls_key-%cid
                          %param = VALUE #( Type    = 'Error'
                                            Message = |JSON parse error: { lx_parse->get_text( ) }| )
                        ) TO result.
          CONTINUE.
      ENDTRY.

      "ThaoNTT add
      " --- 1b. Kiểm quyền theo email từ Work Zone ---
      DATA(lv_auth_err) = zih_cl_auth=>check(
        iv_email      = ls_request-useremail
        iv_process_id = zih_cl_auth=>gc_mod_pp
        iv_actvt      = zih_cl_auth=>gc_act_post ).
      IF lv_auth_err IS NOT INITIAL.
        APPEND VALUE #( %cid   = ls_key-%cid
                        %param = VALUE #( Type    = 'Error'
                                          Message = lv_auth_err ) ) TO result.
        CONTINUE.
      ENDIF.

      " --- 2. Validate (chỉ đọc/convert, không modify -> hợp lệ) ---
      DATA(lo_validator) = NEW zpp_cl_zuplsx_validator( is_request = ls_request ).
      DATA ls_data   TYPE zpp_if_zuplsx_types=>ts_data.
      DATA lt_errors TYPE zpp_if_zuplsx_types=>tt_results.
      CLEAR: ls_data, lt_errors.

*      IF lo_validator->validate( IMPORTING es_data   = ls_data
*                                           et_errors = lt_errors ) = abap_true.
*        LOOP AT lt_errors INTO DATA(ls_verr).
*          APPEND VALUE #( %cid   = ls_key-%cid
*                          %param = VALUE #( ClientRowId = ls_verr-client_row_id
*                                            IdDoc       = ls_verr-id_doc
*                                            Type        = ls_verr-type
*                                            Message     = ls_verr-message ) ) TO result.
*        ENDLOOP.
*        CONTINUE.
*      ENDIF.


      DATA(lv_no_valid_row) = lo_validator->validate( IMPORTING es_data   = ls_data
                                                                et_errors = lt_errors ).

      " Lỗi validate LUÔN được trả về, kể cả khi vẫn còn dòng hợp lệ.
      " Không có bước này thì post bán phần sẽ giấu mất lý do dòng bị bỏ.
      LOOP AT lt_errors INTO DATA(ls_verr).
        APPEND VALUE #( %cid   = ls_key-%cid
                        %param = VALUE #( ClientRowId = ls_verr-client_row_id
                                          IdDoc       = ls_verr-id_doc
                                          Type        = ls_verr-type
                                          Message     = ls_verr-message ) ) TO result.
      ENDLOOP.

      " Chỉ dừng khi KHÔNG còn dòng nào hợp lệ.
      " Còn dòng hợp lệ -> post tiếp, giống FI: chứng từ lỗi không kéo
      " theo chứng từ khác.
      IF lv_no_valid_row = abap_true.
        CONTINUE.
      ENDIF.

      " --- 3. Post qua BAPI (LUW riêng, ngoài RAP framework) ---
      DATA(lo_posting) = NEW zpp_cl_zuplsx_posting_srv( ).
      DATA lt_results TYPE zpp_if_zuplsx_types=>tt_results.
      CLEAR lt_results.

      lo_posting->post( EXPORTING is_data    = ls_data
                        IMPORTING et_results = lt_results ).

      " --- 4. Map kết quả -> action result ---
      LOOP AT lt_results INTO DATA(ls_res).
        APPEND VALUE #( %cid   = ls_key-%cid
                        %param = VALUE #( ClientRowId     = ls_res-client_row_id
                                          IdDoc           = ls_res-id_doc
                                          Type            = ls_res-type
                                          Message         = ls_res-message
                                          ProductionOrder = ls_res-productionorder ) ) TO result.
      ENDLOOP.

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_ZPP_I_ZUPLSX DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZPP_I_ZUPLSX IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
  ENDMETHOD.

  METHOD cleanup.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
