CLASS zmm_cl_job_post_gr DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES:
      if_apj_dt_exec_object,
      if_apj_rt_exec_object.

ENDCLASS.


CLASS zmm_cl_job_post_gr IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #( (
      selname        = 'GRNUMBER'
      kind           = 'S'
      datatype       = 'C'
      length         = 30
      param_text     = 'GR Number'
      changeable_ind = abap_true
    ) ).
  ENDMETHOD.

  METHOD if_apj_rt_exec_object~execute.
    " TODO: variable is assigned but never used (ABAP cleaner)
    DATA lv_gr_number TYPE zmm_de_gr_number.

    READ TABLE it_parameters INTO DATA(ls_p) WITH KEY selname = 'GRNUMBER'.
    IF sy-subrc = 0.
      lv_gr_number = ls_p-low.
    ENDIF.

    " Chỉ quét GR đã được user xác nhận Post (P) — GR nháp (R) và GR post dở dang
    " chờ user bấm Retry, không tự post lại
    DATA lt_hd TYPE STANDARD TABLE OF zmm_tb_gr_h.
    SELECT * FROM zmm_tb_gr_h
      WHERE status = @zmm_cl_gr_srv=>gc_status_pending
      INTO TABLE @lt_hd.

    " Job có thể chạy trước khi transaction gọi retryPost/uploadExcel kịp commit —
    " đợi ngắn rồi quét lại 1 lần thay vì bỏ cuộc ngay
    IF lt_hd IS INITIAL.
      WAIT UP TO 3 SECONDS.
      SELECT * FROM zmm_tb_gr_h
        WHERE status = @zmm_cl_gr_srv=>gc_status_pending
        INTO TABLE @lt_hd.
    ENDIF.

    LOOP AT lt_hd INTO DATA(ls_hd).
      DATA lt_itm TYPE zmm_cl_gr_srv=>tyt_gr_item.
      " Chỉ lấy item CHƯA thành công — tránh post lại item đã có Material Document
              SELECT gr_number, item, po_number, po_item, material, plant, batch, receive_qty, unit, storage_location, order_qty,
               open_qty, status, message
          FROM zmm_tb_gr_i
          WHERE gr_number  = @ls_hd-gr_number
            AND status    <> @zmm_cl_gr_srv=>gc_status_success
          INTO CORRESPONDING FIELDS OF TABLE @lt_itm.


      IF lt_itm IS INITIAL.
        CONTINUE.
      ENDIF.

      LOOP AT lt_itm REFERENCE INTO DATA(lr_itm).
        DATA ls_item_result TYPE zmm_cl_gr_srv=>ty_bapi_result.
        DATA lv_mat_doc     TYPE mblnr.
        DATA lv_mat_year    TYPE mjahr.

        " Mỗi item có message/kết quả riêng — không dùng lại giá trị của item trước
        CLEAR: ls_item_result,
               lv_mat_doc,
               lv_mat_year.

        TRY.
            zmm_cl_gr_srv=>postgr( EXPORTING iv_test                   = ls_hd-testmode
                                             is_header                 = ls_hd
                                             is_item                   = lr_itm->*
                                   IMPORTING ev_material_document      = lv_mat_doc
                                             ev_material_document_year = lv_mat_year
                                   CHANGING  cs_result                 = ls_item_result ).

          CATCH cx_root INTO DATA(lx_item).
            " Ghi lỗi lên chính item đó rồi chạy tiếp — 1 item hỏng không được
            " làm dừng cả đợt quét, những GR xếp sau vẫn phải được xử lý
            CLEAR: lv_mat_doc,
                   lv_mat_year.
            ls_item_result-status  = zmm_cl_gr_srv=>gc_status_error.
            ls_item_result-message = lx_item->get_text( ).
        ENDTRY.

        UPDATE zmm_tb_gr_i
          SET status            = @ls_item_result-status,
              message           = @ls_item_result-message,
              material_document = @lv_mat_doc,
              mat_doc_year      = @lv_mat_year,
              mat_doc_item      = '0001'
          WHERE gr_number = @ls_hd-gr_number AND item = @lr_itm->item.

        " Chốt ngay kết quả của item này: item lỗi phía sau gọi BAPI_TRANSACTION_ROLLBACK,
        " nếu chưa commit thì Material Document vừa post sẽ mất khỏi bảng staging
        COMMIT WORK AND WAIT.
      ENDLOOP.

      " Tổng hợp status header từ TOÀN BỘ item (kể cả item đã OK từ lần chạy trước)
      SELECT COUNT(*) FROM zmm_tb_gr_i
        WHERE gr_number = @ls_hd-gr_number
        INTO @DATA(lv_total_cnt).
      SELECT COUNT(*) FROM zmm_tb_gr_i
        WHERE gr_number = @ls_hd-gr_number AND status = @zmm_cl_gr_srv=>gc_status_success
        INTO @DATA(lv_ok_cnt).
      SELECT COUNT(*) FROM zmm_tb_gr_i
        WHERE gr_number = @ls_hd-gr_number AND status = @zmm_cl_gr_srv=>gc_status_error
        INTO @DATA(lv_err_cnt).

      " Material Document đại diện của GR để tra cứu nhanh ở danh sách;
      " chi tiết từng item xem trong dialog
      SELECT SINGLE material_document
        FROM zmm_tb_gr_i
        WHERE gr_number          = @ls_hd-gr_number
          AND status             = @zmm_cl_gr_srv=>gc_status_success
          AND material_document <> @space
        INTO @DATA(lv_hd_matdoc).

      DATA lv_hd_year TYPE mjahr.
      CLEAR lv_hd_year.
      IF lv_hd_matdoc IS NOT INITIAL.
        lv_hd_year = ls_hd-document_date(4).
      ENDIF.

      UPDATE zmm_tb_gr_h
        SET status          = @( COND #( WHEN lv_ok_cnt = lv_total_cnt  THEN zmm_cl_gr_srv=>gc_status_success
                                         WHEN lv_err_cnt = lv_total_cnt THEN zmm_cl_gr_srv=>gc_status_error
                                         ELSE                                zmm_cl_gr_srv=>gc_status_ready ) ),
            material_document = @lv_hd_matdoc,
            mat_doc_year      = @lv_hd_year,
            last_changed_at = @( utclong_current( ) ),
            last_changed_by = @sy-uname
        WHERE gr_number = @ls_hd-gr_number.

    ENDLOOP.

    COMMIT WORK AND WAIT.
  ENDMETHOD.



ENDCLASS.
