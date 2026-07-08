CLASS zpp_cl_zuplsx_posting_srv DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS post
      IMPORTING is_data    TYPE zpp_if_zuplsx_types=>ts_data
      EXPORTING et_results TYPE zpp_if_zuplsx_types=>tt_results.

  PRIVATE SECTION.
    METHODS create_one_order
      IMPORTING is_row          TYPE zpp_if_zuplsx_types=>ts_row
      EXPORTING ev_order        TYPE aufnr
                ev_error_msg    TYPE string
      RETURNING VALUE(rv_ok)    TYPE abap_bool.

    METHODS save_log
      IMPORTING is_data TYPE zpp_if_zuplsx_types=>ts_data
                is_row  TYPE zpp_if_zuplsx_types=>ts_row
                iv_aufnr TYPE aufnr.

ENDCLASS.


CLASS zpp_cl_zuplsx_posting_srv IMPLEMENTATION.

  METHOD post.
    CLEAR et_results.

    LOOP AT is_data-rows INTO DATA(ls_row).

      " Dòng đã có production order -> đã tạo trước đó, bỏ qua (port từ cloud)
      IF ls_row-production_order IS NOT INITIAL.
        APPEND VALUE #( client_row_id   = ls_row-client_row_id
                        id_doc          = ls_row-id_doc
                        productionorder = ls_row-production_order
                        type            = 'Information'
                        message         = |ID { ls_row-id_doc }: Đã có Production Order { ls_row-production_order }, bỏ qua.| )
               TO et_results.
        CONTINUE.
      ENDIF.

      " Testmode: dữ liệu đã qua validator, không gọi BAPI
      IF is_data-testmode = abap_true.
        APPEND VALUE #( client_row_id = ls_row-client_row_id
                        id_doc        = ls_row-id_doc
                        type          = 'Success'
                        message       = |ID { ls_row-id_doc }: Validate OK ({ ls_row-des_pv }). Testmode - chưa tạo lệnh.| )
               TO et_results.
        CONTINUE.
      ENDIF.

      DATA lv_order TYPE aufnr.
      DATA lv_error TYPE string.

      IF create_one_order( EXPORTING is_row       = ls_row
                           IMPORTING ev_order     = lv_order
                                     ev_error_msg = lv_error ) = abap_true.

        save_log( is_data = is_data is_row = ls_row iv_aufnr = lv_order ).

        APPEND VALUE #( client_row_id   = ls_row-client_row_id
                        id_doc          = ls_row-id_doc
                        productionorder = lv_order
                        type            = 'Success'
                        message         = |ID { ls_row-id_doc }: Production Order { lv_order } đã được tạo.| )
               TO et_results.
      ELSE.
        APPEND VALUE #( client_row_id = ls_row-client_row_id
                        id_doc        = ls_row-id_doc
                        type          = 'Error'
                        message       = |ID { ls_row-id_doc }: { lv_error }| )
               TO et_results.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD create_one_order.
    rv_ok = abap_false.
    CLEAR: ev_order, ev_error_msg.

    " === Mapping đã verify với structure BAPI_PP_ORDER_CREATE trên s40 ===
    DATA(ls_orderdata) = VALUE bapi_pp_order_create(
        material              = is_row-material
        plant                 = is_row-production_plant
        order_type            = is_row-order_type
        quantity              = is_row-total_qty
        quantity_uom          = is_row-base_unit
        basic_start_date      = is_row-date_start
        basic_end_date        = is_row-date_end
        prod_version          = is_row-production_version
        sales_order           = is_row-sale_order
        sales_order_item      = is_row-sale_order_item
        basic_scheduling_type = '3' ).

    DATA ls_return TYPE bapiret2.
    DATA lv_sysmsg TYPE c LENGTH 255.

    CALL FUNCTION 'ZPP_RFC_CREATE_PRODORD'
      DESTINATION 'NONE'
      EXPORTING
        is_orderdata          = ls_orderdata
      IMPORTING
        ev_order              = ev_order
        es_return             = ls_return
      EXCEPTIONS
        communication_failure = 1 MESSAGE lv_sysmsg
        system_failure        = 2 MESSAGE lv_sysmsg
        OTHERS                = 3.

    IF sy-subrc <> 0.
      ev_error_msg = COND #( WHEN lv_sysmsg IS NOT INITIAL
                             THEN |RFC failure: { lv_sysmsg }|
                             ELSE |RFC failure (subrc { sy-subrc }).| ).
      RETURN.
    ENDIF.

    IF ls_return-type CA 'EA' OR ev_order IS INITIAL.
      ev_error_msg = COND #( WHEN ls_return-message IS NOT INITIAL
                             THEN ls_return-message
                             ELSE 'BAPI_PRODORD_CREATE thất bại không rõ nguyên nhân.' ).
      RETURN.
    ENDIF.

    rv_ok = abap_true.
  ENDMETHOD.


  METHOD save_log.
    DATA(ls_save) = VALUE zpp_tb_zuplsx(
        material            = is_row-material
        productionplant     = is_row-production_plant
        productionorder     = iv_aufnr
        productionversion   = is_row-production_version
        productionordertype = is_row-order_type
        salesorder          = is_row-sale_order
        salesorderitem      = is_row-sale_order_item
        iddoc               = is_row-id_doc
        totalqty            = is_row-total_qty
        baseunit            = is_row-base_unit
        startdate           = is_row-date_start
        enddate             = is_row-date_end
        filename            = is_data-filename
        pst_date            = sy-datum
        pst_user            = sy-uname ).

    MODIFY zpp_tb_zuplsx FROM @ls_save.
  ENDMETHOD.

ENDCLASS.

