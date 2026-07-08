CLASS zmm_cl_gr_srv DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_item_raw,
             rowno           TYPE string,
             ponumber        TYPE string,
             poitem          TYPE string,
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
           END OF ty_payload_raw.

    TYPES: BEGIN OF ty_gr_item,
             gr_number        TYPE zmm_de_gr_number,
             item             TYPE numc3,
             po_number        TYPE ebeln,
             po_item          TYPE ebelp,
             " Derive từ PO — không có trong Excel
             material         TYPE matnr,
             plant            TYPE werks_d,
             " Từ Excel
             receive_qty      TYPE menge_d,
             unit             TYPE meins,
             storage_location TYPE lgort_d,
             " Snapshot PO khi validate
             order_qty        TYPE menge_d,
             open_qty         TYPE menge_d,
             " Processing
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

    TYPES: BEGIN OF ty_upload_result,
             batch_id      TYPE zih_de_batch_id,
             total_count   TYPE i,
             success_count TYPE i,
             error_count   TYPE i,
             status        TYPE zih_de_upload_status,
             message       TYPE string,
           END OF ty_upload_result.

    CONSTANTS:
      gc_status_pending TYPE zih_de_upload_status VALUE 'P',
      gc_status_ready   TYPE zih_de_upload_status VALUE 'R',
      gc_status_success TYPE zih_de_upload_status VALUE 'S',
      gc_status_error   TYPE zih_de_upload_status VALUE 'E',
      gc_mvt_gr_po      TYPE bwart VALUE '101',
      gc_gm_code_01     TYPE c LENGTH 2 VALUE '01',
      " mvt_ind = 'B' hardcoded (giống ZIF_CL_API_PGR line ~908)
      gc_mvt_ind_po     TYPE c LENGTH 1 VALUE 'B'.


    " Parse JSON → internal typed structs
    CLASS-METHODS parse_payload
      IMPORTING
        iv_json       TYPE string
        iv_batch_id   TYPE zih_de_batch_id
      EXPORTING
        et_gr_headers TYPE tyt_gr_header
      RAISING
        cx_sy_conversion_error.

    " ─── MAIN POST METHOD ────────────────────────────────────
    " Giống ZIF_CL_API_PGR=>postgr() CLASS-METHOD
    " Gọi từ: RAP behavior impl (action) + background job
    CLASS-METHODS postgr
      IMPORTING
        iv_test                   TYPE abap_boolean
        is_header                 TYPE zmm_tb_gr_h
        it_items                  TYPE tyt_gr_item
      EXPORTING
        ev_material_document      TYPE mblnr
        ev_material_document_year TYPE mjahr
      CHANGING
        cs_result                 TYPE ty_bapi_result.

    " ─── VALIDATE ────────────────────────────────────────────
    " Validate required fields + PO reference
    " Enrich items: fill material, plant, order_qty, open_qty từ PO
    CLASS-METHODS validate
      IMPORTING
        is_header TYPE ty_gr_header
      CHANGING
        cs_header TYPE ty_gr_header
        ct_items  TYPE tyt_gr_item.

    " ─── UPLOAD ORCHESTRATION ────────────────────────────────
    " Gọi từ RAP action uploadExcel:
    " parse → validate → test run → save staging → schedule job
    CLASS-METHODS upload_excel
      IMPORTING
        iv_payload_json  TYPE string
        iv_mapping_id    TYPE zih_de_process_id
        iv_testmode      TYPE abap_boolean
      RETURNING
        VALUE(rs_result) TYPE ty_upload_result.

    CLASS-METHODS schedule_job
      IMPORTING
        iv_gr_number TYPE zmm_de_gr_number.
  PROTECTED SECTION.
  PRIVATE SECTION.
    " Đọc PO từ ZMM_I_PO_LOOKUP (EKPO + EKKO)
    CLASS-METHODS get_po_snapshot
      IMPORTING
        iv_po_number TYPE ebeln
        iv_po_item   TYPE ebelp
      EXPORTING
        es_po        TYPE ty_po_snapshot
        ev_found     TYPE abap_boolean.

    " Tính open qty từ EKBE (on-premise)
    CLASS-METHODS get_open_qty
      IMPORTING
        iv_po_number       TYPE ebeln
        iv_po_item         TYPE ebelp
        iv_order_qty       TYPE menge_d
      RETURNING
        VALUE(rv_open_qty) TYPE menge_d.

    " Check GR đã post thành công chưa → tránh duplicate
    CLASS-METHODS check_duplicate
      IMPORTING
        iv_gr_number     TYPE zmm_de_gr_number
      RETURNING
        VALUE(rv_exists) TYPE abap_boolean.

    " Session-level PO cache tránh SELECT nhiều lần
    CLASS-DATA gt_po_cache TYPE tyt_po_snapshot.
ENDCLASS.



CLASS zmm_cl_gr_srv IMPLEMENTATION.
  METHOD parse_payload.
    " ── Bước 1: deserialize JSON → raw struct ────────────────
    DATA ls_payload TYPE ty_payload_raw.
    /ui2/cl_json=>deserialize(
      EXPORTING json        = iv_json
                pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING  data        = ls_payload ).

    " ── Bước 2: loop từng GR doc → convert sang typed ────────
    LOOP AT ls_payload-doc INTO DATA(ls_raw_hd).
      DATA ls_header TYPE ty_gr_header.
      ls_header-gr_number     = ls_raw_hd-grnumber.
      ls_header-batch_id      = iv_batch_id.
      ls_header-movement_type = COND #( WHEN ls_raw_hd-movementtype IS INITIAL
                                        THEN gc_mvt_gr_po
                                        ELSE ls_raw_hd-movementtype ).
      " Convert date string 'YYYY-MM-DD' hoặc 'YYYYMMDD' → DATS
      REPLACE ALL OCCURRENCES OF '-' IN ls_raw_hd-documentdate WITH ''.
      ls_header-document_date = ls_raw_hd-documentdate.

      DATA lv_item_no TYPE numc3.
      LOOP AT ls_raw_hd-items INTO DATA(ls_raw_item).
        lv_item_no += 1.
        APPEND VALUE ty_gr_item(
          gr_number        = ls_header-gr_number
          item             = lv_item_no
          po_number        = |{ ls_raw_item-ponumber ALPHA = IN }|
          po_item          = |{ ls_raw_item-poitem   ALPHA = IN }|
          receive_qty      = ls_raw_item-quantity
          unit             = ls_raw_item-baseunit
          storage_location = |{ ls_raw_item-storagelocation ALPHA = IN }|
          status           = gc_status_pending
        ) TO ls_header-items.
      ENDLOOP.

      APPEND ls_header TO et_gr_headers.
      CLEAR: ls_header, lv_item_no.
    ENDLOOP.
  ENDMETHOD.


  METHOD validate.
    " ── Required field check ─────────────────────────────────
    IF is_header-gr_number IS INITIAL.
      cs_header-status = gc_status_error.
      cs_header-message = 'GR Number không được rỗng'. RETURN.
    ENDIF.
    IF is_header-document_date IS INITIAL.
      cs_header-status = gc_status_error.
      cs_header-message = 'Document Date không được rỗng'. RETURN.
    ENDIF.
    IF ct_items IS INITIAL.
      cs_header-status = gc_status_error.
      cs_header-message = 'Cần ít nhất 1 PO item'. RETURN.
    ENDIF.

    " ── Duplicate check ───────────────────────────────────────
    IF check_duplicate( is_header-gr_number ) = abap_true.
      cs_header-status  = gc_status_error.
      cs_header-message = |GR { is_header-gr_number } đã post thành công|.
      RETURN.
    ENDIF.

    " ── Validate từng item ────────────────────────────────────
    DATA lv_has_error TYPE abap_boolean.
    LOOP AT ct_items REFERENCE INTO DATA(lr_item).
      DATA ls_po TYPE ty_po_snapshot.
      DATA lv_found TYPE abap_boolean.

      " Item required fields
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

      " PO lookup
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

      " Business checks
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

      " Enrich từ PO
      lr_item->material      = ls_po-material.
      lr_item->plant         = ls_po-plant.
      lr_item->order_qty     = ls_po-order_qty.
      lr_item->open_qty      = get_open_qty(
                                 iv_po_number = lr_item->po_number
                                 iv_po_item   = lr_item->po_item
                                 iv_order_qty = ls_po-order_qty ).

      " Qty check
      IF lr_item->receive_qty > lr_item->open_qty.
        lr_item->status  = gc_status_error.
        lr_item->message = |Receive Qty { lr_item->receive_qty } vượt Open Qty { lr_item->open_qty }|.
        lv_has_error = abap_true. CONTINUE.
      ENDIF.

      lr_item->status = gc_status_ready.
    ENDLOOP.

    cs_header-status = COND #( WHEN lv_has_error = abap_true
                               THEN gc_status_error
                               ELSE gc_status_ready ).
  ENDMETHOD.


  METHOD postgr.
    " ── Giống ZIF_CL_API_PGR=>postgr() ──────────────────────
    DATA ls_gm_code   TYPE bapi2017_gm_code.
    DATA ls_gm_header TYPE bapi2017_gm_head_01.
    DATA lt_gm_items  TYPE STANDARD TABLE OF bapi2017_gm_item_create.
    DATA lt_return    TYPE TABLE OF bapiret2.

    " MVT 101 → GMCode 01
    ls_gm_code-gm_code = SWITCH #( is_header-movement_type
                                    WHEN gc_mvt_gr_po THEN gc_gm_code_01
                                    ELSE gc_gm_code_01 ).

    " ⚠️ documentDate → CẢ pstng_date VÀ doc_date (giống ZIF line ~820)
    ls_gm_header-pstng_date = is_header-document_date.
    ls_gm_header-doc_date   = is_header-document_date.
    ls_gm_header-header_txt = is_header-gr_number.

    " Build BAPI items
    DATA lv_line TYPE i.
    LOOP AT it_items INTO DATA(ls_item).
      lv_line += 1.
      APPEND VALUE bapi2017_gm_item_create(
        line_id   = lv_line
        po_number = ls_item-po_number
        po_item   = ls_item-po_item
        move_type = is_header-movement_type
        plant     = ls_item-plant
        material  = ls_item-material
        entry_qnt = ls_item-receive_qty
        entry_uom = ls_item-unit
        stge_loc  = ls_item-storage_location
        mvt_ind   = gc_mvt_ind_po              " 'B' hardcoded
      ) TO lt_gm_items.
    ENDLOOP.

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

    " Parse BAPIRET2
    DATA lv_has_error TYPE abap_boolean.
    LOOP AT lt_return INTO DATA(ls_ret) WHERE type = 'E' OR type = 'A'.
      lv_has_error = abap_true.
      cs_result-message = COND #( WHEN cs_result-message IS INITIAL
                                  THEN ls_ret-message
                                  ELSE cs_result-message && ' | ' && ls_ret-message ).
    ENDLOOP.

    IF lv_has_error = abap_true.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      cs_result-status = gc_status_error.
      CLEAR: ev_material_document, ev_material_document_year.
    ELSE.
      IF iv_test = abap_false.
        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
        cs_result-status = gc_status_success.
      ELSE.
        cs_result-status = gc_status_ready.  " test run OK
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD upload_excel.
    " ── Gen batch ID ─────────────────────────────────────────
    DATA lv_batch_id TYPE zih_de_batch_id.
    lv_batch_id = cl_system_uuid=>create_uuid_c22_static( ).

    " ── Parse JSON → internal typed ──────────────────────────
    DATA lt_headers TYPE tyt_gr_header.
    TRY.
        parse_payload(
          EXPORTING iv_json     = iv_payload_json
                    iv_batch_id = lv_batch_id
          IMPORTING et_gr_headers = lt_headers ).
      CATCH cx_sy_conversion_error INTO DATA(lx).
        rs_result = VALUE #( batch_id = lv_batch_id
                             status   = gc_status_error
                             message  = lx->get_text( ) ).
        RETURN.
    ENDTRY.

    rs_result-batch_id    = lv_batch_id.
    rs_result-total_count = lines( lt_headers ).

    " ── Loop từng GR header ───────────────────────────────────
    LOOP AT lt_headers REFERENCE INTO DATA(lr_hd).

      " Validate + enrich items
      DATA ls_hd_val TYPE ty_gr_header.
      ls_hd_val = lr_hd->*.
      validate(
        EXPORTING is_header = ls_hd_val
        CHANGING  cs_header = lr_hd->*
                  ct_items  = lr_hd->items ).

      IF lr_hd->status = gc_status_error.
        rs_result-error_count += 1.
      ELSE.
        " BAPI test run
        DATA ls_hd_db    TYPE zmm_tb_gr_h.
        DATA ls_bapi_res TYPE ty_bapi_result.
        MOVE-CORRESPONDING lr_hd->* TO ls_hd_db.

        postgr( EXPORTING iv_test   = abap_true
                          is_header = ls_hd_db
                          it_items  = lr_hd->items
                CHANGING  cs_result = ls_bapi_res ).

        IF ls_bapi_res-status = gc_status_error.
          lr_hd->status  = gc_status_error.
          lr_hd->message = ls_bapi_res-message.
          rs_result-error_count += 1.
        ELSE.
          " Save staging
          MOVE-CORRESPONDING lr_hd->* TO ls_hd_db.
          ls_hd_db-status   = gc_status_ready.
          ls_hd_db-testmode = iv_testmode.
          MODIFY zmm_tb_gr_h FROM @ls_hd_db.
          MODIFY zmm_tb_gr_i FROM TABLE @( CORRESPONDING #( lr_hd->items ) ).
          COMMIT WORK AND WAIT.

          " Schedule job (nếu không phải testmode)
          IF iv_testmode = abap_false.
            schedule_job( lr_hd->gr_number ).
          ENDIF.

          rs_result-success_count += 1.
        ENDIF.
      ENDIF.
    ENDLOOP.

    rs_result-status = COND #( WHEN rs_result-error_count = 0
                               THEN gc_status_success
                               WHEN rs_result-success_count = 0
                               THEN gc_status_error
                               ELSE gc_status_ready ).  " partial
  ENDMETHOD.


  METHOD get_po_snapshot.
    " Check cache trước
    READ TABLE gt_po_cache INTO es_po
      WITH KEY po_number = iv_po_number
               po_item   = iv_po_item.
    IF sy-subrc = 0.
      ev_found = abap_true. RETURN.
    ENDIF.

    " SELECT từ ZMM_I_PO_LOOKUP (view trên EKPO + EKKO)
    SELECT SINGLE
        PurchaseOrder        AS po_number,
        PurchaseOrderItem    AS po_item,
        Material             AS material,
        Plant                AS plant,
        StorageLocation      AS storage_location,
        OrderQuantity        AS order_qty,
        OrderUnit            AS order_unit,
        Supplier             AS supplier,
        DeletionCode         AS deletion_code,
        DeliveryIsCompleted  AS delivery_completed,
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
    " On-premise: tính từ EKBE (history thật, kể cả GR từ ME21N)
    DATA lv_received TYPE menge_d.
    SELECT SUM( menge )
      FROM ekbe
      WHERE ebeln = @iv_po_number
        AND ebelp = @iv_po_item
        AND vgabe = '1'     " GR movement
        AND shkzg = ' '     " positive (không phải reversal)
      INTO @lv_received.

    rv_open_qty = iv_order_qty - lv_received.
    IF rv_open_qty < 0. rv_open_qty = 0. ENDIF.
  ENDMETHOD.


  METHOD check_duplicate.
    SELECT SINGLE @abap_true
      FROM zmm_tb_gr_h
      WHERE gr_number = @iv_gr_number
        AND status    = @gc_status_success
      INTO @rv_exists.
  ENDMETHOD.


  METHOD schedule_job.
    DATA ls_start_info TYPE cl_apj_rt_api=>ty_start_info.
    ls_start_info-start_immediately = abap_true.

    DATA lt_params TYPE cl_apj_rt_api=>tt_job_parameter_value.
    APPEND VALUE #(
      name    = 'GR_NUMBER'
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
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
