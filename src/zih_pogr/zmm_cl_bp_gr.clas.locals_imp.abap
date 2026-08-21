CLASS lhc_gr_upload DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS upload_excel FOR MODIFY
      IMPORTING keys   FOR ACTION GrUpload~uploadExcel
      RESULT    result.

    METHODS retry_post FOR MODIFY
      IMPORTING keys FOR ACTION GrUpload~retryPost.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys   REQUEST requested_features FOR GrUpload
      RESULT    result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys   REQUEST requested_authorizations FOR GrUpload
      RESULT    result.

    METHODS get_my_auth FOR MODIFY
      IMPORTING keys   FOR ACTION GrUpload~getMyAuth
      RESULT    result.

    METHODS create_from_po FOR MODIFY
      IMPORTING keys   FOR ACTION GrUpload~createFromPO
      RESULT    result.

 METHODS save_mapping FOR MODIFY
      IMPORTING keys   FOR ACTION GrUpload~saveMapping
      RESULT    result.
ENDCLASS.

CLASS lhc_gr_upload IMPLEMENTATION.

  METHOD upload_excel.
    IF keys IS INITIAL. RETURN. ENDIF.
    DATA(ls_key) = keys[ 1 ].

    DATA ls_param TYPE zd_gruploadparam.
    ls_param = ls_key-%param.

    DATA ls_srv_result TYPE zmm_cl_gr_srv=>ty_upload_result.

    TRY.
        ls_srv_result = zmm_cl_gr_srv=>upload_excel(
          iv_payload_json = ls_param-payload_json
          iv_mapping_id   = ls_param-mapping_id
          iv_testmode     = ls_param-testmode ).

      CATCH cx_root INTO DATA(lx).
        " Lỗi kỹ thuật ngoài dự kiến — báo về UI thay vì để action dump
        ls_srv_result-status  = zmm_cl_gr_srv=>gc_status_error.
        ls_srv_result-message = lx->get_text( ).
    ENDTRY.

    " Kênh message chuẩn của RAP — UI đọc được kể cả khi không dùng tới result
    IF ls_srv_result-message IS NOT INITIAL.
      APPEND VALUE #(
        %msg = new_message_with_text(
                 severity = COND #( WHEN ls_srv_result-status = zmm_cl_gr_srv=>gc_status_error
                                    THEN if_abap_behv_message=>severity-error
                                    ELSE if_abap_behv_message=>severity-warning )
                 text     = ls_srv_result-message ) ) TO reported-grupload.
    ENDIF.

    DATA ls_result TYPE STRUCTURE FOR ACTION RESULT zmm_i_gr_h~uploadExcel.
    ls_result-%cid   = ls_key-%cid.
    ls_result-%param = VALUE zd_gr_upload_result(
      batch_id      = ls_srv_result-batch_id
      total_count   = ls_srv_result-total_count
      success_count = ls_srv_result-success_count
      error_count   = ls_srv_result-error_count
      status        = ls_srv_result-status
      message       = ls_srv_result-message
      items_json    = ls_srv_result-items_json ).
    APPEND ls_result TO result.
  ENDMETHOD.

  METHOD create_from_po.
    IF keys IS INITIAL. RETURN. ENDIF.
    DATA(ls_key) = keys[ 1 ].

    DATA ls_param TYPE zd_gr_create_po_param.
    ls_param = ls_key-%param.

    DATA(ls_srv_result) = zmm_cl_gr_srv=>create_from_po(
      iv_po_number        = ls_param-po_number
      iv_po_item          = ls_param-po_item
      iv_gr_number        = ls_param-gr_number
      iv_document_date    = ls_param-document_date
      iv_receive_qty      = ls_param-receive_qty
      iv_unit             = ls_param-unit
      iv_storage_location = ls_param-storage_location
      iv_batch            = ls_param-batch
      iv_user_email       = CONV string( ls_param-user_email ) ).

    IF ls_srv_result-message IS NOT INITIAL.
      APPEND VALUE #(
        %msg = new_message_with_text(
                 severity = COND #( WHEN ls_srv_result-status = zmm_cl_gr_srv=>gc_status_error
                                    THEN if_abap_behv_message=>severity-error
                                    ELSE if_abap_behv_message=>severity-warning )
                 text     = ls_srv_result-message ) ) TO reported-grupload.
    ENDIF.

    DATA ls_result TYPE STRUCTURE FOR ACTION RESULT zmm_i_gr_h~createFromPO.
    ls_result-%cid   = ls_key-%cid.
    ls_result-%param = VALUE zd_gr_upload_result(
      batch_id      = ls_srv_result-batch_id
      total_count   = ls_srv_result-total_count
      success_count = ls_srv_result-success_count
      error_count   = ls_srv_result-error_count
      status        = ls_srv_result-status
      message       = ls_srv_result-message ).
    APPEND ls_result TO result.
  ENDMETHOD.

  METHOD retry_post.



    " Dùng chung cho cả "Post ngay" (từ nháp R) và "Retry" (khi lỗi E)
    LOOP AT keys INTO DATA(ls_key).

*      DATA(lv_auth_err) = zih_cl_auth=>check(
*  iv_email      = CONV string( ls_key-%param-user_email )
*  iv_process_id = zih_cl_auth=>gc_mod_gr
*  iv_actvt      = zih_cl_auth=>gc_act_post ).
*      IF lv_auth_err IS NOT INITIAL.
*        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-grupload.
*        APPEND VALUE #( %tky = ls_key-%tky
*                        %msg = new_message_with_text(
*                                 severity = if_abap_behv_message=>severity-error
*                                 text     = lv_auth_err ) ) TO reported-grupload.
*        CONTINUE.
*      ENDIF.


      READ ENTITIES OF zmm_i_gr_h IN LOCAL MODE
        ENTITY GrUpload
        FIELDS ( Status ) WITH VALUE #( ( %tky = ls_key-%tky ) )
        RESULT DATA(lt_entity).

      IF lt_entity IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-grupload.
        APPEND VALUE #(
          %tky = ls_key-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |GR { ls_key-%tky-GrNumber } không tồn tại| )
        ) TO reported-grupload.
        CONTINUE.
      ENDIF.

      DATA(ls_entity) = lt_entity[ 1 ].

      IF ls_entity-Status <> zmm_cl_gr_srv=>gc_status_error
     AND ls_entity-Status <> zmm_cl_gr_srv=>gc_status_ready.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-grupload.
        APPEND VALUE #(
          %tky = ls_key-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |GR { ls_key-%tky-GrNumber } đang ở trạng thái { ls_entity-Status }, | &&
                              |chỉ Post lại được khi ở R hoặc E| )
        ) TO reported-grupload.
        CONTINUE.
      ENDIF.

      UPDATE zmm_tb_gr_h
        SET status          = @zmm_cl_gr_srv=>gc_status_pending,
            message          = 'Đã xác nhận Post — đang xử lý nền',
            testmode         = @abap_false,
            last_changed_at  = @( utclong_current( ) ),
            last_changed_by  = @sy-uname
        WHERE gr_number = @ls_key-%tky-GrNumber.

      DATA(lv_job_err) = zmm_cl_gr_srv=>schedule_job( ls_key-%tky-GrNumber ).
      IF lv_job_err IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-grupload.
        APPEND VALUE #(
          %tky = ls_key-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |GR { ls_key-%tky-GrNumber }: { lv_job_err }| )
        ) TO reported-grupload.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD get_instance_features.
    READ ENTITIES OF zmm_i_gr_h IN LOCAL MODE
      ENTITY GrUpload
      FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_entity).

    result = VALUE #( FOR ls IN lt_entity (
      %tky              = ls-%tky
      %action-retryPost = COND #(
        WHEN ls-Status = zmm_cl_gr_srv=>gc_status_error
          OR ls-Status = zmm_cl_gr_srv=>gc_status_ready
          OR ls-Status = zmm_cl_gr_srv=>gc_status_pending
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled )
    ) ).
  ENDMETHOD.

  METHOD get_my_auth.
    IF keys IS INITIAL. RETURN. ENDIF.
    DATA(ls_key) = keys[ 1 ].
    DATA(lv_email) = CONV string( ls_key-%param-user_email ).

    DATA ls_auth TYPE zd_gr_my_auth.
    ls_auth-can_upload_fi = abap_true.
    ls_auth-can_upload_pp = abap_true.
    ls_auth-can_upload_gr = abap_true.
*    ls_auth-can_upload_fi = COND #( WHEN zih_cl_auth=>check( iv_email = lv_email
*                                          iv_process_id = zih_cl_auth=>gc_mod_fi
*                                          iv_actvt = zih_cl_auth=>gc_act_post ) IS INITIAL
*                                    THEN abap_true ELSE abap_false ).
*    ls_auth-can_upload_pp = COND #( WHEN zih_cl_auth=>check( iv_email = lv_email
*                                          iv_process_id = zih_cl_auth=>gc_mod_pp
*                                          iv_actvt = zih_cl_auth=>gc_act_post ) IS INITIAL
*                                    THEN abap_true ELSE abap_false ).
*    ls_auth-can_upload_gr = COND #( WHEN zih_cl_auth=>check( iv_email = lv_email
*                                          iv_process_id = zih_cl_auth=>gc_mod_gr
*                                          iv_actvt = zih_cl_auth=>gc_act_post ) IS INITIAL
*                                    THEN abap_true ELSE abap_false ).

    DATA ls_result TYPE STRUCTURE FOR ACTION RESULT zmm_i_gr_h~getMyAuth.
    ls_result-%cid   = ls_key-%cid.
    ls_result-%param = ls_auth.
    APPEND ls_result TO result.
  ENDMETHOD.



  METHOD get_instance_authorizations.
    result = VALUE #( FOR ls_key IN keys (
      %tky              = ls_key-%tky
      %action-retryPost = if_abap_behv=>auth-allowed
    ) ).
  ENDMETHOD.

  METHOD save_mapping.
    IF keys IS INITIAL. RETURN. ENDIF.
    DATA(ls_key) = keys[ 1 ].
    DATA(ls_p)   = ls_key-%param.

    DATA(lv_err) = zih_cl_map_srv=>save_mapping(
                     iv_mapping_id   = ls_p-mapping_id
                     iv_process_id   = CONV #( ls_p-process_id )
                     iv_description  = ls_p-description
                     iv_user_email   = CONV string( ls_p-user_email )
                     iv_payload_json = CONV string( ls_p-payload_json ) ).

    DATA ls_res TYPE STRUCTURE FOR ACTION RESULT zmm_i_gr_h~saveMapping.
    ls_res-%cid            = ls_key-%cid.
    ls_res-%param-status   = COND #( WHEN lv_err IS INITIAL
                                     THEN zmm_cl_gr_srv=>gc_status_success
                                     ELSE zmm_cl_gr_srv=>gc_status_error ).
    ls_res-%param-message  = COND #( WHEN lv_err IS INITIAL
                                     THEN |Đã lưu cấu hình { ls_p-mapping_id }|
                                     ELSE lv_err ).
    APPEND ls_res TO result.
  ENDMETHOD.

ENDCLASS.
