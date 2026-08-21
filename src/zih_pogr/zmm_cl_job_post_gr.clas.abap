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
        AND ( @lv_gr_number = '' OR gr_number = @lv_gr_number )
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
            CLEAR: lv_mat_doc,
                   lv_mat_year.
            ls_item_result-status  = zmm_cl_gr_srv=>gc_status_error.
            ls_item_result-message = lx_item->get_text( ).
        ENDTRY.

        " SAP tự tạo Accounting Document (FI) cùng lúc với Material Document qua
        " account determination — không có BAPI riêng, chỉ đọc lại từ BKPF sau khi
        " BAPI_TRANSACTION_COMMIT (đã chạy bên trong postgr) hoàn tất
        DATA lv_fi_belnr TYPE belnr_d.
        DATA lv_fi_bukrs TYPE bukrs.
        DATA lv_fi_gjahr TYPE gjahr.
        CLEAR: lv_fi_belnr, lv_fi_bukrs, lv_fi_gjahr.

        IF ls_hd-testmode = abap_false AND lv_mat_doc IS NOT INITIAL.
          SELECT SINGLE bukrs, belnr, gjahr
            FROM bkpf
            WHERE awtyp = 'MKPF'
              AND awkey = @( |{ lv_mat_doc }{ lv_mat_year }| )
            INTO (@lv_fi_bukrs, @lv_fi_belnr, @lv_fi_gjahr).
        ENDIF.

        UPDATE zmm_tb_gr_i
          SET status            = @ls_item_result-status,
              message           = @ls_item_result-message,
              material_document = @lv_mat_doc,
              mat_doc_year      = @lv_mat_year,
              mat_doc_item      = '0001',
              fi_doc_number     = @lv_fi_belnr,
              fi_doc_company    = @lv_fi_bukrs,
              fi_doc_year       = @lv_fi_gjahr
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

      DATA lv_hd_matdoc   TYPE mblnr.
      DATA lv_hd_fi_bukrs TYPE bukrs.
      DATA lv_hd_fi_belnr TYPE belnr_d.
      DATA lv_hd_fi_gjahr TYPE gjahr.
      CLEAR: lv_hd_matdoc, lv_hd_fi_bukrs, lv_hd_fi_belnr, lv_hd_fi_gjahr.

      SELECT SINGLE material_document, fi_doc_company, fi_doc_number, fi_doc_year
        FROM zmm_tb_gr_i
        WHERE gr_number          = @ls_hd-gr_number
          AND status             = @zmm_cl_gr_srv=>gc_status_success
          AND material_document <> @space
        INTO (@lv_hd_matdoc, @lv_hd_fi_bukrs, @lv_hd_fi_belnr, @lv_hd_fi_gjahr).

      DATA lv_hd_year TYPE mjahr.
      CLEAR lv_hd_year.
      IF lv_hd_matdoc IS NOT INITIAL.
        lv_hd_year = ls_hd-document_date(4).
      ENDIF.

      UPDATE zmm_tb_gr_h
        SET status            = @( COND #( WHEN lv_ok_cnt = lv_total_cnt  THEN zmm_cl_gr_srv=>gc_status_success
                                           WHEN lv_err_cnt = lv_total_cnt THEN zmm_cl_gr_srv=>gc_status_error
                                           ELSE                                zmm_cl_gr_srv=>gc_status_ready ) ),
            material_document = @lv_hd_matdoc,
            mat_doc_year      = @lv_hd_year,
            fi_doc_number     = @lv_hd_fi_belnr,
            fi_doc_company    = @lv_hd_fi_bukrs,
            fi_doc_year       = @lv_hd_fi_gjahr,
            last_changed_at   = @( utclong_current( ) ),
            last_changed_by   = @sy-uname
        WHERE gr_number = @ls_hd-gr_number.
      IF ls_hd-batch_id IS NOT INITIAL.
        SELECT COUNT(*) FROM zmm_tb_gr_h
          WHERE batch_id = @ls_hd-batch_id
          INTO @DATA(lv_b_total).
        SELECT COUNT(*) FROM zmm_tb_gr_h
          WHERE batch_id = @ls_hd-batch_id
            AND status   = @zmm_cl_gr_srv=>gc_status_success
          INTO @DATA(lv_b_ok).
        SELECT COUNT(*) FROM zmm_tb_gr_h
          WHERE batch_id = @ls_hd-batch_id
            AND status   = @zmm_cl_gr_srv=>gc_status_error
          INTO @DATA(lv_b_err).
        SELECT COUNT(*) FROM zmm_tb_gr_h
          WHERE batch_id = @ls_hd-batch_id
            AND status   = @zmm_cl_gr_srv=>gc_status_pending
          INTO @DATA(lv_b_pend).

        UPDATE zih_tb_batch
          SET status          = @( COND #(
                WHEN lv_b_pend > 0         THEN zmm_cl_gr_srv=>gc_status_pending
                WHEN lv_b_ok   = lv_b_total THEN zmm_cl_gr_srv=>gc_status_success
                WHEN lv_b_err  = lv_b_total THEN zmm_cl_gr_srv=>gc_status_error
                ELSE                             zmm_cl_gr_srv=>gc_status_ready ) ),
              total_count     = @lv_b_total,
              success_count   = @lv_b_ok,
              error_count     = @lv_b_err,
              last_changed_at = @( utclong_current( ) ),
              last_changed_by = @sy-uname
          WHERE batch_id = @ls_hd-batch_id.
      ENDIF.
    ENDLOOP.

    COMMIT WORK AND WAIT.
  ENDMETHOD.



ENDCLASS.
