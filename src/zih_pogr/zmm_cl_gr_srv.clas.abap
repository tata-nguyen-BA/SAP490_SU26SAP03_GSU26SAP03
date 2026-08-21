CLASS zmm_cl_gr_srv DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_item_raw,
             rowno           TYPE string,
             ponumber        TYPE string,
             poitem          TYPE string,
             batch           TYPE string,
             quantity        TYPE string,
             baseunit        TYPE string,
             storagelocation TYPE string,
           END OF ty_item_raw.

    TYPES tyt_item_raw TYPE STANDARD TABLE OF ty_item_raw
                       WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_header_raw,
             grnumber     TYPE string,
             documentdate TYPE string,
             movementtype TYPE string,
             items        TYPE tyt_item_raw,
           END OF ty_header_raw.

    TYPES tyt_header_raw TYPE STANDARD TABLE OF ty_header_raw
                         WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_payload_raw,
             filename  TYPE string,
             testmode  TYPE string,
             mappingid TYPE string,
             doc       TYPE tyt_header_raw,
             useremail TYPE string,
           END OF ty_payload_raw.

    TYPES: BEGIN OF ty_gr_item,
             gr_number        TYPE zmm_de_gr_number,
             item             TYPE numc3,
             po_number        TYPE ebeln,
             po_item          TYPE ebelp,
             material         TYPE matnr,
             plant            TYPE werks_d,
             batch            TYPE charg_d,
             company_code     TYPE bukrs,
             receive_qty      TYPE menge_d,
             unit             TYPE meins,
             storage_location TYPE lgort_d,
             order_qty        TYPE menge_d,
             open_qty         TYPE menge_d,
             status           TYPE zih_de_upload_status,
             message          TYPE string,
           END OF ty_gr_item.

    TYPES tyt_gr_item TYPE STANDARD TABLE OF ty_gr_item
                      WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_gr_header,
             gr_number     TYPE zmm_de_gr_number,
             batch_id      TYPE zih_de_batch_id,
             document_date TYPE dats,
             movement_type TYPE bwart,
             testmode      TYPE abap_boolean,
             status        TYPE zih_de_upload_status,
             message       TYPE string,
             items         TYPE tyt_gr_item,
           END OF ty_gr_header.

    TYPES tyt_gr_header TYPE STANDARD TABLE OF ty_gr_header
                        WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_bapi_result,
             material_document      TYPE mblnr,
             material_document_year TYPE mjahr,
             status                 TYPE zih_de_upload_status,
             message                TYPE string,
           END OF ty_bapi_result.

    TYPES: BEGIN OF ty_po_snapshot,
             po_number          TYPE ebeln,
             po_item            TYPE ebelp,
             material           TYPE matnr,
             plant              TYPE werks_d,
             company_code       TYPE bukrs,
             batch_managed      TYPE xfeld,
             storage_location   TYPE lgort_d,
             order_qty          TYPE menge_d,
             order_unit         TYPE meins,
             supplier           TYPE lifnr,
             deletion_code      TYPE loekz,
             delivery_completed TYPE elikz,
             gr_indicator       TYPE wepos,
           END OF ty_po_snapshot.

    TYPES tyt_po_snapshot TYPE SORTED TABLE OF ty_po_snapshot
                          WITH UNIQUE KEY po_number po_item.


 TYPES: BEGIN OF ty_cell,
             name  TYPE string,
             value TYPE string,
           END OF ty_cell,
           tyt_cell TYPE STANDARD TABLE OF ty_cell WITH EMPTY KEY.

    TYPES: BEGIN OF ty_row_raw,
             rowno TYPE i,
             cells TYPE tyt_cell,
           END OF ty_row_raw,
           tyt_row_raw TYPE STANDARD TABLE OF ty_row_raw WITH EMPTY KEY.

    TYPES: BEGIN OF ty_payload_v2,
             filename  TYPE string,
             useremail TYPE string,
             rows      TYPE tyt_row_raw,
           END OF ty_payload_v2.

    TYPES: BEGIN OF ty_row_flat,
             gr_number        TYPE string,
             document_date    TYPE string,
             movement_type    TYPE string,
             po_number        TYPE string,
             po_item          TYPE string,
             receive_qty      TYPE string,
             unit             TYPE string,
             batch            TYPE string,
             storage_location TYPE string,
           END OF ty_row_flat.


    TYPES: BEGIN OF ty_upload_result,
             batch_id      TYPE zih_de_batch_id,
             total_count   TYPE i,
             success_count TYPE i,
             error_count   TYPE i,
             status        TYPE zih_de_upload_status,
             message       TYPE string,
             items_json    TYPE string,
           END OF ty_upload_result.

    CONSTANTS:
      gc_status_pending TYPE zih_de_upload_status VALUE 'P',
      gc_status_ready   TYPE zih_de_upload_status VALUE 'R',
      gc_status_success TYPE zih_de_upload_status VALUE 'S',
      gc_status_error   TYPE zih_de_upload_status VALUE 'E',
      gc_mvt_gr_po      TYPE bwart VALUE '101',
      gc_gm_code_01     TYPE c LENGTH 2 VALUE '01',
      gc_mvt_ind_po     TYPE c LENGTH 1 VALUE 'B'.


    CLASS-METHODS parse_payload
      IMPORTING
        iv_json       TYPE string
        iv_batch_id   TYPE zih_de_batch_id
        iv_mapping_id TYPE zih_tb_map_h-mapping_id OPTIONAL
      EXPORTING
        et_gr_headers TYPE tyt_gr_header
        ev_filename   TYPE string
        ev_user_email TYPE string
        ev_error      TYPE string
      RAISING
        cx_sy_conversion_error.

    CLASS-METHODS postgr
      IMPORTING
        iv_test                   TYPE abap_boolean
        is_header                 TYPE zmm_tb_gr_h
        is_item                   TYPE ty_gr_item
      EXPORTING
        ev_material_document      TYPE mblnr
        ev_material_document_year TYPE mjahr
      CHANGING
        cs_result                 TYPE ty_bapi_result.

    CLASS-METHODS validate
      IMPORTING
        is_header TYPE ty_gr_header
      CHANGING
        cs_header TYPE ty_gr_header
        ct_items  TYPE tyt_gr_item.

    CLASS-METHODS upload_excel
      IMPORTING
        iv_payload_json  TYPE string
        iv_mapping_id    TYPE zih_de_process_id
        iv_testmode      TYPE abap_boolean
      RETURNING
        VALUE(rs_result) TYPE ty_upload_result.

    CLASS-METHODS create_from_po
      IMPORTING
        iv_po_number        TYPE ebeln
        iv_po_item          TYPE ebelp
        iv_gr_number        TYPE zmm_de_gr_number
        iv_document_date    TYPE dats
        iv_receive_qty      TYPE menge_d
        iv_unit             TYPE meins
        iv_storage_location TYPE lgort_d
        iv_batch            TYPE charg_d OPTIONAL
        iv_user_email       TYPE string
      RETURNING
        VALUE(rs_result)    TYPE ty_upload_result.

    CLASS-METHODS schedule_job
      IMPORTING
        iv_gr_number    TYPE zmm_de_gr_number
      RETURNING
        VALUE(rv_error) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS get_po_snapshot
      IMPORTING
        iv_po_number TYPE ebeln
        iv_po_item   TYPE ebelp
      EXPORTING
        es_po        TYPE ty_po_snapshot
        ev_found     TYPE abap_boolean.

    CLASS-METHODS get_open_qty
      IMPORTING
        iv_po_number       TYPE ebeln
        iv_po_item         TYPE ebelp
        iv_order_qty       TYPE menge_d
        iv_exclude_gr      TYPE zmm_de_gr_number OPTIONAL
      RETURNING
        VALUE(rv_open_qty) TYPE menge_d.

    CLASS-METHODS get_existing_status
      IMPORTING
        iv_gr_number     TYPE zmm_de_gr_number
      RETURNING
        VALUE(rv_status) TYPE zih_de_upload_status.

    CLASS-DATA gt_po_cache TYPE tyt_po_snapshot.
ENDCLASS.


CLASS zmm_cl_gr_srv IMPLEMENTATION.

 METHOD parse_payload.
    CLEAR: et_gr_headers, ev_filename, ev_user_email, ev_error.

    DATA ls_payload TYPE ty_payload_v2.
    /ui2/cl_json=>deserialize(
      EXPORTING json        = iv_json
                pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING  data        = ls_payload ).

    ev_filename   = ls_payload-filename.
    ev_user_email = ls_payload-useremail.

    " ── Nạp cấu hình ánh xạ ───────────────────────────────────────────────
    DATA(lt_map) = zih_cl_map_srv=>get_mapping( iv_mapping_id = iv_mapping_id
                                                iv_process_id = zih_cl_auth=>gc_mod_gr ).
    IF lt_map IS INITIAL.
      ev_error = |Chưa có cấu hình ánh xạ cho phân hệ GR| &&
                 COND #( WHEN iv_mapping_id IS NOT INITIAL THEN | (mã { iv_mapping_id })| ).
      RETURN.
    ENDIF.

    DATA(lt_resolver) = zih_cl_map_srv=>build_resolver( lt_map ).

    " ── Kiểm tra file có đủ cột bắt buộc không ────────────────────────────
    " Lấy danh sách cột thật từ dòng đầu tiên — mọi dòng đều cùng bộ cột
    DATA lt_headers TYPE string_table.
    READ TABLE ls_payload-rows INTO DATA(ls_first) INDEX 1.
    IF sy-subrc <> 0.
      ev_error = 'File không có dòng dữ liệu nào'.
      RETURN.
    ENDIF.
    LOOP AT ls_first-cells INTO DATA(ls_c).
      APPEND zih_cl_map_srv=>normalize( ls_c-name ) TO lt_headers.
    ENDLOOP.

    ev_error = zih_cl_map_srv=>check_required( it_map          = lt_map
                                               it_headers_norm = lt_headers ).
    IF ev_error IS NOT INITIAL.
      RETURN.
    ENDIF.

    " ── Phân giải từng dòng rồi gom theo GR Number ────────────────────────
    LOOP AT ls_payload-rows INTO DATA(ls_row).

      DATA ls_flat TYPE ty_row_flat.
      CLEAR ls_flat.

      LOOP AT ls_row-cells INTO DATA(ls_cell).
        READ TABLE lt_resolver INTO DATA(ls_res)
          WITH TABLE KEY source_norm = zih_cl_map_srv=>normalize( ls_cell-name ).
        IF sy-subrc <> 0.
          CONTINUE.   " cột thừa trong file, không nằm trong cấu hình — bỏ qua
        ENDIF.
        ASSIGN COMPONENT ls_res-target_field OF STRUCTURE ls_flat TO FIELD-SYMBOL(<lv_tgt>).
        IF sy-subrc = 0.
          <lv_tgt> = condense( ls_cell-value ).
        ENDIF.
      ENDLOOP.

      DATA(lv_gr) = to_upper( condense( ls_flat-gr_number ) ).
      IF lv_gr IS INITIAL.
        CONTINUE.   " dòng trống hoặc thiếu GR Number — validate() sẽ báo ở cấp phiếu
      ENDIF.

      " Header của phiếu: tạo lần đầu gặp GR Number này
      READ TABLE et_gr_headers REFERENCE INTO DATA(lr_hd)
        WITH KEY gr_number = lv_gr.
      IF sy-subrc <> 0.
        DATA ls_hd TYPE ty_gr_header.
        CLEAR ls_hd.
        ls_hd-gr_number = lv_gr.
        ls_hd-batch_id  = iv_batch_id.

        DATA(lv_mvt) = condense( ls_flat-movement_type ).
        IF lv_mvt IS NOT INITIAL
       AND ( strlen( lv_mvt ) <> 3 OR lv_mvt CN '0123456789' ).
          ls_hd-status  = gc_status_error.
          ls_hd-message = |Movement Type '{ lv_mvt }' phải là 3 chữ số|.
        ELSE.
          ls_hd-movement_type = COND #( WHEN lv_mvt IS INITIAL THEN gc_mvt_gr_po ELSE lv_mvt ).
        ENDIF.

        DATA(lv_date) = ls_flat-document_date.
        REPLACE ALL OCCURRENCES OF '-' IN lv_date WITH ''.
        REPLACE ALL OCCURRENCES OF '/' IN lv_date WITH ''.
        ls_hd-document_date = lv_date.

        APPEND ls_hd TO et_gr_headers.
        READ TABLE et_gr_headers REFERENCE INTO lr_hd WITH KEY gr_number = lv_gr.
      ENDIF.

      " Item
      DATA lv_po_number TYPE ebeln.
      DATA lv_po_item   TYPE ebelp.
      DATA lv_sloc      TYPE lgort_d.

      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING input  = ls_flat-po_number
        IMPORTING output = lv_po_number.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING input  = ls_flat-po_item
        IMPORTING output = lv_po_item.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING input  = ls_flat-storage_location
        IMPORTING output = lv_sloc.

      APPEND VALUE ty_gr_item(
        gr_number        = lv_gr
        item             = lines( lr_hd->items ) + 1
        po_number        = lv_po_number
        po_item          = lv_po_item
        batch            = to_upper( condense( ls_flat-batch ) )
        receive_qty      = ls_flat-receive_qty
        unit             = to_upper( condense( ls_flat-unit ) )
        storage_location = lv_sloc
        status           = gc_status_pending
      ) TO lr_hd->items.

    ENDLOOP.
  ENDMETHOD.

  METHOD validate.
    " Lỗi phát hiện ngay lúc đọc file (vd Movement Type sai) phải giữ nguyên, không ghi đè
    IF is_header-status = gc_status_error AND is_header-message IS NOT INITIAL.
      cs_header-status  = gc_status_error.
      cs_header-message = is_header-message.
      RETURN.
    ENDIF.

    IF is_header-gr_number IS INITIAL.
      cs_header-status  = gc_status_error.
      cs_header-message = 'GR Number không được rỗng'. RETURN.
    ENDIF.
    IF is_header-document_date IS INITIAL.
      cs_header-status  = gc_status_error.
      cs_header-message = 'Document Date không được rỗng'. RETURN.
    ENDIF.
    IF is_header-document_date > sy-datum.
      cs_header-status  = gc_status_error.
      cs_header-message = |Document Date { is_header-document_date } là ngày tương lai|. RETURN.
    ENDIF.
    " Toàn bộ luồng đang dựng cho nhập kho theo PO; movement type khác cần GM Code khác
    IF is_header-movement_type <> gc_mvt_gr_po.
      cs_header-status  = gc_status_error.
      cs_header-message = |Movement Type { is_header-movement_type } chưa được hỗ trợ — chỉ nhận 101|. RETURN.
    ENDIF.
    IF ct_items IS INITIAL.
      cs_header-status  = gc_status_error.
      cs_header-message = 'Cần ít nhất 1 PO item'. RETURN.
    ENDIF.

    CASE get_existing_status( is_header-gr_number ).
      WHEN gc_status_success.
        cs_header-status  = gc_status_error.
        cs_header-message = |GR { is_header-gr_number } đã post thành công|. RETURN.
      WHEN gc_status_pending.
        cs_header-status  = gc_status_error.
        cs_header-message = |GR { is_header-gr_number } đang chờ job xử lý — xem kết quả ở tab Lịch sử|. RETURN.
      WHEN gc_status_ready.
        cs_header-status  = gc_status_error.
        cs_header-message = |GR { is_header-gr_number } đang là nháp ở tab Chờ xử lý — xử lý nó hoặc đổi GR Number khác|. RETURN.

      WHEN gc_status_error.
        cs_header-status  = gc_status_error.
        cs_header-message = |GR { is_header-gr_number } đã tồn tại và đang LỖI ở tab Lịch sử — sửa dữ liệu rồi Retry, hoặc đổi GR Number khác|. RETURN.
    ENDCASE.
    DATA lv_has_error TYPE abap_boolean.
    DATA lv_has_ok    TYPE abap_boolean.
    LOOP AT ct_items REFERENCE INTO DATA(lr_item).
      DATA ls_po    TYPE ty_po_snapshot.
      DATA lv_found TYPE abap_boolean.

      IF lr_item->po_number IS INITIAL OR lr_item->po_item IS INITIAL.
        lr_item->status  = gc_status_error.
        lr_item->message = 'PO Number / PO Item không được rỗng'.
        lv_has_error = abap_true. CONTINUE.
      ENDIF.
      IF lr_item->receive_qty <= 0.
        lr_item->status  = gc_status_error.
        lr_item->message = 'Receive Qty phải > 0'.
        lv_has_error = abap_true. CONTINUE.
      ENDIF.
      IF lr_item->unit IS INITIAL OR lr_item->storage_location IS INITIAL.
        lr_item->status  = gc_status_error.
        lr_item->message = 'Unit / Storage Location không được rỗng'.
        lv_has_error = abap_true. CONTINUE.
      ENDIF.

      get_po_snapshot(
        EXPORTING iv_po_number = lr_item->po_number
                  iv_po_item   = lr_item->po_item
        IMPORTING es_po        = ls_po
                  ev_found     = lv_found ).

      IF lv_found = abap_false.
        lr_item->status  = gc_status_error.
        lr_item->message = |PO { lr_item->po_number }/{ lr_item->po_item } không tồn tại hoặc chưa release|.
        lv_has_error = abap_true. CONTINUE.
      ENDIF.

*      " Quyền nhập kho xét theo plant của PO, nên chỉ kiểm được sau khi đọc PO
*      AUTHORITY-CHECK OBJECT 'Z_UPLOAD'
*        ID 'ZUPLMOD' FIELD 'GR'
*        ID 'ACTVT'   FIELD '01'
*        ID 'WERKS'   FIELD ls_po-plant.
*      IF sy-subrc <> 0.
*        lr_item->status  = gc_status_error.
*        lr_item->message = |Không có quyền nhập kho tại plant { ls_po-plant }|.
*        lv_has_error = abap_true. CONTINUE.
*      ENDIF.

      IF ls_po-gr_indicator <> 'X'.
        lr_item->status  = gc_status_error.
        lr_item->message = 'PO item không cho phép Goods Receipt'.
        lv_has_error = abap_true. CONTINUE.
      ENDIF.
      IF ls_po-delivery_completed = 'X'.
        lr_item->status  = gc_status_error.
        lr_item->message = 'PO item đã nhận đủ hàng (Delivery Completed)'.
        lv_has_error = abap_true. CONTINUE.
      ENDIF.
      IF lr_item->unit <> ls_po-order_unit.
        lr_item->status  = gc_status_error.
        lr_item->message = |Unit { lr_item->unit } không khớp PO unit { ls_po-order_unit }|.
        lv_has_error = abap_true. CONTINUE.
      ENDIF.

      " Sloc phải thuộc đúng plant của PO — sai plant thì BAPI báo lỗi rất khó hiểu
      SELECT SINGLE FROM t001l FIELDS @abap_true
        WHERE werks = @ls_po-plant
          AND lgort = @lr_item->storage_location
        INTO @DATA(lv_sloc_ok).
      IF sy-subrc <> 0.
        lr_item->status  = gc_status_error.
        lr_item->message = |Storage Location { lr_item->storage_location } không thuộc plant { ls_po-plant } của PO|.
        lv_has_error = abap_true. CONTINUE.
      ENDIF.

      " Vật tư không quản lý theo lô mà điền Batch thì SAP từ chối với thông báo khó hiểu.
      " Chiều ngược lại không chặn: nhiều vật tư có đánh số lô tự động, để trống vẫn post được
      IF lr_item->batch IS NOT INITIAL AND ls_po-batch_managed <> 'X'.
        lr_item->status  = gc_status_error.
        lr_item->message = |Vật tư { ls_po-material } không quản lý theo lô — bỏ trống cột Batch|.
        lv_has_error = abap_true. CONTINUE.
      ENDIF.

      lr_item->material     = ls_po-material.
      lr_item->plant        = ls_po-plant.
      lr_item->company_code = ls_po-company_code.
      lr_item->order_qty    = ls_po-order_qty.
      lr_item->open_qty     = get_open_qty(
                                iv_po_number  = lr_item->po_number
                                iv_po_item    = lr_item->po_item
                                iv_order_qty  = ls_po-order_qty
                                iv_exclude_gr = lr_item->gr_number ).

      IF lr_item->receive_qty > lr_item->open_qty.
        lr_item->status  = gc_status_error.
        lr_item->message = |Receive Qty { lr_item->receive_qty } vượt Open Qty { lr_item->open_qty }|.
        lv_has_error = abap_true. CONTINUE.
      ENDIF.

      lr_item->status = gc_status_ready.
    ENDLOOP.

    " Một phiếu chỉ được thuộc một company code: khác company code là khác kỳ kế toán,
    " dẫn tới phiếu post dở dang một nửa
    DATA lv_cc TYPE bukrs.
    LOOP AT ct_items REFERENCE INTO DATA(lr_cc) WHERE status = gc_status_ready.
      IF lv_cc IS INITIAL.
        lv_cc = lr_cc->company_code.
      ELSEIF lr_cc->company_code <> lv_cc.
        lr_cc->status  = gc_status_error.
        lr_cc->message = |PO thuộc company code { lr_cc->company_code }, khác { lv_cc } của các item trước — tách thành GR riêng|.
        lv_has_error = abap_true.
      ENDIF.
    ENDLOOP.

    " ── Kỳ kế toán MM ──────────────────────────────────────────────
    " BAPI chỉ cho post vào kỳ hiện tại + kỳ trước (do MMPV set, lưu ở MARV).
    " validate() không gọi BAPI nên phải tự đọc MARV — nếu không GR lỗi kỳ sẽ
    " lọt qua Check, thành nháp (R) ở tab Chờ xử lý rồi mới chết lúc post thật.
    IF lv_cc IS NOT INITIAL.
      SELECT SINGLE periv FROM t001 WHERE bukrs = @lv_cc INTO @DATA(lv_periv).
      IF sy-subrc = 0.
        DATA lv_poper TYPE poper.
        DATA lv_gjahr TYPE gjahr.
        CALL FUNCTION 'DATE_TO_PERIOD_CONVERT'
          EXPORTING
            i_date         = is_header-document_date
            i_periv        = lv_periv
          IMPORTING
            e_buper        = lv_poper
            e_gjahr        = lv_gjahr
          EXCEPTIONS
            input_false    = 1
            t009_notfound  = 2
            t009b_notfound = 3
            OTHERS         = 4.

        IF sy-subrc = 0.
          SELECT SINGLE lfgja, lfmon, vmgja, vmmon
            FROM marv
            WHERE bukrs = @lv_cc
            INTO @DATA(ls_marv).

          " MARV không có = MMPV chưa chạy cho company này → bỏ qua pre-check,
          " để dry-run/BAPI báo, tránh chặn nhầm.
          IF sy-subrc = 0.
            DATA(lv_period_ok) = xsdbool(
                 ( lv_gjahr = ls_marv-lfgja AND lv_poper = ls_marv-lfmon )
              OR ( lv_gjahr = ls_marv-vmgja AND lv_poper = ls_marv-vmmon ) ).

            IF lv_period_ok = abap_false.
              DATA(lv_period_msg) =
                |Posting date { is_header-document_date+6(2) }/| &&
                |{ is_header-document_date+4(2) }/{ is_header-document_date(4) } | &&
                |ngoài kỳ mở MM của company { lv_cc } — chỉ nhận kỳ | &&
                |{ ls_marv-lfmon }/{ ls_marv-lfgja } và { ls_marv-vmmon }/{ ls_marv-vmgja }|.

              LOOP AT ct_items REFERENCE INTO DATA(lr_pd) WHERE status = gc_status_ready.
                lr_pd->status  = gc_status_error.
                lr_pd->message = lv_period_msg.
              ENDLOOP.
              lv_has_error = abap_true.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

    LOOP AT ct_items TRANSPORTING NO FIELDS WHERE status = gc_status_ready.
      lv_has_ok = abap_true.
      EXIT.
    ENDLOOP.

    cs_header-status = COND #( WHEN lv_has_ok = abap_true THEN gc_status_ready
                               ELSE gc_status_error ).

    IF lv_has_error = abap_true.
      LOOP AT ct_items REFERENCE INTO DATA(lr_err) WHERE status = gc_status_error.
        cs_header-message = COND #( WHEN cs_header-message IS INITIAL
                                    THEN |Item { lr_err->item }: { lr_err->message }|
                                    ELSE cs_header-message && | | && |Item { lr_err->item }: { lr_err->message }| ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD postgr.
    DATA ls_gm_code   TYPE bapi2017_gm_code.
    DATA ls_gm_header TYPE bapi2017_gm_head_01.
    DATA lt_gm_items  TYPE STANDARD TABLE OF bapi2017_gm_item_create.
    DATA lt_return    TYPE TABLE OF bapiret2.

    ls_gm_code-gm_code = SWITCH #( is_header-movement_type
                                    WHEN gc_mvt_gr_po THEN gc_gm_code_01
                                    ELSE gc_gm_code_01 ).

    ls_gm_header-pstng_date = is_header-document_date.
    ls_gm_header-doc_date   = is_header-document_date.
    ls_gm_header-header_txt = is_header-gr_number.

    APPEND VALUE bapi2017_gm_item_create(
      line_id   = 1
      po_number = is_item-po_number
      po_item   = is_item-po_item
      move_type = is_header-movement_type
      batch     = is_item-batch
      plant     = is_item-plant
      material  = is_item-material
      entry_qnt = is_item-receive_qty
      entry_uom = is_item-unit
      stge_loc  = is_item-storage_location
      mvt_ind   = gc_mvt_ind_po
    ) TO lt_gm_items.

    CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
      EXPORTING
        goodsmvt_header  = ls_gm_header
        goodsmvt_code    = ls_gm_code
        testrun          = CONV char1( iv_test )
      IMPORTING
        materialdocument = ev_material_document
        matdocumentyear  = ev_material_document_year
      TABLES
        goodsmvt_item    = lt_gm_items
        return           = lt_return.

    DATA lv_has_error TYPE abap_boolean.
    LOOP AT lt_return INTO DATA(ls_ret) WHERE type = 'E' OR type = 'A'.
      lv_has_error = abap_true.
      cs_result-message = COND #( WHEN cs_result-message IS INITIAL
                                  THEN ls_ret-message
                                  ELSE cs_result-message && ' | ' && ls_ret-message ).
    ENDLOOP.

    IF lv_has_error = abap_true
  OR ( iv_test = abap_false AND ev_material_document IS INITIAL ).
      cs_result-status = gc_status_error.
      IF cs_result-message IS INITIAL.
        cs_result-message = 'BAPI did not create Material Document'.
      ENDIF.
      IF iv_test = abap_false.
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      ENDIF.
    ELSE.
      IF iv_test = abap_false.
        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
      ENDIF.
      cs_result-status = gc_status_success.
    ENDIF.
  ENDMETHOD.


  METHOD upload_excel.

*    AUTHORITY-CHECK OBJECT 'Z_UPLOAD'
*      ID 'ZUPLMOD' FIELD 'GR'
*      ID 'ACTVT'   FIELD '01'
*      ID 'WERKS'   DUMMY.
*    IF sy-subrc <> 0.
*      rs_result = VALUE #( status  = gc_status_error
*                           message = 'Bạn không có quyền upload phiếu nhập kho' ).
*      RETURN.
*    ENDIF.

    " Gom kết quả từng item (mọi header) để trả chi tiết per-dòng về UI
    TYPES: BEGIN OF ty_item_msg,
             gr_number TYPE zmm_de_gr_number,
             item      TYPE numc3,
             po_number TYPE ebeln,
             po_item   TYPE ebelp,
             status    TYPE zih_de_upload_status,
             message   TYPE string,
           END OF ty_item_msg.
    DATA lt_item_msg TYPE STANDARD TABLE OF ty_item_msg.

*    DATA lv_batch_id TYPE zih_de_batch_id.
*    lv_batch_id = cl_system_uuid=>create_uuid_c22_static( ).
    DATA lv_batch_id TYPE zih_de_batch_id.
    TRY.
        lv_batch_id = cl_system_uuid=>create_uuid_c22_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        rs_result = VALUE #( status = gc_status_error message = lx_uuid->get_text( ) ).
        RETURN.
    ENDTRY.

*    DATA lt_headers TYPE tyt_gr_header.
*    TRY.
*        parse_payload(
*          EXPORTING iv_json       = iv_payload_json
*                    iv_batch_id   = lv_batch_id
*          IMPORTING et_gr_headers = lt_headers
*                    ev_filename   = DATA(lv_filename)
*                    ev_user_email = DATA(lv_user_email) ).
*      CATCH cx_sy_conversion_error INTO DATA(lx).
*        rs_result = VALUE #( batch_id = lv_batch_id
*                             status   = gc_status_error
*                             message  = lx->get_text( ) ).
*        RETURN.
*    ENDTRY.

  DATA lt_headers TYPE tyt_gr_header.
    TRY.
        parse_payload(
          EXPORTING iv_json       = iv_payload_json
                    iv_batch_id   = lv_batch_id
                    iv_mapping_id = iv_mapping_id
          IMPORTING et_gr_headers = lt_headers
                    ev_filename   = DATA(lv_filename)
                    ev_user_email = DATA(lv_user_email)
                    ev_error      = DATA(lv_parse_err) ).
      CATCH cx_sy_conversion_error INTO DATA(lx).
        rs_result = VALUE #( batch_id = lv_batch_id
                             status   = gc_status_error
                             message  = lx->get_text( ) ).
        RETURN.
    ENDTRY.

    " Lỗi cấu hình ánh xạ hoặc file thiếu cột — dừng ngay, chưa đụng gì tới SAP
    IF lv_parse_err IS NOT INITIAL.
      rs_result = VALUE #( batch_id = lv_batch_id
                           status   = gc_status_error
                           message  = lv_parse_err ).
      RETURN.
    ENDIF.
*    DATA(lv_auth_err) = zih_cl_auth=>check( iv_email      = lv_user_email
*                                               iv_process_id = zih_cl_auth=>gc_mod_gr
*                                               iv_actvt      = zih_cl_auth=>gc_act_post ).
    DATA(lv_auth_err) = ``.
    IF lv_auth_err IS NOT INITIAL.
      rs_result = VALUE #( batch_id = lv_batch_id
                           status   = gc_status_error
                           message  = lv_auth_err ).
      RETURN.
    ENDIF.

    rs_result-batch_id    = lv_batch_id.
    rs_result-total_count = lines( lt_headers ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_hd).

      DATA ls_hd_val TYPE ty_gr_header.
      ls_hd_val = lr_hd->*.
      validate(
        EXPORTING is_header = ls_hd_val
        CHANGING  cs_header = lr_hd->*
                  ct_items  = lr_hd->items ).

      IF lr_hd->status = gc_status_error.
        " Không có item nào hợp lệ (hoặc lỗi header cứng) — không lưu gì cả
        rs_result-error_count += 1.
        rs_result-message = COND #(
            WHEN rs_result-message IS INITIAL
            THEN |GR { lr_hd->gr_number }: { lr_hd->message }|
            ELSE rs_result-message && | | && |GR { lr_hd->gr_number }: { lr_hd->message }| ).
      ELSE.
        DATA ls_hd_db TYPE zmm_tb_gr_h.
        MOVE-CORRESPONDING lr_hd->* TO ls_hd_db.

        LOOP AT lr_hd->items REFERENCE INTO DATA(lr_dry_itm) WHERE status = gc_status_ready.
          DATA ls_dry_res TYPE ty_bapi_result.
          CLEAR ls_dry_res.
          postgr( EXPORTING iv_test   = abap_true
                            is_header = ls_hd_db
                            is_item   = lr_dry_itm->*
                  CHANGING  cs_result = ls_dry_res ).
          IF ls_dry_res-status = gc_status_error.
            lr_dry_itm->status  = gc_status_error.
            lr_dry_itm->message = ls_dry_res-message.
          ENDIF.
        ENDLOOP.

        " Quyết định trạng thái TRƯỚC khi lưu. Dry-run có thể loại hết item dù
        " validate() đã cho qua — lúc đó phiếu phải là E (vào Lịch sử), tuyệt đối
        " không được là R vì R sẽ rơi vào tab Chờ xử lý như một phiếu nháp hợp lệ.
        DATA ls_first_err TYPE ty_gr_item.
        CLEAR ls_first_err.

        READ TABLE lr_hd->items TRANSPORTING NO FIELDS WITH KEY status = gc_status_ready.
        DATA(lv_has_ready) = xsdbool( sy-subrc = 0 ).

        IF lv_has_ready = abap_false.
          READ TABLE lr_hd->items INTO ls_first_err WITH KEY status = gc_status_error.
          ls_hd_db-status  = gc_status_error.
          ls_hd_db-message = COND #( WHEN sy-subrc = 0 THEN ls_first_err-message
                                     ELSE |Tất cả item đều lỗi| ).
        ELSE.
          ls_hd_db-status  = COND #( WHEN iv_testmode = abap_false
                                     THEN gc_status_pending
                                     ELSE gc_status_ready ).
          CLEAR ls_hd_db-message.
        ENDIF.

        IF lv_has_ready = abap_true OR iv_testmode = abap_false.
          ls_hd_db-testmode   = iv_testmode.
          ls_hd_db-created_by = COND #( WHEN lv_user_email IS NOT INITIAL THEN lv_user_email ELSE sy-uname ).
          ls_hd_db-filename   = lv_filename.
          ls_hd_db-created_at = utclong_current( ).
          MODIFY zmm_tb_gr_h FROM @ls_hd_db.
          MODIFY zmm_tb_gr_i FROM TABLE @( CORRESPONDING #( lr_hd->items ) ).
        ENDIF.

        " Không còn item nào sống thì đừng gọi job — nó sẽ không có gì để post
        IF iv_testmode = abap_false AND lv_has_ready = abap_true.
          DATA(lv_job_err) = schedule_job( lr_hd->gr_number ).
          IF lv_job_err IS NOT INITIAL.
            rs_result-message = COND #(
                WHEN rs_result-message IS INITIAL
                THEN |GR { lr_hd->gr_number }: { lv_job_err }|
                ELSE rs_result-message && | | && |GR { lr_hd->gr_number }: { lv_job_err }| ).
          ENDIF.
        ENDIF.

        IF lv_has_ready = abap_false.
          rs_result-error_count += 1.
          rs_result-message = COND #(
              WHEN rs_result-message IS INITIAL
              THEN |GR { lr_hd->gr_number }: { ls_first_err-message }|
              ELSE rs_result-message && | | && |GR { lr_hd->gr_number }: { ls_first_err-message }| ).
        ELSE.
          rs_result-success_count += 1.
        ENDIF.

      ENDIF.

      " Gom item của header này (bắt cả lỗi validate lẫn lỗi dry-run)
      LOOP AT lr_hd->items INTO DATA(ls_msg_it).
        APPEND VALUE #(
          gr_number = ls_msg_it-gr_number
          item      = ls_msg_it-item
          po_number = ls_msg_it-po_number
          po_item   = ls_msg_it-po_item
          status    = ls_msg_it-status
          message   = ls_msg_it-message ) TO lt_item_msg.
      ENDLOOP.

    ENDLOOP.

    rs_result-items_json = /ui2/cl_json=>serialize(
      data        = lt_item_msg
      pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

    rs_result-status = COND #( WHEN rs_result-error_count = 0
                               THEN gc_status_success
                               WHEN rs_result-success_count = 0
                               THEN gc_status_error
                               ELSE gc_status_ready ).
    " Ghi lô upload
    DATA ls_batch TYPE zih_tb_batch.
    ls_batch-batch_id        = lv_batch_id.
    ls_batch-process_id      = zih_cl_auth=>gc_mod_gr.
    ls_batch-mapping_id      = iv_mapping_id.
    ls_batch-filename        = lv_filename.
    ls_batch-file_type       = 'XLSX'.
    ls_batch-testmode        = iv_testmode.
    ls_batch-status          = rs_result-status.
    ls_batch-message         = rs_result-message.
    ls_batch-total_count     = rs_result-total_count.
    ls_batch-success_count   = rs_result-success_count.
    ls_batch-error_count     = rs_result-error_count.
    ls_batch-created_at      = utclong_current( ).
    ls_batch-created_by      = COND #( WHEN lv_user_email IS NOT INITIAL
                                       THEN lv_user_email
                                       ELSE sy-uname ).
    ls_batch-last_changed_at = ls_batch-created_at.
    ls_batch-last_changed_by = ls_batch-created_by.
    MODIFY zih_tb_batch FROM @ls_batch.
  ENDMETHOD.
  METHOD create_from_po.
*    DATA(lv_auth_err) = zih_cl_auth=>check( iv_email      = iv_user_email
*                                               iv_process_id = zih_cl_auth=>gc_mod_gr
*                                               iv_actvt      = zih_cl_auth=>gc_act_post ).
    DATA(lv_auth_err) = ``.
    IF lv_auth_err IS NOT INITIAL.
      rs_result = VALUE #( status = gc_status_error message = lv_auth_err ).
      RETURN.
    ENDIF.

    DATA ls_header TYPE ty_gr_header.
    ls_header-gr_number     = to_upper( condense( iv_gr_number ) ).
    ls_header-document_date = iv_document_date.
    ls_header-movement_type = gc_mvt_gr_po.

    APPEND VALUE ty_gr_item(
      gr_number        = ls_header-gr_number
      item             = 1
      po_number        = iv_po_number
      po_item          = iv_po_item
      batch            = to_upper( condense( iv_batch ) )
      receive_qty      = iv_receive_qty
      unit             = iv_unit
      storage_location = iv_storage_location
      status           = gc_status_pending
    ) TO ls_header-items.

    DATA ls_hd_val TYPE ty_gr_header.
    ls_hd_val = ls_header.
    validate(
      EXPORTING is_header = ls_hd_val
      CHANGING  cs_header = ls_header
                ct_items  = ls_header-items ).

    rs_result-total_count = 1.

    IF ls_header-status = gc_status_error.
      rs_result-error_count = 1.
      rs_result-status      = gc_status_error.
      rs_result-message     = ls_header-message.
      RETURN.
    ENDIF.

    DATA ls_hd_db TYPE zmm_tb_gr_h.
    MOVE-CORRESPONDING ls_header TO ls_hd_db.

    LOOP AT ls_header-items REFERENCE INTO DATA(lr_dry_itm) WHERE status = gc_status_ready.
      DATA ls_dry_res TYPE ty_bapi_result.
      CLEAR ls_dry_res.
      postgr( EXPORTING iv_test   = abap_true
                        is_header = ls_hd_db
                        is_item   = lr_dry_itm->*
              CHANGING  cs_result = ls_dry_res ).
      IF ls_dry_res-status = gc_status_error.
        lr_dry_itm->status  = gc_status_error.
        lr_dry_itm->message = ls_dry_res-message.
      ENDIF.
    ENDLOOP.

    " Chỉ lưu nháp (R) — không schedule job ngay, user xác nhận qua nút Post/Retry đã có sẵn
    ls_hd_db-status     = gc_status_ready.
    ls_hd_db-testmode   = abap_true.
    ls_hd_db-created_by = COND #( WHEN iv_user_email IS NOT INITIAL THEN iv_user_email ELSE sy-uname ).
    ls_hd_db-filename   = '(PO Lookup)'.
    ls_hd_db-created_at = utclong_current( ).
    MODIFY zmm_tb_gr_h FROM @ls_hd_db.
    MODIFY zmm_tb_gr_i FROM TABLE @( CORRESPONDING #( ls_header-items ) ).

    LOOP AT ls_header-items TRANSPORTING NO FIELDS WHERE status = gc_status_ready.
      rs_result-success_count = 1.
      EXIT.
    ENDLOOP.

    " Dry-run BAPI (kỳ kế toán, khóa sổ...) có thể phát hiện lỗi mà validate() không thấy
    " (validate chỉ kiểm PO/qty/sloc, không gọi BAPI) — phải phản ánh đúng lên kết quả
    " trả về UI, nếu không dialog sẽ báo "thành công" trong khi item đã lỗi thật
    IF rs_result-success_count = 0.
      rs_result-error_count = 1.
      rs_result-status      = gc_status_error.
      READ TABLE ls_header-items INTO DATA(ls_failed_item) WITH KEY status = gc_status_error.
      rs_result-message = COND #( WHEN sy-subrc = 0 THEN ls_failed_item-message ELSE ls_header-message ).
    ELSE.
      rs_result-status  = ls_header-status.
      rs_result-message = ls_header-message.
    ENDIF.
    " <-- FIX: bỏ 2 dòng gán ls_header-status/message thừa ở đây
  ENDMETHOD.


  METHOD get_po_snapshot.
    READ TABLE gt_po_cache INTO es_po
      WITH KEY po_number = iv_po_number
               po_item   = iv_po_item.
    IF sy-subrc = 0.
      ev_found = abap_true. RETURN.
    ENDIF.

    SELECT SINGLE
        PurchaseOrder         AS po_number,
        PurchaseOrderItem     AS po_item,
        Material              AS material,
        Plant                 AS plant,
        CompanyCode           AS company_code,
        BatchManaged          AS batch_managed,
        StorageLocation       AS storage_location,
        OrderQuantity         AS order_qty,
        OrderUnit             AS order_unit,
        Supplier              AS supplier,
        DeletionCode          AS deletion_code,
        DeliveryIsCompleted   AS delivery_completed,
        GoodsReceiptIndicator AS gr_indicator
      FROM zmm_i_po_lookup
      WHERE PurchaseOrder     = @iv_po_number
        AND PurchaseOrderItem = @iv_po_item
      INTO @es_po.

    ev_found = COND #( WHEN sy-subrc = 0 THEN abap_true ELSE abap_false ).
    IF ev_found = abap_true.
      INSERT es_po INTO TABLE gt_po_cache.
    ENDIF.
  ENDMETHOD.


  METHOD get_open_qty.
    DATA lv_received TYPE menge_d.
    SELECT SUM( CASE WHEN shkzg = 'H' THEN menge * -1 ELSE menge END )
      FROM ekbe
      WHERE ebeln = @iv_po_number
        AND ebelp = @iv_po_item
        AND vgabe = '1'
      INTO @lv_received.

    " Trừ cả số đang nằm trong staging chờ post: nếu không, upload cùng một PO item
    " hai lần liên tiếp sẽ qua validate cả hai lần rồi vượt Open Qty lúc post
    DATA lv_pending TYPE menge_d.
    SELECT SUM( i~receive_qty )
      FROM zmm_tb_gr_i AS i
      INNER JOIN zmm_tb_gr_h AS h ON h~gr_number = i~gr_number
      WHERE i~po_number =  @iv_po_number
        AND i~po_item   =  @iv_po_item
        AND i~gr_number <> @iv_exclude_gr
        AND i~status    <> @gc_status_success
        AND h~status    IN ( @gc_status_pending, @gc_status_ready )
      INTO @lv_pending.

    rv_open_qty = iv_order_qty - lv_received - lv_pending.
    IF rv_open_qty < 0. rv_open_qty = 0. ENDIF.
  ENDMETHOD.


  METHOD get_existing_status.
    SELECT SINGLE status FROM zmm_tb_gr_h
      WHERE gr_number = @iv_gr_number
      INTO @rv_status.
  ENDMETHOD.


  METHOD schedule_job.
    DATA ls_start_info TYPE cl_apj_rt_api=>ty_start_info.
    ls_start_info-start_immediately = abap_true.

    DATA lt_params TYPE cl_apj_rt_api=>tt_job_parameter_value.
    APPEND VALUE #(
      name    = 'GRNUMBER'
      t_value = VALUE #( ( sign = 'I' option = 'EQ' low = iv_gr_number ) )
    ) TO lt_params.

    TRY.
        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name   = 'ZMM_AJT_POST_GR'
            iv_job_text            = |POST-GR-{ iv_gr_number }|
            is_start_info          = ls_start_info
            it_job_parameter_value = lt_params ).

      CATCH cx_apj_rt cx_apj_dt_content INTO DATA(lx).
        DATA(lv_text) = lx->get_text( ).
        rv_error = lv_text.
        UPDATE zmm_tb_gr_h
          SET status  = @gc_status_error,
              message = @lv_text
          WHERE gr_number = @iv_gr_number.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
