CLASS zmm_cl_job_post_gr DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES:
      if_apj_dt_exec_object,   " Design time: khai báo parameters
      if_apj_rt_exec_object.   " Runtime: execute logic

ENDCLASS.



CLASS zmm_cl_job_post_gr IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #( (
      selname        = 'GR_NUMBER'
      kind           = 'S'
      datatype       = 'C'
      length         = 30
      param_text     = 'GR Number'
      changeable_ind = abap_true
    ) ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    DATA lv_gr_number TYPE zmm_de_gr_number.

    READ TABLE it_parameters INTO DATA(ls_par)
      WITH KEY selname = 'GR_NUMBER'.
    IF sy-subrc <> 0 OR ls_par-low IS INITIAL. RETURN. ENDIF.
    lv_gr_number = ls_par-low.

    " ── Đọc header từ staging ────────────────────────────────
    DATA ls_hd TYPE zmm_tb_gr_h.
    SELECT SINGLE * FROM zmm_tb_gr_h
      WHERE gr_number = @lv_gr_number
      INTO @ls_hd.
    IF sy-subrc <> 0. RETURN. ENDIF.

    " Chỉ chạy khi status = R (Ready)
    IF ls_hd-status <> zmm_cl_gr_srv=>gc_status_ready. RETURN. ENDIF.

    " ── Đọc items từ staging ─────────────────────────────────
    DATA lt_itm TYPE zmm_cl_gr_srv=>tyt_gr_item.
    SELECT gr_number, item, po_number, po_item,
           material, plant, receive_qty, unit,
           storage_location, order_qty, open_qty,
           status, message
      FROM zmm_tb_gr_i
      WHERE gr_number = @lv_gr_number
      INTO CORRESPONDING FIELDS OF TABLE @lt_itm.

    IF lt_itm IS INITIAL. RETURN. ENDIF.

    " ── Gọi BAPI qua ZMM_CL_GR_SRV=>postgr() ────────────────
    DATA ls_result   TYPE zmm_cl_gr_srv=>ty_bapi_result.
    DATA lv_mat_doc  TYPE mblnr.
    DATA lv_mat_year TYPE mjahr.

    zmm_cl_gr_srv=>postgr(
      EXPORTING
        iv_test   = ls_hd-testmode
        is_header = ls_hd
        it_items  = lt_itm
      IMPORTING
        ev_material_document      = lv_mat_doc
        ev_material_document_year = lv_mat_year
      CHANGING
        cs_result = ls_result ).

    " ── Cập nhật header ──────────────────────────────────────
    UPDATE zmm_tb_gr_h
          SET status            = @ls_result-status,
              message           = @ls_result-message,
              material_document = @lv_mat_doc,
              mat_doc_year      = @lv_mat_year,
              last_changed_at   = @( utclong_current( ) ),
              last_changed_by   = @sy-uname
          WHERE gr_number = @lv_gr_number.

    " ── Cập nhật items ───────────────────────────────────────
    UPDATE zmm_tb_gr_i
      SET status = @ls_result-status
      WHERE gr_number = @lv_gr_number.

    COMMIT WORK AND WAIT.
  ENDMETHOD.

ENDCLASS.
