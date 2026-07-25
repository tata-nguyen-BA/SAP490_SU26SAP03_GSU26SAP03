CLASS lhc_gr_upload DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS upload_excel FOR MODIFY
      IMPORTING keys FOR ACTION GrUpload~uploadExcel
      RESULT    result.

    METHODS retry_post FOR MODIFY
      IMPORTING keys FOR ACTION GrUpload~retryPost.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys     REQUEST requested_features FOR GrUpload
      RESULT    result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys                    REQUEST requested_authorizations FOR GrUpload
      RESULT    result.

ENDCLASS.

CLASS lhc_gr_upload IMPLEMENTATION.

  METHOD upload_excel.
    DATA ls_param TYPE ZD_GRUPLOADPARAM.
    ls_param = keys[ 1 ]-%param.

    DATA(ls_srv_result) = zmm_cl_gr_srv=>upload_excel(
      iv_payload_json = ls_param-payload_json
      iv_mapping_id   = ls_param-mapping_id
      iv_testmode     = ls_param-testmode ).

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
    " Dùng chung cho cả "Post ngay" (từ nháp R) và "Retry" (khi lỗi E)
    LOOP AT keys INTO DATA(ls_key).
      READ ENTITIES OF zmm_i_gr_h IN LOCAL MODE
        ENTITY GrUpload
        FIELDS ( Status ) WITH VALUE #( ( %tky = ls_key-%tky ) )
        RESULT DATA(lt_entity).

      IF lt_entity IS INITIAL. CONTINUE. ENDIF.
      DATA(ls_entity) = lt_entity[ 1 ].

      IF ls_entity-Status <> zmm_cl_gr_srv=>gc_status_error
     AND ls_entity-Status <> zmm_cl_gr_srv=>gc_status_ready.
        CONTINUE.
      ENDIF.

      UPDATE zmm_tb_gr_h
        SET status          = @zmm_cl_gr_srv=>gc_status_pending,
            message          = 'Đã xác nhận Post — đang xử lý nền',
            testmode         = @abap_false,
            last_changed_at  = @( utclong_current( ) ),
            last_changed_by  = @sy-uname
        WHERE gr_number = @ls_key-%tky-GrNumber.

      zmm_cl_gr_srv=>schedule_job( ls_key-%tky-GrNumber ).
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



  METHOD get_instance_authorizations.
    result = VALUE #( FOR ls_key IN keys (
      %tky              = ls_key-%tky
      %action-retryPost = if_abap_behv=>auth-allowed
    ) ).
  ENDMETHOD.

ENDCLASS.
