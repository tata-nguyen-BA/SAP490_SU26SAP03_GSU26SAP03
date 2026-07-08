CLASS zfi_cl_fidoc_http_wrap DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS send_soap
      IMPORTING iv_destination     TYPE rfcdest
                iv_uri_path        TYPE string
                iv_payload         TYPE string
      RETURNING VALUE(rv_response) TYPE string
      RAISING   cx_web_http_client_error.
ENDCLASS.

CLASS zfi_cl_fidoc_http_wrap IMPLEMENTATION.
  METHOD send_soap.
    DATA lo_client TYPE REF TO if_http_client.

    " === Bước 0: Tạo legacy HTTP client từ SM59 destination ===
    cl_http_client=>create_by_destination(
      EXPORTING  destination              = iv_destination
      IMPORTING  client                   = lo_client
      EXCEPTIONS argument_not_found       = 1
                 destination_not_found    = 2
                 destination_no_authority = 3
                 plugin_not_active        = 4
                 internal_error           = 5
                 OTHERS                   = 6 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_web_http_client_error.
    ENDIF.

    " Tắt logon popup, giữ session cookie giữa GET (fetch token) và POST
    lo_client->propertytype_logon_popup = if_http_client=>co_disabled.

    " === Bước 1: GET để fetch CSRF token ===
    lo_client->request->set_method( if_http_request=>co_request_method_get ).
    cl_http_utility=>set_request_uri(
      EXPORTING request = lo_client->request
                uri     = iv_uri_path ).
    lo_client->request->set_header_field( name  = 'X-CSRF-Token'
                                          value = 'Fetch' ).

    lo_client->send(
      EXCEPTIONS http_communication_failure = 1
                 http_invalid_state         = 2
                 http_processing_failed     = 3
                 OTHERS                     = 4 ).
    IF sy-subrc <> 0.
      lo_client->close( EXCEPTIONS OTHERS = 0 ).
      RAISE EXCEPTION TYPE cx_web_http_client_error.
    ENDIF.

    lo_client->receive(
      EXCEPTIONS http_communication_failure = 1
                 http_invalid_state         = 2
                 http_processing_failed     = 3
                 OTHERS                     = 4 ).
    " Lưu ý: GET có thể trả lỗi (vì SOAP endpoint không hỗ trợ GET),
    " nhưng token vẫn được trả về trong header. Không RAISE ở đây.

    DATA(lv_token) = lo_client->response->get_header_field( 'X-CSRF-Token' ).

    " === Bước 2: POST kèm CSRF token ===
    lo_client->request->set_method( if_http_request=>co_request_method_post ).
    cl_http_utility=>set_request_uri(
      EXPORTING request = lo_client->request
                uri     = iv_uri_path ).
    lo_client->request->set_header_field( name  = 'Content-Type'
                                          value = 'text/xml; charset=UTF-8' ).
    IF lv_token IS NOT INITIAL.
      lo_client->request->set_header_field( name  = 'X-CSRF-Token'
                                            value = lv_token ).
    ENDIF.
    lo_client->request->set_cdata( iv_payload ).

    lo_client->send(
      EXCEPTIONS http_communication_failure = 1
                 http_invalid_state         = 2
                 http_processing_failed     = 3
                 OTHERS                     = 4 ).
    IF sy-subrc <> 0.
      lo_client->close( EXCEPTIONS OTHERS = 0 ).
      RAISE EXCEPTION TYPE cx_web_http_client_error.
    ENDIF.

    lo_client->receive(
      EXCEPTIONS http_communication_failure = 1
                 http_invalid_state         = 2
                 http_processing_failed     = 3
                 OTHERS                     = 4 ).
    IF sy-subrc <> 0.
      lo_client->close( EXCEPTIONS OTHERS = 0 ).
      RAISE EXCEPTION TYPE cx_web_http_client_error.
    ENDIF.

    " === Bước 3: Lấy response + đóng ===
    rv_response = lo_client->response->get_cdata( ).
    lo_client->close( EXCEPTIONS OTHERS = 0 ).
  ENDMETHOD.
ENDCLASS.
