CLASS zih_cl_auth DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CONSTANTS:
      gc_mod_fi   TYPE zih_de_process_id VALUE 'FI',
      gc_mod_pp   TYPE zih_de_process_id VALUE 'PP',
      gc_mod_gr   TYPE zih_de_process_id VALUE 'GR',
      gc_act_post TYPE zih_de_actvt      VALUE '01',
      gc_act_view TYPE zih_de_actvt      VALUE '03'.

    " Trả về rỗng nếu được phép, ngược lại trả về lý do để hiển thị cho người dùng
    CLASS-METHODS check
      IMPORTING
        iv_email        TYPE string
        iv_process_id   TYPE zih_de_process_id
        iv_actvt        TYPE zih_de_actvt
      RETURNING
        VALUE(rv_error) TYPE string.
ENDCLASS.

CLASS zih_cl_auth IMPLEMENTATION.
  METHOD check.
    DATA(lv_email) = to_lower( condense( iv_email ) ).

    " Không nhận diện được người dùng thì từ chối, nhưng phải nói rõ lý do —
    " im lặng từ chối là thứ từng làm cả action bị chặn ngầm
    IF lv_email IS INITIAL.
      rv_error = 'Không xác định được tài khoản đăng nhập'.
      RETURN.
    ENDIF.

    SELECT SINGLE @abap_true
      FROM zih_tb_auth_user
      WHERE user_email = @lv_email
        AND process_id = @iv_process_id
        AND actvt      = @iv_actvt
      INTO @DATA(lv_ok).

    IF lv_ok <> abap_true.
      rv_error = |Tài khoản { lv_email } không có quyền { iv_actvt } trên phân hệ { iv_process_id }|.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

