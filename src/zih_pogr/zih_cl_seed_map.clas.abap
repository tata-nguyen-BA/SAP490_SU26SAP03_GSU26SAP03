CLASS zih_cl_seed_map DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zih_cl_seed_map IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    CONSTANTS lc_id TYPE zih_tb_map_h-mapping_id VALUE 'POGR001'.

    DATA(lv_now) = utclong_current( ).

    DELETE FROM zih_tb_map_i WHERE mapping_id = @lc_id.
    DELETE FROM zih_tb_map_h WHERE mapping_id = @lc_id.

    INSERT zih_tb_map_h FROM @( VALUE #(
      mapping_id      = lc_id
      process_id      = 'GR'
      description     = 'Template GR chuẩn (PO-based Goods Receipt)'
      is_default      = abap_true
      created_at      = lv_now
      created_by      = 'system'
      last_changed_at = lv_now
      last_changed_by = 'system' ) ).

    INSERT zih_tb_map_i FROM TABLE @( VALUE #(
      mapping_id = lc_id
      ( target_field = 'gr_number'        seq = 1 field_label = 'Số phiếu nhập'
        bapi_structure = ''               bapi_field = ''
        source_header = 'gr_number'        is_required = abap_true )
      ( target_field = 'document_date'    seq = 2 field_label = 'Ngày chứng từ'
        bapi_structure = 'GOODSMVT_HEADER' bapi_field = 'DOC_DATE'
        source_header = 'document_date'    is_required = abap_true )
      ( target_field = 'movement_type'    seq = 3 field_label = 'Loại chuyển động'
        bapi_structure = 'GOODSMVT_ITEM'   bapi_field = 'MOVE_TYPE'
        source_header = 'movement_type'    is_required = abap_true )
      ( target_field = 'po_number'        seq = 4 field_label = 'Số PO'
        bapi_structure = 'GOODSMVT_ITEM'   bapi_field = 'PO_NUMBER'
        source_header = 'po_number'        is_required = abap_true )
      ( target_field = 'po_item'          seq = 5 field_label = 'Dòng PO'
        bapi_structure = 'GOODSMVT_ITEM'   bapi_field = 'PO_ITEM'
        source_header = 'po_item'          is_required = abap_true )
      ( target_field = 'receive_qty'      seq = 6 field_label = 'Số lượng nhận'
        bapi_structure = 'GOODSMVT_ITEM'   bapi_field = 'ENTRY_QNT'
        source_header = 'receive_qty'      is_required = abap_true )
      ( target_field = 'unit'             seq = 7 field_label = 'Đơn vị tính'
        bapi_structure = 'GOODSMVT_ITEM'   bapi_field = 'ENTRY_UOM'
        source_header = 'unit'             is_required = abap_true )
      ( target_field = 'batch'            seq = 8 field_label = 'Số lô'
        bapi_structure = 'GOODSMVT_ITEM'   bapi_field = 'BATCH'
        source_header = 'batch'            is_required = abap_false )
      ( target_field = 'storage_location' seq = 9 field_label = 'Kho lưu'
        bapi_structure = 'GOODSMVT_ITEM'   bapi_field = 'STGE_LOC'
        source_header = 'storage_location' is_required = abap_true )
    ) ).

    COMMIT WORK.

    SELECT * FROM zih_tb_map_i WHERE mapping_id = @lc_id
      ORDER BY seq INTO TABLE @DATA(lt_check).
    out->write( |Đã seed { lines( lt_check ) } dòng cho cấu hình { lc_id }| ).
    out->write( lt_check ).

  ENDMETHOD.
ENDCLASS.
