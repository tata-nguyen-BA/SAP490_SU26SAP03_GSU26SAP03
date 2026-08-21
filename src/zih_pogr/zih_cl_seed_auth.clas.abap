CLASS zih_cl_seed_auth DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zih_cl_seed_auth IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    DATA lt_auth TYPE STANDARD TABLE OF zih_tb_auth_user.
    lt_auth = VALUE #(
      ( user_email = 'dtphat2k4@gmail.com' process_id = 'FI' actvt = '03' )
      ( user_email = 'dtphat2k4@gmail.com' process_id = 'PP' actvt = '03' )
      ( user_email = 'dtphat2k4@gmail.com' process_id = 'GR' actvt = '03' )
      ( user_email = 'dtphat2k4@gmail.com' process_id = 'PP' actvt = '01' )
*      ( user_email = 'dtphat2k4@gmail.com' process_id = 'GR' actvt = '03' )
    ).

    MODIFY zih_tb_auth_user FROM TABLE @lt_auth.

    IF sy-subrc = 0.
      COMMIT WORK.
      out->write( |Đã chèn { lines( lt_auth ) } dòng thành công| ).
    ELSE.
      ROLLBACK WORK.
      out->write( 'Chèn thất bại' ).
    ENDIF.

    " In lại để kiểm tra
    SELECT * FROM zih_tb_auth_user INTO TABLE @DATA(lt_check).
    out->write( lt_check ).

  ENDMETHOD.
ENDCLASS.
