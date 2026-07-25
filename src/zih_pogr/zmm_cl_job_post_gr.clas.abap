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
    " Sweep TẤT CẢ GR đang PENDING (P = đã xác nhận Post, khác với R = nháp chưa xác nhận)
    DATA lt_hd TYPE STANDARD TABLE OF zmm_tb_gr_h.
    SELECT * FROM zmm_tb_gr_h
      WHERE status = @zmm_cl_gr_srv=>gc_status_pending
      INTO TABLE @lt_hd.

    LOOP AT lt_hd INTO DATA(ls_hd).
      DATA lt_itm TYPE zmm_cl_gr_srv=>tyt_gr_item.
      SELECT gr_number, item, po_number, po_item,
             material, plant, receive_qty, unit,
             storage_location, order_qty, open_qty,
             status, message
        FROM zmm_tb_gr_i
        WHERE gr_number = @ls_hd-gr_number
        INTO CORRESPONDING FIELDS OF TABLE @lt_itm.

      IF lt_itm IS INITIAL. CONTINUE. ENDIF.

      DATA lv_all_ok  TYPE abap_boolean VALUE abap_true.
      DATA lv_all_err TYPE abap_boolean VALUE abap_true.

      LOOP AT lt_itm REFERENCE INTO DATA(lr_itm).
        DATA ls_item_result TYPE zmm_cl_gr_srv=>ty_bapi_result.
        DATA lv_mat_doc  TYPE mblnr.
        DATA lv_mat_year TYPE mjahr.

        zmm_cl_gr_srv=>postgr(
          EXPORTING iv_test   = ls_hd-testmode
                    is_header = ls_hd
                    is_item   = lr_itm->*
          IMPORTING ev_material_document      = lv_mat_doc
                    ev_material_document_year = lv_mat_year
          CHANGING  cs_result = ls_item_result ).

        UPDATE zmm_tb_gr_i
          SET status            = @ls_item_result-status,
              message           = @ls_item_result-message,
              material_document = @lv_mat_doc,
              mat_doc_item      = '0001'
          WHERE gr_number = @ls_hd-gr_number AND item = @lr_itm->item.

        IF ls_item_result-status = zmm_cl_gr_srv=>gc_status_error.
          lv_all_ok = abap_false.
        ELSE.
          lv_all_err = abap_false.
        ENDIF.
      ENDLOOP.
      UPDATE zmm_tb_gr_h
        SET status          = @( COND #( WHEN lv_all_ok  = abap_true THEN zmm_cl_gr_srv=>gc_status_success
                                          WHEN lv_all_err = abap_true THEN zmm_cl_gr_srv=>gc_status_error
                                          ELSE zmm_cl_gr_srv=>gc_status_ready ) ),
            last_changed_at = @( utclong_current( ) ),
            last_changed_by = @sy-uname
        WHERE gr_number = @ls_hd-gr_number.

    ENDLOOP.

    COMMIT WORK AND WAIT.
  ENDMETHOD.

ENDCLASS.

