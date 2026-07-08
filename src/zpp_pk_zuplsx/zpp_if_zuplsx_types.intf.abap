INTERFACE zpp_if_zuplsx_types PUBLIC.

  "============================================================
  " 1. KIỂU GIẢI MÃ JSON (từ UI5, mọi field là string)
  "============================================================
  TYPES: BEGIN OF ts_row_request,
           client_row_id      TYPE string,
           id_doc             TYPE string,
           order_type         TYPE string,
           production_plant   TYPE string,
           total_qty          TYPE string,
           base_unit          TYPE string,
           material           TYPE string,
           production_version TYPE string,
           date_start         TYPE string,
           date_end           TYPE string,
           production_order   TYPE string,
           sale_order         TYPE string,
           sale_order_item    TYPE string,
           long_text          TYPE string,
         END OF ts_row_request.
  TYPES tt_row_request TYPE STANDARD TABLE OF ts_row_request WITH EMPTY KEY.

  TYPES: BEGIN OF ts_post_request,
           filename TYPE string,
           testmode TYPE string,
           rows     TYPE tt_row_request,
         END OF ts_post_request.

  "============================================================
  " 2. KIỂU XỬ LÝ NỘI BỘ (đã convert/validate)
  "============================================================
  TYPES: BEGIN OF ts_row,
           client_row_id      TYPE i,
           id_doc             TYPE zpp_tb_zuplsx-iddoc,
           order_type         TYPE auart,
           production_plant   TYPE werks_d,
           total_qty          TYPE zpp_tb_zuplsx-totalqty,
           base_unit          TYPE meins,
           material           TYPE matnr,
           production_version TYPE verid,
           date_start         TYPE dats,
           date_end           TYPE dats,
           production_order   TYPE aufnr,
           sale_order         TYPE vbeln,
           sale_order_item    TYPE posnr,
           long_text          TYPE string,
           des_pv             TYPE string,
         END OF ts_row.
  TYPES tt_rows TYPE STANDARD TABLE OF ts_row WITH EMPTY KEY.

  TYPES: BEGIN OF ts_data,
           filename TYPE string,
           testmode TYPE abap_bool,
           rows     TYPE tt_rows,
         END OF ts_data.

  "============================================================
  " 3. KIỂU TRẢ VỀ
  "============================================================
  TYPES: BEGIN OF ts_result,
           client_row_id   TYPE i,
           id_doc          TYPE zpp_tb_zuplsx-iddoc,
           type            TYPE string,    " Success / Error / Warning / Information
           message         TYPE string,
           productionorder TYPE aufnr,
         END OF ts_result.
  TYPES tt_results TYPE STANDARD TABLE OF ts_result WITH EMPTY KEY.

ENDINTERFACE.
