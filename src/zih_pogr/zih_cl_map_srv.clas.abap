CLASS zih_cl_map_srv DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_map_line,
             target_field   TYPE zih_tb_map_i-target_field,
             seq            TYPE zih_tb_map_i-seq,
             field_label    TYPE zih_tb_map_i-field_label,
             bapi_structure TYPE zih_tb_map_i-bapi_structure,
             bapi_field     TYPE zih_tb_map_i-bapi_field,
             source_header  TYPE zih_tb_map_i-source_header,
             is_required    TYPE zih_tb_map_i-is_required,
           END OF ty_map_line.
    TYPES tyt_map_line TYPE STANDARD TABLE OF ty_map_line WITH EMPTY KEY.

 TYPES: BEGIN OF ty_resolver,
             source_norm  TYPE string,
             target_field TYPE zih_tb_map_i-target_field,
           END OF ty_resolver.
    TYPES tyt_resolver TYPE HASHED TABLE OF ty_resolver
                       WITH UNIQUE KEY source_norm.

    CLASS-METHODS get_mapping
      IMPORTING
        iv_mapping_id  TYPE zih_tb_map_h-mapping_id OPTIONAL
        iv_process_id  TYPE zih_de_process_id       OPTIONAL
      RETURNING
        VALUE(rt_map)  TYPE tyt_map_line.


    CLASS-METHODS normalize
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_norm) TYPE string.

    CLASS-METHODS build_resolver
      IMPORTING
        it_map             TYPE tyt_map_line
      RETURNING
        VALUE(rt_resolver) TYPE tyt_resolver.

       CLASS-METHODS save_mapping
      IMPORTING
        iv_mapping_id    TYPE zih_tb_map_h-mapping_id
        iv_process_id    TYPE zih_de_process_id
        iv_description   TYPE zih_tb_map_h-description OPTIONAL
        iv_user_email    TYPE string                   OPTIONAL
        iv_payload_json  TYPE string
        iv_commit        TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rv_error)  TYPE string.

         CLASS-METHODS check_required
      IMPORTING
        it_map            TYPE tyt_map_line
        it_headers_norm   TYPE string_table
      RETURNING
        VALUE(rv_error)   TYPE string.

ENDCLASS.
CLASS zih_cl_map_srv IMPLEMENTATION.

  METHOD get_mapping.
    DATA lv_id TYPE zih_tb_map_h-mapping_id.
    lv_id = iv_mapping_id.

    " Không chỉ định cấu hình cụ thể -> lấy cấu hình mặc định của phân hệ
    IF lv_id IS INITIAL AND iv_process_id IS NOT INITIAL.
      SELECT SINGLE mapping_id FROM zih_tb_map_h
        WHERE process_id = @iv_process_id
          AND is_default = @abap_true
        INTO @lv_id.
    ENDIF.

    IF lv_id IS INITIAL.
      RETURN.
    ENDIF.

    SELECT target_field, seq, field_label, bapi_structure, bapi_field,
           source_header, is_required
      FROM zih_tb_map_i
      WHERE mapping_id = @lv_id
      ORDER BY seq
      INTO CORRESPONDING FIELDS OF TABLE @rt_map.
  ENDMETHOD.


  METHOD normalize.
    rv_norm = to_lower( iv_text ).
    REPLACE ALL OCCURRENCES OF ` ` IN rv_norm WITH ``.
    REPLACE ALL OCCURRENCES OF `_` IN rv_norm WITH ``.
    REPLACE ALL OCCURRENCES OF `-` IN rv_norm WITH ``.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN rv_norm WITH ``.
    rv_norm = condense( rv_norm ).
  ENDMETHOD.


  METHOD build_resolver.
    LOOP AT it_map INTO DATA(ls_map).
      IF ls_map-source_header IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( source_norm  = normalize( CONV string( ls_map-source_header ) )
                      target_field = ls_map-target_field )
             INTO TABLE rt_resolver.
    ENDLOOP.
  ENDMETHOD.



  METHOD save_mapping.
    TYPES: BEGIN OF ty_in_line,
             target_field   TYPE string,
             seq            TYPE i,
             field_label    TYPE string,
             bapi_structure TYPE string,
             bapi_field     TYPE string,
             source_header  TYPE string,
             is_required    TYPE abap_bool,
           END OF ty_in_line.
    DATA: BEGIN OF ls_in,
            fields TYPE STANDARD TABLE OF ty_in_line WITH EMPTY KEY,
          END OF ls_in.

    TRY.
        /ui2/cl_json=>deserialize(
          EXPORTING json = iv_payload_json
                    pretty_name = /ui2/cl_json=>pretty_mode-camel_case
          CHANGING  data = ls_in ).
      CATCH cx_root INTO DATA(lx).
        rv_error = |Không đọc được cấu hình gửi lên: { lx->get_text( ) }|.
        RETURN.
    ENDTRY.

    IF ls_in-fields IS INITIAL.
      rv_error = 'Cấu hình rỗng — không có dòng ánh xạ nào'.
      RETURN.
    ENDIF.

    DATA(lv_now) = utclong_current( ).

    " Header: tạo mới nếu chưa có, giữ nguyên created_* nếu đã có
    SELECT SINGLE @abap_true FROM zih_tb_map_h
      WHERE mapping_id = @iv_mapping_id INTO @DATA(lv_exists).

    DATA ls_h TYPE zih_tb_map_h.
    ls_h-mapping_id      = iv_mapping_id.
    ls_h-process_id      = iv_process_id.
    ls_h-description     = iv_description.
    ls_h-last_changed_at = lv_now.
    ls_h-last_changed_by = iv_user_email.
    IF lv_exists <> abap_true.
      ls_h-created_at = lv_now.
      ls_h-created_by = iv_user_email.
    ELSE.
      SELECT SINGLE created_at, created_by FROM zih_tb_map_h
        WHERE mapping_id = @iv_mapping_id
        INTO (@ls_h-created_at, @ls_h-created_by).
    ENDIF.
    MODIFY zih_tb_map_h FROM @ls_h.

    DELETE FROM zih_tb_map_i WHERE mapping_id = @iv_mapping_id.

    DATA lt_i TYPE STANDARD TABLE OF zih_tb_map_i.
    LOOP AT ls_in-fields INTO DATA(ls_f).
      APPEND VALUE #( mapping_id     = iv_mapping_id
                      target_field   = to_lower( ls_f-target_field )
                      seq            = ls_f-seq
                      field_label    = ls_f-field_label
                      bapi_structure = to_upper( ls_f-bapi_structure )
                      bapi_field     = to_upper( ls_f-bapi_field )
                      source_header  = ls_f-source_header
                      is_required    = ls_f-is_required ) TO lt_i.
    ENDLOOP.
    INSERT zih_tb_map_i FROM TABLE @lt_i.

    IF sy-subrc <> 0.
      rv_error = 'Ghi cấu hình thất bại'.
      RETURN.
    ENDIF.

    IF iv_commit = abap_true.
      COMMIT WORK.
    ENDIF.
  ENDMETHOD.


  METHOD check_required.
    DATA lt_missing TYPE string_table.

    LOOP AT it_map INTO DATA(ls_map) WHERE is_required = abap_true.
      IF ls_map-source_header IS INITIAL.
        APPEND |{ ls_map-field_label } (chưa được ánh xạ tới cột nào)| TO lt_missing.
        CONTINUE.
      ENDIF.
      DATA(lv_norm) = normalize( CONV string( ls_map-source_header ) ).
      READ TABLE it_headers_norm TRANSPORTING NO FIELDS WITH KEY table_line = lv_norm.
      IF sy-subrc <> 0.
        APPEND |{ ls_map-field_label } (cột "{ ls_map-source_header }")| TO lt_missing.
      ENDIF.
    ENDLOOP.

    IF lt_missing IS NOT INITIAL.
      rv_error = |File thiếu cột bắt buộc: { concat_lines_of( table = lt_missing sep = `, ` ) }. | &&
                 |Kiểm tra lại file hoặc sửa cấu hình ánh xạ.|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
