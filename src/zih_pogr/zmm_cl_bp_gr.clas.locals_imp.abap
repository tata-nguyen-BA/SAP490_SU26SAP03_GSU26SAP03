CLASS lhc_gr_upload DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    " ─── Static action: upload Excel
    METHODS upload_excel FOR MODIFY
      IMPORTING keys FOR ACTION GrUpload~uploadExcel
      RESULT    result.

    " ─── Instance action: retry failed GR
    METHODS retry_post FOR MODIFY
      IMPORTING keys FOR ACTION GrUpload~retryPost.

    " ─── Feature control: retryPost chỉ enable khi status = E
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys     REQUEST requested_features FOR GrUpload
      RESULT    result.

    " ─── Auth: check ZIH_TB_AUTH_USER thay Authorization Object
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys                    REQUEST requested_authorizations FOR GrUpload
      RESULT    result.

ENDCLASS.

CLASS lhc_gr_upload IMPLEMENTATION.

  METHOD upload_excel.
    " ── Static action — không cần key, gọi từ toolbar button ──

    " Lấy parameter từ RAP framework
    DATA ls_param TYPE ZD_GRUPLOADPARAM.
    ls_param = keys[ 1 ]-%param.

    " Gọi service class (tất cả logic ở đây)
    DATA(ls_srv_result) = zmm_cl_gr_srv=>upload_excel(
      iv_payload_json = ls_param-payload_json
      iv_mapping_id   = ls_param-mapping_id
      iv_testmode     = ls_param-testmode ).

    " Map sang RAP result type
    DATA ls_result TYPE STRUCTURE FOR ACTION RESULT zmm_i_gr_h~uploadExcel.
    ls_result-%param = VALUE ZD_GR_UPLOAD_RESULT(
      batch_id      = ls_srv_result-batch_id
      total_count   = ls_srv_result-total_count
      success_count = ls_srv_result-success_count
      error_count   = ls_srv_result-error_count
      status        = ls_srv_result-status
      message       = ls_srv_result-message ).
    APPEND ls_result TO result.
  ENDMETHOD.


METHOD retry_post.
    LOOP AT keys INTO DATA(ls_key).
      READ ENTITIES OF zmm_i_gr_h IN LOCAL MODE
        ENTITY GrUpload
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_entity).

      DATA(ls_entity) = lt_entity[ 1 ].
      IF ls_entity-Status <> zmm_cl_gr_srv=>gc_status_error.
        CONTINUE.
      ENDIF.

      UPDATE zmm_tb_gr_h
        SET status  = @zmm_cl_gr_srv=>gc_status_pending,
            message = 'Retry triggered'
        WHERE gr_number = @ls_key-%key-GrNumber.

      zmm_cl_gr_srv=>schedule_job( ls_key-%key-GrNumber ).
    ENDLOOP.
  ENDMETHOD.


  METHOD get_instance_features.
    " ── retryPost chỉ enable khi status = E ───────────────────
    READ ENTITIES OF zmm_i_gr_h IN LOCAL MODE
      ENTITY GrUpload
      FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_entity).

    result = VALUE #( FOR ls IN lt_entity (
      %tky                   = ls-%tky
      %action-retryPost      = COND #(
        WHEN ls-Status = zmm_cl_gr_srv=>gc_status_error
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled )
    ) ).
  ENDMETHOD.


  METHOD get_instance_authorizations.
*    " ── Thay AUTHORITY-CHECK bằng table check ZIH_TB_AUTH_USER ──
*    DATA lv_can_execute TYPE abap_boolean.
*
*    SELECT SINGLE @abap_true
*      FROM zih_tb_auth_user
*      WHERE username   = @sy-uname
*        AND process_id = @zmm_cl_gr_srv=>gc_process_pogr
*        AND actvt      = '16'
*      INTO @lv_can_execute.
*
*    result = VALUE #( FOR ls_key IN keys (
*      %tky                   = ls_key-%tky
*      %action-uploadExcel    = COND #(
*        WHEN lv_can_execute = abap_true
*        THEN if_abap_behv=>auth-allowed
*        ELSE if_abap_behv=>auth-unauthorized )
*      %action-retryPost      = COND #(
*        WHEN lv_can_execute = abap_true
*        THEN if_abap_behv=>auth-allowed
*        ELSE if_abap_behv=>auth-unauthorized )
*    ) ).
  ENDMETHOD.

ENDCLASS.
