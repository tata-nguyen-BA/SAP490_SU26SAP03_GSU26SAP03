FUNCTION zpp_rfc_create_prodord.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IS_ORDERDATA) TYPE  BAPI_PP_ORDER_CREATE
*"  EXPORTING
*"     VALUE(EV_ORDER) TYPE  AUFNR
*"     VALUE(ES_RETURN) TYPE  BAPIRET2
*"----------------------------------------------------------------------
  CLEAR: ev_order, es_return.

  CALL FUNCTION 'BAPI_PRODORD_CREATE'
    EXPORTING
      orderdata    = is_orderdata
    IMPORTING
      return       = es_return
      order_number = ev_order.

  IF es_return-type CA 'EA'.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
  ELSE.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.
  ENDIF.

ENDFUNCTION.
