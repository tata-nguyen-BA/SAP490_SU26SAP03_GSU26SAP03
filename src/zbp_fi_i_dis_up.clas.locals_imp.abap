CLASS lhc_Log DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Log RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ Log RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK Log.

    METHODS uploadFromExcel FOR MODIFY
      IMPORTING keys FOR ACTION Log~uploadFromExcel RESULT result.


ENDCLASS.

CLASS lhc_Log IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD uploadFromExcel.
    " ============================================================
    " Toàn bộ chứng từ đi qua SOAP (post_soap), KHÔNG dùng EML i_journalentrytp.
    " Lý do: MODIFY ENTITIES của BO khác bị cấm trong RAP modify-phase
    " (BEHAVIOR_STATEMENT_ILLEGAL). SOAP loopback chạy NGOÀI RAP framework
    " nên hợp lệ trong action handler.
    " ============================================================

    LOOP AT keys INTO DATA(ls_key).

      DATA lt_action_result TYPE zfi_if_fidoc_types=>tt_results.
      CLEAR lt_action_result.

      " --- 1. Parse JSON ---
      DATA ls_request TYPE zfi_if_fidoc_types=>ts_post_request.
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

      " --- 2. Validate (chỉ đọc/convert, không modify -> hợp lệ) ---
      DATA(lo_validator) = NEW zfi_cl_fidoc_validator( is_request = ls_request ).
      DATA lt_data   TYPE zfi_if_fidoc_types=>tt_data.
      DATA lt_errors TYPE zfi_if_fidoc_types=>tt_results.

      DATA(lv_has_validation_error) = lo_validator->validate(
          IMPORTING et_data   = lt_data
                    et_errors = lt_errors ).

      IF lv_has_validation_error = abap_true.
        LOOP AT lt_errors INTO DATA(ls_verr).
          APPEND VALUE #( %cid   = ls_key-%cid
                          %param = CORRESPONDING #( ls_verr ) ) TO result.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      " --- 3. Setup + post TẤT CẢ qua SOAP ---
      DATA(lo_log_srv)     = NEW zfi_cl_fidoc_log_srv( ).
      DATA(lo_posting_srv) = NEW zfi_cl_fidoc_posting_srv( io_log_srv = lo_log_srv ).
      DATA(lv_is_update)   = CONV abap_bool( ls_request-isupdate ).
      DATA(lv_testmode)    = CONV abap_bool( ls_request-testmode ).
      DATA lt_results      TYPE zfi_if_fidoc_types=>tt_results.

      lo_posting_srv->post_soap( EXPORTING it_data      = lt_data
                                           iv_is_update = lv_is_update
                                           iv_testmode  = lv_testmode
                                 IMPORTING et_results   = lt_results ).
      APPEND LINES OF lt_results TO lt_action_result.

      " --- 4. Map kết quả -> action result ---
      LOOP AT lt_action_result INTO DATA(ls_res).
        APPEND VALUE #( %cid   = ls_key-%cid
                        %param = VALUE #(
                          Filename           = ls_res-filename
                          IdDoc              = ls_res-id_doc
                          Type               = ls_res-type
                          Message            = ls_res-message
                          AccountingDocument = ls_res-accountingdocument ) ) TO result.
      ENDLOOP.

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_ZFI_I_DIS_UP DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZFI_I_DIS_UP IMPLEMENTATION.

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
