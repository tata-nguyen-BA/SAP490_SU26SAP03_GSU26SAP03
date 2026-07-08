"! <p class="shorttext synchronized" lang="vn">PP Order Upload – Validator (mirror zfi_cl_fidoc_validator)</p>
"! Port toàn bộ logic validate từ zpp_cl_api_zuplsx (cloud HTTP service):
"! - Convert string -> typed (date, qty, ALPHA IN)
"! - Required fields
"! - Rule Order Type <-> Sales Order (MTO/MTS)
"! - Production Version + Sales Order link qua zpp_i_upload_po_valid_material
CLASS zpp_cl_zuplsx_validator DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING is_request TYPE zpp_if_zuplsx_types=>ts_post_request.

    METHODS validate
      EXPORTING es_data             TYPE zpp_if_zuplsx_types=>ts_data
                et_errors           TYPE zpp_if_zuplsx_types=>tt_results
      RETURNING VALUE(rv_has_error) TYPE abap_bool.

  PRIVATE SECTION.
    DATA ms_request TYPE zpp_if_zuplsx_types=>ts_post_request.

    " Order type yêu cầu Sales Order (MTO).
    " LƯU Ý: Z101/Z201/... là config NTSF. Trên TUM UCC đổi cho khớp
    " config training (thường chỉ có PP01/PP02 MTS -> để bảng RỖNG thì
    " rule "MTO phải có SO" bị tắt, chỉ còn rule "có SO thì order type
    " phải thuộc bảng" -> cũng tắt nốt khi bảng rỗng).
    CLASS-DATA gr_mto_order_type TYPE RANGE OF auart.

    METHODS conv_date
      IMPORTING iv_raw         TYPE string
      RETURNING VALUE(rv_date) TYPE dats.

    METHODS conv_qty
      IMPORTING iv_raw       TYPE string
      EXPORTING ev_qty       TYPE zpp_tb_zuplsx-totalqty
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    "! Đổi mã unit hiển thị (T006A-MSEH3, vd "PC") sang mã nội bộ MEINS (vd "ST").
    "! Thử ngôn ngữ đăng nhập trước, không có thì fallback tiếng Anh.
    METHODS conv_unit
      IMPORTING iv_raw       TYPE string
      EXPORTING ev_unit      TYPE meins
      RETURNING VALUE(rv_ok) TYPE abap_bool.

ENDCLASS.


CLASS zpp_cl_zuplsx_validator IMPLEMENTATION.

  METHOD constructor.
    ms_request = is_request.

    IF gr_mto_order_type IS INITIAL.
      gr_mto_order_type = VALUE #( sign = 'I' option = 'EQ'
                                   ( low = 'Z101' ) ( low = 'Z201' ) ( low = 'Z301' )
                                   ( low = 'Z103' ) ( low = 'Z203' ) ( low = 'Z303' ) ).
      " TUM UCC: comment block trên và để rỗng nếu không test MTO
    ENDIF.
  ENDMETHOD.


  METHOD validate.
    rv_has_error      = abap_false.
    es_data-filename  = ms_request-filename.
    es_data-testmode  = COND #( WHEN ms_request-testmode IS NOT INITIAL THEN abap_true ).

    " --- 1. Convert từng dòng string -> typed ---
    LOOP AT ms_request-rows INTO DATA(ls_raw).
      DATA(ls_row) = VALUE zpp_if_zuplsx_types=>ts_row(
          id_doc             = ls_raw-id_doc
          order_type         = to_upper( ls_raw-order_type )
          production_plant   = ls_raw-production_plant
          material           = |{ ls_raw-material ALPHA = IN }|
          production_version = ls_raw-production_version
          production_order   = ls_raw-production_order
          long_text          = ls_raw-long_text ).

      TRY.
          ls_row-client_row_id = ls_raw-client_row_id.
        CATCH cx_sy_conversion_no_number.
          ls_row-client_row_id = sy-tabix.
      ENDTRY.

      IF ls_raw-base_unit IS NOT INITIAL.
        IF conv_unit( EXPORTING iv_raw  = ls_raw-base_unit
                      IMPORTING ev_unit = ls_row-base_unit ) = abap_false.
          rv_has_error = abap_true.
          APPEND VALUE #( client_row_id = ls_row-client_row_id
                          id_doc        = ls_row-id_doc
                          type          = 'Error'
                          message       = |ID { ls_raw-id_doc }: Đơn vị tính "{ ls_raw-base_unit }" không tồn tại (T006).| )
                 TO et_errors.
          CONTINUE.
        ENDIF.
      ENDIF.

      IF ls_raw-sale_order IS NOT INITIAL.
        ls_row-sale_order = |{ ls_raw-sale_order ALPHA = IN }|.
      ENDIF.
      IF ls_raw-sale_order_item IS NOT INITIAL.
        ls_row-sale_order_item = |{ ls_raw-sale_order_item ALPHA = IN }|.
      ENDIF.

      " Required fields (port từ cloud: material/plant/pv/ordertype/qty)
      IF    ls_row-material           IS INITIAL
         OR ls_row-production_plant   IS INITIAL
         OR ls_row-production_version IS INITIAL
         OR ls_row-order_type         IS INITIAL
         OR ls_raw-total_qty          IS INITIAL.
        rv_has_error = abap_true.
        APPEND VALUE #( client_row_id = ls_row-client_row_id
                        id_doc        = ls_row-id_doc
                        type          = 'Error'
                        message       = |ID { ls_row-id_doc }: Thiếu field bắt buộc (Material/Plant/PV/Order Type/Qty).| )
               TO et_errors.
        CONTINUE.
      ENDIF.

      IF conv_qty( EXPORTING iv_raw = ls_raw-total_qty
                   IMPORTING ev_qty = ls_row-total_qty ) = abap_false.
        rv_has_error = abap_true.
        APPEND VALUE #( client_row_id = ls_row-client_row_id
                        id_doc        = ls_row-id_doc
                        type          = 'Error'
                        message       = |ID { ls_row-id_doc }: Total Qty "{ ls_raw-total_qty }" không phải số hợp lệ.| )
               TO et_errors.
        CONTINUE.
      ENDIF.

      ls_row-date_start = conv_date( ls_raw-date_start ).
      ls_row-date_end   = conv_date( ls_raw-date_end ).
      IF ls_row-date_start IS INITIAL OR ls_row-date_end IS INITIAL.
        rv_has_error = abap_true.
        APPEND VALUE #( client_row_id = ls_row-client_row_id
                        id_doc        = ls_row-id_doc
                        type          = 'Error'
                        message       = |ID { ls_row-id_doc }: Ngày start/end không hợp lệ (nhận DD/MM/YYYY, DD.MM.YYYY hoặc YYYYMMDD).| )
               TO et_errors.
        CONTINUE.
      ENDIF.

      " Rule MTO/MTS (port nguyên từ cloud)
      IF gr_mto_order_type IS NOT INITIAL.
        IF ls_row-order_type IN gr_mto_order_type AND ls_row-sale_order IS INITIAL.
          rv_has_error = abap_true.
          APPEND VALUE #( client_row_id = ls_row-client_row_id
                          id_doc        = ls_row-id_doc
                          type          = 'Error'
                          message       = |ID { ls_row-id_doc }: Order Type { ls_row-order_type } yêu cầu Sales Order.| )
                 TO et_errors.
          CONTINUE.
        ENDIF.
        IF ls_row-order_type NOT IN gr_mto_order_type AND ls_row-sale_order IS NOT INITIAL.
          rv_has_error = abap_true.
          APPEND VALUE #( client_row_id = ls_row-client_row_id
                          id_doc        = ls_row-id_doc
                          type          = 'Error'
                          message       = |ID { ls_row-id_doc }: Order Type { ls_row-order_type } không hợp lệ để liên kết Sales Order.| )
                 TO et_errors.
          CONTINUE.
        ENDIF.
      ENDIF.

      APPEND ls_row TO es_data-rows.
    ENDLOOP.

    IF es_data-rows IS INITIAL.
      RETURN.
    ENDIF.

    " --- 2. Validate Production Version + Sales Order link (1 SELECT) ---
    SELECT DISTINCT ipv~material,
                    ipv~plant,
                    ipv~productionversion,
                    ipv~productionversiontext,
                    ipv~salesorder,
                    ipv~salesorderitem
      FROM zpp_i_upload_po_valid_material AS ipv
             INNER JOIN
               @es_data-rows AS req ON  ipv~material          = req~material
                                    AND ipv~plant             = req~production_plant
                                    AND ipv~productionversion = req~production_version
      INTO TABLE @DATA(lt_pv).

    LOOP AT es_data-rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      READ TABLE lt_pv INTO DATA(ls_pv)
           WITH KEY material          = <ls_row>-material
                    plant             = <ls_row>-production_plant
                    productionversion = <ls_row>-production_version.
      IF sy-subrc <> 0.
        rv_has_error = abap_true.
        APPEND VALUE #( client_row_id = <ls_row>-client_row_id
                        id_doc        = <ls_row>-id_doc
                        type          = 'Error'
                        message       = |ID { <ls_row>-id_doc }: Không tồn tại Production Version { <ls_row>-production_version } cho { <ls_row>-material }/{ <ls_row>-production_plant }.| )
               TO et_errors.
        CONTINUE.
      ENDIF.
      <ls_row>-des_pv = ls_pv-productionversiontext.

      IF <ls_row>-sale_order IS INITIAL.
        CONTINUE.
      ENDIF.

      READ TABLE lt_pv INTO DATA(ls_so)
           WITH KEY material          = <ls_row>-material
                    plant             = <ls_row>-production_plant
                    productionversion = <ls_row>-production_version
                    salesorder        = <ls_row>-sale_order.
      IF sy-subrc = 0.
        <ls_row>-sale_order_item = ls_so-salesorderitem.
      ELSE.
        rv_has_error = abap_true.
        APPEND VALUE #( client_row_id = <ls_row>-client_row_id
                        id_doc        = <ls_row>-id_doc
                        type          = 'Error'
                        message       = |ID { <ls_row>-id_doc }: Sales Order { <ls_row>-sale_order } không thuộc Material/Production Version.| )
               TO et_errors.
      ENDIF.
    ENDLOOP.

    " --- 3. Check sớm các điều kiện BAPI sẽ đòi khi tạo lệnh ---
    " (đồng bộ Check với Post: OPL8 per plant + view Work Scheduling)
    IF es_data-rows IS NOT INITIAL.

      " 3a. Order type đã khai cho plant chưa (T399X = OPL8)
      SELECT werks, auart
        FROM t399x
        FOR ALL ENTRIES IN @es_data-rows
        WHERE werks = @es_data-rows-production_plant
          AND auart = @es_data-rows-order_type
        INTO TABLE @DATA(lt_t399x).

      " 3b. Material đã maintain view Work Scheduling tại plant chưa
      " (MARC-PSTAT chứa 'A' = view Work Scheduling)
      SELECT matnr, werks, pstat
        FROM marc
        FOR ALL ENTRIES IN @es_data-rows
        WHERE matnr = @es_data-rows-material
          AND werks = @es_data-rows-production_plant
        INTO TABLE @DATA(lt_marc).

      LOOP AT es_data-rows INTO DATA(ls_chk).

        IF NOT line_exists( lt_t399x[ werks = ls_chk-production_plant
                                      auart = ls_chk-order_type ] ).
          rv_has_error = abap_true.
          APPEND VALUE #( client_row_id = ls_chk-client_row_id
                          id_doc        = ls_chk-id_doc
                          type          = 'Error'
                          message       = |ID { ls_chk-id_doc }: Order Type { ls_chk-order_type } chưa được khai cho Plant { ls_chk-production_plant } (OPL8).| )
                 TO et_errors.
          CONTINUE.
        ENDIF.

        READ TABLE lt_marc INTO DATA(ls_marc)
             WITH KEY matnr = ls_chk-material
                      werks = ls_chk-production_plant.
        IF sy-subrc <> 0 OR ls_marc-pstat NA 'A'.
          rv_has_error = abap_true.
          APPEND VALUE #( client_row_id = ls_chk-client_row_id
                          id_doc        = ls_chk-id_doc
                          type          = 'Error'
                          message       = |ID { ls_chk-id_doc }: Material { ls_chk-material } chưa maintain view Work Scheduling tại Plant { ls_chk-production_plant } (MM01).| )
                 TO et_errors.
        ENDIF.

      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD conv_date.
    CLEAR rv_date.
    DATA(lv_raw) = condense( iv_raw ).
    IF lv_raw IS INITIAL.
      RETURN.
    ENDIF.

    REPLACE ALL OCCURRENCES OF '.' IN lv_raw WITH '/'.
    REPLACE ALL OCCURRENCES OF '-' IN lv_raw WITH '/'.

    IF lv_raw CA '/'.
      SPLIT lv_raw AT '/' INTO DATA(lv_d) DATA(lv_m) DATA(lv_y).
      IF strlen( lv_y ) = 4 AND lv_d CO '0123456789' AND lv_m CO '0123456789'.
        DATA(lv_try) = |{ lv_y }{ lv_m ALIGN = RIGHT PAD = '0' WIDTH = 2 }{ lv_d ALIGN = RIGHT PAD = '0' WIDTH = 2 }|.
        rv_date = lv_try.
      ENDIF.
    ELSEIF strlen( lv_raw ) = 8 AND lv_raw CO '0123456789'.
      rv_date = lv_raw.
    ENDIF.

    " Sanity check: tháng 01-12, ngày 01-31
    IF rv_date IS NOT INITIAL.
      IF rv_date+4(2) < '01' OR rv_date+4(2) > '12' OR rv_date+6(2) < '01' OR rv_date+6(2) > '31'.
        CLEAR rv_date.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD conv_qty.
    rv_ok = abap_false.
    CLEAR ev_qty.
    DATA(lv_raw) = condense( iv_raw ).
    " Chuẩn hóa định dạng VN: "1.000,5" -> bỏ "." nghìn -> "1000,5" -> "1000.5"
    IF lv_raw CA ',' AND lv_raw CA '.'.
      REPLACE ALL OCCURRENCES OF '.' IN lv_raw WITH ''.
    ENDIF.
    REPLACE ALL OCCURRENCES OF ',' IN lv_raw WITH '.'.
    TRY.
        ev_qty = lv_raw.
        IF ev_qty > 0.
          rv_ok = abap_true.
        ENDIF.
      CATCH cx_sy_conversion_no_number cx_sy_arithmetic_overflow.
        rv_ok = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD conv_unit.
    rv_ok = abap_false.
    CLEAR ev_unit.

    DATA(lv_input) = CONV mseh3( to_upper( condense( iv_raw ) ) ).
    IF lv_input IS INITIAL.
      rv_ok = abap_true. " rỗng hợp lệ: BAPI tự lấy base UoM của material
      RETURN.
    ENDIF.

    " Thử ngôn ngữ đăng nhập trước
    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_INPUT'
      EXPORTING
        input          = lv_input
        language       = sy-langu
      IMPORTING
        output         = ev_unit
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    IF sy-subrc = 0.
      rv_ok = abap_true.
      RETURN.
    ENDIF.

    " Fallback tiếng Anh (mã unit Excel thường theo EN, vd PC/EA)
    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_INPUT'
      EXPORTING
        input          = lv_input
        language       = 'E'
      IMPORTING
        output         = ev_unit
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    IF sy-subrc = 0.
      rv_ok = abap_true.
    ELSE.
      CLEAR ev_unit.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

