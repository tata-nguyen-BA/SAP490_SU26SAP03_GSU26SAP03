CLASS zfi_cl_fidoc_validator DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING is_request TYPE zfi_if_fidoc_types=>ts_post_request.

    METHODS validate
      EXPORTING et_data             TYPE zfi_if_fidoc_types=>tt_data
                et_errors           TYPE zfi_if_fidoc_types=>tt_results
      RETURNING VALUE(rv_has_error) TYPE abap_bool.

  PRIVATE SECTION.
    DATA ms_request TYPE zfi_if_fidoc_types=>ts_post_request.

    METHODS convert_and_validate_item
      IMPORTING is_raw              TYPE zfi_if_fidoc_types=>ts_doc_item_request
                iv_doc_id           TYPE string
      EXPORTING es_item             TYPE zfi_if_fidoc_types=>ts_item
                et_item_errors      TYPE zfi_if_fidoc_types=>tt_results
      RETURNING VALUE(rv_item_valid) TYPE abap_bool.

ENDCLASS.



CLASS ZFI_CL_FIDOC_VALIDATOR IMPLEMENTATION.


  METHOD constructor.
    ms_request = is_request.
  ENDMETHOD.


  METHOD validate.
    rv_has_error = abap_false.

    LOOP AT ms_request-doc INTO DATA(ls_doc).
      DATA(ls_data) = VALUE zfi_if_fidoc_types=>ts_data( filename        = ms_request-filename
                                                         id_doc          = ls_doc-id_doc
                                                         companycode     = ls_doc-companycode
                                                         documentdate    = ls_doc-documentdate
                                                         postingdate     = ls_doc-postingdate
                                                         documenttype    = ls_doc-documenttype
                                                         currency        = ls_doc-currency
                                                         headertext      = ls_doc-headertext
                                                         referencedoc    = ls_doc-referencedoc
                                                         headerref1      = ls_doc-headerref1 ).

      LOOP AT ls_doc-to_item INTO DATA(ls_raw_item).
        ls_raw_item-AccountingDocumentItem = sy-tabix.

        DATA(ls_converted_item) = VALUE zfi_if_fidoc_types=>ts_item( ).
        DATA(lt_item_errors)    = VALUE zfi_if_fidoc_types=>tt_results( ).

        DATA(lv_item_valid) = convert_and_validate_item( EXPORTING is_raw         = ls_raw_item
                                                                   iv_doc_id      = ls_doc-id_doc
                                                         IMPORTING es_item        = ls_converted_item
                                                                   et_item_errors = lt_item_errors ).

        APPEND LINES OF lt_item_errors TO et_errors.
        IF lt_item_errors IS NOT INITIAL.
          rv_has_error = abap_true.
        ENDIF.

        IF lv_item_valid = abap_true.
          APPEND ls_converted_item TO ls_data-to_item.
        ENDIF.
      ENDLOOP.

      APPEND ls_data TO et_data.
    ENDLOOP.
  ENDMETHOD.


  METHOD convert_and_validate_item.
    rv_item_valid     = abap_true.
    DATA(lv_filename) = CONV zfi_de_filename( ms_request-filename ).

    IF is_raw-amountindoumentcurrency IS INITIAL OR is_raw-amountindoumentcurrency = '0'.
      APPEND VALUE #(
          filename = lv_filename
          id_doc   = iv_doc_id
          type     = 'Error'
          message  = |ID Doc { iv_doc_id } - Dòng { is_raw-idline }: Thiếu field "Amount in Document Currency". Vui lòng điền giá trị.| )
             TO et_item_errors.
      rv_item_valid = abap_false.
      RETURN.
    ENDIF.

    IF     is_raw-localtaxbaseamount IS NOT INITIAL AND is_raw-localtaxbaseamount <> '0'
       AND ( is_raw-taxbaseamount IS INITIAL OR is_raw-taxbaseamount = '0' ).
      APPEND VALUE #(
          filename = lv_filename
          id_doc   = iv_doc_id
          type     = 'Error'
          message  = |ID Doc { iv_doc_id } - Dòng { is_raw-idline }: Đã điền "Tax Base Amount in Local Currency" nhưng thiếu "Tax Base Amount in Document Currency".| )
             TO et_item_errors.
      rv_item_valid = abap_false.
      RETURN.
    ENDIF.

    DATA lv_doc_cur   TYPE i value 1.
    DATA lv_local_cur TYPE i value 100.

    IF is_raw-transactioncurrency = 'VND'.
      lv_doc_cur = 100.
    ENDIF.

    DATA(lv_amount_local)   = CONV fins_vwcur12( is_raw-amountinlocalcurrency / lv_local_cur ).
    DATA(lv_local_tax_base) = CONV fins_vwcur12( is_raw-localtaxbaseamount / lv_local_cur ).
    DATA(lv_amount_doc_cur) = CONV fins_vwcur12( is_raw-amountindoumentcurrency / lv_doc_cur ).
    DATA(lv_tax_base_doc)   = CONV fins_vwcur12( is_raw-taxbaseamount / lv_doc_cur ).

    TRY.
        es_item = VALUE #( idline                  = is_raw-idline
                           accountingdocumentitem  = |{ is_raw-accountingdocumentitem ALPHA = IN }|
                           postingkey              = is_raw-postingkey
                           account                 = |{ is_raw-account                ALPHA = IN }|
                           mainassetnumber         = |{ is_raw-mainassetnumber         ALPHA = IN }|
                           subassetnumber          = |{ is_raw-subassetnumber          ALPHA = IN }|
                           profitcenter            = |{ is_raw-profitcenter            ALPHA = IN }|
                           invoicerefnum           = |{ is_raw-invoicerefnum           ALPHA = IN }|
                           invoicereflineitem      = |{ is_raw-invoicereflineitem      ALPHA = IN }|
                           purchasingno            = |{ is_raw-purchasingno            ALPHA = IN }|
                           purchasingitem          = |{ is_raw-purchasingitem          ALPHA = IN }|
                           saleorder               = |{ is_raw-saleorder               ALPHA = IN }|
                           saleorderitem           = |{ is_raw-saleorderitem           ALPHA = IN }|
                           customer                = |{ is_raw-customer                ALPHA = IN }|
                           product                 = |{ is_raw-product                 ALPHA = IN WIDTH = 18 }|

                           amountinlocalcurrency   = lv_amount_local
                           amountindoumentcurrency = lv_amount_doc_cur
                           taxbaseamount           = lv_tax_base_doc
                           localtaxbaseamount      = lv_local_tax_base

                           specialglaccount        = is_raw-specialglaccount
                           assettransactiontype    = is_raw-assettransactiontype
                           companycodecurrency     = is_raw-companycodecurrency
                           transactioncurrency     = is_raw-transactioncurrency
                           exchangerate            = is_raw-exchangerate
                           assignment              = is_raw-assignment
                           businessarea            = is_raw-businessarea
                           costcenter              = is_raw-costcenter
                           internalorder           = is_raw-internalorder
                           assetvaluedate          = is_raw-assetvaluedate
                           itemtext                = is_raw-itemtext
                           overrideglaccount       = is_raw-overrideglaccount
                           taxcode                 = is_raw-taxcode
                           segment                 = is_raw-segment
                           paymentterms            = is_raw-paymentterms
                           paymentblockreason      = is_raw-paymentblockreason
                           paymentmethod           = is_raw-paymentmethod
                           contractnumber          = is_raw-contractnumber
                           contracttype            = is_raw-contracttype
                           housebank               = is_raw-housebank
                           bankaccountid           = is_raw-bankaccountid
                           invoicereffiscalyear    = is_raw-invoicereffiscalyear
                           baselinedate            = is_raw-baselinedate
                           valuedate               = is_raw-valuedate

                           ref1                    = is_raw-ref_1
                           ref2                    = is_raw-ref_2
                           ref3                    = is_raw-ref_3
                           longtext                = is_raw-longtext
                           unit                    = is_raw-unit
                           name1                   = is_raw-name_1
                           name2                   = is_raw-name_2
                           name3                   = is_raw-name_3
                           name4                   = is_raw-name_4
                           city                    = is_raw-city
                           country                 = is_raw-country
                           mst                     = is_raw-mst
                           namecus1                = is_raw-namecus_1
                           namecus2                = is_raw-namecus_2
                           namecus3                = is_raw-namecus_3
                           namecus4                = is_raw-namecus_4
                           citycus                 = is_raw-citycus
                           countrycus              = is_raw-countrycus
                           mstcus                  = is_raw-mstcus
                           vatregno                = is_raw-vatregno
                           quantity                = is_raw-quantity
                           alternativepayee        = is_raw-alternativepayee
                           tennccxuathd            = is_raw-tennccxuathd
                           mstnccxuathd            = is_raw-mstnccxuathd
                           netduedate              = is_raw-netduedate
                           cusgroup                = is_raw-cusgroup
                           division                = is_raw-division
                           distributionchannel     = is_raw-distributionchannel
                           materialgroup           = is_raw-materialgroup
                           wbselement              = is_raw-wbselement
                           plant                   = is_raw-plant
                           salesorganization       = is_raw-salesorganization
                           countrygl               = is_raw-countrygl
                           namemotzeiv             = is_raw-namemotzeiv
                           cityzeiv                = is_raw-cityzeiv
                           baseunit                = is_raw-baseunit
                           orderid                 = is_raw-orderid
                           material                = is_raw-material
                           negativeposting         = is_raw-negativeposting ).

      CATCH cx_sy_conversion_no_number INTO DATA(lx_conv).
        APPEND VALUE #( filename = lv_filename
                        id_doc   = iv_doc_id
                        type     = 'Error'
                        message  = |ID Doc { iv_doc_id } - Dòng { is_raw-idline }: { lx_conv->get_longtext( ) }| )
               TO et_item_errors.
        rv_item_valid = abap_false.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
